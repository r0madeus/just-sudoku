extends SceneTree

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const CustomThemeDialog = preload("res://scenes/menus/dialogs/custom_theme_dialog.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING THEME EDITOR & NEW THEMES TESTS")
	print("========================================")

	test_builtin_themes_exist()
	test_theme_switching_and_notifications()
	test_apply_custom_palette_and_derivation()
	test_persistence_and_reload()
	test_custom_theme_dialog_ui_and_preview()
	test_settings_screen_theme_integration()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")

	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func test_builtin_themes_exist() -> void:
	print("\n--- Test 1: Built-in Themes (Sepia & Forest Included) ---")
	var themes := [
		ThemeManager.THEME_DARK,
		ThemeManager.THEME_AMOLED,
		ThemeManager.THEME_LIGHT,
		ThemeManager.THEME_SEPIA,
		ThemeManager.THEME_FOREST
	]

	var essential_keys := [
		"bg", "surface", "grid_major", "grid_minor", "cell_bg",
		"cell_selected", "cell_peer", "cell_same_num", "text_given",
		"text_user", "text_conflict", "text_notes", "accent_blue", "button_normal"
	]

	for t_name in themes:
		assert_true(ThemeManager.PALETTES.has(t_name), "Palette exists for theme: %s" % t_name)
		var p: Dictionary = ThemeManager.PALETTES[t_name]
		var all_keys_present := true
		for k in essential_keys:
			if not p.has(k) or not (p[k] is Color):
				all_keys_present = false
				break
		assert_true(all_keys_present, "All essential Color keys present in theme: %s" % t_name)

	# Verify specific Sepia and Forest color properties
	var sepia_bg: Color = ThemeManager.PALETTES[ThemeManager.THEME_SEPIA]["bg"]
	assert_true(sepia_bg.is_equal_approx(Color("#f4ecd8")), "Sepia background is warm parchment #f4ecd8")

	var forest_bg: Color = ThemeManager.PALETTES[ThemeManager.THEME_FOREST]["bg"]
	assert_true(forest_bg.is_equal_approx(Color("#101a14")), "Forest background is dark sage #101a14")

func test_theme_switching_and_notifications() -> void:
	print("\n--- Test 2: Theme Switching & Listener Notifications ---")
	var notification_fired := [false]
	var listener := func():
		notification_fired[0] = true

	ThemeManager.add_listener(listener)

	ThemeManager.set_theme(ThemeManager.THEME_SEPIA)
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_SEPIA, "Current theme set to Sepia")
	assert_true(notification_fired[0], "Theme change listener was invoked")
	assert_true(ThemeManager.get_color("bg").is_equal_approx(Color("#f4ecd8")), "get_color('bg') returns Sepia bg")

	notification_fired[0] = false
	ThemeManager.set_theme(ThemeManager.THEME_FOREST)
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_FOREST, "Current theme set to Forest")
	assert_true(notification_fired[0], "Theme change listener was invoked for Forest")
	assert_true(ThemeManager.get_color("accent_blue").is_equal_approx(Color("#059669")), "Forest accent_blue is emerald")

	ThemeManager.remove_listener(listener)
	notification_fired[0] = false
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	assert_true(not notification_fired[0], "Listener was removed and not invoked")

func test_apply_custom_palette_and_derivation() -> void:
	print("\n--- Test 3: Apply Custom Palette & Harmonic Derivation ---")
	var custom_colors: Dictionary = {
		"bg": Color("#1a1a2e"),
		"grid_major": Color("#e94560"),
		"cell_bg": Color("#16213e"),
		"cell_selected": Color("#0f3460"),
		"text_given": Color("#e94560"),
		"text_user": Color("#533483"),
		"accent_blue": Color("#e94560"),
		"text_conflict": Color("#ff2a2a"),
		"text_notes": Color("#a2a8d3")
	}

	ThemeManager.apply_custom_palette(custom_colors)

	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_CUSTOM, "Theme is Custom")
	assert_true(ThemeManager.get_color("bg").is_equal_approx(Color("#1a1a2e")), "Custom bg matches")
	assert_true(ThemeManager.get_color("accent_blue").is_equal_approx(Color("#e94560")), "Custom accent matches")

	# Check derived secondary colors
	assert_true(ThemeManager.current_palette.has("grid_minor"), "Harmonized grid_minor was generated")
	assert_true(ThemeManager.current_palette.has("cell_peer"), "Harmonized cell_peer was generated")
	assert_true(ThemeManager.current_palette.has("surface"), "Harmonized surface was generated")
	assert_true(ThemeManager.current_palette.has("button_normal"), "Harmonized button_normal was generated")

	# Check get_custom_palette returns the 9 core fields
	var exported_palette := ThemeManager.get_custom_palette()
	assert_true(exported_palette.size() == 9, "get_custom_palette returns 9 core fields")
	assert_true(exported_palette.has("text_given") and exported_palette.has("cell_selected"), "Core fields present in exported palette")

