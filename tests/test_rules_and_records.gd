extends SceneTree

## Rules a player sees the result of, which the test audit found unguarded (a deliberate break
## in each went unnoticed by every other suite): how the score counts mistakes, hints and a
## clean solve; that a paused game cannot be changed; that a hint places the right digit; that
## statistics keep the fastest time; and that solving the Daily marks the day done.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const StatisticsManager = preload("res://scripts/data/statistics_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	_run.call_deferred()

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING RULES AND RECORDS TESTS")
	print("========================================")
	AppSettings.animations_enabled = false
	AppSettings.show_wrong_immediately = false
	# The player's own history and Daily dates are put back afterwards
	var saved_records: Array[Dictionary] = HistoryManager.load_all_records(true).duplicate(true)
	var saved_daily: Dictionary = DailyManager.load_daily_data()

	test_score()
	test_paused_game_is_locked()
	test_hint_places_the_right_digit()
	test_statistics_keep_the_fastest_time()
	await test_daily_marked_done()

	HistoryManager.save_all_records(saved_records)
	DailyManager.save_daily_data(saved_daily)
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func test_score() -> void:
	print("\n--- Test 1: Score (GDD §25) ---")
	# Medium, solved in exactly the estimated time: base 82, no time bonus or deduction
	var lvl := DifficultyAnalyzer.LEVEL_MEDIUM
	var clean := PerformanceScorer.calculate_score(lvl, 600.0, 600, 0, 0)
	var one_mistake := PerformanceScorer.calculate_score(lvl, 600.0, 600, 1, 0)
	var two_mistakes := PerformanceScorer.calculate_score(lvl, 600.0, 600, 2, 0)
	var one_hint := PerformanceScorer.calculate_score(lvl, 600.0, 600, 0, 1)
	assert_true(clean == 87, "Clean solve: base 82 + 5 bonus = %d" % clean)
	assert_true(one_mistake == 76 and two_mistakes == 70, "Each mistake costs 6 and loses the clean bonus (%d, %d)" % [one_mistake, two_mistakes])
	assert_true(one_hint == 70, "An applied hint costs 12 and loses the clean bonus (%d)" % one_hint)
	assert_true(PerformanceScorer.calculate_score(lvl, 600.0, 600, 0, 0, 0, 4) == 78, "Hints only looked at cost their hint_cost, no clean bonus")
	var fast := PerformanceScorer.calculate_score(lvl, 300.0, 600, 0, 0)
	var slow := PerformanceScorer.calculate_score(lvl, 1200.0, 600, 0, 0)
	assert_true(fast > clean and slow < clean, "Faster than the estimate scores more, slower less (%d / %d / %d)" % [fast, clean, slow])
	assert_true(PerformanceScorer.calculate_score(lvl, 600.0, 600, 30, 5) == 0, "Never below 0")

func _new_state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	return state

func _first_empty(state: GameState) -> int:
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			return i
	return -1

func test_paused_game_is_locked() -> void:
	print("\n--- Test 2: A paused game cannot be changed ---")
	var state := _new_state(8101)
	var idx := _first_empty(state)
	state.is_paused = true
	assert_true(not state.can_edit_cell(idx), "Cells are not editable while paused")
	assert_true(not state.set_number(idx, state.solution.get_cell(idx)) and state.current_board.get_cell(idx) == 0, "A digit is not placed")
	assert_true(not state.toggle_candidate(idx, 3) and not state.current_board.has_candidate(idx, 3), "A note is not added")
	state.is_paused = false
	assert_true(state.set_number(idx, state.solution.get_cell(idx)), "Resumed: the same move works")

func test_hint_places_the_right_digit() -> void:
	print("\n--- Test 3: A hint places the solution's digit ---")
	var state := _new_state(8202)
	var placed := 0
	for i in range(5):
		var step := state.apply_hint()
		if step != null and step.digit != 0 and step.cells.size() == 1:
			var cell: int = step.cells[0]
			assert_true(state.current_board.get_cell(cell) == state.solution.get_cell(cell),
				"Hint %d: cell %d gets %d (solution %d)" % [i + 1, cell, state.current_board.get_cell(cell), state.solution.get_cell(cell)])
			placed += 1
	assert_true(placed >= 3, "Hints placed digits (%d of 5)" % placed)
	assert_true(state.hints_used == 5, "Every applied hint is counted (%d)" % state.hints_used)

func test_statistics_keep_the_fastest_time() -> void:
	print("\n--- Test 4: Statistics keep the fastest time per level ---")
	var lvl := DifficultyAnalyzer.LEVEL_HARD
	var records: Array[Dictionary] = []
	for t in [300.0, 120.0, 200.0]:
		records.append({"game_id": "s%d" % t, "seed": "1", "difficulty": lvl, "score": 80, "time": t, "mistakes": 0, "hints": 0, "timestamp": 1})
	records.append({"game_id": "slow", "seed": "2", "difficulty": lvl, "score": 95, "time": 900.0, "mistakes": 0, "hints": 0, "timestamp": 2})
	HistoryManager.save_all_records(records)
	var entry: Dictionary = StatisticsManager.get_detailed_statistics()["difficulties"][lvl]
	assert_true(is_equal_approx(float(entry["best_time"]), 120.0), "Best time is the fastest (%.0f s)" % float(entry["best_time"]))
	assert_true(int(entry["best_score"]) == 95, "Best score is the highest (%d)" % int(entry["best_score"]))
	assert_true(int(entry["count"]) == 4, "Every solve counted (%d)" % int(entry["count"]))

## Plays `state` up to its last empty cell on `screen` and fills it
func _finish(screen: GameScreen, state: GameState) -> void:
	var last := -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			if last != -1:
				state.set_number(last, state.solution.get_cell(last))
			last = i
	screen.sudoku_grid.select_cell(last)
	screen._on_numpad_number_pressed(state.solution.get_cell(last))

func test_daily_marked_done() -> void:
	print("\n--- Test 5: Solving the Daily marks the day done ---")
	DailyManager.save_daily_data({"completed_dates": [], "current_streak": 0, "longest_streak": 0, "last_completed_date": ""})
	assert_true(not DailyManager.is_today_completed(), "Today starts open")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(DailyManager.get_today_seed(), DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	_finish(screen, state)
	await _frames(2)
	assert_true(state.is_completed and DailyManager.is_today_completed(), "Today's Daily is marked done")
	assert_true(DailyManager.get_current_streak() == 1, "Streak starts at 1 (%d)" % DailyManager.get_current_streak())
	var last: Dictionary = HistoryManager.load_all_records().back()
	assert_true(last.get("is_daily", false), "The record says it was the Daily")
	screen.queue_free()
	await _frames(2)
