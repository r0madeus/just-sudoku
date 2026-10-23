extends SceneTree

## Guards the "one product" rules from GDD §54 and the stage-1 UX fixes: copy follows the
## glossary in both languages, no screen overflows a phone, destructive actions ask first.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const LoadGameScreen = preload("res://scenes/menus/load_game_screen.gd")

## Keys whose text is a proper name, a machine-read label or deliberately bilingual (GDD §54.4)
const COPY_EXCEPTIONS: Array[String] = [
	"KEY_APP_TITLE", "SHARE_CARD_HEADER", "SETTING_LANGUAGE",
	"THEME_AMOLED", "TECH_X_WING", "TECH_SWORDFISH", "TECH_XY_WING", "TECH_XYZ_WING",
	"TECHNIQUE_X_WING", "TECHNIQUE_XY_WING", "TECHNIQUE_XYZ_WING", "TECHNIQUE_SWORDFISH",
]
## Words the glossary replaced; none may come back in player-facing text
const BANNED_EN: Array[String] = ["seed", "json", "save state", "master it", "pencil mark", "awesome", "solution system"]
const BANNED_TR: Array[String] = ["seed", "json", "save", "master it", "replay", "blok", "çözüm sistemi", "(naked", "(hidden", "(full house", "(locked"]
## "siz" imperatives the old Turkish copy used
const SIZ_FORMS: Array[String] = ["seçin", "girin", "yapıştırın", "basın", "deneyin", "koruyun", "oluşturun", "düzenleyin", "başlatın", "edin"]

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	_run.call_deferred()

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING UX CONSISTENCY TESTS")
	print("========================================")
	AppSettings.animations_enabled = false

	test_copy_follows_glossary()
	test_locale_aware_upper()
	await test_no_screen_overflows_a_phone()
	await test_menu_hides_continue_without_a_game()
	await test_delete_asks_first()
	await test_apply_solution_asks_first()
	test_game_header_has_no_seed()
	test_share_text_imports_across_languages()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

static func _placeholders(text: String) -> Array:
	var out := []
	var rx := RegEx.create_from_string("%[-+0-9.]*[dsf]")
	for m in rx.search_all(text.replace("%%", "")):
		out.append(m.get_string())
	return out

func test_copy_follows_glossary() -> void:
	print("\n--- Test 1: Copy follows the glossary (GDD §54) ---")
	var en: Dictionary = LocalizationManager.DICTIONARY_EN
	var tr: Dictionary = LocalizationManager.DICTIONARY_TR
	# English-only singular forms ("1 game") end in _ONE; Turkish nouns stay singular after a number
	var missing := en.keys().filter(func(k): return not tr.has(k) and not k.ends_with("_ONE")) + tr.keys().filter(func(k): return not en.has(k))
	assert_true(missing.is_empty(), "Both languages have the same keys %s" % str(missing))

	var bad_ph := en.keys().filter(func(k): return tr.has(k) and _placeholders(en[k]) != _placeholders(tr[k]))
	assert_true(bad_ph.is_empty(), "EN and TR take the same placeholders %s" % str(bad_ph))

	var caps := []
	var banned := []
	var siz := []
	var dots := []
	for lang_dict in [[en, BANNED_EN, "en"], [tr, BANNED_TR, "tr"]]:
		var d: Dictionary = lang_dict[0]
		for k in d.keys():
			if COPY_EXCEPTIONS.has(k):
				continue
			var v: String = d[k]
			var letters := RegEx.create_from_string("[^A-Za-zÇĞİÖŞÜçğıöşü]").sub(v, "", true)
			if letters.length() > 3 and letters == letters.to_upper():
				caps.append("%s:%s" % [lang_dict[2], k])
			var low := v.to_lower()
			for word in lang_dict[1]:
				if low.contains(word) and not (k == "BTN_SAVE_APPLY" and word == "save"):
					banned.append("%s:%s(%s)" % [lang_dict[2], k, word])
			if lang_dict[2] == "tr":
				for form in SIZ_FORMS:
					if RegEx.create_from_string("\\b%s\\b" % form).search(low) != null:
						siz.append(k)
			if v.contains("...") and k != "IMPORT_PLACEHOLDER":
				dots.append(k)
	assert_true(caps.is_empty(), "No text is stored in ALL CAPS %s" % str(caps))
	assert_true(banned.is_empty(), "Replaced terms are gone %s" % str(banned))
	assert_true(siz.is_empty(), "Turkish copy uses \"sen\", not \"siz\" %s" % str(siz))
	assert_true(dots.is_empty(), "Ellipsis is a single character %s" % str(dots))