func test_persistence_and_reload() -> void:
	print("\n--- Test 4: Custom Theme Persistence & Reload ---")
	# Custom theme was set in test 3, which calls save_settings()
	# Switch temporarily to Light
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_LIGHT, "Switched to Light")

	# Now re-apply custom and test loading from settings
	var custom_colors: Dictionary = {
		"bg": Color("#2b2b2b"),
		"grid_major": Color("#888888"),
		"cell_bg": Color("#333333"),
		"cell_selected": Color("#444444"),
		"text_given": Color("#ffffff"),
		"text_user": Color("#66aaff"),
		"accent_blue": Color("#66aaff"),
		"text_conflict": Color("#ff4444"),
		"text_notes": Color("#aaaaaa")
	}
	ThemeManager.apply_custom_palette(custom_colors)
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_CUSTOM, "Custom theme active before reload")

	# Reload settings from disk
	ThemeManager.load_settings()
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_CUSTOM, "Reloaded settings restores Custom theme")
	assert_true(ThemeManager.get_color("bg").is_equal_approx(Color("#2b2b2b")), "Reloaded custom bg is #2b2b2b")
	assert_true(ThemeManager.get_color("accent_blue").is_equal_approx(Color("#66aaff")), "Reloaded accent is #66aaff")

func test_custom_theme_dialog_ui_and_preview() -> void:
	print("\n--- Test 5: CustomThemeDialog UI & Live Preview ---")
	var dialog := CustomThemeDialog.new()

	assert_true(dialog.picker_buttons.size() == 9, "Dialog has 9 ColorPickerButton controls")
	assert_true(dialog.preset_buttons.size() == 5, "Dialog has 5 preset copy buttons")
	assert_true(dialog.preview_cells.size() == 9, "Dialog has 3x3 (9) preview cells")

	# Open dialog (loads current palette)
	dialog.open_dialog()

	# Simulate changing a color in picker
	var new_grid := Color("#334455")
	dialog.picker_buttons["grid_major"].color = new_grid
	dialog._on_color_changed("grid_major", new_grid)

	assert_true(dialog._working_palette["grid_major"].is_equal_approx(new_grid), "Working palette updated on grid_major change")
	assert_true(dialog.preview_bg.color.is_equal_approx(new_grid), "Live preview grid background updated immediately")

	# Test preset copy
	dialog._copy_preset(ThemeManager.THEME_SEPIA)
	assert_true(dialog._working_palette["bg"].is_equal_approx(Color("#f4ecd8")), "Preset Sepia copied to working palette")
	assert_true(dialog.picker_buttons["bg"].color.is_equal_approx(Color("#f4ecd8")), "Picker button color updated from preset")

	# Test save confirmation
	var save_signal_fired := [false]
	dialog.theme_saved.connect(func(): save_signal_fired[0] = true)
	dialog._on_confirmed()

	assert_true(save_signal_fired[0], "theme_saved signal emitted upon save")
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_CUSTOM, "ThemeManager set to Custom after dialog save")

	dialog.queue_free()

func test_settings_screen_theme_integration() -> void:
	print("\n--- Test 6: SettingsScreen Theme Integration ---")
	var settings := SettingsScreen.new()

	assert_true(settings.theme_option != null, "SettingsScreen has theme_option dropdown")
	assert_true(settings.custom_theme_btn != null, "SettingsScreen has custom_theme_btn")

	# Verify all 6 options in dropdown
	assert_true(settings.theme_option.item_count == 7, "Theme dropdown has 7 items (System, Dark, AMOLED, Light, Sepia, Forest, Custom)")

	# Verify clicking custom theme button emits signal
	var custom_requested := [false]
	settings.custom_theme_requested.connect(func(): custom_requested[0] = true)
	settings.custom_theme_btn.pressed.emit()
	assert_true(custom_requested[0], "custom_theme_requested signal emitted when button pressed")

	# Verify selecting Sepia in dropdown updates ThemeManager
	settings._on_theme_selected(SettingsScreen.THEME_ORDER.find(ThemeManager.THEME_SEPIA))
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_SEPIA, "Selecting Sepia index sets ThemeManager to Sepia")

	# Verify selecting Forest in dropdown updates ThemeManager
	settings._on_theme_selected(SettingsScreen.THEME_ORDER.find(ThemeManager.THEME_FOREST))
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_FOREST, "Selecting Forest index sets ThemeManager to Forest")

	# Reset back to Dark for clean test end
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	settings.queue_free()
