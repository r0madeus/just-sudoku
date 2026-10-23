extends SceneTree

## Techniques guide: the precomputed examples and practice puzzles (assets/techniques) are what
## the solver finds, the screen lists every technique in both languages, a lesson shows the
## example and plays its move, examples cycle, Practice starts a real game, and the menu leads
## there on every phone width.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const TechniqueLibrary = preload("res://scripts/data/technique_library.gd")
const TechniquesScreen = preload("res://scenes/menus/techniques_screen.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

const KEY_RE := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"

var _passed: int = 0
var _failed: int = 0
var _emitted: Array = []

func _init() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func test_data() -> void:
	print("\n--- Test 1: The example file covers every technique ---")
	var size: int = FileAccess.get_file_as_bytes(TechniqueLibrary.DATA_PATH).size()
	_check("examples.json exists and is small (%d bytes)" % size, size > 1000 and size < 300 * 1024)
	var all_ok := true
	var practice_ok := true
	var names: Array[String] = []
	for tech in TechniqueLibrary.ORDER:
		names.append(tech)
		if TechniqueLibrary.examples(tech).size() != TechniqueLibrary.EXAMPLES_PER_TECHNIQUE:
			all_ok = false
		if TechniqueLibrary.practice(tech).size() < 10 or TechniqueLibrary.practice(tech).size() > TechniqueLibrary.PRACTICE_PER_TECHNIQUE:
			practice_ok = false
	_check("Every one of the %d techniques has %d examples" % [names.size(), TechniqueLibrary.EXAMPLES_PER_TECHNIQUE], all_ok)
	_check("Every technique has 10 to %d practice puzzles" % TechniqueLibrary.PRACTICE_PER_TECHNIQUE, practice_ok)
	var ordered := true
	for i in range(1, TechniqueLibrary.ORDER.size()):
		if TechniqueLibrary.WEIGHTS[TechniqueLibrary.ORDER[i]] < TechniqueLibrary.WEIGHTS[TechniqueLibrary.ORDER[i - 1]]:
			ordered = false
	_check("The techniques are listed easiest first", ordered)

func test_examples() -> void:
	print("\n--- Test 2: Every example's next step is its technique ---")
	var bad: Array[String] = []
	var weight_bad: Array[String] = []
	var count := 0
	for tech in TechniqueLibrary.ORDER:
		for ex in TechniqueLibrary.examples(tech):
			count += 1
			var board := TechniqueLibrary.board_of(ex)
			var puzzle := SudokuBoard.new()
			puzzle.from_string_flat(String(ex["puzzle"]), true)
			var consistent := String(ex["technique"]) == tech and board.to_string_flat().length() == 81
			for i in range(SudokuBoard.CELL_COUNT):
				if puzzle.is_given(i) and board.get_cell(i) != puzzle.get_cell(i):
					consistent = false
			var step := SudokuSolver.find_next_step(board)
			if step == null or step.technique != tech or not consistent:
				bad.append("%s (%s)" % [tech, step.technique if step != null else "no step"])
			elif step.difficulty_weight != TechniqueLibrary.WEIGHTS[tech]:
				weight_bad.append(tech)
	_check("All %d examples find their technique on the stored position %s" % [count, str(bad)], bad.is_empty() and count > 0)
	_check("The weights in TechniqueLibrary are the solver's %s" % str(weight_bad), weight_bad.is_empty())

func test_practice() -> void:
	print("\n--- Test 3: Every practice puzzle is solved with its technique ---")
	var bad: Array[String] = []
	var count := 0
	for tech in TechniqueLibrary.ORDER:
		var seen: Dictionary = {}
		for entry in TechniqueLibrary.practice(tech):
			count += 1
			var flat := String(entry["puzzle"])
			var board := SudokuBoard.new()
			board.from_string_flat(flat, true)
			var analysis := DifficultyAnalyzer.analyze(board)
			if flat.length() != 81 or seen.has(flat) or not analysis.solved_logically or int(analysis.technique_counts.get(tech, 0)) == 0 \
					or not SudokuGenerator.LEVEL_ORDER.has(String(entry["level"])):
				bad.append(tech)
			seen[flat] = true
	_check("All %d practice puzzles are unique, solvable without guessing and use their technique %s" % [count, str(bad)], bad.is_empty() and count > 0)
	# Practice leads with puzzles about the technique itself: the first one's hardest step is it
	var lead_ok := true
	for tech in ["Locked Candidates", "Naked Pair", "Hidden Pair", "X-Wing", "XY-Wing", "XYZ-Wing", "Simple Coloring", "XY-Chain"]:
		var first := SudokuBoard.new()
		first.from_string_flat(String(TechniqueLibrary.practice(tech)[0]["puzzle"]), true)
		var hardest := 0
		for st in DifficultyAnalyzer.analyze(first).steps:
			hardest = maxi(hardest, st.difficulty_weight)
		if hardest != TechniqueLibrary.WEIGHTS[tech]:
			lead_ok = false
	_check("The first practice puzzle of a technique has it as its hardest step", lead_ok)

func test_levels() -> void:
	print("\n--- Test 4: Each technique starts at the level the analyzer rates it ---")
	var ok := true
	for tech in TechniqueLibrary.ORDER:
		var level := TechniqueLibrary.first_level(tech)
		var range_w: Vector2i = DifficultyAnalyzer.WEIGHT_RANGES[level]
		var w: int = TechniqueLibrary.WEIGHTS[tech]
		if w < range_w.x or w > range_w.y:
			ok = false
	_check("The level of every technique holds its weight", ok)
	_check("Singles start at Easy, pairs at Medium, X-Wing at Hard, Swordfish at Expert",
		TechniqueLibrary.first_level("Hidden Single") == "Easy" and TechniqueLibrary.first_level("Naked Pair") == "Medium"
		and TechniqueLibrary.first_level("X-Wing") == "Hard" and TechniqueLibrary.first_level("Swordfish") == "Expert")

func test_strings() -> void:
	print("\n--- Test 5: Every text exists in both languages ---")
	var key_re := RegEx.create_from_string(KEY_RE)
	var missing: Array[String] = []
	var keys: Array[String] = ["BTN_TECHNIQUES", "TECHS_TITLE", "TECHS_INTRO", "TECHS_FIRST_LEVEL", "TECHS_EXAMPLE_OF",
		"TECHS_LEGEND_PLACE", "TECHS_LEGEND_ELIMINATE", "TECHS_BTN_SHOW_MOVE", "TECHS_BTN_RESET", "TECHS_BTN_NEXT_EXAMPLE",
		"TECHS_BTN_PRACTICE", "TECHS_PRACTICE_NOTE"]
	for tech in TechniqueLibrary.ORDER:
		keys.append(TechniqueLibrary.description_key(tech))
	for k in keys:
		if not LocalizationManager.DICTIONARY_EN.has(k) or not LocalizationManager.DICTIONARY_TR.has(k):
			missing.append(k)
	_check("%d keys in English and Turkish %s" % [keys.size(), str(missing)], missing.is_empty())
	var weak: Array[String] = []
	for tech in TechniqueLibrary.ORDER:
		LocalizationManager.set_locale("en")
		var title_en := LocalizationManager.get_technique_title(tech)
		var desc_en := LocalizationManager.translate(TechniqueLibrary.description_key(tech))
		LocalizationManager.set_locale("tr")
		var title_tr := LocalizationManager.get_technique_title(tech)
		var desc_tr := LocalizationManager.translate(TechniqueLibrary.description_key(tech))
		if title_en.is_empty() or title_tr.is_empty() or desc_en.length() < 40 or desc_tr.length() < 40 or desc_en == desc_tr \
				or key_re.search(title_en) != null or key_re.search(title_tr) != null \
				or key_re.search(desc_en) != null or key_re.search(desc_tr) != null:
			weak.append(tech)
	LocalizationManager.set_locale("en")
	_check("Titles and descriptions are written out, and differ between languages %s" % str(weak), weak.is_empty())

func _screen() -> TechniquesScreen:
	var s := TechniquesScreen.new()
	s.theme = ThemeManager.build_godot_theme()
	root.add_child(s)
	return s

func _row_text(row: Node, child: String) -> String:
	var l := row.find_child(child, true, false) as Label
	return l.text if l != null else ""

func test_list() -> void:
	print("\n--- Test 6: The screen lists the techniques in both languages ---")
	var s := _screen()
	await _frames(3)
	_check("The list is on show and no lesson is", s.list_scroll.visible and not s.lesson_scroll.visible and s.current_technique == "")
	_check("One row per technique, easiest first", s.row_buttons.keys() == TechniqueLibrary.ORDER)
	for loc in ["en", "tr"]:
		LocalizationManager.set_locale(loc)
		await _frames(2)
		var ok := s.title.text == LocalizationManager.translate("TECHS_TITLE")
		for tech in TechniqueLibrary.ORDER:
			var row: Node = s.row_buttons[tech].get_parent()
			var name_text := _row_text(row, "Name")
			var desc_text := _row_text(row, "Description")
			var level_text := _row_text(row, "Level")
			if name_text != LocalizationManager.get_technique_title(tech) or desc_text.is_empty() \
					or desc_text != LocalizationManager.translate(TechniqueLibrary.description_key(tech)) or level_text.is_empty():
				ok = false
		_check("[%s] Every row has its title, description and level" % loc, ok)
	LocalizationManager.set_locale("en")
	await _frames(2)
	var hidden_single_level := _row_text(s.row_buttons["Hidden Single"].get_parent(), "Level")
	var x_wing_level := _row_text(s.row_buttons["X-Wing"].get_parent(), "Level")
	_check("Levels read 'Easy and up' and 'Hard and up' (%s, %s)" % [hidden_single_level, x_wing_level], hidden_single_level == "EASY AND UP" and x_wing_level == "HARD AND UP")

	_emitted.clear()
	s.back_requested.connect(func(): _emitted.append("back"))
	s.back_btn.pressed.emit()
	_check("Back from the list leaves the screen", _emitted == ["back"])
	s.queue_free()
	await _frames(2)

func _cells_match(s: TechniquesScreen, board: SudokuBoard) -> bool:
	for i in range(SudokuBoard.CELL_COUNT):
		var cell: SudokuCell = s.lesson_grid.cells[i]
		if cell.value != board.get_cell(i):
			return false
		if board.get_cell(i) == 0 and cell.candidates_mask != board.candidates[i]:
			return false
	return true

func test_lesson() -> void:
	print("\n--- Test 7: A lesson shows the example and plays the move ---")
	var s := _screen()
	await _frames(3)
	_check("A technique opens from its row", s.row_buttons["X-Wing"] != null)
	s.row_buttons["X-Wing"].pressed.emit()
	await _frames(3)
	var example: Dictionary = TechniqueLibrary.examples("X-Wing")[0]
	var board := TechniqueLibrary.board_of(example)
	var step := SudokuSolver.find_next_step(board.clone())
	_check("The lesson replaces the list and is named for the technique", s.lesson_scroll.visible and not s.list_scroll.visible and s.title.text == "X-Wing")
	_check("The board shows the example position, digits and notes", _cells_match(s, board))
	var pattern_ok := s.lesson_grid.multi_cells.size() == step.cells.size()
	for c in step.cells:
		if not s.lesson_grid.multi_cells.has(c):
			pattern_ok = false
	_check("The step's cells are highlighted", pattern_ok)
	var strike_ok := s.lesson_grid.strike_marks.size() == step.eliminations.size() and not step.eliminations.is_empty()
	for idx in step.eliminations:
		if not s.lesson_grid.strike_marks.has(int(idx)):
			strike_ok = false
	_check("The notes it removes are struck through", strike_ok)
	_check("The explanation is the solver's, in the current language", s.explanation_label.text == step.explanation and not step.explanation.is_empty())
	LocalizationManager.set_locale("tr")
	await _frames(2)
	_check("It follows a change of language (%s)" % s.explanation_label.text, s.explanation_label.text == step.explanation and s.explanation_label.text != "" and s.title.text == "X-Wing")
	LocalizationManager.set_locale("en")
	await _frames(2)

	# Show the move: an elimination takes its notes away
	var before := board.clone()
	s.show_move_btn.pressed.emit()
	await _frames(2)
	var after := before.clone()
	for idx_key in step.eliminations.keys():
		for d in step.eliminations[idx_key]:
			after.remove_candidate(int(idx_key), d)
	_check("Show the move removes exactly the notes the step names", _cells_match(s, after) and s.move_shown)
	_check("The struck-through marks are gone and the button offers the way back", s.lesson_grid.strike_marks.is_empty()
		and s.show_move_btn.text == LocalizationManager.translate("TECHS_BTN_RESET"))
	s.show_move_btn.pressed.emit()
	await _frames(2)
	_check("Pressed again it puts the position back", _cells_match(s, before) and not s.move_shown and not s.lesson_grid.strike_marks.is_empty())

	# A placement fills the cell
	s.open_lesson("Hidden Single")
	await _frames(2)
	var hs_board := TechniqueLibrary.board_of(TechniqueLibrary.examples("Hidden Single")[0])
	var hs_step := SudokuSolver.find_next_step(hs_board.clone())
	_check("A single names its cell and digit", hs_step.digit != 0 and hs_step.cells.size() == 1 and s.lesson_grid.highlight_digit == hs_step.digit)
	var target: int = hs_step.cells[0]
	s.toggle_move()
	await _frames(2)
	var shown: SudokuCell = s.lesson_grid.cells[target]
	_check("Show the move writes the digit in its cell", shown.value == hs_step.digit and hs_board.get_cell(target) == 0)
	var peers_clear := true
	for peer in SudokuBoard.PEERS[target]:
		if s.lesson_grid.cells[peer].value == 0 and (s.lesson_grid.cells[peer].candidates_mask & (1 << hs_step.digit)) != 0:
			peers_clear = false
	_check("and strikes it from the notes of its row, column and box", peers_clear)

	# Back leads to the list, then out
	_emitted.clear()
	s.back_requested.connect(func(): _emitted.append("back"))
	s.back_btn.pressed.emit()
	_check("Back from a lesson returns to the list, not the menu", s.list_scroll.visible and not s.lesson_scroll.visible and s.current_technique == "" and _emitted.is_empty())
	s.handle_back()
	_check("Back from the list leaves the screen", _emitted == ["back"])
	s.queue_free()
	await _frames(2)

func test_examples_cycle() -> void:
	print("\n--- Test 8: Next example cycles through the examples ---")
	var s := _screen()
	await _frames(3)
	s.open_lesson("Naked Pair")
	await _frames(2)
	var seen: Array[String] = []
	var matches := true
	var count := TechniqueLibrary.examples("Naked Pair").size()
	for i in range(count + 1):
		var expected_idx := i % count
		var ex: Dictionary = TechniqueLibrary.examples("Naked Pair")[expected_idx]
		matches = matches and s.example_index == expected_idx and _cells_match(s, TechniqueLibrary.board_of(ex)) \
			and s.example_label.text == LocalizationManager.translate("TECHS_EXAMPLE_OF") % [expected_idx + 1, count] \
			and s.current_step != null and s.current_step.technique == "Naked Pair"
		seen.append(String(ex["board"]))
		s.next_example_btn.pressed.emit()
		await _frames(1)
	_check("%d examples come round and the first returns, each with its own board and counter" % count, matches)
	var distinct: Dictionary = {}
	for b in seen:
		distinct[b] = true
	_check("The examples are different positions", distinct.size() == count)
	s.toggle_move()
	s.next_example()
	_check("A move shown on one example does not carry to the next", not s.move_shown and not s.lesson_grid.strike_marks.is_empty())

	# The board is for looking at: a tap does not select or change anything
	await _frames(3)
	var grid := s.lesson_grid
	var selected_before := grid.selected_idx
	var board_before := s._lesson_state.current_board.to_string_flat()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = grid.get_global_rect().position + Vector2(5, 5)
	click.global_position = click.position
	root.push_input(click)
	var up := click.duplicate()
	up.pressed = false
	root.push_input(up)
	await _frames(2)
	_check("Tapping the lesson board changes nothing", grid.selected_idx == selected_before and s._lesson_state.current_board.to_string_flat() == board_before
		and grid.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	s.queue_free()
	await _frames(2)

func test_practice_button() -> void:
	print("\n--- Test 9: Practice starts a puzzle that needs the technique ---")
	var s := _screen()
	await _frames(3)
	for tech in ["X-Wing", "Hidden Single", "XY-Chain"]:
		s.open_lesson(tech)
		await _frames(1)
		_emitted.clear()
		var catcher := func(gen: SudokuGenerator.GeneratedPuzzle): _emitted.append(gen)
		s.practice_requested.connect(catcher)
		s.practice_btn.pressed.emit()
		s.practice_requested.disconnect(catcher)
		var gen: SudokuGenerator.GeneratedPuzzle = _emitted[0] if _emitted.size() == 1 else null
		var listed := false
		if gen != null:
			for entry in TechniqueLibrary.practice(tech):
				if String(entry["puzzle"]) == gen.puzzle.to_string_flat():
					listed = true
		_check("[%s] Practice emits one puzzle from that technique's list" % tech, gen != null and listed)
		if gen != null:
			var used := int(DifficultyAnalyzer.analyze(gen.puzzle).technique_counts.get(tech, 0))
			_check("[%s] and its solution path uses it, with a solution to play toward" % tech,
				used > 0 and gen.solution.get_empty_cell_count() == 0 and gen.puzzle.get_empty_cell_count() > 0)
	s.queue_free()
	await _frames(2)

func test_app() -> void:
	print("\n--- Test 10: The menu leads to the screen, Practice starts a game ---")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var app: AppRoot = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(6)
	_emitted.clear()
	app.main_menu.techniques_requested.connect(func(): _emitted.append("menu"))
	app.main_menu.techniques_btn.pressed.emit()
	await _frames(4)
	_check("The Techniques button asks for the screen", _emitted == ["menu"])
	_check("The app shows it, and only it", app.current_screen == app.techniques_screen and app.techniques_screen.visible
		and not app.main_menu.visible and not app.statistics_screen.visible)
	app.techniques_screen.open_lesson("Naked Triple")
	await _frames(2)
	app.handle_back()
	await _frames(2)
	_check("Back from a lesson stays on the screen, at the list", app.current_screen == app.techniques_screen and app.techniques_screen.current_technique == "")
	app.handle_back()
	await _frames(4)
	_check("Back from the list is the menu", app.current_screen == app.main_menu and app.main_menu.visible and not app.techniques_screen.visible)
	app.main_menu.techniques_btn.pressed.emit()
	await _frames(3)
	_check("Opening it again starts at the list", app.techniques_screen.list_scroll.visible)
	app.techniques_screen.open_lesson("Hidden Pair")
	await _frames(2)
	app.techniques_screen.practice_btn.pressed.emit()
	await _frames(4)
	var state: GameState = app.game_screen.game_state
	var listed := false
	if state != null:
		for entry in TechniqueLibrary.practice("Hidden Pair"):
			if String(entry["puzzle"]) == state.initial_puzzle.to_string_flat():
				listed = true
	_check("Practice opens the game screen with one of the technique's puzzles", app.current_screen == app.game_screen and listed)
	app.queue_free()
	await _frames(2)

func test_menu_fit() -> void:
	print("\n--- Test 11: The four navigation buttons fit across a phone, in both languages and at large text ---")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var app: AppRoot = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(4)
	var regular_size: Vector2i = root.content_scale_size
	var cases: Array = [["en", 411.0, "normal"], ["tr", 411.0, "normal"], ["en", 360.0, "normal"], ["tr", 360.0, "normal"],
		["en", 360.0, "xlarge"], ["tr", 360.0, "xlarge"]]
	for c in cases:
		ThemeManager.set_text_size(c[2], app)
		LocalizationManager.set_locale(c[0])
		ResponsiveManager.apply_device_scaling(root, root.size.x / float(c[1]))
		await _frames(5)
		var view := Rect2(Vector2.ZERO, app.size).grow(1.0)
		var inside := true
		var tall_enough := true
		for btn in [app.main_menu.history_btn, app.main_menu.stats_btn, app.main_menu.techniques_btn, app.main_menu.settings_btn]:
			var r: Rect2 = btn.get_global_rect()
			# At the largest text the buttons may take two rows and the menu scroll; they must still
			# fit across the screen
			if r.position.x < -1.0 or r.end.x > app.size.x + 1.0 or (c[2] == "normal" and not view.encloses(r)):
				inside = false
			if btn.size.y < 44.0 or btn.text.is_empty() or btn.size.x < 44.0:
				tall_enough = false
		_check("[%s %d dp, %s text] All four buttons are on screen and at least 44 dp" % [c[0], int(c[1]), c[2]], inside and tall_enough)
	ThemeManager.set_text_size("normal", app)
	LocalizationManager.set_locale("en")
	root.set_meta(&"dp_density", 0.0)
	root.content_scale_size = regular_size
	app.queue_free()
	await _frames(2)

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING TECHNIQUES TESTS")
	print("========================================")
	LocalizationManager.set_locale("en")
	test_data()
	test_examples()
	test_practice()
	test_levels()
	test_strings()
	await test_list()
	await test_lesson()
	await test_examples_cycle()
	await test_practice_button()
	await test_app()
	await test_menu_fit()
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	print("========================================")
	quit(1 if _failed > 0 else 0)
