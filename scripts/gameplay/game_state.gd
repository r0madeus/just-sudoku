class_name GameState
extends RefCounted

const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

## Manages active game session, cell modifications, and unlimited Undo/Redo

signal cell_changed(idx: int, value: int, candidates_mask: int)
signal game_completed(summary: Dictionary)
signal game_paused(paused: bool)
signal digit_completed(digit: int)

const SAVE_VERSION: int = 1

var game_id: String = ""
var seed_value: int = 0
var difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM
var difficulty_score: int = 50
var estimated_seconds: int = 600
var top_techniques: Array[String] = []

var initial_puzzle: SudokuBoard
var current_board: SudokuBoard
var solution: SudokuBoard

var elapsed_time: float = 0.0
var mistakes_count: int = 0
var hints_used: int = 0
var undo_count: int = 0
var is_completed: bool = false
var is_paused: bool = false
var is_replay: bool = false

var checked_wrong_indices: Array[int] = []

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func _init() -> void:
	initial_puzzle = SudokuBoard.new()
	current_board = SudokuBoard.new()
	solution = SudokuBoard.new()
	game_id = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_msec())

func init_from_puzzle(gen: SudokuGenerator.GeneratedPuzzle) -> void:
	game_id = "game_%d_%d" % [gen.seed_value, int(Time.get_unix_time_from_system())]
	seed_value = gen.seed_value
	difficulty = gen.difficulty
	difficulty_score = gen.difficulty_score
	estimated_seconds = gen.estimated_seconds
	top_techniques = gen.top_techniques.duplicate()

	initial_puzzle = gen.puzzle.clone()
	current_board = gen.puzzle.clone()
	solution = gen.solution.clone()

	# GDD §17: Do not clutter board with candidates by default!
	if not SettingsScreen.smart_candidates_enabled:
		current_board.clear_all_candidates()

	elapsed_time = 0.0
	mistakes_count = 0
	hints_used = 0
	undo_count = 0
	is_completed = false
	is_paused = false
	is_replay = false
	checked_wrong_indices.clear()
	undo_stack.clear()
	redo_stack.clear()

## Resets the board and game state for a fresh replay session (GDD §26)
func reset_for_replay() -> void:
	game_id = "replay_%d_%d" % [seed_value, int(Time.get_unix_time_from_system())]
	current_board = initial_puzzle.clone()

	# GDD §17: Do not clutter board with candidates by default!
	if not SettingsScreen.smart_candidates_enabled:
		current_board.clear_all_candidates()

	elapsed_time = 0.0
	mistakes_count = 0
	hints_used = 0
	undo_count = 0
	is_completed = false
	is_paused = false
	is_replay = true
	checked_wrong_indices.clear()
	undo_stack.clear()
	redo_stack.clear()

func can_edit_cell(idx: int) -> bool:
	if is_completed or is_paused:
		return false
	if idx < 0 or idx >= SudokuBoard.CELL_COUNT:
		return false
	return not initial_puzzle.is_given(idx)

func set_number(idx: int, num: int, auto_remove_notes: bool = true) -> bool:
	if not can_edit_cell(idx):
		return false
	if num < 0 or num > 9:
		return false

	var prev_val: int = current_board.get_cell(idx)
	var prev_cands: int = current_board.candidates[idx]

	# If tapping the same number again, clear cell
	var new_val: int = 0 if prev_val == num else num
	var new_cands: int = 0
	var prev_digit_count: int = current_board.get_digit_count(new_val) if new_val != 0 else 0

	var auto_removed: Dictionary = {}
	if new_val != 0 and auto_remove_notes:
		var bit: int = 1 << new_val
		for peer_idx in SudokuBoard.PEERS[idx]:
			if current_board.has_candidate(peer_idx, new_val):
				auto_removed[peer_idx] = bit
				current_board.remove_candidate(peer_idx, new_val)

	current_board.set_cell(idx, new_val, false)

	# Remove from checked wrong cells if modified
	checked_wrong_indices.erase(idx)

	# Check for conflicts (mistake increment if instant conflict occurs)
	var is_placement_valid: bool = true
	if new_val != 0 and not SudokuValidator.is_valid_placement(current_board, idx, new_val):
		mistakes_count += 1
		is_placement_valid = false

	# Emit digit_completed when all 9 copies are placed without conflict
	if new_val != 0 and is_placement_valid and prev_digit_count < 9 and current_board.get_digit_count(new_val) == 9:
		digit_completed.emit(new_val)

	var move: Dictionary = {
		"action": "set_number",
		"cell": idx,
		"prev_val": prev_val,
		"new_val": new_val,
		"prev_cands": prev_cands,
		"new_cands": new_cands,
		"auto_removed": auto_removed
	}
	undo_stack.append(move)
	redo_stack.clear()

	cell_changed.emit(idx, new_val, current_board.candidates[idx])
	check_completion()
	return true

