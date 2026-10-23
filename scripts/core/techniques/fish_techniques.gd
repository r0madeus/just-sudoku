## X-Wing and Swordfish. Static finders for SudokuSolver, which keeps the public API and the
## search order.
extends RefCounted

static func _find_x_wing(board: SudokuBoard) -> SudokuSolver.SolveStep:
	# Row-based X-Wing
	for d in range(1, 10):
		var row_cols: Dictionary = {}
		for r in range(SudokuBoard.SIZE):
			var cols: Array[int] = []
			for c in range(SudokuBoard.SIZE):
				var idx: int = SudokuBoard.get_index(r, c)
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					cols.append(c)
			if cols.size() == 2:
				row_cols[r] = cols

		var valid_rows: Array = row_cols.keys()
		for i in range(valid_rows.size()):
			var r1: int = valid_rows[i]
			var c1_cols: Array[int] = row_cols[r1]
			for j in range(i + 1, valid_rows.size()):
				var r2: int = valid_rows[j]
				var c2_cols: Array[int] = row_cols[r2]
				if c1_cols[0] == c2_cols[0] and c1_cols[1] == c2_cols[1]:
					var colA: int = c1_cols[0]
					var colB: int = c1_cols[1]
					var elims: Dictionary = {}

					for other_r in range(SudokuBoard.SIZE):
						if other_r != r1 and other_r != r2:
							var idxA: int = SudokuBoard.get_index(other_r, colA)
							var idxB: int = SudokuBoard.get_index(other_r, colB)
							if board.get_cell(idxA) == 0 and board.has_candidate(idxA, d):
								elims[idxA] = [d]
							if board.get_cell(idxB) == 0 and board.has_candidate(idxB, d):
								elims[idxB] = [d]

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "X-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 8
						step.cells = [
							SudokuBoard.get_index(r1, colA), SudokuBoard.get_index(r1, colB),
							SudokuBoard.get_index(r2, colA), SudokuBoard.get_index(r2, colB)
						]
						step.eliminations = elims
						step.set_text("EXPL_X_WING_ROWS", [d, r1 + 1, r2 + 1, d, colA + 1, colB + 1])
						return step

	# Column-based X-Wing
	for d in range(1, 10):
		var col_rows: Dictionary = {}
		for c in range(SudokuBoard.SIZE):
			var rows: Array[int] = []
			for r in range(SudokuBoard.SIZE):
				var idx: int = SudokuBoard.get_index(r, c)
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					rows.append(r)
			if rows.size() == 2:
				col_rows[c] = rows

		var valid_cols: Array = col_rows.keys()
		for i in range(valid_cols.size()):
			var c1: int = valid_cols[i]
			var r1_rows: Array[int] = col_rows[c1]
			for j in range(i + 1, valid_cols.size()):
				var c2: int = valid_cols[j]
				var r2_rows: Array[int] = col_rows[c2]
				if r1_rows[0] == r2_rows[0] and r1_rows[1] == r2_rows[1]:
					var rowA: int = r1_rows[0]
					var rowB: int = r1_rows[1]
					var elims: Dictionary = {}

					for other_c in range(SudokuBoard.SIZE):
						if other_c != c1 and other_c != c2:
							var idxA: int = SudokuBoard.get_index(rowA, other_c)
							var idxB: int = SudokuBoard.get_index(rowB, other_c)
							if board.get_cell(idxA) == 0 and board.has_candidate(idxA, d):
								elims[idxA] = [d]
							if board.get_cell(idxB) == 0 and board.has_candidate(idxB, d):
								elims[idxB] = [d]

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "X-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 8
						step.cells = [
							SudokuBoard.get_index(rowA, c1), SudokuBoard.get_index(rowA, c2),
							SudokuBoard.get_index(rowB, c1), SudokuBoard.get_index(rowB, c2)
						]
						step.eliminations = elims
						step.set_text("EXPL_X_WING_COLS", [d, c1 + 1, c2 + 1, d, rowA + 1, rowB + 1])
						return step

	return null

static func _find_swordfish(board: SudokuBoard) -> SudokuSolver.SolveStep:
	# Three rows whose candidates for a digit lie in three columns, or three columns whose
	# candidates lie in three rows: both, or the solver would depend on the grid's orientation
	for d in range(1, 10):
		var step := _swordfish_for(board, d, true)
		if step == null:
			step = _swordfish_for(board, d, false)
		if step != null:
			return step
	return null

## Swordfish on digit `d` with rows as the base lines (`by_rows`) or columns
static func _swordfish_for(board: SudokuBoard, d: int, by_rows: bool) -> SudokuSolver.SolveStep:
	# line -> the cross positions holding d, for lines with 2 or 3 of them
	var spots: Dictionary = {}
	for line in range(SudokuBoard.SIZE):
		var at: Array[int] = []
		for cross in range(SudokuBoard.SIZE):
			var idx: int = SudokuBoard.get_index(line, cross) if by_rows else SudokuBoard.get_index(cross, line)
			if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
				at.append(cross)
		if at.size() >= 2 and at.size() <= 3:
			spots[line] = at

	var lines: Array = spots.keys()
	if lines.size() < 3:
		return null
	for i in range(lines.size()):
		for j in range(i + 1, lines.size()):
			for k in range(j + 1, lines.size()):
				var l1: int = lines[i]
				var l2: int = lines[j]
				var l3: int = lines[k]
				var cross_set: Dictionary = {}
				for c in spots[l1]: cross_set[c] = true
				for c in spots[l2]: cross_set[c] = true
				for c in spots[l3]: cross_set[c] = true
				if cross_set.size() != 3:
					continue

				var elims: Dictionary = {}
				for other in range(SudokuBoard.SIZE):
					if other == l1 or other == l2 or other == l3:
						continue
					for c in cross_set.keys():
						var idx: int = SudokuBoard.get_index(other, int(c)) if by_rows else SudokuBoard.get_index(int(c), other)
						if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
							elims[idx] = [d]

				if not elims.is_empty():
					var step := SudokuSolver.SolveStep.new()
					step.technique = "Swordfish"
					step.category = "Advanced"
					step.difficulty_weight = 10
					step.eliminations = elims
					step.set_text("EXPL_SWORDFISH" if by_rows else "EXPL_SWORDFISH_COLS", [d, l1 + 1, l2 + 1, l3 + 1])
					return step
	return null
