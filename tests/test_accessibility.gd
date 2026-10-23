extends SceneTree

## Accessibility: a wrong or clashing digit is marked by shape as well as colour, the text size
## setting grows the text on screen at once and is remembered, setting rows stay readable when
## it does, and every built-in theme keeps its text readable against its backgrounds.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const SettingRow = preload("res://scenes/ui/setting_row.gd")

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
	print("🧪 RUNNING ACCESSIBILITY TESTS")
	print("========================================")
	AppSettings.animations_enabled = false
	AppSettings.show_conflicts = true

	test_contrast()
	await test_error_marks()
	test_font_size_scale()
	await test_text_size_setting()
	await test_setting_row_stacks()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)

## WCAG contrast ratio
func _contrast(a: Color, b: Color) -> float:
	var la := 0.2126 * _lin(a.r) + 0.7152 * _lin(a.g) + 0.0722 * _lin(a.b)
	var lb := 0.2126 * _lin(b.r) + 0.7152 * _lin(b.g) + 0.0722 * _lin(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func test_contrast() -> void:
	print("\n--- Test 1: Text contrast in every built-in theme ---")
	# Body text, notes, captions and accent text (scores, dates) are small: WCAG AA 4.5:1.
	# Wrong and clashing digits are large text (3:1) and carry a mark as well.
	var small_text := ["text_given", "text_user", "text_secondary", "text_notes", "accent"]
	var low: Array = []
	for theme_name in ThemeManager.PALETTES:
		var p: Dictionary = ThemeManager.PALETTES[theme_name]
		for bg_key in ["bg", "cell_bg", "surface"]:
			for fg in small_text:
				var r := _contrast(p[fg], p[bg_key])
				if r < 4.5:
					low.append("%s %s/%s %.2f" % [theme_name, fg, bg_key, r])
			for fg in ["text_wrong", "text_conflict"]:
				var r2 := _contrast(p[fg], p["cell_bg"])
				if r2 < 3.0:
					low.append("%s %s/cell_bg %.2f" % [theme_name, fg, r2])
	assert_true(low.is_empty(), "Every theme meets the contrast targets %s" % str(low))

func test_error_marks() -> void:
	print("\n--- Test 2: Wrong and clashing digits are marked by shape ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(5151, DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	await _frames(2)
	var grid = screen.sudoku_grid
	var given := -1
	for i in range(81):
		if state.current_board.get_cell(i) != 0 and given == -1:
			given = i
	assert_true(not grid.cells[given].error_mark.visible, "A given digit has no mark")

	# A digit that is wrong for the solution but clashes with nothing in its row, column or box
	var wrong_idx := -1
	var wrong_val := 0
	for i in range(81):
		if state.current_board.get_cell(i) != 0:
			continue
		for v in range(1, 10):
			if v != state.solution.get_cell(i) and SudokuValidator.is_valid_placement(state.current_board, i, v):
				wrong_idx = i
				wrong_val = v
				break
		if wrong_idx != -1:
			break
	state.set_number(wrong_idx, wrong_val)
	state.check_board()
	grid.select_cell(given)
	grid.refresh_all_cells()
	var cell = grid.cells[wrong_idx]
	assert_true(cell.is_wrong and cell.error_mark.visible, "A digit found wrong by a check is marked")
	assert_true(cell.error_mark.color == ThemeManager.get_color("text_wrong"), "Mark in the digit's colour")
	grid.select_cell(wrong_idx)
	grid.refresh_all_cells()
	assert_true(cell.error_mark.visible, "The mark stays while the cell is selected (the red background does not)")

	# A clash: another empty cell takes the digit of a given in its row
	var clash_idx := -1
	var clash_val := 0
	for i in range(81):
		if i == wrong_idx or state.current_board.get_cell(i) != 0 or i / 9 == wrong_idx / 9:
			continue
		for c in range(9):
			var v: int = state.current_board.get_cell((i / 9) * 9 + c)
			if v != 0:
				clash_idx = i
				clash_val = v
				break
		if clash_idx != -1:
			break
	state.set_number(clash_idx, clash_val)
	grid.refresh_all_cells()
	assert_true(grid.cells[clash_idx].is_conflict and grid.cells[clash_idx].error_mark.visible, "A clashing digit is marked")

	state.set_number(wrong_idx, 0)
	grid.refresh_all_cells()
	assert_true(not cell.error_mark.visible, "Clearing the digit clears its mark")
	screen.queue_free()
	await _frames(2)

func test_font_size_scale() -> void:
	print("\n--- Test 3: Text size steps ---")
	ThemeManager.set_text_size(ThemeManager.TEXT_SIZE_NORMAL)
	assert_true(ThemeManager.fs(14) == 14 and ThemeManager.fs(40) == 40, "Normal changes nothing")
	ThemeManager.set_text_size(ThemeManager.TEXT_SIZE_XLARGE)
	assert_true(ThemeManager.fs(14) == 18 and ThemeManager.fs(10) == 13, "Extra large: body 14 -> %d, caption 10 -> %d" % [ThemeManager.fs(14), ThemeManager.fs(10)])
	assert_true(ThemeManager.fs(20) > 20 and ThemeManager.fs(20) < 26, "Headers grow less (20 -> %d)" % ThemeManager.fs(20))
	assert_true(ThemeManager.fs(40) == 40, "The brand title keeps its size")
	ThemeManager.set_text_size(ThemeManager.TEXT_SIZE_NORMAL)

func _font_size(c: Control) -> int:
	return c.get_theme_font_size("font_size")

func test_text_size_setting() -> void:
	print("\n--- Test 4: The setting resizes what is on screen and is remembered ---")
	var app: AppRoot = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(5)
	AppSettings.animations_enabled = false
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(6161, DifficultyAnalyzer.LEVEL_MEDIUM))
	app._start_game_session(state)
	await _frames(3)
	var cell = app.game_screen.sudoku_grid.cells[0]
	var digit_before: int = _font_size(cell.num_label)
	var notes_before: int = cell.notes_view.font_size
	var settings: SettingsScreen = app.settings_screen
	var row_title: Label = settings.text_size_row.title_label
	var body_before: int = _font_size(row_title)
	var caption_before: int = _font_size(settings.sec_appearance_lbl)

	app._show_screen(settings)
	await _frames(3)
	settings.text_size_option.selected = 2
	settings._on_text_size_selected(2)
	await _frames(3)
	assert_true(ThemeManager.text_size == ThemeManager.TEXT_SIZE_XLARGE, "Extra large chosen")
	assert_true(_font_size(row_title) > body_before, "Theme text grows at once (%d -> %d)" % [body_before, _font_size(row_title)])
	assert_true(_font_size(settings.sec_appearance_lbl) == ThemeManager.fs(11) and _font_size(settings.sec_appearance_lbl) > caption_before,
		"A label with its own size grows too (%d -> %d)" % [caption_before, _font_size(settings.sec_appearance_lbl)])
	assert_true(_font_size(cell.num_label) == digit_before, "Board digits keep their size (sized to the cell)")
	assert_true(cell.notes_view.font_size > notes_before, "Notes grow (%d -> %d)" % [notes_before, cell.notes_view.font_size])
	assert_true(settings.text_size_option.custom_minimum_size.x > SettingsScreen.PICKER_WIDTH, "Pickers widen for the longer text")

	# Remembered: read back from the saved settings
	ThemeManager.set_text_size(ThemeManager.TEXT_SIZE_NORMAL)
	AppSettings.load_config()
	assert_true(ThemeManager.text_size == ThemeManager.TEXT_SIZE_XLARGE, "Saved and loaded again")

	settings._on_text_size_selected(0)
	await _frames(3)
	assert_true(_font_size(row_title) == body_before and _font_size(settings.sec_appearance_lbl) == caption_before,
		"Back to normal restores every size")
	app.queue_free()
	await _frames(3)

func test_setting_row_stacks() -> void:
	print("\n--- Test 5: A setting row puts a wide control under its title when narrow ---")
	var holder := VBoxContainer.new()
	holder.size = Vector2(420, 200)
	root.add_child(holder)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(190, 44)
	var row := SettingRow.new("Text Size", "Larger text on every screen", picker)
	holder.add_child(row)
	await _frames(3)
	assert_true(not row.stacked and picker.get_parent().get_parent() == row, "Wide row: control beside the title")
	holder.size = Vector2(300, 200)
	await _frames(3)
	assert_true(row.stacked and picker.get_parent().get_parent() == row.text_vbox, "Narrow row: control under the title")
	assert_true(row.title_label.size.x > 200.0, "The title keeps the row's width (%.0f)" % row.title_label.size.x)
	holder.size = Vector2(420, 200)
	await _frames(3)
	assert_true(not row.stacked, "Wide again: back beside the title")

	var check := CheckBox.new()
	var check_row := SettingRow.new("Sounds", "", check)
	holder.add_child(check_row)
	holder.size = Vector2(200, 200)
	await _frames(3)
	assert_true(not check_row.stacked, "A check box always stays beside its title")
	holder.queue_free()
	await _frames(1)
