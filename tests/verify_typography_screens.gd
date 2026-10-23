extends SceneTree

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const AppRoot = preload("res://scenes/app_root.gd")
const MainMenu = preload("res://scenes/menus/main_menu.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")
const StatisticsScreen = preload("res://scenes/menus/statistics_screen.gd")
const NewGameDialog = preload("res://scenes/menus/new_game_dialog.gd")
const CustomThemeDialog = preload("res://scenes/menus/dialogs/custom_theme_dialog.gd")

var passes: int = 0
var fails: int = 0

func assert_test(condition: bool, msg: String) -> void:
	if condition:
		passes += 1
		print("  ✓ PASS: %s" % msg)
	else:
		fails += 1
		printerr("  ✗ FAIL: %s" % msg)

func _init() -> void:
	print("\n========================================================")
	print("🔍 TYPOGRAPHY & BUNDLED FONT INTEGRATION VERIFICATION")
	print("========================================================")

	# 1. Bundled Fonts Verification
	print("\n--- 1. Bundled Fonts Resource Loading ---")
	var font_inter := ThemeManager.get_font_inter()
	assert_test(font_inter != null, "Inter variable TTF successfully loaded")
	assert_test(font_inter is FontFile, "Inter is a valid FontFile resource")

	var font_serif_reg := ThemeManager.get_font_serif_regular()
	assert_test(font_serif_reg != null, "Source Serif 4 Regular successfully loaded")
	assert_test(font_serif_reg is FontFile, "Source Serif 4 Regular is a valid FontFile resource")

	var font_serif_semi := ThemeManager.get_font_serif_semibold()
	assert_test(font_serif_semi != null, "Source Serif 4 Semibold successfully loaded")
	assert_test(font_serif_semi is FontFile, "Source Serif 4 Semibold is a valid FontFile resource")

	var font_mono := ThemeManager.get_font_mono()
	assert_test(font_mono != null, "IBM Plex Mono Regular successfully loaded")
	assert_test(font_mono is FontFile, "IBM Plex Mono Regular is a valid FontFile resource")

	# 2. Global Theme Typography Construction
	print("\n--- 2. Global Theme Typography Construction ---")
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	var theme := ThemeManager.build_godot_theme()
	assert_test(theme != null, "Global theme generated")
	assert_test(theme.default_font == font_inter, "Global Theme default_font is Inter variable TTF")
	assert_test(theme.get_font("font", "Label") == font_inter, "Label base font is Inter")
	assert_test(theme.get_font("font", "Button") == font_inter, "Button base font is Inter")
	assert_test(theme.get_font("font", "OptionButton") == font_inter, "OptionButton base font is Inter")
	assert_test(theme.get_font("font", "LineEdit") == font_inter, "LineEdit base font is Inter")

	# Editorial & Brand Variations
	assert_test(theme.get_font("font", "BrandTitle") == font_serif_semi, "BrandTitle font is Source Serif 4 Semibold")
	assert_test(theme.get_font("font", "BrandHeader") == font_serif_semi, "BrandHeader font is Source Serif 4 Semibold")
	assert_test(theme.get_font("font", "EditorialRegular") == font_serif_reg, "EditorialRegular font is Source Serif 4 Regular")
	assert_test(theme.get_font_size("font_size", "BrandTitle") == 40, "BrandTitle font_size is 40px in Theme")

	# Technical / Mono Variations
	assert_test(theme.get_font("font", "MonoLabel") == font_mono, "MonoLabel font is IBM Plex Mono Regular")
	assert_test(theme.get_font("font", "TechnicalLabel") == font_mono, "TechnicalLabel font is IBM Plex Mono Regular")
	assert_test(theme.get_font("font", "SeedLabel") == font_mono, "SeedLabel font is IBM Plex Mono Regular")

	# Standard UI Variations use Inter
	assert_test(theme.get_font("font", "Display") == font_inter, "Display variation font is Inter")
	assert_test(theme.get_font("font", "Header") == font_inter, "Header variation font is Inter")
	assert_test(theme.get_font("font", "Subtitle") == font_inter, "Subtitle variation font is Inter")
	assert_test(theme.get_font("font", "Body") == font_inter, "Body variation font is Inter")
	assert_test(theme.get_font("font", "Caption") == font_inter, "Caption variation font is Inter")
	assert_test(theme.get_font("font", "StatValue") == font_inter, "StatValue variation font is Inter")

	# 3. Screen Typography Inspections
	print("\n--- 3. Screen Typography Inspections ---")
	var root := Control.new()
	root.theme = theme
	root.size = Vector2(400, 720)
	get_root().add_child(root)

	# Helper to resolve font honoring theme_type_variation
	var get_resolved_font := func(c: Control) -> Font:
		var v: String = c.theme_type_variation
		if not v.is_empty():
			var f := c.get_theme_font("font", v)
			if f != null:
				return f
		return c.get_theme_font("font", c.get_class())

	# Home / MainMenu
	var menu := MainMenu.new()
	root.add_child(menu)
	menu._ready()
	assert_test(menu.title_label.theme_type_variation == "BrandTitle", "MainMenu title_label uses BrandTitle variation")
	assert_test(get_resolved_font.call(menu.title_label) == font_serif_semi, "MainMenu brand title resolves to Source Serif 4 Semibold")
	assert_test(get_resolved_font.call(menu.continue_btn) == font_inter, "MainMenu continue_btn resolves to Inter")
	assert_test(get_resolved_font.call(menu.new_game_btn) == font_inter, "MainMenu new_game_btn resolves to Inter")
	menu.queue_free()

	# SettingsScreen
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	AppSettings.save_config()
	var settings := SettingsScreen.new()
	settings.theme = theme
	root.add_child(settings)
	settings._ready()
	assert_test(get_resolved_font.call(settings.title_label) == font_inter, "Settings title resolves to Inter (Header)")
	assert_test(get_resolved_font.call(settings.font_option) == font_inter, "Settings font dropdown resolves to Inter")
	settings.queue_free()

	# HistoryScreen
	var history := HistoryScreen.new()
	history.theme = theme
	root.add_child(history)
	history._ready()
	assert_test(get_resolved_font.call(history.title) == font_inter, "History title resolves to Inter (Header)")
	history.queue_free()

	# StatisticsScreen
	var stats := StatisticsScreen.new()
	stats.theme = theme
	root.add_child(stats)
	stats._ready()
	assert_test(get_resolved_font.call(stats.title) == font_inter, "Statistics title resolves to Inter (Header)")
	stats.queue_free()

	# NewGameDialog
	var new_game_dlg := NewGameDialog.new()
	new_game_dlg.theme = theme
	root.add_child(new_game_dlg)
	new_game_dlg._ready()
	assert_test(new_game_dlg.preview_seed_label.theme_type_variation == "TechnicalLabel", "NewGameDialog preview_seed_label uses TechnicalLabel")
	assert_test(get_resolved_font.call(new_game_dlg.preview_seed_label) == font_mono, "NewGameDialog seed resolves to IBM Plex Mono")
	assert_test(get_resolved_font.call(new_game_dlg.preview_diff_label) == font_inter, "NewGameDialog diff label resolves to Inter")
	new_game_dlg.queue_free()

	# CustomThemeDialog
	var custom_theme_dlg := CustomThemeDialog.new()
	custom_theme_dlg.theme = theme
	root.add_child(custom_theme_dlg)
	custom_theme_dlg._ready()
	assert_test(get_resolved_font.call(custom_theme_dlg.title_label) == font_inter, "CustomThemeDialog title resolves to Inter (Header)")
	custom_theme_dlg.queue_free()

	# GameScreen
	var game := GameScreen.new()
	game.theme = theme
	root.add_child(game)
	game._ready()
	game.sudoku_grid._ready()
	game.sudoku_grid.cells[0]._ready()
	assert_test(get_resolved_font.call(game.info_label) == font_serif_semi, "GameScreen header info resolves to Source Serif 4 (EditorialHeader)")
	assert_test(get_resolved_font.call(game.timer_label) == font_mono, "GameScreen timer resolves to IBM Plex Mono (TechnicalLabel)")
	assert_test(get_resolved_font.call(game.sudoku_grid.cells[0].num_label) == font_inter, "SudokuBoard cell numeral resolves to Inter")
	game.queue_free()

	root.queue_free()

	print("\n========================================================")
	print("🏁 SUMMARY: %d Passed, %d Failed" % [passes, fails])
	print("========================================================")

	if fails > 0:
		quit(1)
	else:
		quit(0)