func test_locale_aware_upper() -> void:
	print("\n--- Test 2: Overline upper case is right in Turkish ---")
	var prev := LocalizationManager.get_locale()
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	assert_true(LocalizationManager.upper("En İyi Süre") == "EN İYİ SÜRE", "\"En İyi Süre\" -> %s" % LocalizationManager.upper("En İyi Süre"))
	assert_true(LocalizationManager.upper("Sıralama") == "SIRALAMA", "\"Sıralama\" -> %s" % LocalizationManager.upper("Sıralama"))
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)
	assert_true(LocalizationManager.upper("Best time") == "BEST TIME", "English unchanged")
	LocalizationManager.set_locale(prev)

## Right edge of the widest visible text, button or image under `node`
func _content_right(node: Node) -> float:
	var right := 0.0
	for c in node.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is Label or c is BaseButton or c is TextureRect or c is LineEdit:
			right = maxf(right, c.get_global_rect().end.x)
		right = maxf(right, _content_right(c))
	return right

func test_no_screen_overflows_a_phone() -> void:
	print("\n--- Test 3: No screen runs off the right edge at 360 / 390 px ---")
	HistoryManager.add_record({"game_id": "ux_1", "seed": 77, "difficulty": DifficultyAnalyzer.LEVEL_EXPERT,
		"score": 100, "time": 3725.0, "mistakes": 12, "hints": 10, "is_replay": true})
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(5151, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_game_slot(state)

	var app := AppRoot.new()
	get_root().add_child(app)
	await _frames(10)
	var prev := LocalizationManager.get_locale()
	for loc in [LocalizationManager.LOCALE_EN, LocalizationManager.LOCALE_TR]:
		LocalizationManager.set_locale(loc)
		for width in [360, 390]:
			get_root().size = Vector2i(width, 780)
			app.size = Vector2(width, 780)
			for screen in [app.main_menu, app.game_screen, app.load_game_screen, app.history_screen,
					app.statistics_screen, app.settings_screen]:
				if screen == app.game_screen:
					app._start_game_session(state)
				else:
					app._show_screen(screen)
				if screen == app.load_game_screen:
					app.load_game_screen.refresh_list()
				await _frames(6)
				var right := _content_right(screen)
				assert_true(right <= width + 0.5, "%s %s at %d px: content ends at %.0f" % [
					loc, screen.get_script().get_global_name(), width, right])
	LocalizationManager.set_locale(prev)
	app.queue_free()
	await _frames(2)

func test_menu_hides_continue_without_a_game() -> void:
	print("\n--- Test 4: Continue only shows when there is a game to resume ---")
	SaveManager.clear_active_game()
	var app := AppRoot.new()
	get_root().add_child(app)
	await _frames(5)
	app.main_menu.refresh_buttons()
	assert_true(not app.main_menu.continue_btn.visible, "Hidden with nothing to resume")
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	app.main_menu.refresh_buttons()
	assert_true(app.main_menu.continue_btn.visible, "Shown once a game is saved")
	SaveManager.clear_active_game()
	app.queue_free()
	await _frames(2)

func _find_open_modal(root_node: Node) -> AppModal:
	for m in root_node.get_tree().get_nodes_in_group(AppModal.GROUP):
		if m is AppModal and m.visible:
			return m
	return null

func test_delete_asks_first() -> void:
	print("\n--- Test 5: Deleting a saved game asks first ---")
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(6161, DifficultyAnalyzer.LEVEL_EASY))
	state.game_id = "ux_delete_%d" % Time.get_ticks_usec()
	SaveManager.save_game_slot(state)
	var screen := LoadGameScreen.new()
	root.add_child(screen)
	await process_frame
	screen.refresh_list()
	await _frames(40)
	var item: GameRecordItem = null
	for c in screen.list_vbox.get_children():
		if c is GameRecordItem and c.current_data.get("game_id", "") == state.game_id:
			item = c
	assert_true(item != null, "Card for the game is listed")
	item.delete_pressed.emit(state.game_id)
	var modal := _find_open_modal(screen)
	assert_true(modal != null, "A confirmation opens")
	assert_true(SaveManager.get_games_index().has(state.game_id), "Nothing deleted before confirming")
	modal.canceled.emit()
	modal.close_modal()
	assert_true(SaveManager.get_games_index().has(state.game_id), "Cancel keeps the game")
	item.delete_pressed.emit(state.game_id)
	modal = _find_open_modal(screen)
	modal.get_ok_button().pressed.emit()
	assert_true(not SaveManager.get_games_index().has(state.game_id), "Confirm deletes it")
	screen.queue_free()
	await _frames(2)