func clear_cell(idx: int) -> bool:
	if not can_edit_cell(idx):
		return false

	var prev_val: int = current_board.get_cell(idx)
	var prev_cands: int = current_board.candidates[idx]
	if prev_val == 0 and prev_cands == 0:
		return false

	current_board.set_cell(idx, 0, false)
	current_board.clear_candidates(idx)
	checked_wrong_indices.erase(idx)

	var move: Dictionary = {
		"action": "clear_cell",
		"cell": idx,
		"prev_val": prev_val,
		"new_val": 0,
		"prev_cands": prev_cands,
		"new_cands": 0,
		"auto_removed": {}
	}
	undo_stack.append(move)
	redo_stack.clear()

	cell_changed.emit(idx, 0, 0)
	return true

func toggle_candidate(idx: int, num: int) -> bool:
	if not can_edit_cell(idx):
		return false
	if num < 1 or num > 9:
		return false

	# If cell already has a number, don't edit notes without clearing first
	if current_board.get_cell(idx) != 0:
		return false

	var prev_cands: int = current_board.candidates[idx]
	current_board.toggle_candidate(idx, num)
	var new_cands: int = current_board.candidates[idx]

	var move: Dictionary = {
		"action": "toggle_candidate",
		"cell": idx,
		"prev_val": 0,
		"new_val": 0,
		"prev_cands": prev_cands,
		"new_cands": new_cands,
		"auto_removed": {}
	}
	undo_stack.append(move)
	redo_stack.clear()

	cell_changed.emit(idx, 0, new_cands)
	return true

func can_undo() -> bool:
	return not is_completed and not undo_stack.is_empty()

func can_redo() -> bool:
	return not is_completed and not redo_stack.is_empty()

func undo() -> bool:
	if not can_undo():
		return false

	var move: Dictionary = undo_stack.pop_back()
	var idx: int = move["cell"]

	current_board.set_cell(idx, move["prev_val"], false)
	current_board.candidates[idx] = move["prev_cands"]

	# Restore any auto-removed candidates from peers
	var auto_removed: Dictionary = move.get("auto_removed", {})
	for peer_str in auto_removed.keys():
		var peer_idx: int = int(peer_str)
		current_board.candidates[peer_idx] |= auto_removed[peer_str]
		cell_changed.emit(peer_idx, current_board.get_cell(peer_idx), current_board.candidates[peer_idx])

	checked_wrong_indices.erase(idx)
	redo_stack.append(move)
	undo_count += 1

	cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	return true

func redo() -> bool:
	if not can_redo():
		return false

	var move: Dictionary = redo_stack.pop_back()
	var idx: int = move["cell"]

	current_board.set_cell(idx, move["new_val"], false)
	current_board.candidates[idx] = move["new_cands"]

	# Re-apply auto-removals
	var auto_removed: Dictionary = move.get("auto_removed", {})
	for peer_str in auto_removed.keys():
		var peer_idx: int = int(peer_str)
		current_board.candidates[peer_idx] &= ~auto_removed[peer_str]
		cell_changed.emit(peer_idx, current_board.get_cell(peer_idx), current_board.candidates[peer_idx])

	undo_stack.append(move)
	cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	check_completion()
	return true

func check_board() -> Array[int]:
	var wrong_cells: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		var val: int = current_board.get_cell(idx)
		if val != 0 and val != solution.get_cell(idx):
			wrong_cells.append(idx)
			if not checked_wrong_indices.has(idx):
				mistakes_count += 1
				checked_wrong_indices.append(idx)
	return wrong_cells

