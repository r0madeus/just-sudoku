extends SceneTree

## Stage 2: the "Puzzle Solved" screen puts the solve in context and leads straight on to the
## next puzzle at the same level, this puzzle again, or the menu.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
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
	print("🧪 RUNNING RESULT SCREEN TESTS")
	print("========================================")
	AppSettings.animations_enabled = false
	var prev_locale := LocalizationManager.get_locale()
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)

	test_highlights()
	test_duration_words()
	test_benchmarks_skip_replays_and_assists()
	await test_result_dialog_and_new_puzzle()
	await test_new_puzzle_when_none_is_prepared()
	await test_menu_and_back_button()
	await test_assisted_result()

	LocalizationManager.set_locale(prev_locale)
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _t(key: String) -> String:
	return LocalizationManager.translate(key)

func test_highlights() -> void:
	print("\n--- Test 1: Context lines ---")
	var base := {"time": 300.0, "score": 90, "mistakes": 0, "hints": 0}
	var lines := ResultSummary.build_highlights(base, {"count": 0}, {})
	assert_true(lines == [_t("RESULT_FIRST_AT_LEVEL")], "First solve at a level: %s" % str(lines))

	lines = ResultSummary.build_highlights(base, {"count": 2, "best_time": 400.0, "avg_time": 450.0}, {})
	assert_true(lines == [_t("RESULT_FASTEST")], "Record with too few solves for an average: %s" % str(lines))

	lines = ResultSummary.build_highlights(base, {"count": 5, "best_time": 400.0, "avg_time": 380.0}, {})
	assert_true(lines.size() == 2 and lines[0] == _t("RESULT_FASTEST") and lines[1] == _t("RESULT_FASTER_THAN_AVG") % "1 min 20 s",
		"Record and faster than average: %s" % str(lines))

	lines = ResultSummary.build_highlights(base, {"count": 5, "best_time": 200.0, "avg_time": 255.0}, {})
	assert_true(lines == [_t("RESULT_SLOWER_THAN_AVG") % "45 s"], "Slower than average: %s" % str(lines))

	lines = ResultSummary.build_highlights(base, {"count": 5, "best_time": 200.0, "avg_time": 302.0}, {})
	assert_true(lines == [_t("RESULT_ON_AVG")], "Within a few seconds counts as on average: %s" % str(lines))

	var replay := base.duplicate()
	replay["is_replay"] = true
	lines = ResultSummary.build_highlights(replay, {"count": 5, "best_time": 1.0, "avg_time": 1.0}, {"score": 80})
	assert_true(lines == [_t("NEW_BEST_SCORE")], "Replay above the old best: %s" % str(lines))
	lines = ResultSummary.build_highlights(replay, {}, {"score": 95})
	assert_true(lines == [_t("SCORE_BEST_COMPARISON") % [95, 90]], "Replay below the old best: %s" % str(lines))

	var daily := base.duplicate()
	daily["is_daily"] = true
	lines = ResultSummary.build_highlights(daily, {"count": 5, "best_time": 400.0, "avg_time": 380.0}, {}, 3)
	assert_true(lines.size() == 2 and lines[0] == _t("RESULT_FASTEST") and lines[1] == _t("RESULT_DAILY") % LocalizationManager.format_streak(3),
		"Daily keeps its streak as the second line: %s" % str(lines))

	var assisted := base.duplicate()
	assisted["assisted"] = true
	lines = ResultSummary.build_highlights(assisted, {"count": 0}, {}, 3)
	assert_true(lines == [_t("RESULT_ASSISTED")], "A shown solution says so and nothing else: %s" % str(lines))

func test_duration_words() -> void:
	print("\n--- Test 2: Durations in words ---")
	assert_true(LocalizationManager.format_duration_words(80.0) == "1 min 20 s", "80 s -> %s" % LocalizationManager.format_duration_words(80.0))
	assert_true(LocalizationManager.format_duration_words(120.0) == "2 min", "120 s -> %s" % LocalizationManager.format_duration_words(120.0))
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	assert_true(LocalizationManager.format_duration_words(45.4) == "45 sn", "Turkish 45 s -> %s" % LocalizationManager.format_duration_words(45.4))
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)

func test_benchmarks_skip_replays_and_assists() -> void:
	print("\n--- Test 3: Level references count first solves only ---")
	var level := DifficultyAnalyzer.LEVEL_EXPERT
	var before := HistoryManager.get_level_benchmarks(level)
	HistoryManager.add_record({"game_id": "b1", "seed": 1, "difficulty": level, "time": 1234.0, "score": 70})
	HistoryManager.add_record({"game_id": "b2", "seed": 1, "difficulty": level, "time": 2.0, "score": 99, "is_replay": true})
	HistoryManager.add_record({"game_id": "b3", "seed": 2, "difficulty": level, "time": 1.0, "score": 50, "assisted": true})
	var after := HistoryManager.get_level_benchmarks(level)
	assert_true(after["count"] == before["count"] + 1, "Only the first solve counts (%d -> %d)" % [before["count"], after["count"]])
	assert_true(after["best_time"] > 2.0, "Replay and shown-solution times are not records (%.0f)" % after["best_time"])
	var stats: Dictionary = StatisticsManager.get_detailed_statistics()["difficulties"][level]
	assert_true(stats["best_time"] != 1.0, "Statistics ignore a shown solution for best time (%.0f)" % stats["best_time"])
	var last: Dictionary = HistoryManager.load_all_records().back()
	assert_true(last.get("assisted", false) == true, "History keeps the assisted flag")

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

