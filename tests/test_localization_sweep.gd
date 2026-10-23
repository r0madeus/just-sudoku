extends SceneTree

## Localization coverage: both dictionaries hold the same keys and placeholders, every key the
## code asks for exists, solver explanations follow the language on screen, and a walk through
## every screen and dialog in each language (switched from Settings, a different font each time,
## and at the largest text size too) finds no raw keys, no text from the other language, no
## missing glyphs and no clipped text.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var app: AppRoot
var issues: Dictionary = {}
var en_values: Dictionary = {}
var tr_values: Dictionary = {}
var naive_caps: Dictionary = {}
var key_re := RegEx.create_from_string("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$")
var en_word_re := RegEx.create_from_string("(?i)\\b(the|and|your|of|givens|solved|day|days|streak|best|time|score|mistakes|hints|easy|medium|hard|expert|new|game|cancel|close|back|play|delete|share|copied|none|step|unique|solution|puzzle|settings|history|statistics)\\b")
var tr_char_re := RegEx.create_from_string("[çğıöşüÇĞİÖŞÜ]")

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _issue(loc: String, ctx: String, kind: String, node: Node, text: String) -> void:
	var k := "%s|%s|%s|%s" % [loc, kind, node.name, text]
	if issues.has(k):
		return
	issues[k] = true
	assert_true(false, "[%s] %s on %s: %s (%s)" % [loc, kind, ctx, text.replace("\n", "⏎"), node.name])

