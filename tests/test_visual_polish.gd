extends SceneTree

## Visual polish rules found in a screen-by-screen review at real phone resolutions
## (1080x2340 = 2x, 720x1600 = 1.33x): centred titles, crisp board lines, quieter disabled
## keys, aligned pickers and labels, and dialogs that show all of their content.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var app: AppRoot

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
	print("🧪 RUNNING VISUAL POLISH TESTS")
	print("========================================")
	app = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	AppSettings.animations_enabled = false
	await _frames(5)

	await test_titles_are_centred()
	test_line_snapping()
	test_disabled_keys_recede()
	await test_settings_pickers_line_up()
	test_new_game_labels_share_alignment()
	await test_stats_card_values()
	await test_custom_theme_dialog()
	await test_solution_board_layout()
	test_list_row_actions_match()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _text_centre(label: Label) -> float:
	var r := label.get_global_rect()
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		return r.position.x + r.size.x * 0.5
	var w: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x
	return r.position.x + w * 0.5

func test_titles_are_centred() -> void:
	print("\n--- Test 1: Screen titles sit on the centre line ---")
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_EASY))
	var prev := LocalizationManager.get_locale()
	for loc in [LocalizationManager.LOCALE_TR, LocalizationManager.LOCALE_EN]:
		LocalizationManager.set_locale(loc)
		app._start_game_session(state)
		await _frames(4)
		var mid: float = app.size.x * 0.5
		var off := _text_centre(app.game_screen.info_label) - mid
		assert_true(absf(off) < 0.6, "%s game title centred (off by %.1f px)" % [loc, off])
		app._show_screen(app.load_game_screen)
		await _frames(4)
		off = _text_centre(app.load_game_screen.title) - mid
		assert_true(absf(off) < 0.6, "%s Saved games title centred (off by %.1f px)" % [loc, off])
		# On a narrow screen the centring gives way before the title gets cut or the row overflows
		var full := app.size
		app.size = Vector2(360, full.y)
		await _frames(4)
		var t: Label = app.load_game_screen.title
		var text_w: float = t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			t.get_theme_font_size("font_size")).x
		var row_end: float = app.load_game_screen.import_btn.get_global_rect().end.x
		assert_true(t.size.x >= text_w and row_end <= 360.5, "%s Saved games title whole at 360 px (%.0f >= %.0f, row ends %.0f)" % [loc, t.size.x, text_w, row_end])
		app.size = full
		await _frames(2)
	LocalizationManager.set_locale(prev)

func test_line_snapping() -> void:
	print("\n--- Test 2: Board lines land on device pixels ---")
	for scale: float in [1.0, 1.3333, 2.0, 2.625, 0.75]:
		var t := Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2(13.4, 7.9))
		var x: float = GridLines.snap(t, 101.37, 0)
		var dev: float = t.origin.x + x * scale
		var w: float = GridLines.snap_width(t, 2.0, 0) * scale
		assert_true(absf(dev - roundf(dev)) < 0.001 and absf(w - roundf(w)) < 0.001 and w >= 1.0,
			"At %.2fx a line edge and width are whole device pixels (%.3f, %.3f)" % [scale, dev, w])

func test_disabled_keys_recede() -> void:
	print("\n--- Test 3: A disabled number key is quieter than an active one ---")
	var btn := Button.new()
	ThemeManager.apply_numpad_button_style(btn)
	var normal: StyleBoxFlat = btn.get_theme_stylebox("normal")
	var disabled: StyleBoxFlat = btn.get_theme_stylebox("disabled")
	assert_true(disabled.border_color.a < normal.border_color.a, "Disabled outline is fainter (%.2f < %.2f)" % [disabled.border_color.a, normal.border_color.a])
	btn.free()

func test_settings_pickers_line_up() -> void:
	print("\n--- Test 4: Settings dropdowns share one width and one left edge ---")
	app._show_screen(app.settings_screen)
	await _frames(4)
	var s := app.settings_screen
	var opts: Array = [s.lang_option, s.theme_option, s.font_option]
	var widths: Array = opts.map(func(o): return roundi(o.size.x))
	var lefts: Array = opts.map(func(o): return roundi(o.get_global_rect().position.x))
	assert_true(widths.all(func(w): return w == widths[0]), "Same width %s" % str(widths))
	assert_true(lefts.all(func(x): return x == lefts[0]), "Same left edge %s" % str(lefts))

