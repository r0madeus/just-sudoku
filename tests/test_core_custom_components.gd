extends SceneTree

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

const SudokuGrid = preload("res://scenes/gameplay/sudoku_grid.gd")
const SmartNumpad = preload("res://scenes/gameplay/smart_numpad.gd")
const GameActionDock = preload("res://scenes/ui/game_action_dock.gd")
const SegmentedControl = preload("res://scenes/ui/segmented_control.gd")

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING CORE CUSTOM UI COMPONENTS TESTS")
	print("========================================")

	test_segmented_control()
	test_game_action_dock()
	test_sudoku_numpad()
	test_sudoku_grid()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [passed_count, failed_count])
	print("========================================")

	if failed_count > 0:
		quit(1)
	else:
		quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ PASS: %s" % msg)
		passed_count += 1
	else:
		printerr("  ✗ FAIL: %s" % msg)
		failed_count += 1

func test_segmented_control() -> void:
	print("\n--- Test 1: SegmentedControl ---")
	var seg := SegmentedControl.new()
	root.add_child(seg)

	seg.add_segment("opt1", "Option 1")
	seg.add_segment("opt2", "Option 2")
	seg.add_segment("opt3", "Option 3")

	assert_true(seg.buttons.size() == 3, "Created 3 segment buttons")
	assert_true(seg.items.size() == 3, "Created 3 segment items")

	var res := {"id": "", "idx": -1}
	seg.item_selected.connect(func(id: String, idx: int):
		res["id"] = id
		res["idx"] = idx
	)

	seg.select_id("opt2")
	assert_true(seg.get_selected_id() == "opt2", "Selected ID is opt2")
	assert_true(seg.get_selected_index() == 1, "Selected index is 1")
	assert_true(res["id"] == "opt2" and res["idx"] == 1, "Signal item_selected emitted correctly")
	assert_true(seg.buttons[1].theme_type_variation == "PrimaryButton", "Selected button has PrimaryButton style")
	assert_true(seg.buttons[0].theme_type_variation == "GhostButton", "Unselected button has GhostButton style")

	seg.set_segment_text("opt2", "Option Two")
	assert_true(seg.buttons[1].text == "Option Two", "Segment text updated via set_segment_text")

	seg.queue_free()

func test_game_action_dock() -> void:
	print("\n--- Test 2: GameActionDock ---")
	var dock := GameActionDock.new()
	root.add_child(dock)

	assert_true(dock.undo_btn != null, "Undo button exists")
	assert_true(dock.redo_btn != null, "Redo button exists")
	assert_true(dock.notes_btn != null, "Notes button exists")
	assert_true(dock.hint_btn != null, "Hint button exists")

	var res := {
		"undo_fired": false,
		"redo_fired": false,
		"notes_fired": false,
		"hint_fired": false
	}

	dock.undo_pressed.connect(func(): res["undo_fired"] = true)
	dock.redo_pressed.connect(func(): res["redo_fired"] = true)
	dock.notes_toggled.connect(func(_a: bool): res["notes_fired"] = true)
	dock.hint_pressed.connect(func(): res["hint_fired"] = true)

	dock.undo_btn.pressed.emit()
	assert_true(res["undo_fired"], "undo_pressed signal emitted")

	dock.redo_btn.pressed.emit()
	assert_true(res["redo_fired"], "redo_pressed signal emitted")

	dock.notes_btn.pressed.emit()
	assert_true(res["notes_fired"], "notes_toggled signal emitted")
	assert_true(dock.is_notes_mode == true, "is_notes_mode toggled to true")

	dock.hint_btn.pressed.emit()
	assert_true(res["hint_fired"], "hint_pressed signal emitted")

	dock.set_can_undo(false)
	assert_true(dock.undo_btn.disabled == true, "set_can_undo(false) disabled undo_btn")

	dock.set_can_redo(true)
	assert_true(dock.redo_btn.disabled == false, "set_can_redo(true) enabled redo_btn")

	dock.queue_free()

func test_sudoku_numpad() -> void:
	print("\n--- Test 3: SudokuNumpad (SmartNumpad) ---")
	var numpad := SmartNumpad.new()
	root.add_child(numpad)

	assert_true(numpad.grid_container != null, "GridContainer created for 3x3 layout")
	assert_true(numpad.grid_container.columns == 3, "GridContainer has exactly 3 columns")
	assert_true(numpad.num_buttons.size() == 9, "Contains 9 digit buttons (1-9)")

	for i in range(9):
		assert_true(numpad.num_buttons[i].text == str(i + 1), "Button %d has text %s" % [i, str(i + 1)])

	numpad.set_selected_digit(5)
	assert_true(numpad.selected_digit == 5, "selected_digit set to 5")

	var res := {"num": 0}
	numpad.number_pressed.connect(func(d: int): res["num"] = d)

	numpad.num_buttons[6].pressed.emit() # Digit 7
	assert_true(res["num"] == 7, "number_pressed emitted 7")
	assert_true(numpad.selected_digit == 7, "selected_digit updated to 7 on button press")

	numpad.queue_free()

func test_sudoku_grid() -> void:
	print("\n--- Test 4: SudokuGrid (SudokuBoard) ---")
	var grid := SudokuGrid.new()
	grid.size = Vector2(450, 450)
	root.add_child(grid)
	grid._ready()

	assert_true(grid.cells.size() == 81, "Grid created 81 cells")

	var puzzle := SudokuGenerator.generate(12345, DifficultyAnalyzer.LEVEL_EASY)
	var state := GameState.new()
	state.init_from_puzzle(puzzle)
	grid.bind_game_state(state)

	var res := {"idx": -1, "val": -1}
	grid.cell_selected.connect(func(idx: int, val: int):
		res["idx"] = idx
		res["val"] = val
	)

	grid.select_cell(4)
	assert_true(grid.selected_idx == 4, "Selected cell index is 4")
	assert_true(res["idx"] == 4, "cell_selected signal emitted cell index 4")

	grid.move_selection(1, 0)
	assert_true(grid.selected_idx == 13, "move_selection down moved to index 13")

	grid.queue_free()
