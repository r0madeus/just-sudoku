extends SceneTree

## Regenerates screenshots/ from the live app (needs a window, so not --headless).
## It seeds demo history and switches themes, so run it with a throwaway user dir:
##   APPDATA=/tmp/fakeappdata godot --path . -s res://tests/capture_screenshots.gd

const SaveManager = preload("res://scripts/data/save_manager.gd")
const OUT: String = "res://screenshots/"
var app: AppRoot

func _init() -> void:
	_run.call_deferred()

func _wait(n: int = 14) -> void:
	for i in range(n):
		await process_frame

func _shot(file: String) -> void:
	await _wait(18)
	get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)

func _seed_history() -> void:
	var diffs := ["Easy", "Easy", "Medium", "Medium", "Hard", "Easy", "Medium", "Expert", "Hard", "Medium"]
	for i in range(diffs.size()):
		HistoryManager.add_record({
			"game_id": "demo_%d" % i, "seed": 1000 + i * 37, "difficulty": diffs[i],
			"difficulty_score": 30 + i * 6, "score": 94 - i * 3, "time": 240.0 + i * 95.0,
			"mistakes": i % 3, "hints": i % 2, "undo_count": i, "is_replay": false, "is_daily": i == 2
		})
	var d := Time.get_date_dict_from_system()
	DailyManager.mark_date_completed(d.year, d.month, d.day)

func _run() -> void:
	SettingsScreen.auto_open_last_game = false
	_seed_history()
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var win := get_root()
	win.size = Vector2i(540, 960)
	app = AppRoot.new()
	win.add_child(app)
	app.size = Vector2(540, 960)
	await _wait(20)

	await _shot("01_main_menu_dark.png")
	app.new_game_dialog.open_dialog()
	await _shot("02_new_game_dialog.png")
	app.new_game_dialog.visible = false

	var gen := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	SaveManager.save_active_game(state)
	app._start_game_session(state)
	await _wait(10)
	for idx in range(81):
		if state.current_board.get_cell(idx) == 5:
			app.game_screen.sudoku_grid.select_cell(idx)
			app.game_screen.numpad.set_selected_digit(5)
			break
	for t in [ThemeManager.THEME_DARK, ThemeManager.THEME_LIGHT, ThemeManager.THEME_AMOLED]:
		ThemeManager.set_theme(t)
		await _shot("03_game_%s.png" % t.to_lower())
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	app.game_screen.toggle_pause()
	await _shot("04_pause.png")
	app.game_screen.toggle_pause()

	app._show_screen(app.history_screen)
	await _shot("05_history.png")
	app._show_screen(app.statistics_screen)
	await _shot("06_statistics.png")
	app._show_screen(app.settings_screen)
	await _shot("07_settings.png")
	app._show_screen(app.load_game_screen)
	await _shot("08_load_game.png")
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	app.main_menu.refresh_buttons()
	app._show_screen(app.main_menu)
	await _shot("09_main_menu_light.png")
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	await _shot("11_main_menu_resume_dark.png")

	# Desktop landscape
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	win.size = Vector2i(1280, 800)
	app.size = Vector2(1280, 800)
	app._show_screen(app.game_screen)
	app.game_screen.size = Vector2(1280, 800)
	app.game_screen._apply_responsive_layout()
	await _shot("10_game_desktop.png")
	quit()