func test_new_game_labels_share_alignment() -> void:
	print("\n--- Test 5: The New Game preview aligns all its lines the same way ---")
	var d := app.new_game_dialog
	assert_true(d.preview_seed_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Puzzle number aligned left like the lines above")

func test_stats_card_values() -> void:
	print("\n--- Test 6: Statistics overview ---")
	var prev := LocalizationManager.get_locale()
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	app._show_screen(app.statistics_screen)
	app.statistics_screen.refresh_stats()
	await _frames(4)
	var texts: Array = app.statistics_screen.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_true(texts.any(func(t): return t.begins_with("%")) and not texts.any(func(t): return t.ends_with("%") and t.length() > 1),
		"Turkish percentage reads %N")
	var stray: Array = app.statistics_screen.stats_vbox.get_children().filter(func(c): return c is HSeparator)
	assert_true(stray.is_empty(), "No loose divider lines between the cards")
	LocalizationManager.set_locale(prev)

func test_custom_theme_dialog() -> void:
	print("\n--- Test 7: Custom theme shows every picker, swatches whole, presets translated ---")
	var prev := LocalizationManager.get_locale()
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	var d = app.custom_theme_dialog
	d.open_dialog()
	await _frames(4)
	var names: Array = d.preset_buttons.map(func(b): return b.text)
	assert_true(not names.has("Dark") and names.has(LocalizationManager.translate("THEME_DARK")), "Preset names translated %s" % str(names))
	var cpb: ColorPickerButton = d.picker_buttons.values()[0]
	var sb: StyleBox = cpb.get_theme_stylebox("normal")
	assert_true(sb.get_content_margin(SIDE_LEFT) <= 4.0 and sb.get_content_margin(SIDE_RIGHT) <= 4.0, "Swatch is not squeezed by wide margins")
	var all_inside := true
	for key in d.picker_buttons:
		var b: Control = d.picker_buttons[key]
		var scroll: Control = b.get_parent()
		while scroll != null and not (scroll is ScrollContainer):
			scroll = scroll.get_parent()
		if scroll != null and b.get_global_rect().end.y > scroll.get_global_rect().end.y + 0.5:
			all_inside = false
	assert_true(all_inside, "All %d colour pickers are visible without hidden scrolling" % d.picker_buttons.size())
	d.close_modal()
	LocalizationManager.set_locale(prev)

func test_solution_board_layout() -> void:
	print("\n--- Test 8: Solution board is laid out on exact ninths ---")
	app._show_screen(app.game_screen)
	await _frames(2)
	var d: SolutionDialog = app.game_screen.solution_dialog
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(5151, DifficultyAnalyzer.LEVEL_EASY))
	d.open_solution(state.initial_puzzle, state.current_board)
	await _frames(4)
	var side: float = minf(d.grid_frame.size.x, d.grid_frame.size.y)
	var ok := true
	for i in range(81):
		var p: Control = d.cells[i]["panel"]
		var expect := Vector2((i % 9) * side / 9.0, (i / 9) * side / 9.0)
		if p.position.distance_to(expect) > 0.01 or absf(p.size.x - side / 9.0) > 0.01:
			ok = false
	assert_true(ok and side > 0.0, "All 81 cells equal and in place (side %.1f)" % side)
	assert_true(d.grid_frame.find_children("*", "GridContainer", true, false).is_empty(), "No uneven GridContainer spacing")
	d.close_modal()

func test_list_row_actions_match() -> void:
	print("\n--- Test 9: The ⋯ action matches the primary action's size ---")
	var item := GameRecordItem.new()
	root.add_child(item)
	item.setup_saved_game({"game_id": "p", "difficulty": "Easy", "progress_percentage": 10, "elapsed_time": 1.0})
	assert_true(item.more_btn.custom_minimum_size == item.resume_btn.custom_minimum_size, "⋯ and Play are the same size")
	item.queue_free()
