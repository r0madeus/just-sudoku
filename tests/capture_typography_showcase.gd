extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/Melih Uçgun/.gemini/antigravity/brain/c2380364-d48a-41c9-adba-d53cfa2ddc62/"
const AppRoot = preload("res://scenes/app_root.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")

var app: AppRoot

func _init() -> void:
	_run_captures.call_deferred()

func _wait_frames(n: int = 10) -> void:
	for i in range(n):
		await process_frame

func _save_screenshot(filename: String) -> void:
	await _wait_frames(12)
	var img: Image = get_root().get_texture().get_image()
	if img != null:
		var target_path: String = ARTIFACT_DIR + filename
		img.save_png(target_path)
		print("  -> Saved: ", filename)

func _run_captures() -> void:
	print("\n--- CAPTURING CLEAN TYPOGRAPHY SHOWCASE SCREENSHOTS ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var win := get_root()
	win.size = Vector2i(400, 720)

	app = AppRoot.new()
	win.add_child(app)
	app.size = Vector2(400, 720)
	await _wait_frames(15)

	# 1. Home Screen (Source Serif 4 Brand Heading + Inter Controls)
	print("Capturing 1. Home Screen...")
	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(400, 720)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_typography_home.png")

	# 2. Game Screen (Inter UI + Sudoku Cells + Numpad)
	print("Capturing 2. Game Screen...")
	var gen := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	app._start_game_session(state)
	app.game_screen.size = Vector2(400, 720)
	app.game_screen._apply_responsive_layout()
	await _save_screenshot("qa_typography_game.png")

	# 3. Pause Modal (Inter Header & Subtitle + Seed Value)
	print("Capturing 3. Pause Modal...")
	app.game_screen.toggle_pause()
	await _save_screenshot("qa_typography_pause_modal.png")
	app.game_screen.toggle_pause()

	# 4. Settings Screen (Inter Typography + Font Options)
	print("Capturing 4. Settings Screen...")
	app._show_screen(app.settings_screen)
	app.settings_screen.size = Vector2(400, 720)
	app.settings_screen._apply_responsive_layout()
	await _save_screenshot("qa_typography_settings.png")

	# 5. History Screen (Inter Headers + GameRecordItems)
	print("Capturing 5. History Screen...")
	app.history_screen.refresh_history()
	app._show_screen(app.history_screen)
	app.history_screen.size = Vector2(400, 720)
	app.history_screen._apply_responsive_layout()
	await _save_screenshot("qa_typography_history.png")

	# 6. Statistics Screen (Inter Headers + Stats)
	print("Capturing 6. Statistics Screen...")
	app.statistics_screen.refresh_stats()
	app._show_screen(app.statistics_screen)
	app.statistics_screen.size = Vector2(400, 720)
	app.statistics_screen._apply_responsive_layout()
	await _save_screenshot("qa_typography_statistics.png")

	# 7. New Game Modal (IBM Plex Mono Seed + Inter)
	print("Capturing 7. New Game Modal...")
	app._show_screen(app.main_menu)
	app.new_game_dialog.open_dialog(DifficultyAnalyzer.LEVEL_MEDIUM)
	await _wait_frames(15)
	await _save_screenshot("qa_typography_new_game_modal.png")
	app.new_game_dialog.close_modal()

	# 8. Custom Theme Modal (Liquid Glass + Mini Grid)
	print("Capturing 8. Custom Theme Modal...")
	app._show_screen(app.settings_screen)
	app.custom_theme_dialog.open_dialog()
	await _wait_frames(15)
	await _save_screenshot("qa_typography_custom_theme_modal.png")
	app.custom_theme_dialog.close_modal()

	print("--- ALL TYPOGRAPHY SCREENSHOTS CAPTURED SUCCESSFULLY ---")
	quit(0)
