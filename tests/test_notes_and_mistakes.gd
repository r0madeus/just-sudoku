extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING FILL NOTES & SHOW WRONG DIGITS TESTS")
	print("========================================")

	var smart: bool = AppSettings.smart_candidates_enabled
	var wrong: bool = AppSettings.show_wrong_immediately
	AppSettings.smart_candidates_enabled = false
	AppSettings.show_wrong_immediately = false

	test_fill_notes()
	test_fill_notes_undo_after_reload()
	test_fill_notes_button()
	test_show_wrong_immediately()
	test_checked_wrong_survives_reload()
	test_settings_change_keeps_notes()
	test_resume_keeps_notes()
	test_enabling_show_wrong_reveals_board()

	AppSettings.smart_candidates_enabled = smart
	AppSettings.show_wrong_immediately = wrong

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

func _new_state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	return state

func _empty_cells(state: GameState) -> Array[int]:
	var out: Array[int] = []
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			out.append(i)
	return out

## A digit that breaks no rule at idx but is not the solution, or 0 if none exists
func _wrong_but_legal(state: GameState, idx: int) -> int:
	for d in range(1, 10):
		if d != state.solution.get_cell(idx) and SudokuValidator.is_valid_placement(state.current_board, idx, d):
			return d
	return 0

func test_fill_notes() -> void:
	print("\n--- Test 1: Fill notes writes candidates and keeps the player's eliminations ---")
	var state := _new_state(31415926)
	var empties := _empty_cells(state)
	var kept: int = empties[0]
	var expected := state.current_board.clone()
	expected.reset_candidates_from_grid()

	# The player already narrowed this cell down to one real candidate plus an impossible one
	var real: int = state.solution.get_cell(kept)
	var impossible: int = state.current_board.get_cell(SudokuBoard.PEERS[kept].filter(
		func(p): return state.current_board.get_cell(p) != 0)[0])
	state.toggle_candidate(kept, real)
	state.toggle_candidate(kept, impossible)
	var undo_before: int = state.undo_stack.size()

	assert_true(state.fill_notes(), "Fill notes changed the board")
	assert_true(state.current_board.candidates[kept] == (1 << real), "Kept the player's note, dropped the impossible one")
	var all_full := true
	for idx in empties:
		if idx != kept and state.current_board.candidates[idx] != expected.candidates[idx]:
			all_full = false
	assert_true(all_full, "Every other empty cell has all its possible candidates")
	assert_true(state.undo_stack.size() == undo_before + 1, "Fill notes is a single undo step")
	assert_true(not state.fill_notes(), "Filling again changes nothing")

	state.undo()
	assert_true(state.current_board.candidates[kept] == ((1 << real) | (1 << impossible)), "Undo restored the player's notes")
	assert_true(state.current_board.candidates[empties[1]] == 0, "Undo emptied the filled cells")
	state.redo()
	assert_true(state.current_board.candidates[empties[1]] == expected.candidates[empties[1]], "Redo filled them again")

	state.is_paused = true
	assert_true(not state.fill_notes(), "Fill notes is ignored while paused")
	state.is_paused = false

func test_fill_notes_undo_after_reload() -> void:
	print("\n--- Test 2: Fill notes undo survives a save ---")
	var state := _new_state(27182818)
	state.fill_notes()
	var loaded := SaveManager.import_game_from_string(SaveManager.export_game_to_string(state))
	var idx: int = _empty_cells(loaded)[0]
	assert_true(loaded.current_board.candidates[idx] != 0, "Filled notes were saved")
	assert_true(loaded.undo() and loaded.current_board.candidates[idx] == 0, "Undo after reload empties the notes")