func _texts_of(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(n.text)
	elif n is OptionButton:
		out.append(n.text)
		for i in n.item_count:
			out.append(n.get_item_text(i))
	elif n is Button:
		out.append(n.text)
		if n.tooltip_text != "":
			out.append(n.tooltip_text)
	elif n is LineEdit:
		out.append(n.text)
		out.append(n.placeholder_text)
	elif n is TextEdit:
		out.append(n.placeholder_text)
	elif n is RichTextLabel:
		out.append(n.get_parsed_text())
	return out

func _check(loc: String, ctx: String) -> void:
	await _frames(6)
	var vw: float = app.size.x
	for n in app.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var texts := _texts_of(c)
		for t in texts:
			var s: String = String(t).strip_edges()
			if s.is_empty():
				continue
			if key_re.search(s) != null:
				_issue(loc, ctx, "RAW_KEY", c, s)
			var mine := tr_values if loc == "tr" else en_values
			var other := en_values if loc == "tr" else tr_values
			if other.has(s) and not mine.has(s):
				_issue(loc, ctx, "OTHER_LANG", c, s)
			elif loc == "en" and tr_char_re.search(s) != null and s != "Türkçe":
				_issue(loc, ctx, "TR_IN_EN", c, s)
			elif loc == "tr" and en_word_re.search(s) != null and not s in ["English", "Just Sudoku", "JUST SUDOKU"]:
				_issue(loc, ctx, "EN_IN_TR?", c, s)
			if loc == "tr" and naive_caps.has(s):
				_issue(loc, ctx, "TR_CAPS", c, s)
			if s.contains("%") and (s.contains("%s") or s.contains("%d")):
				_issue(loc, ctx, "PLACEHOLDER", c, s)
			# Glyph coverage
			var font: Font = c.get_theme_font("font")
			if font != null:
				for ch in s:
					if ch.unicode_at(0) > 127 and not font.has_char(ch.unicode_at(0)):
						_issue(loc, ctx, "NO_GLYPH", c, "%s in '%s'" % [ch, s])
						break
		# Overflow: single-line text wider than its control
		if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and not c.clip_text \
				and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.text != "" and not c.text.contains("\n"):
			var f: Font = c.get_theme_font("font")
			var w: float = f.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
			if w > c.size.x + 1.0:
				_issue(loc, ctx, "OVERFLOW", c, "%s (%.0f > %.0f)" % [c.text, w, c.size.x])
		if c is Button and not (c is OptionButton) and c.text != "" and not c.clip_text \
				and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var f2: Font = c.get_theme_font("font")
			var tw: float = f2.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
			if tw > c.size.x:
				_issue(loc, ctx, "BTN_OVERFLOW", c, "%s (%.0f > %.0f)" % [c.text, tw, c.size.x])
		if c is OptionButton and c.clip_text:
			var f3: Font = c.get_theme_font("font")
			var sb: StyleBox = c.get_theme_stylebox("normal")
			var avail: float = c.size.x - sb.get_minimum_size().x - c.get_theme_icon("arrow").get_width() - 4
			for i in c.item_count:
				var iw: float = f3.get_string_size(c.get_item_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
				if iw > avail:
					_issue(loc, ctx, "OPT_CLIPPED", c, "%s (%.0f > %.0f)" % [c.get_item_text(i), iw, avail])
		var r := c.get_global_rect()
		if (c is Label or c is Button) and c.size.x > 0 and (r.end.x > vw + 0.5 or r.position.x < -0.5) and not _in_scroll(c):
			_issue(loc, ctx, "OFFSCREEN", c, "%s (%.0f..%.0f)" % [texts[0] if texts.size() > 0 else "", r.position.x, r.end.x])

func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and p.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false

func _seed_data() -> void:
	# One record in lower case, as older or imported records may have it
	var diffs := ["Easy", "Medium", "Hard", "Expert", "medium"]
	for i in range(diffs.size()):
		HistoryManager.add_record({
			"game_id": "l10n_%d" % i, "seed": 1000 + i * 37, "difficulty": diffs[i],
			"difficulty_score": 30 + i * 6, "score": 90 - i * 3, "time": 240.0 + i * 95.0,
			"mistakes": i % 3, "hints": i % 2, "undo_count": i, "is_replay": i == 4, "is_daily": i == 1
		})
	var st := GameState.new()
	st.init_from_puzzle(SudokuGenerator.generate(777, DifficultyAnalyzer.LEVEL_HARD))
	st.game_id = "l10n_saved"
	for i in range(81):
		if st.current_board.get_cell(i) == 0:
			st.set_number(i, st.solution.get_cell(i))
			break
	SaveManager.save_game_slot(st)

func _close_modals() -> void:
	for m in get_nodes_in_group(AppModal.GROUP):
		if m.visible and m.has_method("close_modal"):
			m.close_modal()
	await _frames(3)

func _tour(loc: String) -> void:
	await _check(loc, "menu")
	app.new_game_dialog.open_dialog()
	await _check(loc, "new_game")
	await _close_modals()

	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_MEDIUM))
	app._start_game_session(state)
	await _check(loc, "game")
	for lvl in range(3):
		app.game_screen._on_hint_pressed()
		await _check(loc, "hint%d" % lvl)
	await _close_modals()
	app.game_screen.toggle_pause()
	await _check(loc, "pause")
	app.game_screen.toggle_pause()
	await _close_modals()
	var sd: SolutionDialog = app.game_screen.solution_dialog
	sd.open_solution(state.initial_puzzle, state.current_board)
	await _check(loc, "sol_step0")
	for i in [1, 5, 20]:
		sd.set_step(i)
		await _check(loc, "sol_step%d" % i)
	sd.switch_view_mode(SolutionDialog.Mode.FULL_SOLUTION)
	await _check(loc, "sol_full")
	sd._on_apply_solution_pressed()
	await _check(loc, "sol_apply?")
	await _close_modals()

	app._show_screen(app.main_menu)
	app.main_menu.refresh_buttons()
	await _check(loc, "menu_resume")
	app._show_screen(app.load_game_screen)
	app.load_game_screen.refresh_list()
	await _check(loc, "saved")
	var items := app.load_game_screen.find_children("*", "GameRecordItem", true, false)
	if items.size() > 0:
		items[0].open_actions()
		await _check(loc, "saved_sheet")
		await _close_modals()
	app.import_puzzle_dialog.open_dialog()
	await _check(loc, "import_empty")
	app.import_puzzle_dialog.input_edit.text = "12345"
	app.import_puzzle_dialog._validate_input()
	await _check(loc, "import_bad")
	app.import_puzzle_dialog.input_edit.text = "4242"
	app.import_puzzle_dialog._validate_input()
	await _check(loc, "import_seed")
	app.import_puzzle_dialog.input_edit.text = state.initial_puzzle.to_string_flat()
	app.import_puzzle_dialog._validate_input()
	await _check(loc, "import_grid")
	await _close_modals()

	app._show_screen(app.history_screen)
	app.history_screen.refresh_history()
	await _check(loc, "history")
	app._show_screen(app.statistics_screen)
	app.statistics_screen.refresh_stats()
	await _check(loc, "stats")
	app.techniques_screen.show_list()
	app._show_screen(app.techniques_screen)
	await _check(loc, "techniques")
	app.techniques_screen.open_lesson("XY-Wing")
	await _check(loc, "technique_lesson")
	app.techniques_screen.toggle_move()
	await _check(loc, "technique_lesson_moved")
	app.techniques_screen.show_list()
	app._show_screen(app.settings_screen)
	await _check(loc, "settings")
	app.custom_theme_dialog.open_dialog()
	await _check(loc, "custom_theme")
	await _close_modals()

	# Finish a game for the result dialog
	var st2 := GameState.new()
	st2.init_from_puzzle(SudokuGenerator.generate(3131, DifficultyAnalyzer.LEVEL_EASY))
	app._start_game_session(st2)
	await _frames(4)
	var last := -1
	for i in range(81):
		if st2.current_board.get_cell(i) == 0:
			if last != -1:
				st2.set_number(last, st2.solution.get_cell(last))
			last = i
	app.game_screen.sudoku_grid.select_cell(last)
	app.game_screen._on_numpad_number_pressed(st2.solution.get_cell(last))
	await _frames(30)
	await _check(loc, "result")
	await _close_modals()
	app._show_screen(app.main_menu)
	await _frames(3)

