class_name TestLocalization
extends SceneTree

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const MainMenu = preload("res://scenes/menus/main_menu.gd")
const NewGameDialog = preload("res://scenes/menus/new_game_dialog.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

func _init() -> void:
	print("\n==============================================")
	print("   JUST SUDOKU - LOCALIZATION & I18N TEST     ")
	print("==============================================")

	var stats := {"passed": 0, "total": 0}

	# Helper runner
	var run_test := func(name: String, test_cb: Callable):
		stats.total += 1
		print("Test %d: %s..." % [stats.total, name])
		var result: bool = test_cb.call()
		if result:
			stats.passed += 1
			print("  -> PASSED")
		else:
			printerr("  -> FAILED!")

	# --- Test 1: Translation Keys & Locale Switching ---
	run_test.call("LocalizationManager translates core keys in TR and EN", func() -> bool:
		LocalizationManager.set_locale("tr")
		var tr_new := LocalizationManager.translate("BTN_NEW_GAME")
		var tr_set := LocalizationManager.translate("SETTINGS_TITLE")
		if tr_new != "Yeni Oyun" or tr_set != "Ayarlar":
			printerr("TR failed: %s, %s" % [tr_new, tr_set])
			return false

		LocalizationManager.set_locale("en")
		var en_new := LocalizationManager.translate("BTN_NEW_GAME")
		var en_set := LocalizationManager.translate("SETTINGS_TITLE")
		if en_new != "New Game" or en_set != "Settings":
			printerr("EN failed: %s, %s" % [en_new, en_set])
			return false

		return true
	)

	# --- Test 2: Difficulty Level Localization ---
	run_test.call("Difficulty names translated correctly per locale", func() -> bool:
		LocalizationManager.set_locale("tr")
		var tr_easy := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EASY)
		var tr_med := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_MEDIUM)
		var tr_hard := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD)
		var tr_exp := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EXPERT)

		if tr_easy != "Kolay" or tr_med != "Orta" or tr_hard != "Zor" or tr_exp != "Uzman":
			printerr("TR diff failed: %s, %s, %s, %s" % [tr_easy, tr_med, tr_hard, tr_exp])
			return false

		LocalizationManager.set_locale("en")
		var en_easy := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EASY)
		var en_med := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_MEDIUM)
		var en_hard := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD)
		var en_exp := LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EXPERT)

		if en_easy != "Easy" or en_med != "Medium" or en_hard != "Hard" or en_exp != "Expert":
			printerr("EN diff failed: %s, %s, %s, %s" % [en_easy, en_med, en_hard, en_exp])
			return false

		return true
	)

	# --- Test 3: GDD §44 Culture Formatting (Numbers, Percentages, Dates) ---
	run_test.call("GDD §44 formatters for percentages, numbers, and dates", func() -> bool:
		LocalizationManager.set_locale("tr")
		var tr_pct := LocalizationManager.format_percentage(85)
		var tr_num := LocalizationManager.format_number(12500)
		var tr_date := LocalizationManager.format_date(2026, 10, 3)

		if tr_pct != "%85" or tr_num != "12.500" or tr_date != "03.10.2026":
			printerr("TR formatting failed: pct=%s, num=%s, date=%s" % [tr_pct, tr_num, tr_date])
			return false

		LocalizationManager.set_locale("en")
		var en_pct := LocalizationManager.format_percentage(85)
		var en_num := LocalizationManager.format_number(12500)
		var en_date := LocalizationManager.format_date(2026, 10, 3)

		if en_pct != "85%" or en_num != "12,500" or en_date != "2026-10-03":
			printerr("EN formatting failed: pct=%s, num=%s, date=%s" % [en_pct, en_num, en_date])
			return false

		return true
	)

	# --- Test 4: Settings Config Persistence of Locale ---
	run_test.call("SettingsScreen config persists and reloads locale", func() -> bool:
		LocalizationManager.set_locale("en")
		SettingsScreen.save_config()

		# Reset in-memory locale
		LocalizationManager.current_locale = "tr"

		SettingsScreen.load_config()
		var restored_loc := LocalizationManager.get_locale()
		if restored_loc != "en":
			printerr("Failed to restore EN locale from config: %s" % restored_loc)
			return false

		# Switch back to TR and save
		LocalizationManager.set_locale("tr")
		SettingsScreen.save_config()
		SettingsScreen.load_config()
		return LocalizationManager.get_locale() == "tr"
	)

	# --- Test 5: Dynamic UI Hot-Swapping in MainMenu ---
	run_test.call("MainMenu hot-swaps button texts on locale change without restart", func() -> bool:
		LocalizationManager.set_locale("tr")
		var menu := MainMenu.new()
		root.add_child(menu)

		var tr_cont := menu.continue_btn.text
		var tr_new := menu.new_game_btn.text
		if tr_cont != "Devam Et" or tr_new != "Yeni Oyun":
			printerr("Initial TR MainMenu failed: %s, %s" % [tr_cont, tr_new])
			menu.queue_free()
			return false

		# Change language to EN
		LocalizationManager.set_locale("en")
		var en_cont := menu.continue_btn.text
		var en_new := menu.new_game_btn.text
		if en_cont != "Continue" or en_new != "New Game":
			printerr("Hot-swapped EN MainMenu failed: %s, %s" % [en_cont, en_new])
			menu.queue_free()
			return false

		# Change back to TR
		LocalizationManager.set_locale("tr")
		var final_tr_cont := menu.continue_btn.text
		menu.queue_free()
		return final_tr_cont == "Devam Et"
	)

	# --- Test 6: Dynamic UI Hot-Swapping in SettingsScreen ---
	run_test.call("SettingsScreen hot-swaps all labels and options dynamically", func() -> bool:
		LocalizationManager.set_locale("tr")
		var settings := SettingsScreen.new()
		root.add_child(settings)

		var tr_title := settings.title_label.text
		var tr_lang := settings.lang_label.text
		if tr_title != "Ayarlar" or tr_lang != "Dil / Language":
			printerr("Initial TR SettingsScreen failed: %s, %s" % [tr_title, tr_lang])
			settings.queue_free()
			return false

		LocalizationManager.set_locale("en")
		var en_title := settings.title_label.text
		var en_lang := settings.lang_label.text
		if en_title != "Settings" or en_lang != "Language / Dil":
			printerr("Hot-swapped EN SettingsScreen failed: %s, %s" % [en_title, en_lang])
			settings.queue_free()
			return false

		LocalizationManager.set_locale("tr")
		settings.queue_free()
		return true
	)

	# --- Test 7: NewGameDialog Difficulty Buttons Localization ---
	run_test.call("NewGameDialog updates localized difficulty buttons", func() -> bool:
		LocalizationManager.set_locale("tr")
		var dlg := NewGameDialog.new()
		root.add_child(dlg)

		var tr_btn0 := dlg.diff_buttons[0].text
		var tr_btn3 := dlg.diff_buttons[3].text
		if tr_btn0 != "Kolay" or tr_btn3 != "Uzman":
			printerr("Initial TR NewGameDialog diff buttons failed: %s, %s" % [tr_btn0, tr_btn3])
			dlg.queue_free()
			return false

		LocalizationManager.set_locale("en")
		var en_btn0 := dlg.diff_buttons[0].text
		var en_btn3 := dlg.diff_buttons[3].text
		if en_btn0 != "Easy" or en_btn3 != "Expert":
			printerr("Hot-swapped EN NewGameDialog diff buttons failed: %s, %s" % [en_btn0, en_btn3])
			dlg.queue_free()
			return false

		LocalizationManager.set_locale("tr")
		dlg.queue_free()
		return true
	)

	print("\n==============================================")
	print("   TEST RESULTS: %d / %d PASSED               " % [stats.passed, stats.total])
	print("==============================================")

	if stats.passed == stats.total:
		print(">>> ALL LOCALIZATION TESTS PASSED! <<<\n")
		quit.call_deferred(0)
	else:
		printerr(">>> LOCALIZATION TESTS FAILED! <<<\n")
		quit.call_deferred(1)
