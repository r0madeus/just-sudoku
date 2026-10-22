extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const LoadGameScreen = preload("res://scenes/menus/load_game_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var _base: SudokuGenerator.GeneratedPuzzle

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

func _new_state() -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(_base)
	state.game_id = "test_%d_%d" % [Time.get_ticks_usec(), randi()]
	return state

## Fills every empty cell but `keep` with the solution; returns the cell left empty
func _fill_all_but_one(state: GameState) -> int:
	var last := -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			if last != -1:
				state.set_number(last, state.solution.get_cell(last))
			last = i
	return last

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING SAVED GAMES LIST & FINISHED GAME TESTS")
	print("========================================")
	SettingsScreen.animations_enabled = false
	_base = SudokuGenerator.generate(5151, DifficultyAnalyzer.LEVEL_EASY)

	await test_saved_games_list_builds_in_batches()
	await test_history_list_builds_across_frames()
	test_finished_game_is_not_resumable()
	test_finished_active_save_heals()
	test_backups_need_an_active_save()
	test_delete_active_game()
	test_solution_from_pause_closes_overlay()
	test_finished_game_has_no_clock()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func test_saved_games_list_builds_in_batches() -> void:
	print("\n--- Test 1: Saved games list shows the first cards at once, the rest over frames ---")
	for i in range(LoadGameScreen.FIRST_BATCH + 15):
		SaveManager.save_game_slot(_new_state())
	var total: int = SaveManager.list_active_games().size()

	var screen := LoadGameScreen.new()
	root.add_child(screen)
	await process_frame
	screen.refresh_list()
	assert_true(screen.list_vbox.get_child_count() == LoadGameScreen.FIRST_BATCH, "First batch built at once (%d of %d)" % [screen.list_vbox.get_child_count(), total])

	# A refresh while the rest is still being added starts over instead of mixing two lists
	await process_frame
	screen.refresh_list()
	await _frames(total / LoadGameScreen.BATCH_PER_FRAME + 5)
	assert_true(screen.list_vbox.get_child_count() == total, "All %d cards present, none twice (%d)" % [total, screen.list_vbox.get_child_count()])
	screen.queue_free()

func test_history_list_builds_across_frames() -> void:
	print("\n--- Test 2: History adds its batches on later frames ---")
	for i in range(HistoryScreen.BATCH_SIZE + 5):
		HistoryManager.add_record({"game_id": "hist_%d" % i, "seed": 1000 + i, "difficulty": DifficultyAnalyzer.LEVEL_EASY, "score": 80, "time": 100.0})
	var screen := HistoryScreen.new()
	root.add_child(screen)
	await process_frame
	screen.refresh_history()
	var first: int = screen.list_vbox.get_child_count()
	await process_frame
	await process_frame
	var later: int = screen.list_vbox.get_child_count()
	assert_true(first == HistoryScreen.BATCH_SIZE, "Only the first batch in the opening frame (%d)" % first)
	assert_true(later > first, "More cards added on the next frames (%d)" % later)
	screen.queue_free()

func test_finished_game_is_not_resumable() -> void:
	print("\n--- Test 3: Finishing a game leaves nothing to resume ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state()
	screen.setup_game(state)
	var last := _fill_all_but_one(state)
	SaveManager.save_active_game(state)
	assert_true(SaveManager.has_active_game(), "In-progress game is resumable")

	screen.sudoku_grid.select_cell(last)
	screen._on_numpad_number_pressed(state.solution.get_cell(last))
	assert_true(state.is_completed, "Game finished")
	assert_true(not SaveManager.has_active_game(), "No active save after finishing")
	assert_true(SaveManager.load_active_game() == null, "Continue has nothing to load")
	var entry: Dictionary = SaveManager.get_games_index().get(state.game_id, {})
	assert_true(entry.get("is_completed", false) == true, "Index marks the game finished")
	assert_true(SaveManager.list_active_games().filter(func(g): return g.get("game_id") == state.game_id).is_empty(), "Finished game left the saved games list")
	screen.queue_free()

func test_finished_active_save_heals() -> void:
	print("\n--- Test 4: A finished game saved as active by older versions is dropped ---")
	var state := _new_state()
	state.is_completed = true
	SaveManager.safe_write_active(state.serialize())
	assert_true(not SaveManager.has_active_game(), "Finished active save is not offered")
	assert_true(not FileAccess.file_exists(SaveManager.ACTIVE_GAME_FILE), "...and is removed")

func test_backups_need_an_active_save() -> void:
	print("\n--- Test 5: Backups only stand in for an unreadable active save ---")
	var a := _new_state()
	var b := _new_state()
	SaveManager.save_active_game(a)
	SaveManager.save_active_game(b) # a is now the backup
	SaveManager.clear_active_game()
	assert_true(SaveManager.load_active_game() == null, "Cleared active save does not bring back an older game")

	SaveManager.save_active_game(a)
	SaveManager.save_active_game(b)
	var f := FileAccess.open(SaveManager.ACTIVE_GAME_FILE, FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var recovered := SaveManager.load_active_game()
	assert_true(recovered != null and recovered.game_id == a.game_id, "Corrupted active save recovers from the backup")
	SaveManager.clear_active_game()

func test_delete_active_game() -> void:
	print("\n--- Test 6: Deleting the active game from the list removes it from Continue ---")
	var state := _new_state()
	SaveManager.save_active_game(state)
	SaveManager.delete_game_slot(state.game_id)
	assert_true(not SaveManager.has_active_game(), "Continue no longer offers the deleted game")
	var other := _new_state()
	SaveManager.save_active_game(other)
	SaveManager.delete_game_slot(state.game_id)
	assert_true(SaveManager.has_active_game(), "Deleting another game keeps the active one")
	SaveManager.clear_active_game()

func test_solution_from_pause_closes_overlay() -> void:
	print("\n--- Test 7: Show Solution (in the pause menu) closes the pause ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state()
	screen.setup_game(state)
	screen.toggle_pause()
	assert_true(state.is_paused and screen.pause_overlay.visible, "Paused")
	screen._on_solution_applied(state.solution)
	assert_true(state.is_completed, "Solution completes the game")
	assert_true(not state.is_paused and not screen.pause_overlay.visible, "Pause overlay closed, game not stuck paused")
	screen.queue_free()

func test_finished_game_has_no_clock() -> void:
	print("\n--- Test 8: Opening a finished game shows its time without a running clock ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state()
	state.elapsed_time = 125.0
	state.is_completed = true
	screen.setup_game(state)
	assert_true(not screen.game_timer.is_running, "Clock stopped")
	assert_true(screen.timer_label.text == GameTimer.format_seconds(125.0), "Final time shown (%s)" % screen.timer_label.text)
	screen.queue_free()
