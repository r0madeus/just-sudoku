extends SceneTree

## What the first days on a phone showed:
##  - the app looked stretched off the right edge for about a second at start (and after coming
##    back): the navigation buttons were tried in several looks within one frame, Godot saw no
##    change in their minimum size and never sorted the row again, so it stayed as wide as a look
##    that did not fit;
##  - Continue sat to the right of New Game and Saved Games (its icon took room from its label);
##  - Settings rows toggled while a finger scrolled over their text (a row toggled as the finger
##    landed), and their check boxes were large;
##  - the small animations and the screen changes could hardly be seen.

const AppRoot = preload("res://scenes/app_root.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const SettingRow = preload("res://scenes/ui/setting_row.gd")
const TouchScroll = preload("res://scenes/ui/touch_scroll.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")

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

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	await process_frame
	print("\n=== MOTION AND START ===")
	AppSettings.auto_open_last_game = false
	await _test_row()
	await _test_scroll_over_rows()
	_test_checkbox_size()
	await _test_menu()
	await _test_relayout_sorts()
	await _test_transitions()
	await _test_start()
	await _test_motion_sizes()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _button(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)

func _mouse(row: Control, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	row._gui_input(e)

func _test_row() -> void:
	var cb := CheckBox.new()
	var row := SettingRow.new("Sounds", "", cb)
	root.add_child(row)
	row.size = Vector2(300, 44)
	await process_frame
	_mouse(row, true, Vector2(20, 20))
	_check("A press on a row does not toggle its check box", not cb.button_pressed)
	_mouse(row, false, Vector2(20, 20))
	_check("it toggles when the finger is lifted on the row", cb.button_pressed)
	_mouse(row, true, Vector2(20, 20))
	_mouse(row, false, Vector2(20, 400))
	_check("but not when the finger slides off the row first", cb.button_pressed)
	_mouse(row, false, Vector2(20, 20))
	_check("and a lift with no press on the row does nothing", cb.button_pressed)
	row.queue_free()
	await process_frame

func _test_scroll_over_rows() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var boxes: Array[CheckBox] = []
	for i in 30:
		var cb := CheckBox.new()
		var row := SettingRow.new("Setting %d" % i, "A line that says what it does", cb)
		row.custom_minimum_size = Vector2(0, 64)
		box.add_child(row)
		boxes.append(cb)
	TouchScroll.attach(scroll)
	await _frames(3)
	var row0: Control = box.get_child(0)
	# On the title, on the left of the row, far from the check box
	var at: Vector2 = row0.get_global_rect().position + Vector2(24, 30)
	_button(true, at)
	await _wait(TouchScroll.TAP_TIMEOUT + 0.1)
	for i in range(1, 7):
		_move(at + Vector2(0, -40.0 * i))
		await process_frame
	_button(false, at + Vector2(0, -240))
	await process_frame
	_check("A finger that rests on a row's text and then scrolls does not toggle it", not boxes[0].button_pressed)
	_check("and the list scrolled", scroll.scroll_vertical > 100)
	scroll.scroll_vertical = 0
	TouchScroll.attach(scroll).velocity = 0.0
	await process_frame
	_button(true, at)
	_button(false, at)
	await process_frame
	_check("A tap on the same text toggles it", boxes[0].button_pressed)
	scroll.queue_free()
	await process_frame

func _test_checkbox_size() -> void:
	var theme := ThemeManager.build_godot_theme()
	var checked: Texture2D = theme.get_icon("checked", "CheckBox")
	var unchecked: Texture2D = theme.get_icon("unchecked", "CheckBox")
	_check("Check boxes are 18 px, a standard size (%s)" % str(checked.get_size()),
		checked.get_size() == Vector2(18, 18) and unchecked.get_size() == Vector2(18, 18))

func _fresh_app() -> Control:
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	return app

func _test_menu() -> void:
	AppSettings.animations_enabled = false
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(6363, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	var app := _fresh_app()
	await _frames(4)
	var menu = app.main_menu
	menu.refresh_buttons()
	_check("Continue has no icon of its own, so its label centres like the other two",
		menu.continue_btn.icon == null and menu.new_game_btn.icon == null and menu.load_game_btn.icon == null)
	_check("its play icon sits at the left edge", menu.continue_icon != null and menu.continue_icon.get_parent() == menu.continue_btn
		and menu.continue_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("and the three share one alignment", menu.continue_btn.alignment == menu.new_game_btn.alignment
		and menu.new_game_btn.alignment == menu.load_game_btn.alignment)

	# The layout, made again and again, ends where it began: at 360 dp the four buttons fit across
	ResponsiveManager.apply_device_scaling(root, root.size.x / 360.0)
	await _frames(5)
	var fits := func() -> bool:
		for btn in [menu.history_btn, menu.stats_btn, menu.techniques_btn, menu.settings_btn]:
			var r: Rect2 = btn.get_global_rect()
			if r.position.x < -1.0 or r.end.x > app.size.x + 1.0:
				return false
		return true
	var before: float = menu.history_btn.size.x
	_check("At 360 dp the navigation buttons fit across the screen", fits.call())
	menu._apply_responsive_layout()
	await _frames(3)
	menu._apply_responsive_layout()
	await _frames(3)
	_check("and still do after the menu is laid out again (%d px wide, was %d)" % [menu.history_btn.size.x, before],
		fits.call() and is_equal_approx(menu.history_btn.size.x, before))
	ResponsiveManager.relayout(root)
	await _frames(3)
	_check("and after every screen is laid out again, as coming back to the app does", fits.call())
	SaveManager.clear_active_game()
	app.queue_free()
	await process_frame

func _test_relayout_sorts() -> void:
	var box := VBoxContainer.new()
	var child := Control.new()
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.custom_minimum_size = Vector2(10, 20)
	box.add_child(child)
	root.add_child(box)
	box.size = Vector2(300, 100)
	await _frames(2)
	# What a layout tried out within one frame can leave behind: a child stretched past its parent
	child.size = Vector2(500, 20)
	ResponsiveManager.relayout(root)
	await _frames(2)
	_check("Laying everything out again sorts the containers (a child 500 wide is back to %d)" % int(child.size.x), child.size.x <= 300.5)
	box.queue_free()
	await process_frame

func _test_transitions() -> void:
	if DisplayServer.get_name() == "headless":
		return
	AppSettings.animations_enabled = true
	var app := _fresh_app()
	await _wait(AppRoot.REVEAL_LATEST + AppRoot.REVEAL_TIME + 0.3)
	app.main_menu.settings_requested.emit()
	var settings = app.settings_screen
	_check("A screen coming in starts to the right of its place, transparent",
		settings.offset_left > AppRoot.TRANSITION_SLIDE * 0.5 and settings.modulate.a < 0.5)
	_check("and the one it covers stays opaque beneath", app.main_menu.visible and app.main_menu.modulate.a == 1.0)
	await _wait(AppRoot.TRANSITION_TIME * 0.5)
	_check("it moves in over time", settings.offset_left < AppRoot.TRANSITION_SLIDE and settings.modulate.a > 0.0)
	await _wait(AppRoot.TRANSITION_TIME + 0.2)
	_check("it ends in its place, opaque and the full size of the app",
		settings.offset_left == 0.0 and settings.offset_right == 0.0 and settings.modulate.a == 1.0 and settings.size.is_equal_approx(app.size))
	_check("with the menu out of sight, in its place for next time",
		not app.main_menu.visible and app.main_menu.offset_left == 0.0 and app.main_menu.offset_right == 0.0)

	app.handle_back()
	var menu = app.main_menu
	_check("Going back brings the menu in from the left", menu.offset_left < -AppRoot.TRANSITION_SLIDE * 0.5 and menu.visible)
	await _wait(AppRoot.TRANSITION_TIME + 0.2)
	_check("and it ends in its place too", menu.offset_left == 0.0 and menu.modulate.a == 1.0 and not settings.visible
		and settings.offset_left == 0.0 and settings.offset_right == 0.0)

	# A second change before the first is over
	menu.settings_requested.emit()
	await _wait(AppRoot.TRANSITION_TIME * 0.4)
	menu.statistics_requested.emit()
	await _wait(AppRoot.TRANSITION_TIME + 0.2)
	var stats = app.statistics_screen
	var at_rest := true
	for s in [menu, settings, stats]:
		at_rest = at_rest and s.offset_left == 0.0 and s.offset_right == 0.0 and s.modulate.a == 1.0
	_check("Changing screens before a change is over leaves every screen in its place", at_rest)
	_check("with only the last one on show", stats.visible and not settings.visible and not menu.visible)
	app.queue_free()
	await process_frame

func _test_start() -> void:
	if DisplayServer.get_name() == "headless":
		return
	AppSettings.animations_enabled = true
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	var display := ["1080x2400 px"]
	app.display_probe = func() -> String: return display[0]
	root.add_child(app)
	_check("At start the app is invisible while the display may still be settling", app.modulate.a == 0.0)
	await _wait(AppRoot.REVEAL_AFTER_STABLE + AppRoot.REVEAL_TIME + 0.3)
	_check("and shows once the display has not changed for a moment", app.modulate.a == 1.0)
	_check("the display it started with is in the trace (%s)" % str(ResponsiveManager.start_trace),
		ResponsiveManager.start_trace.size() == 1 and ResponsiveManager.start_trace[0].contains("1080x2400"))

	var margin: MarginContainer = app.main_menu.margin_container
	var good: int = margin.get_theme_constant("margin_left")
	margin.add_theme_constant_override("margin_left", good + 120)
	display[0] = "1080x2400 px, safe 110,0"
	await _wait(0.4)
	_check("A change in the display lays the screens out again", margin.get_theme_constant("margin_left") == good)
	_check("and is written to the trace", ResponsiveManager.start_trace.size() == 2 and ResponsiveManager.start_trace[1].contains("safe 110,0"))
	app.queue_free()
	await process_frame

	# A display that never settles does not keep the app invisible
	var counter := [0]
	var restless: Control = load("res://scenes/app_root.tscn").instantiate()
	restless.display_probe = func() -> String:
		counter[0] += 1
		return "tick %d" % counter[0]
	root.add_child(restless)
	await _wait(AppRoot.REVEAL_LATEST + AppRoot.REVEAL_TIME + 0.3)
	_check("however long the display keeps changing, the app shows by %.1f s" % AppRoot.REVEAL_LATEST, restless.modulate.a == 1.0)
	_check("the trace keeps only its last %d entries" % AppRoot.TRACE_LIMIT, ResponsiveManager.start_trace.size() <= AppRoot.TRACE_LIMIT)
	restless.queue_free()
	await process_frame

	AppSettings.animations_enabled = false
	var plain: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(plain)
	_check("With animations off nothing is hidden at start", plain.modulate.a == 1.0)
	plain.queue_free()
	await process_frame

func _test_motion_sizes() -> void:
	# Long and big enough to be seen on a phone: a cell used to settle in 0.05 s after a tap
	_check("A tapped cell pulses for at least 0.12 s", SudokuCell.SELECT_TIME >= 0.12 and SudokuCell.SELECT_SCALE >= 1.06)
	_check("a digit pops for at least 0.25 s", SudokuCell.POP_TIME >= 0.25 and SudokuCell.POP_SCALE >= 1.2)
	_check("a wrong digit shakes at least 4 px", SudokuCell.SHAKE_PX >= 4.0)
	_check("a finished row ripples for at least 0.2 s", SudokuCell.WAVE_TIME >= 0.2)
	_check("screens take at least 0.2 s to change", AppRoot.TRANSITION_TIME >= 0.2 and AppRoot.TRANSITION_SLIDE >= 24.0)

	AppSettings.animations_enabled = true
	var modal := AppModal.new()
	root.add_child(modal)
	modal.open_modal()
	_check("A dialog grows in from a visibly smaller size", modal.modal_panel.scale.x < 0.95 and modal.modulate.a < 0.5)
	await _wait(0.5)
	_check("and ends full size", is_equal_approx(modal.modal_panel.scale.x, 1.0) and modal.modulate.a == 1.0)
	modal.queue_free()
	AppSettings.animations_enabled = false
	await process_frame
