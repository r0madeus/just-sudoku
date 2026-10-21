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
	print("\n--- CAPTURING MULTI-RESOLUTION RESPONSIVE SCREENS ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var win := get_root()

	app = AppRoot.new()
	win.add_child(app)
	await _wait_frames(16)

	var default_puzzle := SudokuGenerator.generate(42, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(default_puzzle)

	# 1. Compact Phone: 360 x 640
	print("Capturing Compact Phone (360x640)...")
	win.size = Vector2i(360, 640)
	app.size = Vector2(360, 640)
	await _wait_frames(8)

	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(360, 640)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_responsive_360x640_home.png")

	app._show_screen(app.game_screen)
	app.game_screen.setup_game(state)
	app.game_screen.size = Vector2(360, 640)
	app.game_screen._apply_responsive_layout()
	await _save_screenshot("qa_responsive_360x640_game.png")

	# 2. Standard Phone: 390 x 844
	print("Capturing Standard Phone (390x844)...")
	win.size = Vector2i(390, 844)
	app.size = Vector2(390, 844)
	await _wait_frames(8)

	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(390, 844)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_responsive_390x844_home.png")

	app._show_screen(app.game_screen)
	app.game_screen.size = Vector2(390, 844)
	app.game_screen._apply_responsive_layout()
	await _save_screenshot("qa_responsive_390x844_game.png")

	# 3. Tablet Portrait: 768 x 1024
	print("Capturing Tablet Portrait (768x1024)...")
	win.size = Vector2i(768, 1024)
	app.size = Vector2(768, 1024)
	await _wait_frames(8)

	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(768, 1024)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_responsive_768x1024_home.png")

	app._show_screen(app.game_screen)
	app.game_screen.size = Vector2(768, 1024)
	app.game_screen._apply_responsive_layout()
	await _save_screenshot("qa_responsive_768x1024_game.png")

	# 4. Desktop Landscape: 1280 x 720
	print("Capturing Desktop Landscape (1280x720)...")
	win.size = Vector2i(1280, 720)
	app.size = Vector2(1280, 720)
	await _wait_frames(8)

	app._show_screen(app.main_menu)
	app.main_menu.size = Vector2(1280, 720)
	app.main_menu._apply_responsive_layout()
	await _save_screenshot("qa_responsive_1280x720_home.png")

	app._show_screen(app.game_screen)
	app.game_screen.size = Vector2(1280, 720)
	app.game_screen._apply_responsive_layout()
	await _save_screenshot("qa_responsive_1280x720_game.png")

	app._show_screen(app.settings_screen)
	app.settings_screen.size = Vector2(1280, 720)
	app.settings_screen._apply_responsive_layout()
	await _save_screenshot("qa_responsive_1280x720_settings.png")

	print("\n>>> ALL RESPONSIVE SCREENSHOTS CAPTURED SUCCESSFULLY! <<<\n")
	quit(0)
