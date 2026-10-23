## Singles, locked candidates, pairs and triples: the Basic and Medium techniques.
## Static finders for SudokuSolver, which keeps the public API and the search order.
extends RefCounted

static func _find_naked_single(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var cands: Array[int] = board.get_candidates(idx)
			if cands.size() == 1:
				var step := SudokuSolver.SolveStep.new()
				step.technique = "Naked Single"
				step.category = "Basic"
				step.difficulty_weight = 1
				step.cells = [idx]
				step.digit = cands[0]
				step.set_text("EXPL_NAKED_SINGLE", [{"cell": idx}, step.digit])
				return step
	return null

static func _find_hidden_single(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for u_idx in range(SudokuSolver.ALL_UNITS.size()):
		var unit: Array = SudokuSolver.ALL_UNITS[u_idx]
		for d in range(1, 10):
			var matching_cells: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					matching_cells.append(idx)
			if matching_cells.size() == 1:
				var target_idx: int = matching_cells[0]
				var step := SudokuSolver.SolveStep.new()
				step.technique = "Hidden Single"
				step.category = "Basic"
				step.difficulty_weight = 2
				step.cells = [target_idx]
				step.digit = d
				step.focus_unit = u_idx
				step.set_text("EXPL_HIDDEN_SINGLE", [{"unit": u_idx}, d, {"cell": target_idx}])
				return step
	return null

static func _find_locked_candidates(board: SudokuBoard) -> SudokuSolver.SolveStep:
	# Type 1: Pointing (Box -> Row/Col)
	for b in range(SudokuBoard.SIZE):
		var box_indices: Array = SudokuBoard.BOX_INDICES[b]
		for d in range(1, 10):
			var in_box: Array[int] = []
			for idx in box_indices:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					in_box.append(idx)

			if in_box.size() >= 2 and in_box.size() <= 3:
				var same_row: bool = true
				var same_col: bool = true
				var first_r: int = SudokuBoard.CELL_ROW[in_box[0]]
				var first_c: int = SudokuBoard.CELL_COL[in_box[0]]

				for k in range(1, in_box.size()):
					if SudokuBoard.CELL_ROW[in_box[k]] != first_r:
						same_row = false
					if SudokuBoard.CELL_COL[in_box[k]] != first_c:
						same_col = false

				if same_row:
					var elims: Dictionary = {}
					for peer_idx in SudokuBoard.ROW_INDICES[first_r]:
						if not in_box.has(peer_idx) and board.get_cell(peer_idx) == 0 and board.has_candidate(peer_idx, d):
							elims[peer_idx] = [d]
					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Locked Candidates"
						step.category = "Medium"
						step.difficulty_weight = 3
						step.cells = in_box
						step.eliminations = elims
						step.set_text("EXPL_POINTING_ROW", [{"unit": 18 + b}, d, d])
						return step

				if same_col:
					var elims: Dictionary = {}
					for peer_idx in SudokuBoard.COL_INDICES[first_c]:
						if not in_box.has(peer_idx) and board.get_cell(peer_idx) == 0 and board.has_candidate(peer_idx, d):
							elims[peer_idx] = [d]
					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Locked Candidates"
						step.category = "Medium"
						step.difficulty_weight = 3
						step.cells = in_box
						step.eliminations = elims
						step.set_text("EXPL_POINTING_COL", [{"unit": 18 + b}, d, d])
						return step

	# Type 2: Claiming (Row/Col -> Box)
	for r in range(SudokuBoard.SIZE):
		var row_indices: Array = SudokuBoard.ROW_INDICES[r]
		for d in range(1, 10):
			var in_row: Array[int] = []
			for idx in row_indices:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					in_row.append(idx)
			if in_row.size() >= 2 and in_row.size() <= 3:
				var first_b: int = SudokuBoard.CELL_BOX[in_row[0]]
				var same_box: bool = true
				for k in range(1, in_row.size()):
					if SudokuBoard.CELL_BOX[in_row[k]] != first_b:
						same_box = false
						break
				if same_box:
					var elims: Dictionary = {}
					for peer_idx in SudokuBoard.BOX_INDICES[first_b]:
						if not in_row.has(peer_idx) and board.get_cell(peer_idx) == 0 and board.has_candidate(peer_idx, d):
							elims[peer_idx] = [d]
					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Locked Candidates"
						step.category = "Medium"
						step.difficulty_weight = 3
						step.cells = in_row
						step.eliminations = elims
						step.set_text("EXPL_CLAIMING", [{"unit": r}, d, d])
						return step

	for c in range(SudokuBoard.SIZE):
		var col_indices: Array = SudokuBoard.COL_INDICES[c]
		for d in range(1, 10):
			var in_col: Array[int] = []
			for idx in col_indices:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					in_col.append(idx)
			if in_col.size() >= 2 and in_col.size() <= 3:
				var first_b: int = SudokuBoard.CELL_BOX[in_col[0]]
				var same_box: bool = true
				for k in range(1, in_col.size()):
					if SudokuBoard.CELL_BOX[in_col[k]] != first_b:
						same_box = false
						break
				if same_box:
					var elims: Dictionary = {}
					for peer_idx in SudokuBoard.BOX_INDICES[first_b]:
						if not in_col.has(peer_idx) and board.get_cell(peer_idx) == 0 and board.has_candidate(peer_idx, d):
							elims[peer_idx] = [d]
					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Locked Candidates"
						step.category = "Medium"
						step.difficulty_weight = 3
						step.cells = in_col
						step.eliminations = elims
						step.set_text("EXPL_CLAIMING", [{"unit": 9 + c}, d, d])
						return step

	return null

static func _find_naked_pairs(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for unit in SudokuSolver.ALL_UNITS:
		var pair_cells: Array[int] = []
		for idx in unit:
			if board.get_cell(idx) == 0 and board.get_candidate_count(idx) == 2:
				pair_cells.append(idx)

		for i in range(pair_cells.size()):
			var idx1: int = pair_cells[i]
			var mask1: int = board.candidates[idx1]
			for j in range(i + 1, pair_cells.size()):
				var idx2: int = pair_cells[j]
				if board.candidates[idx2] == mask1:
					var cands: Array[int] = board.get_candidates(idx1)
					var elims: Dictionary = {}
					for other_idx in unit:
						if other_idx != idx1 and other_idx != idx2 and board.get_cell(other_idx) == 0:
							var cell_elims: Array[int] = []
							for d in cands:
								if board.has_candidate(other_idx, d):
									cell_elims.append(d)
							if not cell_elims.is_empty():
								elims[other_idx] = cell_elims

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Naked Pair"
						step.category = "Medium"
						step.difficulty_weight = 4
						step.cells = [idx1, idx2]
						step.eliminations = elims
						step.set_text("EXPL_NAKED_PAIR", [{"cell": idx1}, {"cell": idx2}, cands[0], cands[1]])
						return step
	return null

static func _find_hidden_pairs(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for unit in SudokuSolver.ALL_UNITS:
		var digit_locations: Dictionary = {}
		for d in range(1, 10):
			var locs: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					locs.append(idx)
			if locs.size() == 2:
				digit_locations[d] = locs

		var digits_with_2: Array = digit_locations.keys()
		for i in range(digits_with_2.size()):
			var d1: int = digits_with_2[i]
			var locs1: Array[int] = digit_locations[d1]
			for j in range(i + 1, digits_with_2.size()):
				var d2: int = digits_with_2[j]
				var locs2: Array[int] = digit_locations[d2]
				if locs1[0] == locs2[0] and locs1[1] == locs2[1]:
					var idx1: int = locs1[0]
					var idx2: int = locs1[1]
					var elims: Dictionary = {}

					var extra1: Array[int] = []
					for cd in board.get_candidates(idx1):
						if cd != d1 and cd != d2:
							extra1.append(cd)
					if not extra1.is_empty():
						elims[idx1] = extra1

					var extra2: Array[int] = []
					for cd in board.get_candidates(idx2):
						if cd != d1 and cd != d2:
							extra2.append(cd)
					if not extra2.is_empty():
						elims[idx2] = extra2

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "Hidden Pair"
						step.category = "Medium"
						step.difficulty_weight = 5
						step.cells = [idx1, idx2]
						step.eliminations = elims
						step.set_text("EXPL_HIDDEN_PAIR", [d1, d2, {"cell": idx1}, {"cell": idx2}])
						return step
	return null

static func _find_naked_triples(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for unit in SudokuSolver.ALL_UNITS:
		var cand_cells: Array[int] = []
		for idx in unit:
			if board.get_cell(idx) == 0:
				var cnt: int = board.get_candidate_count(idx)
				if cnt >= 2 and cnt <= 3:
					cand_cells.append(idx)

		if cand_cells.size() < 3:
			continue

		for i in range(cand_cells.size()):
			var idx1: int = cand_cells[i]
			for j in range(i + 1, cand_cells.size()):
				var idx2: int = cand_cells[j]
				for k in range(j + 1, cand_cells.size()):
					var idx3: int = cand_cells[k]
					var combined_mask: int = board.candidates[idx1] | board.candidates[idx2] | board.candidates[idx3]
					var triple_board := SudokuBoard.new()
					triple_board.candidates[0] = combined_mask
					if triple_board.get_candidate_count(0) == 3:
						var triple_cands: Array[int] = triple_board.get_candidates(0)
						var elims: Dictionary = {}
						for other_idx in unit:
							if other_idx != idx1 and other_idx != idx2 and other_idx != idx3 and board.get_cell(other_idx) == 0:
								var cell_elims: Array[int] = []
								for d in triple_cands:
									if board.has_candidate(other_idx, d):
										cell_elims.append(d)
								if not cell_elims.is_empty():
									elims[other_idx] = cell_elims

						if not elims.is_empty():
							var step := SudokuSolver.SolveStep.new()
							step.technique = "Naked Triple"
							step.category = "Medium"
							step.difficulty_weight = 6
							step.cells = [idx1, idx2, idx3]
							step.eliminations = elims
							step.set_text("EXPL_NAKED_TRIPLE", [{"cell": idx1}, {"cell": idx2}, {"cell": idx3}, {"digits": triple_cands}])
							return step
	return null

static func _find_hidden_triples(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for unit in SudokuSolver.ALL_UNITS:
		var digit_locations: Dictionary = {}
		for d in range(1, 10):
			var locs: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					locs.append(idx)
			if locs.size() >= 2 and locs.size() <= 3:
				digit_locations[d] = locs

		var digits: Array = digit_locations.keys()
		if digits.size() < 3:
			continue

		for i in range(digits.size()):
			var d1: int = digits[i]
			for j in range(i + 1, digits.size()):
				var d2: int = digits[j]
				for k in range(j + 1, digits.size()):
					var d3: int = digits[k]
					var union_dict: Dictionary = {}
					for idx in digit_locations[d1]: union_dict[idx] = true
					for idx in digit_locations[d2]: union_dict[idx] = true
					for idx in digit_locations[d3]: union_dict[idx] = true

					if union_dict.size() == 3:
						var cells_list: Array[int] = []
						for c_idx in union_dict.keys():
							cells_list.append(int(c_idx))

						var elims: Dictionary = {}
						var target_digits: Array[int] = [d1, d2, d3]
						for c_idx in cells_list:
							var cell_elims: Array[int] = []
							for cd in board.get_candidates(c_idx):
								if not target_digits.has(cd):
									cell_elims.append(cd)
							if not cell_elims.is_empty():
								elims[c_idx] = cell_elims

						if not elims.is_empty():
							var step := SudokuSolver.SolveStep.new()
							step.technique = "Hidden Triple"
							step.category = "Medium"
							step.difficulty_weight = 7
							step.cells = cells_list
							step.eliminations = elims
							step.set_text("EXPL_HIDDEN_TRIPLE", [d1, d2, d3])
							return step
	return null
