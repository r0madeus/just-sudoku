extends SceneTree

## Stage 3: Saved games, History and Statistics share one list design: rows grouped in one
## card, each row = thumbnail, title line, detail line and a single round primary action.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const LoadGameScreen = preload("res://scenes/menus/load_game_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")
const StatisticsScreen = preload("res://scenes/menus/statistics_screen.gd")
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
	print("🧪 RUNNING LIST CARD TESTS")
	print("========================================")
	SettingsScreen.animations_enabled = false

	test_thumbnail_data_is_stored()
	test_mini_board_from_strings()
	await test_rows_share_one_structure()
	await test_saved_game_actions_sheet()
	await test_lists_sit_in_one_card()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	state.game_id = "list_%d_%d" % [seed_val, Time.get_ticks_usec()]
	return state

func test_thumbnail_data_is_stored() -> void:
	print("\n--- Test 1: Lists know the board without opening every save ---")
	var state := _state(3131)
	var idx: int = 0
	while state.current_board.get_cell(idx) != 0:
		idx += 1
	state.set_number(idx, state.solution.get_cell(idx))
	SaveManager.save_game_slot(state)
	var entry: Dictionary = SaveManager.get_games_index().get(state.game_id, {})
	assert_true(entry.get("initial", "") == state.initial_puzzle.to_string_flat(), "Index keeps the starting digits")
	assert_true(entry.get("current", "") == state.current_board.to_string_flat(), "Index keeps the current board")

	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup_game(state)
	var last := -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			if last != -1:
				state.set_number(last, state.solution.get_cell(last))
			last = i
	screen.sudoku_grid.select_cell(last)
	screen._on_numpad_number_pressed(state.solution.get_cell(last))
	var record: Dictionary = HistoryManager.load_all_records().back()
	assert_true(record.get("puzzle", "") == state.initial_puzzle.to_string_flat(), "History keeps the puzzle")
	screen.queue_free()

func test_mini_board_from_strings() -> void:
	print("\n--- Test 2: Thumbnails from stored strings ---")
	var board := MiniBoard.new()
	var initial := "5" + "0".repeat(80)
	var current := "53" + "0".repeat(79)
	board.set_strings(current, initial)
	assert_true(not board._decorative and board._values[0] == 5 and board._values[1] == 3, "Digits read")
	assert_true(board._given[0] == 1 and board._given[1] == 0, "Starting digits told apart from the player's")
	board.set_strings("")
	assert_true(board._decorative, "Older entries without a board show the quiet sample")
	board.free()

## [thumbnail, info, ..., primary action] in the row's first child
func _row_shape(item: GameRecordItem) -> Dictionary:
	var hbox: HBoxContainer = item.get_child(0)
	var kids := hbox.get_children()
	var last: Control = kids.back()
	return {
		"thumb": kids[0] is MiniBoard and kids[0].custom_minimum_size == Vector2(GameRecordItem.THUMB_SIZE, GameRecordItem.THUMB_SIZE),
		"info": kids[1] is VBoxContainer,
		"primary": last is Button and last.get_meta("primary", false),
		"primary_size": last.custom_minimum_size,
	}

func test_rows_share_one_structure() -> void:
	print("\n--- Test 3: Saved game and history rows are built the same way ---")
	var saved := GameRecordItem.new()
	root.add_child(saved)
	saved.setup_saved_game({"game_id": "g1", "difficulty": "Hard", "progress_percentage": 40, "elapsed_time": 90.0,
		"initial": "5" + "0".repeat(80), "current": "53" + "0".repeat(79)})
	var hist := GameRecordItem.new()
	root.add_child(hist)
	hist.setup_history({"difficulty": "Hard", "score": 80, "time": 90.0, "seed": 5, "puzzle": "5" + "0".repeat(80)})
	await process_frame

	var a := _row_shape(saved)
	var b := _row_shape(hist)
	for key in ["thumb", "info", "primary"]:
		assert_true(a[key] and b[key], "Both rows have %s" % key)
	assert_true(a["primary_size"] == b["primary_size"], "Primary actions are the same size")
	assert_true(saved.thumbnail._values[1] == 3, "Saved row shows its own board")
	assert_true(saved.progress_label.size.x > 0 and saved.time_label.size.x > 0, "Detail line is not squeezed away")
	assert_true(hist.time_label.size.x > 0 and hist.mistakes_label.size.x > 0, "History detail line is not squeezed away")
	saved.queue_free()
	hist.queue_free()
	await _frames(2)

func test_saved_game_actions_sheet() -> void:
	print("\n--- Test 4: Share and Delete sit behind ⋯ ---")
	var item := GameRecordItem.new()
	root.add_child(item)
	item.setup_saved_game({"game_id": "sheet_1", "difficulty": "Medium", "progress_percentage": 10, "elapsed_time": 5.0})
	var shared := {"id": "", "btn": null}
	var deleted := {"id": ""}
	item.share_pressed.connect(func(id, btn):
		shared["id"] = id
		shared["btn"] = btn)
	item.delete_pressed.connect(func(id): deleted["id"] = id)

	var sheet := item.open_actions()
	assert_true(sheet.visible and item.share_btn != null and item.delete_btn != null, "Sheet offers Share and Delete")
	item.share_btn.pressed.emit()
	assert_true(shared["id"] == "sheet_1" and shared["btn"] == item.share_btn, "Share reports the game and its button")
	assert_true(sheet.visible, "Sheet stays open to show the copied state")
	item.delete_btn.pressed.emit()
	assert_true(deleted["id"] == "sheet_1", "Delete reports the game")
	assert_true(not sheet.visible, "Sheet closes so the delete confirmation can take over")
	item.queue_free()
	await _frames(2)

func test_lists_sit_in_one_card() -> void:
	print("\n--- Test 5: Each list is one card ---")
	var saved := LoadGameScreen.new()
	root.add_child(saved)
	var history := HistoryScreen.new()
	root.add_child(history)
	var stats := StatisticsScreen.new()
	root.add_child(stats)
	await _frames(3)
	saved.refresh_list()
	history.refresh_history()
	stats.refresh_stats()
	await _frames(3)
	assert_true(saved.list_card is GlassPanel and saved.list_vbox.get_parent() == saved.list_card, "Saved games rows are inside one card")
	assert_true(history.list_card is GlassPanel and history.list_vbox.get_parent() == history.list_card, "History rows are inside one card")
	var cards := stats.find_children("*", "PanelContainer", true, false).filter(func(n): return n is GlassPanel)
	assert_true(cards.size() >= 3, "Statistics: overview, streak and by-difficulty are all cards (%d)" % cards.size())
	saved.queue_free()
	history.queue_free()
	stats.queue_free()
	await _frames(2)
