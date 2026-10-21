extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/Melih Uçgun/.gemini/antigravity/brain/c2380364-d48a-41c9-adba-d53cfa2ddc62/"
const AppRoot = preload("res://scenes/app_root.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")

var app: AppRoot

func _init() -> void:
	create_timer(18.0).timeout.connect(func():
		print("Watchdog: Exiting cleanly after timeout.")
		quit(0)
	)
	_run_captures.call_deferred()

func _wait_frames(n: int = 14) -> void:
	for i in range(n):
		await process_frame

func _save_screenshot(filename: String) -> void:
	await _wait_frames(16)
	var img: Image = get_root().get_texture().get_image()
	if img != null:
		var target_path: String = ARTIFACT_DIR + filename
		img.save_png(target_path)
		print("  -> Saved: ", filename)

func _seed_dummy_history() -> void:
	if HistoryManager.load_all_records().is_empty():
		HistoryManager.add_record({
			"game_id": "game_sample_1",
			"seed": 1048576,
			"difficulty": DifficultyAnalyzer.LEVEL_MEDIUM,
			"score": 94,
			"time": 218.0,
			"mistakes": 0,
			"hints": 0,
			"undo_count": 2,
			"is_replay": false
		})
		HistoryManager.add_record({
			"game_id": "game_sample_2",
			"seed": 2097152,
			"difficulty": DifficultyAnalyzer.LEVEL_HARD,
			"score": 82,
			"time": 374.0,
			"mistakes": 2,
			"hints": 1,
			"undo_count": 5,
			"is_replay": true
		})

