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

func _wait_frames(n: int = 12) -> void:
	for i in range(n):
		await process_frame

func _save_screenshot(filename: String) -> void:
	await _wait_frames(14)
	var img: Image = get_root().get_texture().get_image()
	if img != null:
		var target_path: String = ARTIFACT_DIR + filename
		img.save_png(target_path)
		print("  -> Saved: ", filename)

func _run_captures() -> void:
	print("\n--- CAPTURING REDESIGNED GAME SCREEN COMPOSITION SCREENSHOTS ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var win := get_root()
	win.size = Vector2i(400, 720)

	app = AppRoot.new()
	win.add_child(app)
	app.size = Vector2(400, 720)
	await _wait_frames(15)

	# Generate puzzle
	var gen := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	app._start_game_session(state)
	app.game_screen.size = Vector2(400, 720)
	app.game_screen._apply_responsive_layout()
	await _wait_frames(10)

	# Select cell with digit 5 to showcase strong visual hierarchy:
	# active cell with border ring + peer row/col crosshair + all matching digit 5s highlighted + 3x3 boundaries + numpad active
	var target_cell_idx: int = -1
	for idx in range(81):
		if state.current_board.get_cell(idx) == 5:
			target_cell_idx = idx
			break
	if target_cell_idx != -1:
		app.game_screen.sudoku_grid.select_cell(target_cell_idx)
		app.game_screen.numpad.set_selected_digit(5)
	await _wait_frames(10)

	# 1. Dark Theme Game Screen
	print("Capturing 1. Dark Theme Game Screen Redesign...")
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	await _wait_frames(10)
	await _save_screenshot("qa_game_redesign_dark.png")

	# 2. Light Theme Game Screen
	print("Capturing 2. Light Theme Game Screen Redesign...")
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	await _wait_frames(10)
	await _save_screenshot("qa_game_redesign_light.png")

	# 3. AMOLED Theme Game Screen
	print("Capturing 3. AMOLED Theme Game Screen Redesign...")
	ThemeManager.set_theme(ThemeManager.THEME_AMOLED)
	await _wait_frames(10)
	await _save_screenshot("qa_game_redesign_amoled.png")

	print("--- ALL REDESIGN SCREENSHOTS CAPTURED SUCCESSFULLY ---")
	quit(0)