func check_completion() -> bool:
	if is_completed:
		return true

	if current_board.get_empty_cell_count() > 0:
		return false

	if not SudokuValidator.is_board_complete_and_valid(current_board):
		return false

	# Match with solution
	for i in range(SudokuBoard.CELL_COUNT):
		if current_board.get_cell(i) != solution.get_cell(i):
			return false

	is_completed = true
	var score: int = PerformanceScorer.calculate_score(
		difficulty, elapsed_time, estimated_seconds, mistakes_count, hints_used, undo_count
	)

	var summary: Dictionary = {
		"game_id": game_id,
		"seed": seed_value,
		"difficulty": difficulty,
		"difficulty_score": difficulty_score,
		"score": score,
		"time": elapsed_time,
		"mistakes": mistakes_count,
		"hints": hints_used,
		"undo_count": undo_count,
		"is_replay": is_replay
	}
	game_completed.emit(summary)
	return true

func apply_hint(specific_step: SudokuSolver.SolveStep = null) -> SudokuSolver.SolveStep:
	if is_completed:
		return null

	var step: SudokuSolver.SolveStep = specific_step
	if step == null:
		step = SudokuSolver.find_best_hint(current_board, -1, solution)

	if step != null:
		hints_used += 1
		if step.digit != 0 and step.cells.size() == 1:
			set_number(step.cells[0], step.digit, true)
		elif not step.eliminations.is_empty():
			for idx_key in step.eliminations.keys():
				var idx: int = int(idx_key)
				for d in step.eliminations[idx_key]:
					current_board.remove_candidate(idx, d)
				cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	return step

func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"game_id": game_id,
		"seed": seed_value,
		"difficulty": difficulty,
		"difficulty_score": difficulty_score,
		"estimated_seconds": estimated_seconds,
		"top_techniques": top_techniques,
		"initial_puzzle": initial_puzzle.to_string_flat(),
		"current_board": current_board.to_string_flat(),
		"solution": solution.to_string_flat(),
		"candidates": Array(current_board.candidates),
		"elapsed_time": elapsed_time,
		"mistakes": mistakes_count,
		"hints": hints_used,
		"undo_count": undo_count,
		"is_completed": is_completed,
		"is_replay": is_replay,
		"undo_stack": undo_stack,
		"redo_stack": redo_stack
	}

func deserialize(data: Dictionary) -> bool:
	if not data.has("initial_puzzle") or not data.has("solution"):
		return false

	game_id = data.get("game_id", "")
	seed_value = int(data.get("seed", 0))
	difficulty = data.get("difficulty", DifficultyAnalyzer.LEVEL_MEDIUM)
	difficulty_score = int(data.get("difficulty_score", 50))
	top_techniques.clear()
	for t in data.get("top_techniques", []):
		top_techniques.append(str(t))

	initial_puzzle.from_string_flat(data["initial_puzzle"], true)
	solution.from_string_flat(data["solution"], false)
	current_board.from_string_flat(data.get("current_board", data["initial_puzzle"]), false)

	# Restore givens on current_board according to initial_puzzle
	for i in range(SudokuBoard.CELL_COUNT):
		current_board.givens[i] = initial_puzzle.givens[i]

	var saved_cands: Array = data.get("candidates", [])
	if saved_cands.size() == SudokuBoard.CELL_COUNT:
		for i in range(SudokuBoard.CELL_COUNT):
			current_board.candidates[i] = int(saved_cands[i])
	else:
		current_board.reset_candidates_from_grid()

	elapsed_time = float(data.get("elapsed_time", 0.0))
	mistakes_count = int(data.get("mistakes", 0))
	hints_used = int(data.get("hints", 0))
	undo_count = int(data.get("undo_count", 0))
	is_completed = bool(data.get("is_completed", false))
	is_replay = bool(data.get("is_replay", false))
	undo_stack.clear()
	for u in data.get("undo_stack", []):
		if u is Dictionary:
			undo_stack.append(u)

	redo_stack.clear()
	for r in data.get("redo_stack", []):
		if r is Dictionary:
			redo_stack.append(r)
	return true
