class_name GameState
extends RefCounted

const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

## Manages active game session, cell modifications, and unlimited Undo/Redo

signal cell_changed(idx: int, value: int, candidates_mask: int)
signal game_completed(summary: Dictionary)
signal game_paused(paused: bool)
signal digit_completed(digit: int)
## A move filled rows/columns/boxes with no conflict; units holds each one's cell indices
signal units_completed(origin_idx: int, units: Array)

const SAVE_VERSION: int = 1

## Score cost of one hint, cumulative per level: show the area, explain the technique, apply it
const HINT_COST_FOCUS: int = 3
const HINT_COST_TECHNIQUE: int = 8
const HINT_COST_APPLY: int = 12
const HINT_LEVEL_FOCUS: int = 1
const HINT_LEVEL_TECHNIQUE: int = 2
const HINT_LEVEL_APPLY: int = 3

## Cell colours the player can choose from (see SudokuCell.MARK_COLORS)
const MARK_COLOR_COUNT: int = 9

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
## Score points spent on hints, including ones only looked at
var hint_cost: int = 0
var undo_count: int = 0
var is_completed: bool = false
var is_paused: bool = false
var is_replay: bool = false

var checked_wrong_indices: Array[int] = []
## Colour the player gave each cell (0 = none, 1..MARK_COLOR_COUNT); a solving aid outside Undo
var cell_colors: PackedByteArray = PackedByteArray()

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

# Hint currently being revealed level by level, so looking at it again costs nothing extra
var _hint_key: String = ""
var _hint_level: int = 0

func _init() -> void:
	initial_puzzle = SudokuBoard.new()
	current_board = SudokuBoard.new()
	solution = SudokuBoard.new()
	cell_colors.resize(SudokuBoard.CELL_COUNT)
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
	hint_cost = 0
	undo_count = 0
	is_completed = false
	is_paused = false
	is_replay = false
	_reset_hint_progress()
	checked_wrong_indices.clear()
	cell_colors.fill(0)
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
	hint_cost = 0
	undo_count = 0
	is_completed = false
	is_paused = false
	is_replay = true
	_reset_hint_progress()
	checked_wrong_indices.clear()
	cell_colors.fill(0)
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
	elif new_val != 0 and SettingsScreen.show_wrong_immediately and new_val != solution.get_cell(idx):
		# Same as a Check of this one cell: marked and counted once, and not celebrated below
		mistakes_count += 1
		checked_wrong_indices.append(idx)
		is_placement_valid = false

	# Emit digit_completed when all 9 copies are placed without conflict
	if new_val != 0 and is_placement_valid and prev_digit_count < 9 and current_board.get_digit_count(new_val) == 9:
		digit_completed.emit(new_val)

	# The last cell of the board gets the victory animation instead
	if new_val != 0 and is_placement_valid and current_board.get_empty_cell_count() > 0:
		var done_units: Array = _completed_units_at(idx)
		if not done_units.is_empty():
			units_completed.emit(idx, done_units)

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

## Row, column and box through idx that are full and conflict-free
func _completed_units_at(idx: int) -> Array:
	var done: Array = []
	for unit in [
		SudokuBoard.ROW_INDICES[SudokuBoard.CELL_ROW[idx]],
		SudokuBoard.COL_INDICES[SudokuBoard.CELL_COL[idx]],
		SudokuBoard.BOX_INDICES[SudokuBoard.CELL_BOX[idx]]
	]:
		var seen: int = 0
		for cell in unit:
			var v: int = current_board.get_cell(cell)
			if v == 0 or (seen & (1 << v)) != 0:
				seen = -1
				break
			seen |= 1 << v
		if seen != -1:
			done.append(unit)
	return done

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

## The note num in several cells as one undoable move: added to every empty editable cell when
## any of them lacks it, otherwise removed from all of them
func toggle_candidate_many(indices: Array, num: int) -> bool:
	if num < 1 or num > 9:
		return false
	var targets: Array[int] = []
	for idx in indices:
		if can_edit_cell(idx) and current_board.get_cell(idx) == 0:
			targets.append(idx)
	if targets.is_empty():
		return false
	var add := false
	for idx in targets:
		if not current_board.has_candidate(idx, num):
			add = true
			break
	var changes: Dictionary = {}
	for idx in targets:
		var prev: int = current_board.candidates[idx]
		var next: int = prev | (1 << num) if add else prev & ~(1 << num)
		if next != prev:
			changes[idx] = [prev, next]
			current_board.candidates[idx] = next
	_push_cand_changes("notes_many", changes)
	return true

