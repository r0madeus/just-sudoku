extends SceneTree

## Settings use on/off switches (a pill and a sliding knob) instead of check boxes, all of one size;
## the knob slides when animations are on and jumps when they are off. Glass effects is a setting:
## off, the glass cards and the dimmed backdrop behind dialogs are plain. And the browser version
## says once that progress stays in the browser.

const ToggleSwitch = preload("res://scenes/ui/toggle_switch.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const WebFiles = preload("res://scripts/services/web_files.gd")

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
	print("\n=== SWITCHES, GLASS EFFECTS, WEB NOTICE ===")
	AppSettings.auto_open_last_game = false
	await _test_switch()
	await _test_settings_screen()
	await _test_glass()
	await _test_web_notice()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_switch() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var sw := ToggleSwitch.new()
	sw.button_pressed = true
	holder.add_child(sw)
	await _frames(3)
	_check("A switch is a CheckBox underneath, so the Settings rows work as before", sw is CheckBox)
	_check("It has its own size, track and knob (%s)" % sw.size, sw.size.x >= ToggleSwitch.TRACK_WIDTH and sw.size.y >= ToggleSwitch.TRACK_HEIGHT)
	_check("A switch that starts on has the knob across", is_equal_approx(sw.position_t, 1.0))
	AppSettings.animations_enabled = false
	sw.button_pressed = false
	_check("With animations off the knob jumps at once", is_equal_approx(sw.position_t, 0.0))
	AppSettings.animations_enabled = true
	sw.button_pressed = true
	await _frames(3)
	_check("With animations on it is on its way a moment later (%.2f)" % sw.position_t, sw.position_t > 0.0 and sw.position_t < 1.0)
	await create_timer(ToggleSwitch.SLIDE_TIME + 0.2).timeout
	_check("and has arrived (%.2f)" % sw.position_t, is_equal_approx(sw.position_t, 1.0))
	sw.button_pressed = false
	await create_timer(ToggleSwitch.SLIDE_TIME + 0.2).timeout
	_check("and goes back the same way", is_equal_approx(sw.position_t, 0.0))
	var early := ToggleSwitch.new()
	early.button_pressed = true
	holder.add_child(early)
	await _frames(2)
	_check("it shows as on when it appears", is_equal_approx(early.position_t, 1.0))
	holder.queue_free()
	await process_frame

func _test_settings_screen() -> void:
	AppSettings.animations_enabled = false
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	app.main_menu.settings_requested.emit()
	await create_timer(1.0).timeout
	var boxes: Array = app.settings_screen.find_children("*", "CheckBox", true, false)
	var plain := 0
	var sizes := {}
	for b in boxes:
		if not b is ToggleSwitch:
			plain += 1
		else:
			sizes[b.size] = true
	_check("Settings has its switches (%d)" % boxes.size(), boxes.size() >= 10)
	_check("every one of them a switch, no plain check box left (%d)" % plain, plain == 0)
	_check("all the same size (%d sizes)" % sizes.size(), sizes.size() == 1)
	_check("Glass effects is one of them", app.settings_screen.glass_check is ToggleSwitch and app.settings_screen.glass_check.button_pressed == AppSettings.glass_effects)
	var backup = app.settings_screen.backup_section
	backup._on_backup_pressed()
	await _frames(3)
	_check("The backup dialog is part of the app (it carries the app's theme), not hung on the bare window",
		backup._choice != null and backup._choice.get_parent() == app)
	app.queue_free()
	await process_frame

func _shader_reads_screen(panel: GlassPanel) -> bool:
	return panel.glass_rect.material.shader.code.contains("hint_screen_texture")

func _test_glass() -> void:
	ThemeManager.set_theme("Dark")
	AppSettings.glass_effects = true
	var panel := GlassPanel.new()
	root.add_child(panel)
	await _frames(2)
	_check("On: the glass reads and blurs the screen", _shader_reads_screen(panel))
	AppSettings.glass_effects = false
	ThemeManager.notify_changed()
	await _frames(2)
	_check("Off: the same card is a plain surface, the screen is not copied for it", not _shader_reads_screen(panel))
	var modal := AppModal.new()
	modal.blur_background = true
	root.add_child(modal)
	await _frames(2)
	_check("and the backdrop behind a dialog is a plain dim, not a blur", modal.backdrop.material == null)
	modal.queue_free()
	AppSettings.glass_effects = true
	ThemeManager.notify_changed()
	await _frames(2)
	_check("On again: glass is back without restarting", _shader_reads_screen(panel))
	var modal2 := AppModal.new()
	modal2.blur_background = true
	root.add_child(modal2)
	await _frames(2)
	_check("and the dialog's backdrop blurs again", modal2.backdrop.material != null)
	modal2.queue_free()
	panel.queue_free()
	AppSettings.glass_effects = false
	AppSettings.web_notice_seen = true
	AppSettings.save_config()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(AppSettings.CONFIG_PATH))
	_check("Both are kept in the saved settings", saved is Dictionary and saved.get("glass_effects", true) == false and saved.get("web_notice_seen", false) == true)
	AppSettings.glass_effects = true
	AppSettings.web_notice_seen = false
	AppSettings.save_config()
	await process_frame

func _test_web_notice() -> void:
	AppSettings.animations_enabled = false
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	AppSettings.web_notice_seen = false
	_check("Outside a browser nothing is said", app._maybe_show_web_notice() == null and not AppSettings.web_notice_seen)
	var note = app._maybe_show_web_notice(true)
	_check("In a browser the first start has a note", note != null and AppSettings.web_notice_seen)
	_check("saying progress stays in the browser", note != null and note.dialog_text == LocalizationManager.translate("WEB_NOTICE_BODY") and note.title != "WEB_NOTICE_TITLE")
	_check("and it is said only once", app._maybe_show_web_notice(true) == null)
	_check("Files in the browser are for the web export only", not WebFiles.available())
	AppSettings.web_notice_seen = false
	AppSettings.save_config()
	app.queue_free()
	await process_frame