func _new_screen(seed_val: int) -> GameScreen:
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	return screen

func test_result_dialog_and_new_puzzle() -> void:
	print("\n--- Test 4: Result shows the score and starts the next puzzle at once ---")
	var screen := _new_screen(9191)
	var finished := screen.game_state
	_finish(screen, finished)
	var dlg := screen.complete_dialog
	assert_true(dlg.visible, "Result opens")
	assert_true(screen.complete_summary.score_box.visible and screen.complete_summary.score_label.text == str(finished_score(finished)),
		"Score is shown (%s)" % screen.complete_summary.score_label.text)
	assert_true(screen.complete_summary.highlight_labels[0].visible, "At least one context line")
	assert_true(dlg.primary_btn.text == _t("BTN_NEW_SAME_LEVEL") % _t("DIFF_EASY"), "Primary action: %s" % dlg.primary_btn.text)
	assert_true(screen.complete_replay_btn.visible and dlg.cancel_btn.visible and dlg.cancel_btn.text == _t("BTN_MENU"), "Solve Again and Menu offered")
	assert_true(not dlg.close_btn.visible, "No ambiguous close button")

	# A prepared puzzle opens in the same frame
	var prepared := SudokuGenerator.generate(9292, DifficultyAnalyzer.LEVEL_EASY)
	PuzzlePrefetcher.put_back(prepared)
	dlg.primary_btn.pressed.emit()
	assert_true(screen.game_state != finished and screen.game_state.seed_value == 9292, "Next puzzle started from the prepared one")
	assert_true(not screen.game_state.is_completed and screen.game_state.difficulty == DifficultyAnalyzer.LEVEL_EASY, "Same level, fresh board")
	assert_true(not dlg.visible, "Result closed")
	var active := SaveManager.load_active_game()
	assert_true(active != null and active.game_id == screen.game_state.game_id, "New puzzle is the one Continue resumes")
	screen.queue_free()
	await _frames(2)

func finished_score(state: GameState) -> int:
	return int(HistoryManager.load_all_records().back().get("score", -1)) if state.is_completed else -1

func test_new_puzzle_when_none_is_prepared() -> void:
	print("\n--- Test 5: Without a prepared puzzle the result waits and then starts it ---")
	var screen := _new_screen(9393)
	var finished := screen.game_state
	_finish(screen, finished)
	PuzzlePrefetcher.take(DifficultyAnalyzer.LEVEL_EASY) # make sure none is waiting
	var dlg := screen.complete_dialog
	dlg.primary_btn.pressed.emit()
	assert_true(dlg.visible and dlg.primary_btn.disabled, "Result stays open, button busy")
	assert_true(dlg.primary_btn.text == _t("LOADING_PUZZLE") % _t("DIFF_EASY"), "Busy text: %s" % dlg.primary_btn.text)
	var frames := 0
	while screen.game_state == finished and frames < 3000:
		await process_frame
		frames += 1
	assert_true(screen.game_state != finished and not screen.game_state.is_completed, "Next puzzle started after %d frames" % frames)
	assert_true(not dlg.visible, "Result closed")
	screen.queue_free()
	await _frames(2)

func test_menu_and_back_button() -> void:
	print("\n--- Test 6: Menu and the back button leave the result for the menu ---")
	var app := AppRoot.new()
	root.add_child(app)
	# AppRoot loads the saved settings, which may turn animations back on
	AppSettings.animations_enabled = false
	await _frames(5)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(9494, DifficultyAnalyzer.LEVEL_EASY))
	app._start_game_session(state)
	await _frames(3)
	_finish(app.game_screen, state)
	assert_true(app.game_screen.complete_dialog.visible, "Result open")
	app.handle_back()
	await _frames(3)
	assert_true(app.current_screen == app.main_menu and not app.game_screen.complete_dialog.visible, "Back goes to the menu")

	var state2 := GameState.new()
	state2.init_from_puzzle(SudokuGenerator.generate(9595, DifficultyAnalyzer.LEVEL_EASY))
	app._start_game_session(state2)
	await _frames(3)
	_finish(app.game_screen, state2)
	app.game_screen.complete_dialog.cancel_btn.pressed.emit()
	await _frames(3)
	assert_true(app.current_screen == app.main_menu, "Menu button goes to the menu")
	app.queue_free()
	await _frames(2)

func test_assisted_result() -> void:
	print("\n--- Test 7: A shown solution gets no score on the result ---")
	var screen := _new_screen(9696)
	screen._on_solution_applied(screen.game_state.solution)
	assert_true(screen.complete_dialog.visible, "Result opens")
	assert_true(not screen.complete_summary.score_box.visible, "Score hidden")
	assert_true(screen.complete_summary.highlight_labels[0].text == _t("RESULT_ASSISTED"), "Says the solution was shown")
	var last: Dictionary = HistoryManager.load_all_records().back()
	assert_true(last.get("assisted", false) == true, "Recorded as assisted")
	screen.queue_free()
	await _frames(2)
