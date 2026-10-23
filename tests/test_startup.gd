extends SceneTree

## Start-up loads only what the menu needs. Loading the scripts was most of the time before the
## first frame (about 0.7 s on a desktop, more on a phone): every screen and dialog was made at
## start, and the game's state read its settings from the Settings screen, which loaded it with
## everything it builds. The rest is now made a moment after the menu is on show, or at once when
## it is needed first.
##
## This file names none of those screens' classes, so it does not load them itself.

const APP_ROOT: String = "res://scenes/app_root.gd"

var _passed: int = 0
var _failed: int = 0

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await process_frame
	print("\n=== START-UP ===")
	await _test_start()
	await _test_on_demand()
	await _test_reopened_game()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _not_loaded(paths: Array) -> Array:
	return paths.filter(func(p): return ResourceLoader.has_cached(p))

func _app() -> Control:
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var app: Control = load(APP_ROOT).new()
	root.add_child(app)
	return app

func _test_start() -> void:
	var script: GDScript = load(APP_ROOT)
	var lazy: Array = script.LAZY_NODES.values()
	_check("Loading the app loads none of the screens behind the menu (loaded: %s)" % str(_not_loaded(lazy)), _not_loaded(lazy).is_empty())
	var app := _app()
	await _frames(3)
	_check("The menu is on show", app.current_screen == app.main_menu and app.main_menu.visible)
	_check("and nothing else was made or loaded for it", app._made.is_empty() and _not_loaded(lazy).is_empty())

	await create_timer(script.WARM_UP_DELAY + script.WARM_UP_STEP * (lazy.size() + 4) + 0.3).timeout
	_check("A moment later the rest are made (%d of %d)" % [app._made.size(), lazy.size()], app._made.size() == lazy.size())
	var screens_hidden := true
	for key in app._made:
		if not script.DIALOGS.has(key) and app._made[key].visible:
			screens_hidden = false
	_check("hidden, the menu still on show", screens_hidden and app.current_screen == app.main_menu)
	var last_screen := 0
	var first_dialog := app.get_child_count()
	for key in app._made:
		var index: int = app._made[key].get_index()
		if script.DIALOGS.has(key):
			first_dialog = mini(first_dialog, index)
		else:
			last_screen = maxi(last_screen, index)
	_check("with the dialogs above every screen", first_dialog > last_screen)
	app.queue_free()
	await process_frame

func _test_on_demand() -> void:
	var app := _app()
	await _frames(2)
	app.main_menu.settings_requested.emit()
	_check("Settings asked for before it was made opens at once", app._made.has("settings_screen") and app.current_screen == app.settings_screen and app.settings_screen.visible)
	app.handle_back()
	_check("and Back leads to the menu", app.current_screen == app.main_menu and not app.settings_screen.visible)
	app.main_menu.statistics_requested.emit()
	_check("Statistics too", app.current_screen == app.statistics_screen)
	app.handle_back()
	_check("and back", app.current_screen == app.main_menu)
	app.main_menu.new_game_requested.emit()
	await process_frame
	_check("The New Game sheet opens above the menu", app.new_game_dialog.visible
		and app.new_game_dialog.get_index() > app.main_menu.get_index())
	app.new_game_dialog.close_dialog()
	app.settings_screen.data_restored.emit()
	_check("Restoring a backup with no game open does not make the game screen", not app._made.has("game_screen"))
	app.queue_free()
	await process_frame

func _test_reopened_game() -> void:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(8181, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	AppSettings.auto_open_last_game = true
	AppSettings.animations_enabled = false
	var app: Control = load(APP_ROOT).new()
	root.add_child(app)
	await _frames(2)
	_check("With a game to reopen, the game is on show from the start", app.current_screen == app.game_screen and app.game_screen.visible)
	_check("and it is that game", app.game_screen.game_state != null and app.game_screen.game_state.seed_value == 8181)
	app.queue_free()
	SaveManager.clear_active_game()
	await process_frame
