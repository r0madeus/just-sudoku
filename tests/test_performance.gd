extends SceneTree

## RUN ALONE: it measures frames drawn and the time of cell selections, which other suites running at the same time would skew

## Performance guards: an idle screen is not redrawn, a tap on the board does not re-style all
## 81 cells, the board is built from few nodes, and hidden lists are not built at start.
## Timings have wide margins (about 10x the measured cost) so slower machines still pass.

const GameState = preload("res://scripts/gameplay/game_state.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var app: AppRoot

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

func _wait_ms(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING PERFORMANCE TESTS")
	print("========================================")
	SettingsScreen.auto_open_last_game = false
	SettingsScreen.animations_enabled = false
	for i in range(40):
		HistoryManager.add_record({"game_id": "perf_%d" % i, "seed": 300 + i, "difficulty": DifficultyAnalyzer.LEVEL_EASY, "score": 70, "time": 100.0})

	app = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(10)

	print("\n--- Test 1: Hidden lists are not built at start ---")
	assert_true(app.history_screen.list_vbox.get_child_count() == 0 and app.load_game_screen.list_vbox.get_child_count() == 0,
		"History and Saved games wait until they are opened")

	print("\n--- Test 2: An idle screen is not redrawn ---")
	assert_true(ProjectSettings.get_setting("application/run/low_processor_mode", false), "Low processor mode is on")
	OS.low_processor_usage_mode = true
	await _wait_ms(300)
	var f0 := Engine.get_frames_drawn()
	await _wait_ms(1000)
	var drawn: int = Engine.get_frames_drawn() - f0
	assert_true(drawn <= 2, "The menu draws %d frames in an idle second" % drawn)

	print("\n--- Test 3: The board ---")
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_MEDIUM))
	app._start_game_session(state)
	await _frames(3)
	var grid = app.game_screen.sudoku_grid
	var board_nodes: int = grid.find_children("*", "Node", true, false).size()
	assert_true(board_nodes < 500, "The board is %d nodes (notes are drawn, not 729 labels)" % board_nodes)
	var empty: Array[int] = []
	for i in range(81):
		if state.current_board.get_cell(i) == 0:
			empty.append(i)
	var t0 := Time.get_ticks_usec()
	for i in range(50):
		grid.select_cell(empty[i % empty.size()])
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(ms < 300.0, "50 cell selections take %.0f ms (about 1100 ms when every cell was re-styled)" % ms)

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)
