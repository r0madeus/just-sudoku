extends SceneTree

## Android readiness: the back button walks modal -> screen -> menu, and narrow phones get a
## dock and home screen that fit instead of overflowing.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameActionDock = preload("res://scenes/ui/game_action_dock.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const AppRoot = preload("res://scenes/app_root.gd")

var passed: int = 0
var failed: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		printerr("  ✗ FAIL: ", msg)

func _frames(n: int = 6) -> void:
	for i in range(n):
		await process_frame

## Screen and modal transitions are timed tweens, so give them real time to finish
func _settle() -> void:
	await create_timer(0.45).timeout

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- ANDROID LAYOUT & BACK BUTTON ---")
	AppSettings.animations_enabled = false
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(360, 640)
	await _frames()

	# Dock: labelled when it fits, icon-only when it does not
	var dock := GameActionDock.new()
	win.add_child(dock)
	await _frames()
	dock.fit_to_width(600.0)
	_check(not dock.is_compact and dock.undo_btn.text != "", "Dock keeps labels when there is room")
	dock.fit_to_width(300.0)
	_check(dock.is_compact and dock.undo_btn.text == "" and dock.undo_btn.tooltip_text != "", "Dock turns icon-only (with tooltips) on a narrow screen")
	_check(dock.get_combined_minimum_size().x <= 300.0, "Compact dock fits 300 px (min width %.0f)" % dock.get_combined_minimum_size().x)

	# With the app's theme, turning notes or colours on must not change the dock's width: it chooses
	# labels or icons by that width, and a 2 px difference used to flip it on every tap
	var themed := Control.new()
	themed.theme = ThemeManager.build_godot_theme()
	win.add_child(themed)
	var tdock := GameActionDock.new()
	themed.add_child(tdock)
	await _frames()
	var widths: Array[float] = []
	for state in [[false, false], [true, false], [false, true], [false, false]]:
		tdock.set_notes_active(state[0])
		tdock.set_color_active(state[1])
		await _frames()
		tdock._apply_compact(false)
		widths.append(tdock.get_combined_minimum_size().x)
	var steady := true
	for w in widths:
		steady = steady and is_equal_approx(w, widths[0])
	_check(steady, "The dock is as wide with notes or colours on as off %s" % str(widths))
	var edge := widths[0] - 0.5
	var verdicts: Array[bool] = []
	for state in [[false, false], [true, false], [false, true]]:
		tdock.set_notes_active(state[0])
		tdock.set_color_active(state[1])
		tdock.fit_to_width(edge)
		verdicts.append(tdock.is_compact)
	_check(verdicts == [true, true, true], "so just under that width it is icon-only in every state %s" % str(verdicts))

	# A fit is only as good as the measure it was made with. When the text gets wider after it (a font
	# or theme applied late, another language), the labelled dock must notice by itself and turn
	# icon-only, or it hangs out of the screen (seen in the browser version on a phone)
	tdock.set_notes_active(false)
	tdock.set_color_active(false)
	tdock.fit_to_width(widths[0] - 1.0 + 40.0)
	await _frames(3)
	_check(not tdock.is_compact, "Fitted with room to spare, it is labelled")
	tdock.undo_btn.add_theme_font_size_override("font_size", 30)
	await _frames(5)
	_check(tdock.is_compact and tdock.get_combined_minimum_size().x <= widths[0] + 39.0,
		"A larger font later turns it icon-only by itself (min width %.0f)" % tdock.get_combined_minimum_size().x)
	themed.queue_free()

	var app := AppRoot.new()
	win.add_child(app)
	app.size = Vector2(360, 640)
	await _frames(12)

	# Game screen at 360x640 has no horizontal overflow
	var gen := SudokuGenerator.generate(77, DifficultyAnalyzer.LEVEL_EASY)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	app._start_game_session(state)
	await _frames(12)
	var content_w: float = app.game_screen.root_vbox.get_combined_minimum_size().x
	var avail_w: float = 360.0 - float(app.game_screen.margin_container.get_theme_constant("margin_left") + app.game_screen.margin_container.get_theme_constant("margin_right"))
	_check(content_w <= avail_w + 0.5, "Game screen content (%.0f px) fits the 360 px phone (%.0f px available)" % [content_w, avail_w])

	# Back button: topmost modal first
	app.game_screen.toggle_pause()
	await _settle()
	_check(app.game_screen.pause_overlay.visible, "Pause overlay is open")
	app.handle_back()
	await _settle()
	_check(not app.game_screen.pause_overlay.visible and app.current_screen == app.game_screen, "Back closes the pause overlay and stays in the game")

	# Then the screen: game -> menu
	app.handle_back()
	await _settle()
	_check(app.current_screen == app.main_menu, "Back from the game returns to the menu")

	# Settings -> previous screen
	app.main_menu.settings_requested.emit()
	await _settle()
	_check(app.current_screen == app.settings_screen, "Settings opens from the menu")
	app.handle_back()
	await _settle()
	_check(app.current_screen == app.main_menu, "Back from settings returns to the menu")

	# A modal over the menu is dismissed before anything else
	app.new_game_dialog.open_dialog()
	await _settle()
	app.handle_back()
	await _settle()
	_check(not app.new_game_dialog.visible and app.current_screen == app.main_menu, "Back dismisses the New Game dialog first")

	# Home screen: at 360x640 nothing is clipped on the right
	var menu_margins: float = float(app.main_menu.margin_container.get_theme_constant("margin_left") + app.main_menu.margin_container.get_theme_constant("margin_right"))
	var menu_w: float = app.main_menu.root_vbox.get_combined_minimum_size().x
	_check(menu_w + menu_margins <= 360.0 + 0.5, "Home screen content (%.0f px + %.0f margins) fits 360 px" % [menu_w, menu_margins])

	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
