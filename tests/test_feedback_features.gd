extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const PerformanceScorer = preload("res://scripts/gameplay/performance_scorer.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")

class UnitsTracker extends RefCounted:
	var calls: int = 0
	var origin: int = -1
	var units: Array = []
	func on_units(o: int, u: Array) -> void:
		calls += 1
		origin = o
		units = u

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING HINT LEVELS, UNIT COMPLETION & HAPTICS TESTS")
	print("========================================")

	test_hint_levels_charge_once()
	test_hint_cost_in_score_and_save()
	test_focus_unit()
	test_units_completed_signal()
	test_game_screen_hint_flow()
	test_haptics_setting()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")

	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _new_state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	return state

func test_hint_levels_charge_once() -> void:
	print("\n--- Test 1: Hint levels charge only the unpaid part ---")
	var state := _new_state(31415926)
	var step := SudokuSolver.find_best_hint(state.current_board, -1, state.solution)
	assert_true(step != null and state.get_hint_level(step) == 0, "Fresh hint starts at level 0")

	state.reveal_hint(step, GameState.HINT_LEVEL_FOCUS)
	assert_true(state.hint_cost == GameState.HINT_COST_FOCUS, "Area costs %d" % GameState.HINT_COST_FOCUS)
	state.reveal_hint(step, GameState.HINT_LEVEL_FOCUS)
	assert_true(state.hint_cost == GameState.HINT_COST_FOCUS, "Looking at the area again is free")
	state.reveal_hint(step, GameState.HINT_LEVEL_TECHNIQUE)
	assert_true(state.hint_cost == GameState.HINT_COST_TECHNIQUE, "Technique brings the total to %d" % GameState.HINT_COST_TECHNIQUE)
	assert_true(state.get_hint_level(step) == GameState.HINT_LEVEL_TECHNIQUE, "Level remembered for the same hint")

	state.apply_hint(step)
	assert_true(state.hint_cost == GameState.HINT_COST_APPLY and state.hints_used == 1, "Applying totals exactly one full hint (%d)" % state.hint_cost)

	state.apply_hint()
	assert_true(state.hint_cost == 2 * GameState.HINT_COST_APPLY and state.hints_used == 2, "A hint applied directly costs one full hint")

func test_hint_cost_in_score_and_save() -> void:
	print("\n--- Test 2: Hint cost feeds the score and survives a save ---")
	var clean := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 600.0, 600, 0, 0, 0, 0)
	var peeked := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 600.0, 600, 0, 0, 0, GameState.HINT_COST_FOCUS)
	assert_true(peeked < clean, "Only looking at an area lowers the score (%d < %d)" % [peeked, clean])
	assert_true(clean - peeked < 12, "...but less than a full hint")
	var old_save := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 600.0, 600, 0, 1, 0, 0)
	var new_save := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 600.0, 600, 0, 1, 0, GameState.HINT_COST_APPLY)
	assert_true(old_save == new_save, "Saves without hint_cost score applied hints as before")

	var state := _new_state(27182818)
	state.reveal_hint(SudokuSolver.find_best_hint(state.current_board, -1, state.solution), GameState.HINT_LEVEL_FOCUS)
	var loaded := SaveManager.import_game_from_string(SaveManager.export_game_to_string(state))
	assert_true(loaded.hint_cost == GameState.HINT_COST_FOCUS, "hint_cost restored on load")
	state.reset_for_replay()
	assert_true(state.hint_cost == 0, "Replay starts with no hint cost")

func test_focus_unit() -> void:
	print("\n--- Test 3: First-level hints point at a unit ---")
	var step := SudokuSolver.SolveStep.new()
	step.cells = [40]
	assert_true(SudokuSolver.get_focus_unit(step) == 18 + 4, "Without a unit, the box of the cell (box 5)")
	step.focus_unit = 3
	assert_true(SudokuSolver.get_focus_unit(step) == 3, "A step's own unit wins")
	var elim := SudokuSolver.SolveStep.new()
	elim.eliminations = { 80: [5] }
	assert_true(SudokuSolver.get_focus_unit(elim) == 18 + 8, "Elimination-only step uses its first cell's box")
	assert_true(SudokuSolver.get_unit_name(3).contains("4"), "Unit name is readable: %s" % SudokuSolver.get_unit_name(3))

	var state := _new_state(16180339)
	var hint := SudokuSolver.find_best_hint(state.current_board, -1, state.solution)
	assert_true(SudokuSolver.get_focus_unit(hint) >= 0, "Real hint has a focus unit (%s)" % hint.technique)