func _placeholders(text: String) -> Array:
	var out: Array = []
	for m in RegEx.create_from_string("%[-+ 0#]*\\d*(?:\\.\\d+)?[sdif]").search_all(text.replace("%%", "")):
		out.append(m.get_string())
	return out

func test_dictionaries() -> void:
	print("\n--- Test 1: Both languages hold the same keys and placeholders ---")
	var en: Dictionary = LocalizationManager.DICTIONARY_EN
	var tr: Dictionary = LocalizationManager.DICTIONARY_TR
	var missing: Array = []
	for k in en:
		# English-only singular forms ("1 game"); Turkish nouns stay singular after a number
		if not String(k).ends_with("_ONE") and not tr.has(k):
			missing.append(k)
	for k in tr:
		if not en.has(k):
			missing.append(k)
	assert_true(missing.is_empty(), "No key missing from either language %s" % str(missing))
	var bad: Array = []
	for k in en:
		var base: String = String(k).trim_suffix("_ONE")
		var other: String = tr.get(k, en.get(base, ""))
		if _placeholders(en[k]) != _placeholders(other):
			bad.append(k)
	assert_true(bad.is_empty(), "Placeholders match across languages and singular forms %s" % str(bad))

func _scan_keys(dir_path: String, re: RegEx, found: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_keys(dir_path.path_join(sub), re, found)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(dir_path.path_join(f))
			for m in re.search_all(text):
				found[m.get_string(2)] = f

func test_used_keys_exist() -> void:
	print("\n--- Test 2: Every key the code asks for exists ---")
	var found: Dictionary = {}
	var re := RegEx.create_from_string("(translate|plural)\\(\\s*\"([A-Z][A-Z0-9_]*[A-Z0-9])\"")
	_scan_keys("res://scenes", re, found)
	_scan_keys("res://scripts", re, found)
	var undefined: Array = []
	for k in found:
		if not LocalizationManager.DICTIONARY_EN.has(k):
			undefined.append("%s (%s)" % [k, found[k]])
	assert_true(found.size() > 100 and undefined.is_empty(), "%d keys used, none undefined %s" % [found.size(), str(undefined)])

func test_plurals() -> void:
	print("\n--- Test 3: Counts read naturally ---")
	LocalizationManager.set_locale("en")
	assert_true(LocalizationManager.plural("STAT_GAMES_COUNT", 1) == "1 game completed" and LocalizationManager.plural("STAT_GAMES_COUNT", 2) == "2 games completed", "English singular and plural")
	assert_true(LocalizationManager.format_days(1) == "1 Day" and LocalizationManager.format_streak(4) == "Streak: 4 Days", "Days and streaks")
	LocalizationManager.set_locale("tr")
	assert_true(LocalizationManager.plural("STAT_GAMES_COUNT", 1) == "1 oyun tamamlandı" and LocalizationManager.format_days(1) == "1 Gün", "Turkish has one form")

func test_solver_text_follows_language() -> void:
	print("\n--- Test 4: Solver explanations are written in the language on screen ---")
	var gen := SudokuGenerator.generate(9191, DifficultyAnalyzer.LEVEL_HARD)
	var sol: Dictionary = SudokuSolver.get_full_step_by_step_solution(gen.puzzle)
	var steps: Array = sol["steps"]
	var techniques: Dictionary = {}
	var ok := true
	for s in steps:
		techniques[s.technique] = true
		LocalizationManager.set_locale("tr")
		var tr_text: String = s.explanation
		LocalizationManager.set_locale("en")
		var en_text: String = s.explanation
		if tr_text == en_text or tr_text.contains("%") or en_text.contains("%") or tr_char_re.search(en_text) != null \
				or key_re.search(en_text) != null or tr_text.is_empty():
			ok = false
			printerr("    %s | %s | %s" % [s.technique, tr_text, en_text])
	assert_true(ok and steps.size() > 20, "%d steps (%s) read in both languages" % [steps.size(), ", ".join(techniques.keys())])
	var hint := SudokuSolver.find_best_hint(gen.puzzle)
	LocalizationManager.set_locale("tr")
	var hint_tr: String = hint.explanation
	LocalizationManager.set_locale("en")
	assert_true(hint.explanation != hint_tr and tr_char_re.search(hint.explanation) == null, "A hint switches language with the app: %s" % hint.explanation)
	var step := SudokuSolver.SolveStep.new()
	step.set_text("EXPL_NAKED_TRIPLE", [{"cell": 0}, {"cell": 1}, {"cell": 2}, {"digits": [1, 4, 7]}])
	assert_true(step.explanation.contains("{1, 4, 7}"), "Digit sets read as {1, 4, 7}: %s" % step.explanation)

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING LOCALIZATION COVERAGE TESTS")
	print("========================================")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	for k in LocalizationManager.DICTIONARY_EN:
		en_values[LocalizationManager.DICTIONARY_EN[k]] = true
	for k in LocalizationManager.DICTIONARY_TR:
		var v: String = LocalizationManager.DICTIONARY_TR[k]
		tr_values[v] = true
		if v.to_upper() != v and v.to_upper() != _proper_upper(v):
			naive_caps[v.to_upper()] = true
	test_dictionaries()
	test_used_keys_exist()
	test_plurals()
	test_solver_text_follows_language()

	print("\n--- Test 5: Every screen and dialog in each language ---")
	_seed_data()
	app = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(10)
	# Then again on a 360 x 640 dp phone, the narrowest and shortest layout the game supports,
	# and with the largest text size on both phones
	var passes: Array = [["en", false, "normal"], ["tr", false, "normal"], ["tr", true, "normal"], ["en", true, "normal"],
		["tr", true, "xlarge"], ["en", true, "xlarge"], ["tr", false, "xlarge"]]
	var small := false
	var regular_size: Vector2i = root.content_scale_size
	var fonts: Array = [FontManager.FONT_MODERN_SANS, FontManager.FONT_ROUNDED_SANS, FontManager.FONT_CLASSIC_SERIF]
	var i := 0
	for p in passes:
		var loc: String = p[0]
		if p[1] != small:
			small = p[1]
			if small:
				ResponsiveManager.apply_device_scaling(root, root.size.x / 360.0)
			else:
				root.set_meta(&"dp_density", 0.0) # stops following the density
				root.content_scale_size = regular_size
			await _frames(4)
		# Switch through Settings like a player would
		app._show_screen(app.settings_screen)
		await _frames(3)
		var lang_idx: int = SettingsScreen.LANG_ORDER.find(loc)
		app.settings_screen.lang_option.selected = lang_idx
		app.settings_screen._on_language_selected(lang_idx)
		FontManager.set_font(fonts[i % fonts.size()])
		var size_idx: int = SettingsScreen.TEXT_SIZE_ORDER.find(p[2])
		app.settings_screen.text_size_option.selected = size_idx
		app.settings_screen._on_text_size_selected(size_idx)
		print("  … %s with %s at %s, %s text" % [loc, fonts[i % fonts.size()], str(app.size), p[2]])
		i += 1
		app._show_screen(app.main_menu)
		await _tour(loc)
	app.settings_screen._on_text_size_selected(0)
	assert_true(issues.is_empty(), "No text problems on any screen in either language, on a regular and a small phone, at normal and extra large text")
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _proper_upper(v: String) -> String:
	return v.replace("i", "İ").replace("ı", "I").to_upper()