func test_fill_notes_button() -> void:
	print("\n--- Test 3: Fill notes button appears in notes mode ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(16180339)
	screen.setup_game(state)
	var btn: Button = screen.action_dock.fill_notes_btn
	assert_true(not btn.visible, "Hidden outside notes mode")
	screen._on_notes_toggle_pressed()
	assert_true(btn.visible, "Shown in notes mode")
	btn.pressed.emit()
	assert_true(state.current_board.candidates[_empty_cells(state)[0]] != 0, "Pressing it fills the notes")
	assert_true(state.can_undo(), "Undo becomes available")
	screen._on_notes_toggle_pressed()
	assert_true(not btn.visible, "Hidden again after leaving notes mode")
	screen.queue_free()

func test_show_wrong_immediately() -> void:
	print("\n--- Test 4: Show wrong digits right away ---")
	var state := _new_state(14142135)
	var idx := -1
	var wrong := 0
	for i in _empty_cells(state):
		wrong = _wrong_but_legal(state, i)
		if wrong != 0:
			idx = i
			break

	AppSettings.show_wrong_immediately = false
	state.set_number(idx, wrong)
	assert_true(state.mistakes_count == 0 and not state.checked_wrong_indices.has(idx), "Off: a legal wrong digit is not revealed")
	state.clear_cell(idx)

	AppSettings.show_wrong_immediately = true
	state.set_number(idx, wrong)
	assert_true(state.checked_wrong_indices.has(idx), "On: the wrong digit is marked at once")
	assert_true(state.mistakes_count == 1, "On: it counts as one mistake")
	state.check_board()
	assert_true(state.mistakes_count == 1, "A later Check does not count it again")

	state.set_number(idx, state.solution.get_cell(idx))
	assert_true(not state.checked_wrong_indices.has(idx) and state.mistakes_count == 1, "Fixing the cell clears the mark")
	AppSettings.show_wrong_immediately = false

func test_checked_wrong_survives_reload() -> void:
	print("\n--- Test 5: Checked wrong cells survive a save ---")
	var state := _new_state(17320508)
	var idx := -1
	var wrong := 0
	for i in _empty_cells(state):
		wrong = _wrong_but_legal(state, i)
		if wrong != 0:
			idx = i
			break
	state.set_number(idx, wrong)
	state.check_board()
	assert_true(state.mistakes_count == 1, "Check counted the wrong digit")
	var loaded := SaveManager.import_game_from_string(SaveManager.export_game_to_string(state))
	assert_true(loaded.checked_wrong_indices.has(idx), "Red mark restored after reload")
	loaded.check_board()
	assert_true(loaded.mistakes_count == 1, "Checking again after reload does not count it twice")

func test_settings_change_keeps_notes() -> void:
	print("\n--- Test 6: Changing an unrelated setting keeps the notes ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(22360679)
	screen.setup_game(state)
	var idx: int = _empty_cells(state)[0]
	state.toggle_candidate(idx, 5)
	AppSettings._notify_listeners()
	assert_true(state.current_board.has_candidate(idx, 5), "Note kept after another setting changed")
	screen.queue_free()

func test_resume_keeps_notes() -> void:
	print("\n--- Test 7: Resuming a game keeps the notes ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(26457513)
	var idx: int = _empty_cells(state)[0]
	state.toggle_candidate(idx, 7)
	var loaded := SaveManager.import_game_from_string(SaveManager.export_game_to_string(state))
	screen.setup_game(loaded)
	assert_true(loaded.current_board.has_candidate(idx, 7), "Note kept when the saved game is opened")
	screen.queue_free()

func test_enabling_show_wrong_reveals_board() -> void:
	print("\n--- Test 8: Turning the setting on reveals wrong digits already placed ---")
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := _new_state(28284271)
	screen.setup_game(state)
	var idx := -1
	var wrong := 0
	for i in _empty_cells(state):
		wrong = _wrong_but_legal(state, i)
		if wrong != 0:
			idx = i
			break
	state.set_number(idx, wrong)
	assert_true(not state.checked_wrong_indices.has(idx), "Hidden while the setting is off")
	AppSettings.show_wrong_immediately = true
	AppSettings._notify_listeners()
	assert_true(state.checked_wrong_indices.has(idx) and state.mistakes_count == 1, "Revealed and counted once when turned on")
	AppSettings._notify_listeners()
	assert_true(state.mistakes_count == 1, "Further setting changes do not count it again")
	AppSettings.show_wrong_immediately = false
	screen.queue_free()
