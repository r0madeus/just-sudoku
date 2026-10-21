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

## Bitmask backtracking counter with MRV; keeps row/column/box masks incrementally
## instead of recomputing every candidate at each node
class SolutionCounter extends RefCounted:
	const ALL_DIGITS: int = 0x1FF

	static var _popcount: PackedInt32Array = PackedInt32Array()

	var cells: PackedInt32Array = PackedInt32Array()
	var row_used: PackedInt32Array = PackedInt32Array()
	var col_used: PackedInt32Array = PackedInt32Array()
	var box_used: PackedInt32Array = PackedInt32Array()
	var limit: int = 2
	var count: int = 0

	## Builds the shared popcount table; call once before using counters from several threads
	static func warm_up() -> void:
		_ensure_popcount()

	static func _ensure_popcount() -> void:
		if _popcount.size() == 512:
			return
		_popcount.resize(512)
		for m in range(1, 512):
			_popcount[m] = _popcount[m >> 1] + (m & 1)

	## Returns false when the givens already contradict each other
	func load_board(board: SudokuBoard) -> bool:
		_ensure_popcount()
		cells.resize(SudokuBoard.CELL_COUNT)
		row_used.resize(9)
		col_used.resize(9)
		box_used.resize(9)
		row_used.fill(0)
		col_used.fill(0)
		box_used.fill(0)
		for idx in range(SudokuBoard.CELL_COUNT):
			var v: int = board.get_cell(idx)
			cells[idx] = v
			if v == 0:
				continue
			var bit: int = 1 << (v - 1)
			var r: int = SudokuBoard.CELL_ROW[idx]
			var c: int = SudokuBoard.CELL_COL[idx]
			var b: int = SudokuBoard.CELL_BOX[idx]
			if (row_used[r] | col_used[c] | box_used[b]) & bit != 0:
				return false
			row_used[r] |= bit
			col_used[c] |= bit
			box_used[b] |= bit
		return true

	func search() -> void:
		if count >= limit:
			return
		var best_idx: int = -1
		var best_mask: int = 0
		var best_n: int = 10
		for idx in range(SudokuBoard.CELL_COUNT):
			if cells[idx] != 0:
				continue
			var mask: int = ~(row_used[SudokuBoard.CELL_ROW[idx]] | col_used[SudokuBoard.CELL_COL[idx]] | box_used[SudokuBoard.CELL_BOX[idx]]) & ALL_DIGITS
			var n: int = _popcount[mask]
			if n == 0:
				return
			if n < best_n:
				best_n = n
				best_idx = idx
				best_mask = mask
				if n == 1:
					break
		if best_idx == -1:
			count += 1
			return

		var r: int = SudokuBoard.CELL_ROW[best_idx]
		var c: int = SudokuBoard.CELL_COL[best_idx]
		var b: int = SudokuBoard.CELL_BOX[best_idx]
		var remaining: int = best_mask
		while remaining != 0:
			var bit: int = remaining & -remaining
			remaining ^= bit
			cells[best_idx] = bit
			row_used[r] |= bit
			col_used[c] |= bit
			box_used[b] |= bit
			search()
			row_used[r] ^= bit
			col_used[c] ^= bit
			box_used[b] ^= bit
			cells[best_idx] = 0
			if count >= limit:
				return

static func count_solutions(board: SudokuBoard, max_solutions: int = 2) -> int:
	var counter := SolutionCounter.new()
	if not counter.load_board(board):
		return 0
	counter.limit = max_solutions
	counter.search()
	return counter.count

static func has_unique_solution(board: SudokuBoard) -> bool:
	return count_solutions(board, 2) == 1
