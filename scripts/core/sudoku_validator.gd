class_name SudokuValidator
extends RefCounted

## Validates Sudoku rules, detects cell conflicts, and verifies solution uniqueness.

static func get_conflicts(board: SudokuBoard) -> Array[int]:
	var conflict_set: Dictionary = {}

	# Check rows
	for r in range(SudokuBoard.SIZE):
		_check_unit_conflicts(board, SudokuBoard.ROW_INDICES[r], conflict_set)

	# Check columns
	for c in range(SudokuBoard.SIZE):
		_check_unit_conflicts(board, SudokuBoard.COL_INDICES[c], conflict_set)

	# Check boxes
	for b in range(SudokuBoard.SIZE):
		_check_unit_conflicts(board, SudokuBoard.BOX_INDICES[b], conflict_set)

	var result: Array[int] = []
	for k in conflict_set.keys():
		result.append(k)
	return result

static func _check_unit_conflicts(board: SudokuBoard, indices: Array, out_conflicts: Dictionary) -> void:
	var seen: Dictionary = {}
	for idx in indices:
		var val: int = board.get_cell(idx)
		if val == 0:
			continue
		if seen.has(val):
			out_conflicts[idx] = true
			out_conflicts[seen[val]] = true
		else:
			seen[val] = idx

static func is_valid_placement(board: SudokuBoard, idx: int, num: int) -> bool:
	if num < 1 or num > 9:
		return false
	for peer_idx in SudokuBoard.PEERS[idx]:
		if board.get_cell(peer_idx) == num:
			return false
	return true

static func is_board_complete_and_valid(board: SudokuBoard) -> bool:
	if board.get_empty_cell_count() > 0:
		return false
	return get_conflicts(board).is_empty()

## Fast backtracking solution counter with MRV (Minimum Remaining Values) heuristic
static func count_solutions(board: SudokuBoard, max_solutions: int = 2) -> int:
	var working_board := board.clone()
	working_board.reset_candidates_from_grid()
	var count_ref := [0]
	_backtrack_count(working_board, max_solutions, count_ref)
	return count_ref[0]

static func _backtrack_count(board: SudokuBoard, max_solutions: int, count_ref: Array) -> void:
	if count_ref[0] >= max_solutions:
		return

	# Find empty cell with minimum remaining candidates (MRV)
	var best_idx: int = -1
	var min_candidates: int = 10

	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var c_count: int = board.get_candidate_count(idx)
			if c_count == 0:
				# Dead end, cannot solve this branch
				return
			if c_count < min_candidates:
				min_candidates = c_count
				best_idx = idx
				if min_candidates == 1:
					break

	if best_idx == -1:
		# Solved one solution!
		count_ref[0] += 1
		return

	var possible: Array[int] = board.get_candidates(best_idx)
	for num in possible:
		var saved_candidates: PackedInt32Array = board.candidates.duplicate()
		board.set_cell(best_idx, num, false)
		board.reset_candidates_from_grid()

		_backtrack_count(board, max_solutions, count_ref)
		if count_ref[0] >= max_solutions:
			return

		# Restore
		board.set_cell(best_idx, 0, false)
		board.candidates = saved_candidates

static func has_unique_solution(board: SudokuBoard) -> bool:
	return count_solutions(board, 2) == 1