func test_units_completed_signal() -> void:
	print("\n--- Test 4: Completing a row, column or box emits units_completed ---")
	var state := _new_state(14142135)
	var tracker := UnitsTracker.new()
	state.units_completed.connect(tracker.on_units)

	# Fill row 0 from the solution, leaving its last empty cell for later
	var row: Array = SudokuBoard.ROW_INDICES[0]
	var empties: Array[int] = []
	for idx in row:
		if state.current_board.get_cell(idx) == 0:
			empties.append(idx)
	var last: int = empties.pop_back()
	for idx in empties:
		state.set_number(idx, state.solution.get_cell(idx))
	var before: int = tracker.calls

	# A conflicting digit must not count as completing the row
	var wrong: int = state.current_board.get_cell(row[0]) if row[0] != last else state.current_board.get_cell(row[1])
	state.set_number(last, wrong)
	assert_true(tracker.calls == before, "Conflicting digit does not complete the row")

	state.set_number(last, state.solution.get_cell(last))
	assert_true(tracker.calls == before + 1 and tracker.origin == last, "Signal fired once from the last cell")
	var has_row := false
	for u in tracker.units:
		if u == row:
			has_row = true
	assert_true(has_row, "Completed units include row 1")

	# Clearing and re-placing the same cell completes the row again
	state.set_number(last, state.solution.get_cell(last))
	state.set_number(last, state.solution.get_cell(last))
	assert_true(tracker.calls == before + 2, "Re-completing the row fires again")

func test_game_screen_hint_flow() -> void:
	print("\n--- Test 5: Hint button walks area -> technique -> apply ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(17320508)
	screen.setup_game(state)
	var filled_before: int = 81 - state.current_board.get_empty_cell_count()

	screen._on_hint_pressed()
	assert_true(screen.hint_dialog.ok_button_text == LocalizationManager.translate("HINT_SHOW_TECHNIQUE"), "Level 1 offers the technique next")
	assert_true(screen.sudoku_grid.hint_focus_unit >= 0, "Level 1 outlines a unit on the grid")
	assert_true(state.hint_cost == GameState.HINT_COST_FOCUS and state.hints_used == 0, "Level 1 charged, nothing placed")

	screen.hint_dialog.confirmed.emit()
	assert_true(screen.hint_dialog.ok_button_text == LocalizationManager.translate("HINT_APPLY_MOVE"), "Level 2 offers applying the move")
	assert_true(state.hint_cost == GameState.HINT_COST_TECHNIQUE, "Level 2 charged up to %d" % GameState.HINT_COST_TECHNIQUE)

	# Closing and pressing Hint again shows the technique again without charging more
	screen._on_hint_pressed()
	assert_true(state.hint_cost == GameState.HINT_COST_TECHNIQUE, "Reopening the same hint is free")

	screen.hint_dialog.confirmed.emit()
	assert_true(state.hints_used == 1 and state.hint_cost == GameState.HINT_COST_APPLY, "Applied as one full hint")
	assert_true(81 - state.current_board.get_empty_cell_count() == filled_before + 1, "Hint placed a digit")
	assert_true(screen.sudoku_grid.hint_focus_unit == -1, "Focus outline cleared after the move")

	state.is_paused = true
	screen._on_hint_pressed()
	assert_true(state.hint_cost == GameState.HINT_COST_APPLY, "Hint does nothing while paused")
	state.is_paused = false

	screen.sudoku_grid.play_units_completed(0, [SudokuBoard.ROW_INDICES[0]])
	assert_true(true, "Unit completion animation runs without errors")
	screen.queue_free()

func test_haptics_setting() -> void:
	print("\n--- Test 6: Vibration setting ---")
	assert_true(not Haptics.is_available(), "No vibration on desktop/headless")
	Haptics.tap()
	Haptics.conflict()
	Haptics.unit_completed()
	Haptics.game_completed()
	assert_true(true, "Haptics calls are safe where vibration is unavailable")

	var original: bool = AppSettings.haptics_enabled
	AppSettings.haptics_enabled = false
	AppSettings.save_config()
	AppSettings.haptics_enabled = true
	AppSettings.load_config()
	assert_true(AppSettings.haptics_enabled == false, "Vibration setting persists")
	AppSettings.haptics_enabled = original
	AppSettings.save_config()
