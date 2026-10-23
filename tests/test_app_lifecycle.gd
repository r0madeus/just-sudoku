extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING APP LIFECYCLE & UNDO EDGE CASE TESTS")
	print("========================================")

	test_elimination_hint_undo_redo()
	test_undo_blocked_while_paused()
	test_active_save_replaces_atomically()
	test_focus_out_pauses_and_saves()
	test_back_stops_clock_and_new_game_closes_pause()

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

func _first_empty(state: GameState, skip: int = -1) -> int:
	for i in range(SudokuBoard.CELL_COUNT):
		if i != skip and state.current_board.get_cell(i) == 0:
			return i
	return -1

func test_elimination_hint_undo_redo() -> void:
	print("\n--- Test 1: Elimination hints can be undone and redone ---")
	var state := _new_state(31415926)
	var a: int = _first_empty(state)
	var b: int = _first_empty(state, a)
	state.current_board.clear_candidates(a)
	state.current_board.clear_candidates(b)
	state.current_board.add_candidate(a, 3)
	state.current_board.add_candidate(a, 7)
	state.current_board.add_candidate(b, 5)

	var step := SudokuSolver.SolveStep.new()
	step.eliminations = { a: [3, 7], b: [5, 9] }
	state.apply_hint(step)
	assert_true(state.current_board.candidates[a] == 0 and state.current_board.candidates[b] == 0, "Hint removed the notes")
	assert_true(state.can_undo(), "Elimination hint is on the undo stack")

	# Round-trip through a save, as a real resume would
	var loaded := SaveManager.import_game_from_string(SaveManager.export_game_to_string(state))
	assert_true(loaded.undo(), "Undo of the elimination hint succeeds after reload")
	assert_true(loaded.current_board.has_candidate(a, 3) and loaded.current_board.has_candidate(a, 7)
		and loaded.current_board.has_candidate(b, 5), "Undo restored the removed notes")
	assert_true(not loaded.current_board.has_candidate(b, 9), "Undo did not add a note the hint never removed")
	assert_true(loaded.redo(), "Redo of the elimination hint succeeds")
	assert_true(loaded.current_board.candidates[a] == 0 and loaded.current_board.candidates[b] == 0, "Redo removed the notes again")

func test_undo_blocked_while_paused() -> void:
	print("\n--- Test 2: Undo/Redo are blocked while paused ---")
	var state := _new_state(27182818)
	var idx: int = _first_empty(state)
	state.set_number(idx, state.solution.get_cell(idx))
	state.is_paused = true
	assert_true(not state.can_undo() and not state.undo(), "Undo refused while paused")
	assert_true(state.current_board.get_cell(idx) != 0, "Board unchanged while paused")
	state.is_paused = false
	assert_true(state.undo(), "Undo works again after resuming")
	state.is_paused = true
	assert_true(not state.can_redo() and not state.redo(), "Redo refused while paused")

func test_active_save_replaces_atomically() -> void:
	print("\n--- Test 3: Active save is replaced in place, no temp file left ---")
	var state := _new_state(16180339)
	assert_true(SaveManager.save_active_game(state), "First save succeeds")
	state.elapsed_time = 321.0
	assert_true(SaveManager.save_active_game(state), "Overwriting save succeeds")
	assert_true(not FileAccess.file_exists(SaveManager.ACTIVE_GAME_FILE + ".tmp"), "Temp file was moved into place")
	var loaded := SaveManager.load_active_game()
	assert_true(loaded != null and loaded.elapsed_time == 321.0, "Latest save is the active one")

func test_focus_out_pauses_and_saves() -> void:
	print("\n--- Test 4: Leaving the app pauses the clock and saves ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(14142135)
	screen.setup_game(state)
	screen.game_timer.elapsed_time = 77.5

	screen.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(state.is_paused, "Game paused on focus loss")
	assert_true(not screen.game_timer.is_running, "Clock stopped on focus loss")
	var saved := SaveManager.load_active_game()
	assert_true(saved != null and saved.game_id == state.game_id and saved.elapsed_time == 77.5, "Exact elapsed time saved on focus loss")

	# A second focus loss while already paused must not resume the game
	screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(state.is_paused, "Still paused after a second background notification")

	screen.toggle_pause()
	screen.game_timer.elapsed_time = 90.0
	screen.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	saved = SaveManager.load_active_game()
	assert_true(saved != null and saved.elapsed_time == 90.0, "Exact elapsed time saved on window close")
	screen.queue_free()

func test_back_stops_clock_and_new_game_closes_pause() -> void:
	print("\n--- Test 5: Back stops the clock; a new game never starts under the pause overlay ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup_game(_new_state(17320508))
	screen._on_back_pressed()
	assert_true(not screen.game_timer.is_running, "Clock stopped after leaving a running game")

	screen.setup_game(_new_state(17320508))
	screen.toggle_pause()
	screen._on_back_pressed()

	# Without animations the overlay closes synchronously, so it can be checked here
	var animations: bool = AppSettings.animations_enabled
	AppSettings.animations_enabled = false
	var next := _new_state(22360679)
	screen.setup_game(next)
	assert_true(not next.is_paused and screen.game_timer.is_running, "New game runs")
	assert_true(not screen.pause_overlay.visible, "Pause overlay closed for the new game")
	AppSettings.animations_enabled = animations
	screen.queue_free()
