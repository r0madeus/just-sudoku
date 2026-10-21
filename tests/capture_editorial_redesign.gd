extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/Melih Uçgun/.gemini/antigravity/brain/c2380364-d48a-41c9-adba-d53cfa2ddc62/"
const AppRoot = preload("res://scenes/app_root.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SolutionDialog = preload("res://scenes/gameplay/dialogs/solution_dialog.gd")

var app: AppRoot

func _init() -> void:
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

func _run_captures() -> void:
	print("\n--- CAPTURING SWISS EDITORIAL × RESTRAINED LIQUID GLASS SCREENSHOTS ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var win := get_root()
	win.size = Vector2i(400, 720)

	app = AppRoot.new()
	win.add_child(app)
	app.size = Vector2(400, 720)
	await _wait_frames(16)

	# 1. Home Screen (Swiss Editorial Masthead + Hero Action + Restrained Daily Strip + Low-weight baseline)
	print("Capturing 1. Home Screen...")
	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(400, 720)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_editorial_home.png")

	# 2. Statistics Screen (Clean Callouts + Hairlines, Zero Card Panels)
	print("Capturing 2. Statistics Screen...")
	app._show_screen(app.statistics_screen)
	app.statistics_screen.size = Vector2(400, 720)
	app.statistics_screen._apply_responsive_layout()
	app.statistics_screen.refresh_stats()
	await _save_screenshot("qa_editorial_statistics.png")

	# 3. History Screen (Clean Filter Toolbar + Hairline-divided List Items)
	print("Capturing 3. History Screen...")
	app._show_screen(app.history_screen)
	app.history_screen.size = Vector2(400, 720)
	app.history_screen._apply_responsive_layout()
	app.history_screen.refresh_history()
	await _save_screenshot("qa_editorial_history.png")

	# 4. Settings Screen (Clean Hairlines, Transparent Category Groups, Precision Rows)
	print("Capturing 4. Settings Screen...")
	app._show_screen(app.settings_screen)
	app.settings_screen.size = Vector2(400, 720)
	app.settings_screen._apply_responsive_layout()
	await _save_screenshot("qa_editorial_settings.png")

	# 5. Load Game Screen (Clean Saved Games List)
	print("Capturing 5. Load Game Screen...")
	app._show_screen(app.load_game_screen)
	app.load_game_screen.size = Vector2(400, 720)
	app.load_game_screen._apply_responsive_layout()
	app.load_game_screen.refresh_list()
	await _save_screenshot("qa_editorial_load_game.png")

	# 6. New Game Modal (Restrained Liquid Glass + Technical IBM Plex Mono Seed)
	print("Capturing 6. New Game Modal...")
	app._show_screen(app.main_menu)
	app.new_game_dialog.open_dialog(DifficultyAnalyzer.LEVEL_MEDIUM)
	while app.new_game_dialog.is_generating:
		await process_frame
	await _wait_frames(10)
	await _save_screenshot("qa_editorial_new_game_modal.png")
	app.new_game_dialog.close_modal()

	# 7. Pause Modal (Floating Liquid Glass on Game Backdrop)
	print("Capturing 7. Pause Modal...")
	var gen := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	app._start_game_session(state)
	app.game_screen.size = Vector2(400, 720)
	app.game_screen._apply_responsive_layout()
	await _wait_frames(10)
	app.game_screen.toggle_pause()
	await _save_screenshot("qa_editorial_pause_modal.png")
	app.game_screen.toggle_pause()

	# 8. Solution Modal (Floating Liquid Glass Modal)
	print("Capturing 8. Solution Modal...")
	var sol_dialog := SolutionDialog.new()
	win.add_child(sol_dialog)
	sol_dialog.theme = ThemeManager.build_godot_theme()
	sol_dialog.open_solution(gen.puzzle)
	await _save_screenshot("qa_editorial_solution_modal.png")
	sol_dialog.close_modal()
	sol_dialog.queue_free()

	print("--- ALL EDITORIAL REDESIGN SCREENSHOTS CAPTURED SUCCESSFULLY ---")
	quit(0)