func test_apply_solution_asks_first() -> void:
	print("\n--- Test 6: Applying the full solution asks first ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(7171, DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	screen._on_view_solution_pressed()
	await _frames(3)
	screen.solution_dialog._on_apply_solution_pressed()
	assert_true(not state.is_completed, "Not applied before confirming")
	var modal: AppModal = null
	for m in get_nodes_in_group(AppModal.GROUP):
		if m is AppModal and m.visible and m != screen.solution_dialog:
			modal = m
	assert_true(modal != null, "A confirmation opens")
	if modal != null:
		modal.get_ok_button().pressed.emit()
	assert_true(state.is_completed, "Confirm applies the solution")
	screen.queue_free()
	await _frames(2)

func test_game_header_has_no_seed() -> void:
	print("\n--- Test 7: The game header shows no puzzle number ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(123456789, DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	var found := []
	for n in screen.header_bar.find_children("*", "Label", true, false) + screen.header_bar.find_children("*", "Button", true, false):
		if n.text.contains("123456789"):
			found.append(n.name)
	assert_true(found.is_empty(), "No puzzle number in the header %s" % str(found))
	screen.toggle_pause()
	assert_true(screen.pause_info_label.text.contains("123456789"), "Pause menu still shows it: %s" % screen.pause_info_label.text)
	screen.queue_free()

func test_share_text_imports_across_languages() -> void:
	print("\n--- Test 8: Share text uses the glossary and imports in any language ---")
	var gen := SudokuGenerator.generate(8181, DifficultyAnalyzer.LEVEL_HARD)
	var prev := LocalizationManager.get_locale()
	var texts := {}
	for loc in [LocalizationManager.LOCALE_TR, LocalizationManager.LOCALE_EN]:
		LocalizationManager.set_locale(loc)
		texts[loc] = PuzzleShareService.export_puzzle_share_text(8181, DifficultyAnalyzer.LEVEL_HARD, gen.puzzle)
	assert_true(texts["tr"].contains("Zorluk: Zor") and texts["tr"].contains("Bulmaca No: 8181") and texts["tr"].contains("Bulmaca kodu: "),
		"Turkish share text: %s" % texts["tr"].replace("\n", " | ").left(80))
	assert_true(texts["en"].contains("Difficulty: Hard") and texts["en"].contains("Puzzle No: 8181"),
		"English share text: %s" % texts["en"].replace("\n", " | ").left(80))

	# Each language's text opens in the other one
	for pair in [["tr", "en"], ["en", "tr"]]:
		LocalizationManager.set_locale(pair[1])
		var res := PuzzleShareService.parse_import_string(texts[pair[0]])
		assert_true(res.get("success", false) and res.get("seed", 0) == 8181, "%s text imports under %s" % [pair[0], pair[1]])

	# Texts shared by older versions ("Seed:" / "Kod:", English difficulty) still open
	var legacy := "Just Sudoku\nZorluk: Hard\nSeed: 8181\nKod: %s" % gen.puzzle.to_string_flat()
	var res_legacy := PuzzleShareService.parse_import_string(legacy)
	assert_true(res_legacy.get("success", false) and res_legacy.get("seed", 0) == 8181, "Older share text still imports")

	# Number and difficulty alone (no code) regenerate the same puzzle
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	var res_seed := PuzzleShareService.parse_import_string("Zorluk: Zor\nBulmaca No: 8181")
	assert_true(res_seed.get("type", "") == "seed" and res_seed.get("difficulty", "") == DifficultyAnalyzer.LEVEL_HARD,
		"Number + Turkish difficulty name picks the right level (%s)" % res_seed.get("difficulty", ""))
	LocalizationManager.set_locale(prev)
