extends SceneTree

const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const MainMenu = preload("res://scenes/menus/main_menu.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")
const StatisticsScreen = preload("res://scenes/menus/statistics_screen.gd")
const LoadGameScreen = preload("res://scenes/menus/load_game_screen.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const SmartNumpad = preload("res://scenes/gameplay/smart_numpad.gd")
const SudokuGrid = preload("res://scenes/gameplay/sudoku_grid.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print("🧪 RUNNING CENTRALIZED RESPONSIVE SYSTEM TEST SUITE")
	print("========================================================\n")

	_test_design_constants_and_tokens()
	_test_device_categorization_and_scaling()
	_test_safe_area_insets()
	_test_game_screen_multi_resolution_layout()
	_test_main_menu_multi_resolution_layout()
	_test_secondary_screens_content_margins()
	_test_app_modal_responsive_clamping()
	_test_touch_targets()

	print("\n========================================================")
	print("🏁 SUMMARY: %d Passed, %d Failed" % [_passed, _failed])
	print("========================================================\n")

	if _failed > 0:
		quit(1)
	else:
		quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		_failed += 1
		printerr("  ✗ FAIL: %s" % message)

# -----------------------------------------------------------------------------
# 1. Base Design Resolution & Semantic Tokens
# -----------------------------------------------------------------------------
func _test_design_constants_and_tokens() -> void:
	print("--- 1. Base Design Resolution & Semantic Tokens ---")
	_assert(ResponsiveManager.BASE_WIDTH == 390.0, "Base width is 390.0 (Portrait iPhone/Standard Phone)")
	_assert(ResponsiveManager.BASE_HEIGHT == 844.0, "Base height is 844.0 (Portrait iPhone/Standard Phone)")
	_assert(ResponsiveManager.TOUCH_TARGET_MIN >= 44.0, "Minimum mobile touch target floor >= 44.0px")

	# Control heights
	_assert(ResponsiveManager.HEIGHT_BUTTON_HERO == 52.0, "Hero button height is 52.0px")
	_assert(ResponsiveManager.HEIGHT_BUTTON_PRIMARY == 48.0, "Primary button height is 48.0px")
	_assert(ResponsiveManager.HEIGHT_BUTTON_SECONDARY == 44.0, "Secondary button height is 44.0px")
	_assert(ResponsiveManager.HEIGHT_BUTTON_COMPACT == 36.0, "Compact button height is 36.0px")
	_assert(ResponsiveManager.HEIGHT_ACTION_DOCK >= 44.0, "Action dock height >= 44.0px")
	_assert(ResponsiveManager.HEIGHT_ROW_SETTING >= 44.0, "Setting row height >= 44.0px")

	# Spacing tokens (4px rhythm)
	_assert(ResponsiveManager.SPACE_2XS == 2, "SPACE_2XS is 2px")
	_assert(ResponsiveManager.SPACE_XS == 4, "SPACE_XS is 4px")
	_assert(ResponsiveManager.SPACE_SM == 8, "SPACE_SM is 8px")
	_assert(ResponsiveManager.SPACE_MD == 12, "SPACE_MD is 12px")
	_assert(ResponsiveManager.SPACE_LG == 16, "SPACE_LG is 16px")
	_assert(ResponsiveManager.SPACE_XL == 24, "SPACE_XL is 24px")
	_assert(ResponsiveManager.SPACE_2XL == 32, "SPACE_2XL is 32px")

	# Typography tokens
	_assert(ResponsiveManager.FONT_SIZE_HERO == 40, "FONT_SIZE_HERO is 40px")
	_assert(ResponsiveManager.FONT_SIZE_BODY == 14, "FONT_SIZE_BODY is 14px")
	_assert(ResponsiveManager.FONT_SIZE_CAPTION == 12, "FONT_SIZE_CAPTION is 12px")

	# Radii
	_assert(ResponsiveManager.RADIUS_SM == 4, "RADIUS_SM is 4px")
	_assert(ResponsiveManager.RADIUS_PILL == 22, "RADIUS_PILL is 22px")

# -----------------------------------------------------------------------------
# 2. Device Categorization & Automatic Scaling
# -----------------------------------------------------------------------------
func _test_device_categorization_and_scaling() -> void:
	print("\n--- 2. Device Categorization & Automatic Scaling ---")
	# Compact Phone (360x640)
	var cat_compact := ResponsiveManager.get_device_category(Vector2(360, 640))
	_assert(cat_compact == ResponsiveManager.DeviceCategory.COMPACT_PHONE, "360x640 correctly categorized as COMPACT_PHONE")

	# Standard Phone (390x844)
	var cat_phone := ResponsiveManager.get_device_category(Vector2(390, 844))
	_assert(cat_phone == ResponsiveManager.DeviceCategory.PHONE, "390x844 correctly categorized as PHONE")

	# Large Phone (430x932)
	var cat_large_phone := ResponsiveManager.get_device_category(Vector2(430, 932))
	_assert(cat_large_phone == ResponsiveManager.DeviceCategory.PHONE, "430x932 correctly categorized as PHONE")

	# Tablet (768x1024)
	var cat_tablet := ResponsiveManager.get_device_category(Vector2(768, 1024))
	_assert(cat_tablet == ResponsiveManager.DeviceCategory.TABLET, "768x1024 correctly categorized as TABLET")

	# Desktop (1280x720)
	var cat_desktop := ResponsiveManager.get_device_category(Vector2(1280, 720))
	_assert(cat_desktop == ResponsiveManager.DeviceCategory.DESKTOP, "1280x720 correctly categorized as DESKTOP")

	# Scale factors
	var scale_compact := ResponsiveManager.get_scale_factor(Vector2(360, 640))
	_assert(scale_compact >= 0.88 and scale_compact <= 1.0, "Scale factor for 360x640 is clamped between 0.88 and 1.0")

	var scale_phone := ResponsiveManager.get_scale_factor(Vector2(390, 844))
	_assert(is_equal_approx(scale_phone, 1.0), "Scale factor for base 390x844 is exactly 1.0")

	var scale_desktop := ResponsiveManager.get_scale_factor(Vector2(1280, 720))
	_assert(is_equal_approx(scale_desktop, 1.0), "Scale factor for Desktop is normalized to 1.0")

# -----------------------------------------------------------------------------
# 3. Mobile Safe Area & Notch Insets
# -----------------------------------------------------------------------------
func _test_safe_area_insets() -> void:
	print("\n--- 3. Mobile Safe Area & Notch Insets ---")
	var insets := ResponsiveManager.get_safe_area_insets(null)
	_assert(insets.has("top") and insets.has("bottom") and insets.has("left") and insets.has("right"), "Safe insets dictionary has all 4 edges")
	_assert(insets["top"] >= 16, "Top inset enforces minimum comfortable margin >= 16px")
	_assert(insets["bottom"] >= 16, "Bottom inset enforces minimum home indicator margin >= 16px")

# -----------------------------------------------------------------------------
# 4. Game Screen Multi-Resolution Layout & 1:1 Board Aspect Ratio
# -----------------------------------------------------------------------------
func _test_game_screen_multi_resolution_layout() -> void:
	print("\n--- 4. Game Screen Multi-Resolution Layout ---")
	var test_resolutions := [
		{"res": Vector2(360, 640), "name": "Compact Phone (360x640)"},
		{"res": Vector2(390, 844), "name": "Standard Phone (390x844)"},
		{"res": Vector2(430, 932), "name": "Large Phone (430x932)"},
		{"res": Vector2(768, 1024), "name": "Tablet Portrait (768x1024)"},
		{"res": Vector2(1280, 720), "name": "Desktop Landscape (1280x720)"},
		{"res": Vector2(844, 390), "name": "Phone Landscape (844x390)"}
	]

	for tr in test_resolutions:
		var r: Vector2 = tr["res"]
		var rname: String = tr["name"]

		var screen := GameScreen.new()
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.size = r
		screen._apply_responsive_layout()

		# Board 1:1 Aspect Ratio check
		var grid_min: Vector2 = screen.grid_container.custom_minimum_size
		_assert(is_equal_approx(grid_min.x, grid_min.y), "%s: Sudoku board minimum size is strictly 1:1 square (%dx%d)" % [rname, int(grid_min.x), int(grid_min.y)])
		_assert(grid_min.x > 180.0, "%s: Sudoku board has usable minimum dimensions (> 180px, actual: %dpx)" % [rname, int(grid_min.x)])
		if not ResponsiveManager.is_game_landscape(r):
			_assert(grid_min.x <= ResponsiveManager.MAX_BOARD_WIDTH, "%s: Sudoku board does not exceed max width cap (<= 520px)" % rname)

		# Check no vertical overflow budget
		var margin_top: int = screen.margin_container.get_theme_constant("margin_top", "MarginContainer")
		var margin_bottom: int = screen.margin_container.get_theme_constant("margin_bottom", "MarginContainer")
		var header_h: float = screen.header_bar.custom_minimum_size.y
		var action_h: float = screen.action_dock.custom_minimum_size.y
		var numpad_h: float = screen.numpad.custom_minimum_size.y
		var top_sp: float = screen.top_spacer.custom_minimum_size.y
		var mid_sp: float = screen.mid_spacer.custom_minimum_size.y
		var num_sp: float = screen.numpad_spacer.custom_minimum_size.y
		var bot_sp: float = screen.bottom_spacer.custom_minimum_size.y

		var total_needed_h: float = float(margin_top + margin_bottom) + header_h + action_h + numpad_h + grid_min.y + top_sp + mid_sp + num_sp + bot_sp
		if ResponsiveManager.is_game_landscape(r):
			# Landscape: board sits beside the dock + numpad, so only header + board share the height
			_assert(screen._landscape, "%s: Landscape layout is active (board beside controls)" % rname)
			var side_h: float = action_h + numpad_h + 16.0
			total_needed_h = float(margin_top + margin_bottom) + header_h + maxf(grid_min.y, side_h)
			_assert(grid_min.x <= ResponsiveManager.MAX_BOARD_WIDTH_LANDSCAPE, "%s: Landscape board respects its own cap" % rname)
		_assert(total_needed_h <= r.y + 4.0, "%s: Layout height budget (%dpx) fits viewport (%dpx) without clipping" % [rname, int(total_needed_h), int(r.y)])

		if int(r.x) == 360 and int(r.y) == 640:
			_assert(screen.numpad.is_compact_mode == true, "360x640: SmartNumpad entered compact mode for tight screen")
		elif int(r.x) == 390 and int(r.y) == 844:
			_assert(screen.numpad.is_compact_mode == false, "390x844: SmartNumpad in standard mode")

		screen.queue_free()

# -----------------------------------------------------------------------------
# 5. Main Menu Multi-Resolution Layout & Centering
# -----------------------------------------------------------------------------
func _test_main_menu_multi_resolution_layout() -> void:
	print("\n--- 5. Main Menu Multi-Resolution Layout ---")
	var test_resolutions := [
		{"res": Vector2(360, 640), "name": "Compact Phone (360x640)"},
		{"res": Vector2(390, 844), "name": "Standard Phone (390x844)"},
		{"res": Vector2(768, 1024), "name": "Tablet Portrait (768x1024)"},
		{"res": Vector2(1280, 720), "name": "Desktop Landscape (1280x720)"}
	]

	for tr in test_resolutions:
		var r: Vector2 = tr["res"]
		var rname: String = tr["name"]

		var menu := MainMenu.new()
		menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
		menu.size = r
		menu._apply_responsive_layout()

		var side_margin: int = menu.margin_container.get_theme_constant("margin_left", "MarginContainer")
		var effective_content_w: float = r.x - float(side_margin * 2)
		_assert(effective_content_w <= ResponsiveManager.MAX_MENU_WIDTH + 8.0, "%s: Content width is restrained (<= %dpx, actual: %dpx)" % [rname, int(ResponsiveManager.MAX_MENU_WIDTH), int(effective_content_w)])
		_assert(side_margin >= 16, "%s: Side margins maintain comfortable breathing room (>= 16px, actual: %dpx)" % [rname, side_margin])

		menu.queue_free()

# -----------------------------------------------------------------------------
# 6. Secondary Screens Content Margins
# -----------------------------------------------------------------------------
func _test_secondary_screens_content_margins() -> void:
	print("\n--- 6. Secondary Screens Content Margins & Desktop Centering ---")
	var test_classes := [SettingsScreen, HistoryScreen, StatisticsScreen, LoadGameScreen]
	var names := ["SettingsScreen", "HistoryScreen", "StatisticsScreen", "LoadGameScreen"]

	for i in range(test_classes.size()):
		var cls = test_classes[i]
		var sname: String = names[i]

		var scr: Control = cls.new()
		scr.set_anchors_preset(Control.PRESET_TOP_LEFT)
		scr.size = Vector2(1280, 720)
		if not scr.is_node_ready():
			scr._ready()
		scr._apply_responsive_layout()

		var margin_ctrl: MarginContainer = scr.get("margin")
		_assert(margin_ctrl != null, "%s has margin container" % sname)
		if margin_ctrl != null:
			var side_margin: int = margin_ctrl.get_theme_constant("margin_left", "MarginContainer")
			var content_w: float = 1280.0 - float(side_margin * 2)
			_assert(is_equal_approx(content_w, ResponsiveManager.MAX_CONTENT_WIDTH), "%s on 1280px desktop centers column to exactly 480px (margin=%dpx)" % [sname, side_margin])

		scr.queue_free()

# -----------------------------------------------------------------------------
# 7. AppModal Responsive Clamping
# -----------------------------------------------------------------------------
func _test_app_modal_responsive_clamping() -> void:
	print("\n--- 7. AppModal Responsive Clamping ---")
	var modal1 := AppModal.new()
	modal1.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modal1.size = Vector2(1280, 720)
	modal1._apply_responsive_layout()
	_assert(modal1.modal_panel.custom_minimum_size.x <= ResponsiveManager.MAX_MODAL_WIDTH, "Modal width on 1280px screen clamped to max %dpx" % int(ResponsiveManager.MAX_MODAL_WIDTH))
	modal1.queue_free()

	var modal2 := AppModal.new()
	modal2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modal2.size = Vector2(360, 640)
	modal2._apply_responsive_layout()
	_assert(modal2.modal_panel.custom_minimum_size.x <= 328.0, "Modal width on 360px screen clamped to 328px without clipping")
	modal2.queue_free()

# -----------------------------------------------------------------------------
# 8. Mobile Touch Target Floor
# -----------------------------------------------------------------------------
func _test_touch_targets() -> void:
	print("\n--- 8. Mobile Touch Targets (Floor >= 40-44px) ---")
	var menu := MainMenu.new()
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.size = Vector2(390, 844)

	_assert(menu.continue_btn.custom_minimum_size.y >= ResponsiveManager.TOUCH_TARGET_MIN, "MainMenu Continue button height (%.0fpx) >= 44px" % menu.continue_btn.custom_minimum_size.y)
	_assert(menu.new_game_btn.custom_minimum_size.y >= ResponsiveManager.TOUCH_TARGET_MIN, "MainMenu New Game button height (%.0fpx) >= 44px" % menu.new_game_btn.custom_minimum_size.y)
	_assert(menu.daily_btn.custom_minimum_size.y >= 40.0, "MainMenu Daily button height (%.0fpx) >= 40px" % menu.daily_btn.custom_minimum_size.y)
	_assert(menu.history_btn.custom_minimum_size.y >= 40.0, "MainMenu History button height (%.0fpx) >= 40px" % menu.history_btn.custom_minimum_size.y)
	_assert(menu.stats_btn.custom_minimum_size.y >= 40.0, "MainMenu Stats button height (%.0fpx) >= 40px" % menu.stats_btn.custom_minimum_size.y)
	_assert(menu.settings_btn.custom_minimum_size.y >= 40.0, "MainMenu Settings button height (%.0fpx) >= 40px" % menu.settings_btn.custom_minimum_size.y)

	var game := GameScreen.new()
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(390, 844)

	_assert(game.back_btn.custom_minimum_size.y >= 38.0, "GameScreen Back button height (%.0fpx) >= 38px" % game.back_btn.custom_minimum_size.y)
	_assert(game.pause_btn.custom_minimum_size.y >= 38.0, "GameScreen Pause button height (%.0fpx) >= 38px" % game.pause_btn.custom_minimum_size.y)
	_assert(game.action_dock.custom_minimum_size.y >= ResponsiveManager.TOUCH_TARGET_MIN, "GameScreen Action dock height (%.0fpx) >= 44px" % game.action_dock.custom_minimum_size.y)

	# SmartNumpad button touch targets
	for d in range(1, 10):
		var btn: Button = game.numpad.num_buttons[d - 1]
		_assert(btn.custom_minimum_size.x >= 60.0 and btn.custom_minimum_size.y >= 60.0, "SmartNumpad digit %d touch target (%dx%dpx) >= 60px" % [d, int(btn.custom_minimum_size.x), int(btn.custom_minimum_size.y)])

	menu.queue_free()
	game.queue_free()
