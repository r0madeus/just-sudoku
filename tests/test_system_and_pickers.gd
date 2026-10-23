extends SceneTree

## Language and theme follow the phone unless the player picks one, and the dropdowns open the
## app's own sheet. Before, the phone's language and light/dark mode were read only on the very
## first start and then saved as if chosen, so changing the phone later changed nothing; and the
## dropdowns opened Godot's desktop-style popup menu.

const PickerButton = preload("res://scenes/ui/picker_button.gd")
const TouchScroll = preload("res://scenes/ui/touch_scroll.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const AppRoot = preload("res://scenes/app_root.gd")

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
	print("\n=== SYSTEM LANGUAGE AND THEME, PICKERS ===")
	AppSettings.animations_enabled = false
	await _test_picker()
	await _test_picker_in_list()
	_test_theme_follows_system()
	_test_language_follows_system()
	await _test_settings_and_resume()
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

func _tap(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	_button(true, at)
	_button(false, at)

func _host() -> Control:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = ThemeManager.build_godot_theme()
	root.add_child(host)
	return host

func _rows(picker: PickerButton) -> Array:
	return picker.sheet.body_vbox.find_children("*", "Button", true, false)

func _test_picker() -> void:
	var host := _host()
	var box := VBoxContainer.new()
	box.position = Vector2(20, 100)
	host.add_child(box)
	var title := Label.new()
	title.text = "Language"
	box.add_child(title)
	var picker := PickerButton.new()
	picker.custom_minimum_size = Vector2(200, 44)
	for t in ["System", "Türkçe", "English"]:
		picker.add_item(t)
	picker.selected = 0
	picker.title_source = title
	box.add_child(picker)
	var chosen: Array[int] = []
	picker.item_selected.connect(func(i): chosen.append(i))
	await _frames(2)

	var at := picker.get_global_rect().get_center()
	_button(true, at)
	await process_frame
	_check("Nothing opens as the finger lands", picker.sheet == null)
	_button(false, at + Vector2(0, 200))
	await process_frame
	_check("nor when it slides off before lifting", picker.sheet == null)

	_tap(picker)
	await process_frame
	_check("A tap opens the app's sheet", picker.sheet != null and picker.sheet.visible)
	_check("not Godot's popup menu", not picker.get_popup().visible)
	_check("over the whole app, not inside the row (%s)" % str(picker.sheet.get_parent()), picker.sheet.get_parent() == host)
	_check("titled with the setting's name", picker.sheet.title_label.text == "Language")
	var rows := _rows(picker)
	_check("one row per choice", rows.size() == 3 and rows[1].text == "Türkçe")
	_check("the current one ticked and tinted", rows[0].button_pressed and rows[0].icon != null
		and not rows[1].button_pressed and rows[1].icon == null)
	_check("rows as tall as a finger", rows.all(func(r): return r.get_combined_minimum_size().y >= 48.0))

	rows[2].pressed.emit()
	await process_frame
	_check("Picking a choice selects it", picker.selected == 2 and Array(chosen) == [2])
	await process_frame
	_check("and closes the sheet", picker.sheet == null)

	_tap(picker)
	await process_frame
	_rows(picker)[2].pressed.emit()
	await _frames(2)
	_check("Picking the current one again changes nothing", Array(chosen) == [2] and picker.sheet == null)

	_tap(picker)
	await process_frame
	picker.sheet._on_canceled()
	await _frames(2)
	_check("Back or the backdrop closes it without a change", picker.sheet == null and picker.selected == 2 and chosen.size() == 1)

	picker.disabled = true
	_tap(picker)
	await process_frame
	_check("A disabled picker does not open", picker.sheet == null)
	host.queue_free()
	await process_frame

func _test_picker_in_list() -> void:
	var host := _host()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 3000)
	scroll.add_child(box)
	var picker := PickerButton.new()
	picker.custom_minimum_size = Vector2(200, 44)
	picker.add_item("One")
	picker.add_item("Two")
	box.add_child(picker)
	TouchScroll.attach(scroll)
	await _frames(3)
	var at := picker.get_global_rect().get_center()
	_button(true, at)
	for i in range(1, 7):
		await process_frame
		_move(at + Vector2(0, 40.0 * i))
	_button(false, at + Vector2(0, 240))
	await process_frame
	_check("A drag down a list that starts on a picker scrolls and opens nothing", picker.sheet == null)
	scroll.scroll_vertical = 0
	await process_frame
	_tap(picker)
	await process_frame
	_check("A tap on it in a list opens it", picker.sheet != null and picker.sheet.visible)
	host.queue_free()
	await process_frame

func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func _read(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _other_theme() -> String:
	return ThemeManager.THEME_LIGHT if ThemeManager.detect_system_theme() == ThemeManager.THEME_DARK else ThemeManager.THEME_DARK

func _test_theme_follows_system() -> void:
	var path := ThemeManager.SETTINGS_PATH
	DirAccess.remove_absolute(path)
	ThemeManager.load_settings()
	_check("A first start follows the phone's light or dark mode",
		ThemeManager.follows_system and ThemeManager.current_theme_name == ThemeManager.detect_system_theme())
	_check("and saves that it follows it, not the theme it found", _read(path).get("theme", "") == ThemeManager.THEME_SYSTEM)

	ThemeManager.set_theme(_other_theme())
	ThemeManager.load_settings()
	_check("A theme picked is kept", not ThemeManager.follows_system and ThemeManager.current_theme_name == _other_theme())
	ThemeManager.refresh_system_theme()
	_check("whatever the phone is set to", ThemeManager.current_theme_name == _other_theme())

	_write(path, {"theme": _other_theme()})
	ThemeManager.load_settings()
	_check("Settings saved by 1.0.0 with Light or Dark follow the phone (that was never a choice)",
		ThemeManager.follows_system and ThemeManager.current_theme_name == ThemeManager.detect_system_theme())
	_write(path, {"theme": ThemeManager.THEME_SEPIA})
	ThemeManager.load_settings()
	_check("but a Sepia saved then was picked, and stays", not ThemeManager.follows_system and ThemeManager.current_theme_name == ThemeManager.THEME_SEPIA)

	ThemeManager.set_theme(ThemeManager.THEME_SYSTEM)
	ThemeManager._apply_palette(_other_theme())
	var heard := [0]
	var listener := func(): heard[0] += 1
	ThemeManager.add_listener(listener)
	ThemeManager.refresh_system_theme()
	ThemeManager.remove_listener(listener)
	_check("Following the phone, a switch made while away is picked up on return",
		ThemeManager.current_theme_name == ThemeManager.detect_system_theme() and heard[0] == 1)

func _other_locale() -> String:
	return LocalizationManager.LOCALE_TR if LocalizationManager.detect_system_locale() == LocalizationManager.LOCALE_EN else LocalizationManager.LOCALE_EN

func _test_language_follows_system() -> void:
	var path := AppSettings.CONFIG_PATH
	var system := LocalizationManager.detect_system_locale()
	DirAccess.remove_absolute(path)
	AppSettings.load_config()
	_check("A first start uses the phone's language (%s)" % system, AppSettings.locale_follows_system and LocalizationManager.get_locale() == system)
	AppSettings.save_config()
	_check("and saves that it follows it", _read(path).get("locale", "") == AppSettings.LOCALE_SYSTEM)

	AppSettings.set_language(_other_locale())
	AppSettings.load_config()
	_check("A language picked is kept", not AppSettings.locale_follows_system and LocalizationManager.get_locale() == _other_locale())
	AppSettings.follow_system_changes()
	_check("whatever the phone's language", LocalizationManager.get_locale() == _other_locale())

	_write(path, {"locale": _other_locale()})
	AppSettings.load_config()
	_check("A config saved by 1.0.0 follows the phone", AppSettings.locale_follows_system and LocalizationManager.get_locale() == system)

	AppSettings.set_language(AppSettings.LOCALE_SYSTEM)
	LocalizationManager.set_locale(_other_locale())
	AppSettings.follow_system_changes()
	_check("Following the phone, a language changed while away is picked up on return", LocalizationManager.get_locale() == system)

func _test_settings_and_resume() -> void:
	var settings := SettingsScreen.new()
	settings.theme = ThemeManager.build_godot_theme()
	root.add_child(settings)
	await process_frame
	var pickers := [settings.lang_option, settings.theme_option, settings.font_option, settings.text_size_option]
	_check("Every Settings dropdown is a picker titled by its row",
		pickers.all(func(p): return p is PickerButton and p.title_source != null and not p.title_source.text.is_empty()))
	AppSettings.set_language(AppSettings.LOCALE_SYSTEM)
	_check("Language offers System first, and shows it chosen",
		settings.lang_option.selected == 0 and settings.lang_option.get_item_text(0) == LocalizationManager.translate("OPTION_SYSTEM"))
	settings._on_language_selected(SettingsScreen.LANG_ORDER.find(_other_locale()))
	_check("Picking a language there sets it", not AppSettings.locale_follows_system and LocalizationManager.get_locale() == _other_locale()
		and settings.lang_option.selected == SettingsScreen.LANG_ORDER.find(_other_locale()))
	settings._on_language_selected(0)
	_check("and System goes back to the phone's", AppSettings.locale_follows_system and LocalizationManager.get_locale() == LocalizationManager.detect_system_locale())
	settings._on_theme_selected(SettingsScreen.THEME_ORDER.find(ThemeManager.THEME_FOREST))
	_check("Theme: picking Forest shows Forest", settings.theme_option.selected == SettingsScreen.THEME_ORDER.find(ThemeManager.THEME_FOREST))
	settings._on_theme_selected(0)
	_check("and System shows System", ThemeManager.follows_system and settings.theme_option.selected == 0
		and settings.theme_option.get_item_text(0) == LocalizationManager.translate("OPTION_SYSTEM"))
	settings.queue_free()
	await process_frame

	var app := AppRoot.new()
	root.add_child(app)
	await process_frame
	AppSettings.set_language(AppSettings.LOCALE_SYSTEM)
	LocalizationManager.set_locale(_other_locale())
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check("Coming back to the app picks up the phone's language", LocalizationManager.get_locale() == LocalizationManager.detect_system_locale())
	app.queue_free()
	await process_frame