## Clears the digits and notes of several cells as one undoable move
func clear_cells(indices: Array) -> bool:
	var changes: Dictionary = {}
	for idx in indices:
		if not can_edit_cell(idx):
			continue
		var prev_val: int = current_board.get_cell(idx)
		var prev_cands: int = current_board.candidates[idx]
		if prev_val == 0 and prev_cands == 0:
			continue
		changes[idx] = [prev_val, prev_cands, 0, 0]
		current_board.set_cell(idx, 0, false)
		current_board.clear_candidates(idx)
		checked_wrong_indices.erase(idx)
	if changes.is_empty():
		return false
	undo_stack.append({
		"action": "clear_cells",
		"cell": -1,
		"prev_val": 0,
		"new_val": 0,
		"prev_cands": 0,
		"new_cands": 0,
		"auto_removed": {},
		"cell_changes": changes
	})
	redo_stack.clear()
	for idx in changes.keys():
		cell_changed.emit(idx, 0, 0)
	return true

## Gives the cells colour (1..MARK_COLOR_COUNT), or takes it off when they all have it already.
## Colours are marks for the player's own reasoning, so they stay out of Undo and the score.
func set_cell_color(indices: Array, color: int) -> bool:
	if is_completed or is_paused or color < 1 or color > MARK_COLOR_COUNT:
		return false
	var cells: Array[int] = []
	for idx in indices:
		if idx >= 0 and idx < SudokuBoard.CELL_COUNT:
			cells.append(idx)
	if cells.is_empty():
		return false
	var all_have := true
	for idx in cells:
		if cell_colors[idx] != color:
			all_have = false
			break
	for idx in cells:
		cell_colors[idx] = 0 if all_have else color
		cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	return true

func get_cell_color(idx: int) -> int:
	return cell_colors[idx] if idx >= 0 and idx < cell_colors.size() else 0

## Writes every possible candidate into empty cells without notes; cells that already have notes
## keep the player's eliminations and only lose candidates that are no longer possible.
## One undoable move; returns false when nothing changed.
func fill_notes() -> bool:
	if is_completed or is_paused:
		return false
	var possible := current_board.clone()
	possible.reset_candidates_from_grid()
	var changes: Dictionary = {}
	for idx in range(SudokuBoard.CELL_COUNT):
		if current_board.get_cell(idx) != 0:
			continue
		var prev: int = current_board.candidates[idx]
		var next: int = possible.candidates[idx] if prev == 0 else prev & possible.candidates[idx]
		if next != prev:
			changes[idx] = [prev, next]
			current_board.candidates[idx] = next
	if changes.is_empty():
		return false
	_push_cand_changes("fill_notes", changes)
	return true

## Records a notes-only move ({idx: [prev, next]}) and shows the changed cells
func _push_cand_changes(action: String, changes: Dictionary) -> void:
	if changes.is_empty():
		return
	undo_stack.append({
		"action": action,
		"cell": -1,
		"prev_val": 0,
		"new_val": 0,
		"prev_cands": 0,
		"new_cands": 0,
		"auto_removed": {},
		"cand_changes": changes
	})
	redo_stack.clear()
	for idx in changes.keys():
		cell_changed.emit(idx, 0, current_board.candidates[idx])

func can_undo() -> bool:
	return not is_completed and not is_paused and not undo_stack.is_empty()

func can_redo() -> bool:
	return not is_completed and not is_paused and not redo_stack.is_empty()

func undo() -> bool:
	if not can_undo():
		return false

	var move: Dictionary = undo_stack.pop_back()
	var idx: int = int(move["cell"])

	# cell is -1 for moves that only remove notes (elimination hints)
	if idx >= 0:
		current_board.set_cell(idx, int(move["prev_val"]), false)
		current_board.candidates[idx] = int(move["prev_cands"])

	# Restore any auto-removed candidates from peers
	var auto_removed: Dictionary = move.get("auto_removed", {})
	for peer_str in auto_removed.keys():
		var peer_idx: int = int(peer_str)
		current_board.candidates[peer_idx] |= int(auto_removed[peer_str])
		cell_changed.emit(peer_idx, current_board.get_cell(peer_idx), current_board.candidates[peer_idx])
	_apply_cand_changes(move, 0)
	_apply_cell_changes(move, 0)

	checked_wrong_indices.erase(idx)
	redo_stack.append(move)
	undo_count += 1

	if idx >= 0:
		cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	return true

func redo() -> bool:
	if not can_redo():
		return false

	var move: Dictionary = redo_stack.pop_back()
	var idx: int = int(move["cell"])

	if idx >= 0:
		current_board.set_cell(idx, int(move["new_val"]), false)
		current_board.candidates[idx] = int(move["new_cands"])

	# Re-apply auto-removals
	var auto_removed: Dictionary = move.get("auto_removed", {})
	for peer_str in auto_removed.keys():
		var peer_idx: int = int(peer_str)
		current_board.candidates[peer_idx] &= ~int(auto_removed[peer_str])
		cell_changed.emit(peer_idx, current_board.get_cell(peer_idx), current_board.candidates[peer_idx])
	_apply_cand_changes(move, 1)
	_apply_cell_changes(move, 1)

	undo_stack.append(move)
	if idx >= 0:
		cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
	check_completion()
	return true

