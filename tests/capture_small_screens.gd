extends SceneTree

## Captures the key screens at real phone/tablet sizes (content scaling off, so layouts see the
## true pixel size). Needs a window, so not --headless; run with a throwaway user dir:
##   APPDATA=/tmp/fakeappdata godot --path . -s res://tests/capture_small_screens.gd

const SaveManager = preload("res://scripts/data/save_manager.gd")
const OUT: String = "user://small_screens/"
const SIZES: Array[Vector2i] = [Vector2i(320, 568), Vector2i(360, 640), Vector2i(412, 915), Vector2i(800, 1280)]

var app: AppRoot

func _init() -> void:
	_run.call_deferred()

func _wait(n: int = 14) -> void:
	for i in range(n):
		await process_frame

func _shot(file: String) -> void:
	await _wait(16)
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().get_texture().get_image().save_png(OUT + file)
	print("saved ", ProjectSettings.globalize_path(OUT + file))

func _run() -> void:
	AppSettings.auto_open_last_game = false
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for size_px in SIZES:
		win.size = size_px
		await _wait(4)
		app = AppRoot.new()
		win.add_child(app)
		app.size = Vector2(size_px)
		await _wait(15)
		var tag := "%dx%d" % [size_px.x, size_px.y]

		var gen := SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_MEDIUM)
		var state := GameState.new()
		state.init_from_puzzle(gen)
		SaveManager.save_active_game(state)
		app.main_menu.refresh_buttons()
		await _shot("%s_1_menu.png" % tag)

		app.new_game_dialog.open_dialog()
		await _shot("%s_2_new_game.png" % tag)
		app.new_game_dialog.visible = false

		app._start_game_session(state)
		app.game_screen.size = Vector2(size_px)
		await _wait(10)
		await _shot("%s_3_game.png" % tag)

		app.game_screen.toggle_pause()
		await _shot("%s_4_pause.png" % tag)
		app.game_screen.toggle_pause()

		app._show_screen(app.settings_screen)
		await _shot("%s_5_settings.png" % tag)
		app._show_screen(app.statistics_screen)
		await _shot("%s_6_stats.png" % tag)

		app.queue_free()
		await _wait(5)
	quit()
