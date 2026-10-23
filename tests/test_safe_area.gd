extends SceneTree

## Safe area insets that cannot be right are not used, and coming back from the background lays
## every screen out again. On a phone, Android once reported the landscape safe area to a portrait
## window on resume: the camera cut-out became a wide left margin and the menu and the game ran
## off the right edge until the app was restarted.

const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AppRoot = preload("res://scenes/app_root.gd")

const PHONE_PX := Vector2i(1080, 2400)
const PHONE_DP := Vector2(393.0, 873.0)

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

func _run() -> void:
	await process_frame
	print("\n=== SAFE AREA AND RELAYOUT ===")
	_test_insets()
	await _test_relayout()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _insets(safe: Rect2i, window: Vector2i = PHONE_PX, vp: Vector2 = PHONE_DP) -> Dictionary:
	return ResponsiveManager.insets_from_safe_area(safe, window, vp)

func _test_insets() -> void:
	# Status bar of 100 px and gesture bar of 60 px on a 1080x2400 phone at 2.75 px per dp
	var normal := _insets(Rect2i(0, 100, 1080, 2240))
	_check("A portrait phone: status and gesture bars become top and bottom margins (%s)" % str(normal),
		normal.top == 36 and normal.bottom == 21 and normal.left == 0 and normal.right == 0)
	var landscape_area := _insets(Rect2i(110, 0, 2290, 1080))
	_check("The landscape safe area told to a portrait window is ignored (%s)" % str(landscape_area),
		landscape_area.left == 0 and landscape_area.right == 0 and landscape_area.top == 16)
	_check("A safe area reaching outside the window is ignored",
		_insets(Rect2i(-20, 100, 1080, 2240)).left == 0)
	_check("A side inset wider than any cut-out is ignored", _insets(Rect2i(400, 100, 680, 2240)).left == 0)
	_check("A top inset of half the screen is ignored", _insets(Rect2i(0, 1200, 1080, 1200)).top == 16)
	var tablet := _insets(Rect2i(110, 0, 2290, 1080), Vector2i(2400, 1080), Vector2(873.0, 393.0))
	_check("A real landscape cut-out on the left is kept (%s)" % str(tablet), tablet.left == 40 and tablet.right == 0)
	_check("No safe area: the defaults", _insets(Rect2i()).top == 16 and _insets(Rect2i()).left == 0)

func _test_relayout() -> void:
	var app := AppRoot.new()
	root.add_child(app)
	await process_frame
	await process_frame
	var menu := app.main_menu
	var margin: MarginContainer = menu.margin_container
	var good_left: int = margin.get_theme_constant("margin_left")
	# What a wrong safe area left behind: a wide left margin, the roomy navigation look
	margin.add_theme_constant_override("margin_left", good_left + 120)
	menu.nav_grid.columns = 1
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check("Coming back from the background lays the menu out again",
		margin.get_theme_constant("margin_left") == good_left and menu.nav_grid.columns != 1)

	var game_margin: MarginContainer = app.game_screen.margin_container
	var game_left: int = game_margin.get_theme_constant("margin_left")
	game_margin.add_theme_constant_override("margin_left", game_left + 120)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("and the game screen, though it is not on show", game_margin.get_theme_constant("margin_left") == game_left)

	margin.add_theme_constant_override("margin_left", good_left + 120)
	await create_timer(AppRoot.RELAYOUT_DELAYS[AppRoot.RELAYOUT_DELAYS.size() - 1] + 0.2).timeout
	_check("and again once Android has settled", margin.get_theme_constant("margin_left") == good_left)

	app.settings_screen.visible = true
	_check("Settings shows what the app was told about the display",
		app.settings_screen.display_label.text.contains(" px · ") and app.settings_screen.display_label.text.contains(" dp · "))
	app.queue_free()
	await process_frame
