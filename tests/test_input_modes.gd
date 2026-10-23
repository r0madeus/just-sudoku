extends SceneTree

## Input modes: several cells at once (drag or Ctrl-click), digit-first input and cell colours

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const SudokuCell = preload("res://scenes/gameplay/sudoku_cell.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")

const GRID_PX: float = 450.0

var _passed: int = 0
var _failed: int = 0

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _new_state() -> GameState:
	var gen := SudokuGenerator.generate(424242, DifficultyAnalyzer.LEVEL_EASY)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	return state

## The first n empty cells, in board order
func _empty_cells(state: GameState, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.is_empty(i):
			out.append(i)
			if out.size() == n:
				break
	return out

func _first_given(state: GameState) -> int:
	for i in range(SudokuBoard.CELL_COUNT):
		if state.initial_puzzle.is_given(i):
			return i
	return -1

func _new_screen() -> GameScreen:
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup_game(_new_state())
	# No frame runs in these checks, so give the board its size by hand
	screen.sudoku_grid.size = Vector2(GRID_PX, GRID_PX)
	return screen

func _cell_pos(idx: int) -> Vector2:
	var cell := GRID_PX / 9.0
	return Vector2((SudokuBoard.CELL_COL[idx] + 0.5) * cell, (SudokuBoard.CELL_ROW[idx] + 0.5) * cell)

func _press(grid: Control, idx: int, ctrl: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.position = _cell_pos(idx)
	grid._gui_input(e)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = e.position
	if ctrl:
		grid._gui_input(up)

func _drag(grid: Control, path: Array[int]) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = _cell_pos(path[0])
	grid._gui_input(e)
	for i in range(1, path.size()):
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.position = _cell_pos(path[i])
		grid._gui_input(m)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _cell_pos(path[path.size() - 1])
	grid._gui_input(up)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Nodes added before the first frame are not ready yet (the board has no cells)
	await process_frame
	print("\n=== INPUT MODES ===")
	SettingsScreen.digit_first = false
	SettingsScreen.smart_candidates_enabled = false

	_test_notes_in_many_cells()
	_test_clear_many_cells()
	_test_cell_colors_state()
	_test_drag_selection()
	_test_screen_multi_selection()
	_test_digit_first()
	_test_color_mode_screen()
	_test_digit_first_setting_saved()

	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_notes_in_many_cells() -> void:
	var state := _new_state()
	var cells := _empty_cells(state, 3)
	var given := _first_given(state)
	var targets: Array[int] = cells.duplicate()
	targets.append(given)
	state.toggle_candidate(cells[0], 4)
	var undo_before := state.undo_stack.size()

	# One cell already has the note, so the move adds it to the others
	_check("A note goes into every selected empty cell when some lack it",
		state.toggle_candidate_many(targets, 4)
		and cells.all(func(c): return state.current_board.has_candidate(c, 4)))
	_check("The given in the selection is left alone", state.current_board.candidates[given] == 0)
	_check("Several cells' notes are one move", state.undo_stack.size() == undo_before + 1)
	_check("With every cell holding it, the same key takes the note out of all",
		state.toggle_candidate_many(targets, 4)
		and cells.all(func(c): return not state.current_board.has_candidate(c, 4)))
	state.undo()
	_check("Undo brings the note back to all of them at once",
		cells.all(func(c): return state.current_board.has_candidate(c, 4)))
	state.undo()
	_check("A second Undo goes back to the one note there was",
		state.current_board.has_candidate(cells[0], 4)
		and not state.current_board.has_candidate(cells[1], 4))
	state.redo()
	_check("Redo puts it in all again", cells.all(func(c): return state.current_board.has_candidate(c, 4)))
	_check("Only givens selected: nothing to do", not state.toggle_candidate_many([given], 4))

func _test_clear_many_cells() -> void:
	var state := _new_state()
	var cells := _empty_cells(state, 3)
	state.set_number(cells[0], 7, false)
	state.toggle_candidate(cells[1], 2)
	var undo_before := state.undo_stack.size()
	_check("Erasing several cells clears digits and notes in one move",
		state.clear_cells(cells)
		and state.current_board.get_cell(cells[0]) == 0
		and state.current_board.candidates[cells[1]] == 0
		and state.undo_stack.size() == undo_before + 1)
	state.undo()
	_check("Undo brings back the digit and the note",
		state.current_board.get_cell(cells[0]) == 7 and state.current_board.has_candidate(cells[1], 2))
	state.redo()
	_check("Redo clears them again",
		state.current_board.get_cell(cells[0]) == 0 and state.current_board.candidates[cells[1]] == 0)
	_check("Nothing left to clear: no move", not state.clear_cells(cells))

func _test_cell_colors_state() -> void:
	var state := _new_state()
	var cells := _empty_cells(state, 2)
	var given := _first_given(state)
	var undo_before := state.undo_stack.size()
	_check("Cells, givens included, take a colour",
		state.set_cell_color([cells[0], given], 3)
		and state.get_cell_color(cells[0]) == 3 and state.get_cell_color(given) == 3)
	_check("Colours stay out of Undo", state.undo_stack.size() == undo_before)
	state.set_cell_color([cells[0], cells[1]], 3)
	_check("Mixed cells all get the colour", state.get_cell_color(cells[1]) == 3)
	state.set_cell_color([cells[0], cells[1]], 3)
	_check("The same colour again takes it off", state.get_cell_color(cells[0]) == 0 and state.get_cell_color(cells[1]) == 0)
	_check("Out-of-range colours are refused", not state.set_cell_color([cells[0]], 0) and not state.set_cell_color([cells[0]], 10))

	state.set_cell_color([cells[1]], 6)
	var copy := GameState.new()
	copy.deserialize(JSON.parse_string(JSON.stringify(state.serialize())))
	_check("Colours survive saving and loading", copy.get_cell_color(cells[1]) == 6 and copy.get_cell_color(given) == 3)
	var old := state.serialize()
	old.erase("colors")
	var older := GameState.new()
	older.deserialize(old)
	_check("A save from before colours loads with none", older.get_cell_color(cells[1]) == 0)

	state.reset_for_replay()
	_check("A replay starts without colours", state.get_cell_color(cells[1]) == 0 and state.get_cell_color(given) == 0)
	state.set_cell_color([cells[0]], 2)
	state.is_paused = true
	_check("No colouring while paused", not state.set_cell_color([cells[1]], 2))

func _test_drag_selection() -> void:
	var screen := _new_screen()
	var grid := screen.sudoku_grid
	_drag(grid, [0, 1, 10, 1])
	_check("Dragging over cells selects each of them once", Array(grid.multi_cells) == [0, 1, 10])
	_check("The last new cell is the selected one", grid.selected_idx == 10)
	_check("All of them are drawn selected",
		grid.cells[0].is_selected and grid.cells[1].is_selected and grid.cells[10].is_selected and not grid.cells[2].is_selected)
	_check("Several selected cells tint no row or column", not grid.cells[9].is_peer)
	_press(grid, 40)
	_check("A plain tap selects one cell again", grid.multi_cells.is_empty() and grid.selected_idx == 40)
	_press(grid, 42, true)
	_press(grid, 44, true)
	_check("Ctrl-click adds cells", Array(grid.multi_cells) == [40, 42, 44])
	_press(grid, 42, true)
	_check("Ctrl-click on a selected cell takes it out", Array(grid.multi_cells) == [40, 44])
	grid.multi_select_enabled = false
	_drag(grid, [0, 1, 2])
	_check("With multi-select off a drag keeps one cell", grid.multi_cells.is_empty() and grid.selected_idx == 0)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(GRID_PX + 20.0, 10.0)
	grid._gui_input(e)
	_check("A press outside the cells changes nothing", grid.selected_idx == 0)
	screen.free()

func _test_screen_multi_selection() -> void:
	var screen := _new_screen()
	var state := screen.game_state
	var cells := _empty_cells(state, 3)
	_drag(screen.sudoku_grid, cells)
	screen._on_numpad_number_pressed(5)
	_check("A key with several cells selected writes a note in each, not the digit",
		cells.all(func(c): return state.current_board.get_cell(c) == 0 and state.current_board.has_candidate(c, 5)))
	_check("The notes show on the board", screen.sudoku_grid.cells[cells[1]].candidates_mask & (1 << 5) != 0)
	screen._on_erase_pressed()
	_check("Erase clears every selected cell",
		cells.all(func(c): return state.current_board.candidates[c] == 0))
	_check("Smart keys only dim finished digits with several cells selected",
		screen.numpad.num_buttons.all(func(b): return not b.disabled or state.current_board.get_digit_count(int(b.text)) >= 9))
	screen.sudoku_grid.select_cell(cells[0])
	screen._on_numpad_number_pressed(5)
	_check("One cell selected: the key places the digit", state.current_board.get_cell(cells[0]) == 5)
	screen.free()

func _test_digit_first() -> void:
	SettingsScreen.digit_first = true
	var screen := _new_screen()
	screen._on_settings_changed()
	var state := screen.game_state
	var grid := screen.sudoku_grid
	var cells := _empty_cells(state, 3)
	var given := _first_given(state)
	_check("Digit-first turns off dragging over cells", not grid.multi_select_enabled)

	screen._on_numpad_number_pressed(6)
	_check("A key picks the digit", screen.locked_digit == 6 and screen.numpad.selected_digit == 6)
	_check("The board highlights the picked digit", grid.highlight_digit == 6)
	_check("Picking a digit places nothing", state.current_board.get_cell(grid.selected_idx) == 0 or not state.can_edit_cell(grid.selected_idx))
	_press(grid, cells[0])
	_press(grid, cells[1])
	_check("Each tapped cell gets the picked digit",
		state.current_board.get_cell(cells[0]) == 6 and state.current_board.get_cell(cells[1]) == 6)
	_press(grid, cells[1])
	_check("Tapping a cell with that digit again clears it", state.current_board.get_cell(cells[1]) == 0)
	_check("The digit stays picked between taps", screen.numpad.selected_digit == 6)

	screen._on_action_dock_notes_toggled(true)
	_press(grid, cells[2])
	_check("In notes mode a tap writes the picked digit as a note",
		state.current_board.get_cell(cells[2]) == 0 and state.current_board.has_candidate(cells[2], 6))
	screen._on_action_dock_notes_toggled(false)

	var given_val := state.current_board.get_cell(given)
	_press(grid, given)
	_check("Tapping a given picks its digit", screen.locked_digit == given_val and grid.highlight_digit == given_val)
	screen._on_numpad_number_pressed(given_val)
	_check("The picked key again puts the digit down", screen.locked_digit == 0 and grid.highlight_digit == 0)
	var before := state.current_board.to_string_flat()
	_press(grid, cells[1])
	_check("With no digit picked a tap only selects", state.current_board.to_string_flat() == before and grid.selected_idx == cells[1])

	screen._apply_key(3, grid.get_target_cells())
	_check("The keyboard still fills the selected cell", state.current_board.get_cell(cells[1]) == 3)

	SettingsScreen.digit_first = false
	screen._on_settings_changed()
	_check("Turning digit-first off brings dragging back", grid.multi_select_enabled)
	screen.free()

func _test_color_mode_screen() -> void:
	var screen := _new_screen()
	var state := screen.game_state
	var cells := _empty_cells(state, 2)
	screen._on_action_dock_notes_toggled(true)
	screen.action_dock.set_notes_active(true)
	screen.action_dock.colors_btn.pressed.emit()
	_check("The Colours button turns the keys into colours", screen.numpad.is_color_mode and screen.action_dock.is_color_mode)
	_check("Colour mode ends notes mode", not screen.numpad.is_notes_mode and not screen.action_dock.is_notes_mode)
	_check("Colour keys show no digits and none is dimmed",
		screen.numpad.num_buttons.all(func(b): return b.text == "" and not b.disabled))
	var sb: StyleBoxFlat = screen.numpad.num_buttons[2].get_theme_stylebox("normal")
	_check("Each key wears its colour", sb != null and sb.bg_color == SudokuCell.MARK_COLORS[2])

	_drag(screen.sudoku_grid, cells)
	var undo_before := state.undo_stack.size()
	screen._on_numpad_number_pressed(3)
	_check("A colour key colours the selected cells",
		state.get_cell_color(cells[0]) == 3 and state.get_cell_color(cells[1]) == 3)
	_check("The board shows the colour", screen.sudoku_grid.cells[cells[0]].mark_color == 3)
	_check("The cell's background takes on the colour",
		screen.sudoku_grid.cells[cells[0]].bg_style.bg_color != ThemeManager.get_color("cell_selected"))
	_check("Colouring places no digit and no note, and adds no Undo step",
		state.current_board.get_cell(cells[0]) == 0 and state.current_board.candidates[cells[0]] == 0
		and state.undo_stack.size() == undo_before)
	screen._on_numpad_number_pressed(3)
	_check("The same colour again takes it off", state.get_cell_color(cells[0]) == 0)

	screen._on_action_dock_notes_toggled(true)
	_check("Notes mode ends colour mode", not screen.numpad.is_color_mode and not screen.action_dock.is_color_mode)
	_check("The keys are digits again", screen.numpad.num_buttons[2].text == "3")
	screen._on_action_dock_notes_toggled(false)
	screen.action_dock.set_notes_active(false)
	screen._set_color_mode(true)
	screen._set_color_mode(false)
	_check("Colour mode off by itself also gives the digits back", screen.numpad.num_buttons[0].text == "1")
	screen.free()

func _test_digit_first_setting_saved() -> void:
	SettingsScreen.digit_first = true
	SettingsScreen.save_config()
	SettingsScreen.digit_first = false
	SettingsScreen.load_config()
	_check("Digit-first is saved with the settings", SettingsScreen.digit_first)
	SettingsScreen.digit_first = false
	SettingsScreen.save_config()