## Sets each cell in a move's cand_changes ({idx: [prev, next]}) to side 0 (prev) or 1 (next)
func _apply_cand_changes(move: Dictionary, side: int) -> void:
	var changes: Dictionary = move.get("cand_changes", {})
	for idx_key in changes.keys():
		var idx: int = int(idx_key)
		current_board.candidates[idx] = int(changes[idx_key][side])
		cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])

## Sets each cell in a move's cell_changes ({idx: [prev_val, prev_cands, new_val, new_cands]})
## to side 0 (before) or 1 (after)
func _apply_cell_changes(move: Dictionary, side: int) -> void:
	var changes: Dictionary = move.get("cell_changes", {})
	for idx_key in changes.keys():
		var idx: int = int(idx_key)
		var c: Array = changes[idx_key]
		current_board.set_cell(idx, int(c[side * 2]), false)
		current_board.candidates[idx] = int(c[side * 2 + 1])
		checked_wrong_indices.erase(idx)
		cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])

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
		difficulty, elapsed_time, estimated_seconds, mistakes_count, hints_used, undo_count, hint_cost
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
		"is_replay": is_replay,
		"puzzle": initial_puzzle.to_string_flat()
	}
	game_completed.emit(summary)
	return true

static func hint_cost_for_level(level: int) -> int:
	match level:
		HINT_LEVEL_FOCUS:
			return HINT_COST_FOCUS
		HINT_LEVEL_TECHNIQUE:
			return HINT_COST_TECHNIQUE
		HINT_LEVEL_APPLY:
			return HINT_COST_APPLY
	return 0

static func _hint_step_key(step: SudokuSolver.SolveStep) -> String:
	return "%s|%s|%d|%s" % [step.technique, str(step.cells), step.digit, str(step.eliminations)]

## How far this hint has already been revealed (0 when it is a different hint)
func get_hint_level(step: SudokuSolver.SolveStep) -> int:
	if step == null or _hint_step_key(step) != _hint_key:
		return 0
	return _hint_level

## Reveals a hint up to level, charging only the part of its cost not paid yet
func reveal_hint(step: SudokuSolver.SolveStep, level: int) -> void:
	if step == null:
		return
	var key := _hint_step_key(step)
	if key != _hint_key:
		_hint_key = key
		_hint_level = 0
	if level > _hint_level:
		hint_cost += hint_cost_for_level(level) - hint_cost_for_level(_hint_level)
		_hint_level = level

func _reset_hint_progress() -> void:
	_hint_key = ""
	_hint_level = 0

func apply_hint(specific_step: SudokuSolver.SolveStep = null) -> SudokuSolver.SolveStep:
	if is_completed:
		return null

	var step: SudokuSolver.SolveStep = specific_step
	if step == null:
		step = SudokuSolver.find_best_hint(current_board, -1, solution)

	if step != null:
		reveal_hint(step, HINT_LEVEL_APPLY)
		_reset_hint_progress()
		hints_used += 1
		if step.digit != 0 and step.cells.size() == 1:
			set_number(step.cells[0], step.digit, true)
		elif not step.eliminations.is_empty():
			# Record only the notes actually removed, so Undo brings back exactly those
			var removed: Dictionary = {}
			for idx_key in step.eliminations.keys():
				var idx: int = int(idx_key)
				for d in step.eliminations[idx_key]:
					if current_board.remove_candidate(idx, d):
						removed[idx] = int(removed.get(idx, 0)) | (1 << d)
				cell_changed.emit(idx, current_board.get_cell(idx), current_board.candidates[idx])
			if not removed.is_empty():
				undo_stack.append({
					"action": "hint_eliminate",
					"cell": -1,
					"prev_val": 0,
					"new_val": 0,
					"prev_cands": 0,
					"new_cands": 0,
					"auto_removed": removed
				})
				redo_stack.clear()
	return step

func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"game_id": game_id,
		# Stored as text: JSON numbers are doubles and seeds exceed 2^53
		"seed": str(seed_value),
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
		"hint_cost": hint_cost,
		"checked_wrong": checked_wrong_indices,
		"colors": Array(cell_colors),
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
	estimated_seconds = int(data.get("estimated_seconds", 600))
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
	hint_cost = int(data.get("hint_cost", 0))
	checked_wrong_indices.clear()
	for w in data.get("checked_wrong", []):
		checked_wrong_indices.append(int(w))
	cell_colors.fill(0)
	var saved_colors: Array = data.get("colors", [])
	if saved_colors.size() == SudokuBoard.CELL_COUNT:
		for i in range(SudokuBoard.CELL_COUNT):
			cell_colors[i] = clampi(int(saved_colors[i]), 0, MARK_COLOR_COUNT)
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
