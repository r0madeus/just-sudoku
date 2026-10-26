extends SceneTree

## Three small things players asked for: a GitHub link in Settings' corner (level with Back, the
## title staying in the middle); the Notes and Colours buttons are plain when off and a filled
## circle when on (no outline); and on a wide window the resume card and the Daily Sudoku beside it
## start at the same height and the card is as tall as the actions next to it.

const MainMenu = preload("res://scenes/menus/main_menu.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const GameActionDock = preload("res://scenes/ui/game_action_dock.gd")

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
	print("\n=== HEADER, DOCK, MENU ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	await _test_github_link()
	await _test_toggles()
	await _test_wide_menu()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_github_link() -> void:
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(390, 844)
	await _frames(4)
	_check("Settings has a GitHub button with the mark on it", screen.github_btn != null and screen.github_btn.icon != null and screen.github_btn.text == "")
	_check("pointing at the project's page", SettingsScreen.REPO_URL == "https://github.com/r0madeus/just-sudoku")
	_check("with a name for the mouse and screen readers", screen.github_btn.tooltip_text == LocalizationManager.translate("BTN_GITHUB") and screen.github_btn.tooltip_text != "BTN_GITHUB")
	var back: Control = screen.back_btn
	var link: Control = screen.github_btn
	_check("It is the size of Back (%s and %s)" % [back.size, link.size], back.size.is_equal_approx(link.size))
	var left_gap: float = back.global_position.x - screen.global_position.x
	var right_gap: float = screen.global_position.x + screen.size.x - link.get_global_rect().end.x
	_check("and level with it across from it (%d and %d from the edges)" % [int(left_gap), int(right_gap)], absf(left_gap - right_gap) <= 1.0
		and absf(back.global_position.y - link.global_position.y) <= 1.0)
	var title_mid: float = screen.title_label.get_global_rect().get_center().x
	_check("The title stays in the middle (%d of %d)" % [int(title_mid), int(screen.size.x / 2.0)], absf(title_mid - screen.global_position.x - screen.size.x / 2.0) <= 1.0)
	_check("The mark ships with its licence note", FileAccess.get_file_as_string("res://assets/icons/LICENSE-lucide.txt").contains("github.svg"))
	screen.queue_free()
	await process_frame

func _test_toggles() -> void:
	var dock := GameActionDock.new()
	root.add_child(dock)
	await _frames(3)
	for pair in [[dock.notes_btn, "notes"], [dock.colors_btn, "colours"]]:
		var btn: Button = pair[0]
		var name: String = pair[1]
		if name == "notes":
			dock.set_notes_active(false)
		else:
			dock.set_color_active(false)
		await _frames(2)
		_check("%s off: no outline of its own" % name, not btn.has_theme_stylebox_override("normal"))
		if name == "notes":
			dock.set_notes_active(true)
		else:
			dock.set_color_active(true)
		await _frames(2)
		var sb := btn.get_theme_stylebox("normal") as StyleBoxFlat
		_check("%s on: a filled circle (radius %d), without a border" % [name, sb.corner_radius_top_left if sb != null else -1],
			sb != null and sb.corner_radius_top_left >= 99 and sb.border_width_left == 0 and sb.border_width_top == 0)
		_check("on a square button (%s)" % btn.size, absf(btn.size.x - btn.size.y) <= 1.0)
		_check("%s on: the icon is white" % name, btn.get_theme_color("icon_normal_color") == Color.WHITE)
		if name == "notes":
			dock.set_notes_active(false)
		else:
			dock.set_color_active(false)
	dock.queue_free()
	await process_frame

func _test_wide_menu() -> void:
	var menu := MainMenu.new()
	root.add_child(menu)
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.size = Vector2(1280, 800)
	menu._apply_responsive_layout()
	await _frames(6)
	var card: Control = menu.resume_card
	var daily: Control = menu.daily_panel
	var hero: Control = menu.actions_vbox
	_check("Wide: the resume card is level with the Daily Sudoku at the top (%d and %d)" % [int(card.global_position.y), int(daily.global_position.y)],
		menu.is_wide and absf(card.global_position.y - daily.global_position.y) <= 1.0)
	_check("and as tall as the actions beside it, bottoms level (%d and %d)" % [int(card.get_global_rect().end.y), int(hero.get_global_rect().end.y)],
		absf(card.get_global_rect().end.y - hero.get_global_rect().end.y) <= 1.0)
	menu.size = Vector2(390, 844)
	menu._apply_responsive_layout()
	await _frames(4)
	_check("Back to a phone: the card is its own height again", not menu.is_wide and card.custom_minimum_size.y == 0.0)
	menu.queue_free()
	await process_frame