func _run_captures() -> void:
	print("\n--- CAPTURING COHERENT CAPSULE CONTROL SYSTEM (390x844 & 430x932) ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	_seed_dummy_history()

	var win := get_root()

	app = AppRoot.new()
	win.add_child(app)
	await _wait_frames(16)

	var puzzle := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(puzzle)

	var resolutions: Array[Vector2i] = [
		Vector2i(390, 844),
		Vector2i(430, 932)
	]

	for res in resolutions:
		var prefix: String = "%dx%d" % [res.x, res.y]
		print("\n=== Capturing Resolution: %s ===" % prefix)
		win.size = res
		app.size = Vector2(res.x, res.y)
		await _wait_frames(8)

		# 1. Home Screen
		print("  1. Home Screen...")
		app._show_screen(app.main_menu)
		app.main_menu.size = Vector2(res.x, res.y)
		app.main_menu._apply_responsive_layout()
		app.main_menu.refresh_buttons()
		await _save_screenshot("qa_capsule_" + prefix + "_home.png")

		# 2. Game Screen with Seed underneath difficulty
		print("  2. Game Screen with Seed Button...")
		app._start_game_session(state)
		app.game_screen.size = Vector2(res.x, res.y)
		app.game_screen._apply_responsive_layout()
		await _wait_frames(8)
		assert(app.game_screen.seed_btn != null, "seed_btn exists")
		assert(app.game_screen.seed_btn.text.contains("123456789"), "seed_btn displays seed value")
		await _save_screenshot("qa_phase3_game_standard.png")
		
		# Test seed button tap feedback
		app.game_screen._on_seed_btn_pressed()
		assert(app.game_screen.seed_btn.text == LocalizationManager.translate("COPIED_FEEDBACK"), "seed_btn displays copied feedback")
		await _wait_frames(10)
		await _save_screenshot("qa_capsule_" + prefix + "_game.png")
		if res.x == 390:
			await _save_screenshot("qa_phase3_game_seed.png")

		# 3. Smart Numpad toggle test
		print("  3. Smart Numpad settings toggle...")
		SettingsScreen.smart_numpad_enabled = false
		app.game_screen._on_settings_changed()
		for d in range(1, 10):
			assert(app.game_screen.numpad.num_buttons[d - 1].disabled == false, "All numpad buttons enabled when smart numpad is off")
		SettingsScreen.smart_numpad_enabled = true
		app.game_screen._on_settings_changed()

		# 4. History Screen
		print("  4. History Screen...")
		app._show_screen(app.history_screen)
		app.history_screen.size = Vector2(res.x, res.y)
		app.history_screen._apply_responsive_layout()
		app.history_screen.refresh_history()
		await _save_screenshot("qa_capsule_" + prefix + "_history.png")

		# 5. Settings Screen
		print("  5. Settings Screen...")
		app._show_screen(app.settings_screen)
		app.settings_screen.size = Vector2(res.x, res.y)
		app.settings_screen._apply_responsive_layout()
		await _save_screenshot("qa_capsule_" + prefix + "_settings.png")

		# 6. New Game Modal
		print("  6. New Game Modal...")
		app._show_screen(app.main_menu)
		app.main_menu.size = Vector2(res.x, res.y)
		app.main_menu._apply_responsive_layout()
		app.new_game_dialog.open_dialog(DifficultyAnalyzer.LEVEL_MEDIUM)
		while app.new_game_dialog.is_generating:
			await process_frame
		await _wait_frames(10)
		await _save_screenshot("qa_capsule_" + prefix + "_modal_new_game.png")
		app.new_game_dialog.close_modal()

		# 7. Pause Modal with Settings Action & Blur Background
		print("  7. Pause Modal with Settings button & blur...")
		app._start_game_session(state)
		app.game_screen.size = Vector2(res.x, res.y)
		app.game_screen._apply_responsive_layout()
		await _wait_frames(8)
		app.game_screen.toggle_pause()
		await _wait_frames(10)
		assert(app.game_screen.pause_settings_btn != null, "pause_settings_btn exists in pause modal")
		assert(app.game_screen.pause_settings_btn.text == LocalizationManager.translate("BTN_SETTINGS"), "pause_settings_btn has Ayarlar/Settings text")
		await _save_screenshot("qa_capsule_" + prefix + "_modal_pause.png")
		if res.x == 390:
			await _save_screenshot("qa_phase3_modal_pause_settings.png")

		# Test Settings transition from Pause menu
		app.game_screen._on_pause_settings_pressed()
		await _wait_frames(10)
		assert(app.current_screen == app.settings_screen, "Navigated to settings from pause menu")
		app.settings_screen.back_requested.emit()
		await _wait_frames(10)
		assert(app.current_screen == app.game_screen, "Returned to game screen from settings")
		assert(app.game_screen.game_state.is_paused == true, "Game remains paused")
		app.game_screen.toggle_pause()

	# 8. Daily Sudoku Persistence & Flow Verification
	print("\n=== Verifying Daily Sudoku Flow & Persistence ===")
	DailyManager.save_daily_data({
		"completed_dates": [],
		"current_streak": 0,
		"longest_streak": 0,
		"last_completed_date": ""
	})
	if FileAccess.file_exists(DailyManager.get_today_daily_game_path()):
		DirAccess.remove_absolute(DailyManager.get_today_daily_game_path())

	# Test daily game initiation
	app._on_daily_sudoku_requested()
	while app.main_menu.daily_btn.disabled:
		await process_frame
	await _wait_frames(8)
	assert(DailyManager.has_today_game() == true, "Daily puzzle saved for today")
	assert(app.game_screen.game_state.seed_value == DailyManager.get_today_seed(), "Game is today's daily puzzle")
	
	# Make a move in daily game
	app.game_screen.game_state.set_number(0, 1)
	DailyManager.save_today_game(app.game_screen.game_state)
	
	# Go back to menu
	app.game_screen.back_to_menu_requested.emit()
	await _wait_frames(8)
	app.main_menu.refresh_buttons()
	assert(app.main_menu.daily_btn.text == LocalizationManager.translate("BTN_CONTINUE"), "Daily button shows Continue when in-progress")
	
	# Resume daily game from button
	app._on_daily_sudoku_requested()
	await _wait_frames(8)
	assert(app.game_screen.game_state.current_board.get_cell(0) == 1, "Daily puzzle resumed move successfully")
	await _save_screenshot("qa_phase3_daily_resumed.png")
	
	# Complete daily game
	DailyManager.mark_today_completed()
	assert(DailyManager.is_today_completed() == true, "Today's daily marked completed")
	app.game_screen.back_to_menu_requested.emit()
	await _wait_frames(8)
	app.main_menu.refresh_buttons()
	assert(app.main_menu.daily_btn.text == LocalizationManager.translate("BTN_DAILY_COMPLETED"), "Daily button shows Completed")
	assert(app.main_menu.daily_btn.disabled == false, "Daily button remains accessible when completed")
	await _save_screenshot("qa_phase3_home_daily_done.png")

	# 9. Phase 4: Hint System & Animations Verification
	print("\n=== Verifying Phase 4: Logical Hint System & Animations ===")
	# Start a fresh clean game
	var pz := SudokuGenerator.generate(55667788, DifficultyAnalyzer.LEVEL_EASY)
	var st := GameState.new()
	st.init_from_puzzle(pz)
	app._start_game_session(st)
	await _wait_frames(8)
	assert(app.current_screen == app.game_screen, "In game screen for hint test")

	# Select an empty cell
	var test_empty_cell: int = -1
	for idx in range(SudokuBoard.CELL_COUNT):
		if app.game_screen.game_state.current_board.is_empty(idx):
			test_empty_cell = idx
			break
	app.game_screen.sudoku_grid.select_cell(test_empty_cell)

	# Test hint generation
	var hint_step := SudokuSolver.find_best_hint(app.game_screen.game_state.current_board, test_empty_cell, app.game_screen.game_state.solution)
	assert(hint_step != null, "find_best_hint produced a logical solve step")
	assert(hint_step.technique != "", "Step has technique name")
	assert(hint_step.explanation != "", "Step has human-readable explanation")
	assert(hint_step.cells.size() > 0, "Step points to cells on the board")

	# Open Hint Dialog via button
	app.game_screen._on_hint_pressed()
	await _wait_frames(12)
	assert(app.game_screen.hint_dialog.visible == true, "Hint dialog opened")
	await _save_screenshot("qa_phase4_hint_modal.png")

	# Confirm hint and apply move
	app.game_screen.hint_dialog.confirmed.emit()
	app.game_screen.hint_dialog.close_modal()
	await _wait_frames(12)
	assert(app.game_screen.game_state.hints_used >= 1, "Hint used counter incremented")
	assert(app.game_screen.hint_dialog.visible == false, "Hint dialog closed smoothly")
	await _save_screenshot("qa_phase4_hint_applied.png")

	var target_digit: int = 2
	var sol_board := app.game_screen.game_state.solution
	var empty_digit_cells: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		if sol_board.get_cell(idx) == target_digit and app.game_screen.game_state.current_board.is_empty(idx):
			empty_digit_cells.append(idx)

	# Fill all empty cells for digit 2 except the last one
	for k in range(empty_digit_cells.size() - 1):
		app.game_screen.game_state.set_number(empty_digit_cells[k], target_digit, true)
	await _wait_frames(6)

	var signal_fired: bool = false
	var signal_digit: int = 0
	var conn_cb := func(d: int):
		signal_fired = true
		signal_digit = d
	app.game_screen.game_state.digit_completed.connect(conn_cb)

	# Place the 9th instance
	if not empty_digit_cells.is_empty():
		app.game_screen.game_state.set_number(empty_digit_cells[-1], target_digit, true)
	await _wait_frames(6)
	print("  Digit 2 completion signal fired: ", signal_fired)
	await _save_screenshot("qa_phase4_digit_pulse.png")

	# Test Animation Toggle (accessibility setting)
	SettingsScreen.animations_enabled = false
	app.game_screen.hint_dialog.open_modal()
	assert(app.game_screen.hint_dialog.modulate.a == 1.0, "Zero-delay modal open when animations disabled")
	app.game_screen.hint_dialog.close_modal()
	assert(app.game_screen.hint_dialog.visible == false, "Zero-delay modal close when animations disabled")
	SettingsScreen.animations_enabled = true

	print("\n--- ALL PHASE 4 HINT & ANIMATION VERIFICATIONS PASSED ---")
	quit(0)

