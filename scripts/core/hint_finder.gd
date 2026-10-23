## The hint search behind SudokuSolver.find_best_hint: picks the most helpful next step for the
## board on screen. Static, SudokuSolver keeps the public API.
extends RefCounted

## Finds the best human-logic next step for an active game board.
## - Analyzes the actual board state with complete candidates.
## - Prioritizes the player's selected cell if deduction exists.
## - Prioritizes easiest human deductions (Full House, Naked Single, Box Hidden Single) over complex ones.
## - Within a technique tier, prioritizes the most constrained houses (most filled numbers).
## - Uses backtracking strictly as a fallback.
## - Returns a single logical step with localized human-friendly explanation.
static func find_best_hint(board: SudokuBoard, focus_cell: int = -1, solution: SudokuBoard = null) -> SudokuSolver.SolveStep:
	if board.get_empty_cell_count() == 0:
		return null

	var working := board.clone()
	working.reset_candidates_from_grid()

	# 1. Collect all Single placement steps (Full House, Naked Single, Hidden Single)
	var single_steps: Array[SudokuSolver.SolveStep] = []

	# 1a. Full House (Unit with 8 numbers filled -> 1 empty cell remaining)
	for u_idx in range(SudokuSolver.ALL_UNITS.size()):
		var unit: Array = SudokuSolver.ALL_UNITS[u_idx]
		var empty_cells: Array[int] = []
		var present_mask: int = 0
		for idx in unit:
			var val: int = working.get_cell(idx)
			if val == 0:
				empty_cells.append(idx)
			else:
				present_mask |= (1 << val)

		if empty_cells.size() == 1:
			var target_idx: int = empty_cells[0]
			var missing_digit: int = 0
			for d in range(1, 10):
				if (present_mask & (1 << d)) == 0:
					missing_digit = d
					break

			if missing_digit != 0:
				var step := SudokuSolver.SolveStep.new()
				step.technique = "Full House"
				step.category = "Basic"
				step.difficulty_weight = 1
				step.cells = [target_idx]
				step.digit = missing_digit
				step.focus_unit = u_idx
				step.set_text("EXPL_FULL_HOUSE", [{"unit": u_idx}, {"cell": target_idx}, missing_digit])
				single_steps.append(step)

	# 1b. Naked Singles
	for idx in range(SudokuBoard.CELL_COUNT):
		if working.get_cell(idx) == 0:
			var cands: Array[int] = working.get_candidates(idx)
			if cands.size() == 1:
				var d: int = cands[0]
				var step := SudokuSolver.SolveStep.new()
				step.technique = "Naked Single"
				step.category = "Basic"
				step.difficulty_weight = 1
				step.cells = [idx]
				step.digit = d
				step.set_text("EXPL_NAKED_SINGLE", [{"cell": idx}, d])
				single_steps.append(step)

	# 1c. Hidden Singles
	for u_idx in range(SudokuSolver.ALL_UNITS.size()):
		var unit: Array = SudokuSolver.ALL_UNITS[u_idx]
		for d in range(1, 10):
			var matching_cells: Array[int] = []
			for idx in unit:
				if working.get_cell(idx) == 0 and working.has_candidate(idx, d):
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
				single_steps.append(step)

	# If any single placement step exists, pick the most human-accessible one!
	if not single_steps.is_empty():
		return _pick_best_single_step(single_steps, working, focus_cell)

	# 2. Medium: Locked Candidates (Pointing & Claiming)
	var locked_step := SudokuSolver._find_locked_candidates(working)
	if locked_step != null:
		return locked_step

	# 3. Medium: Naked & Hidden Pairs
	var pair_step := SudokuSolver._find_naked_pairs(working)
	if pair_step == null:
		pair_step = SudokuSolver._find_hidden_pairs(working)
	if pair_step != null:
		return pair_step

	# 4. Medium: Triples
	var triple_step := SudokuSolver._find_naked_triples(working)
	if triple_step == null:
		triple_step = SudokuSolver._find_hidden_triples(working)
	if triple_step != null:
		return triple_step

	# 5. Advanced: Wings & Fish
	var adv_step: SudokuSolver.SolveStep = null
	adv_step = SudokuSolver._find_x_wing(working)
	if adv_step == null: adv_step = SudokuSolver._find_xy_wing(working)
	if adv_step == null: adv_step = SudokuSolver._find_xyz_wing(working)
	if adv_step == null: adv_step = SudokuSolver._find_swordfish(working)
	if adv_step != null:
		return adv_step

	# 6. Fallback: Backtracking / Solution
	var solved_board: SudokuBoard = solution
	if solved_board == null:
		solved_board = SudokuSolver.solve_fast(working)

	if solved_board != null:
		var target_idx: int = -1
		if focus_cell != -1 and working.is_empty(focus_cell):
			target_idx = focus_cell
		else:
			var max_peers: int = -1
			for idx in range(SudokuBoard.CELL_COUNT):
				if working.is_empty(idx):
					var peer_cnt: int = 0
					for p in SudokuBoard.PEERS[idx]:
						if not working.is_empty(p):
							peer_cnt += 1
					if peer_cnt > max_peers:
						max_peers = peer_cnt
						target_idx = idx

		if target_idx != -1:
			var target_digit: int = solved_board.get_cell(target_idx)
			var step := SudokuSolver.SolveStep.new()
			step.technique = "Solution Hint"
			step.category = "Advanced"
			step.difficulty_weight = 6
			step.cells = [target_idx]
			step.digit = target_digit
			step.set_text("EXPL_DIRECT", [{"cell": target_idx}, target_digit])
			return step

	return null

static func _pick_best_single_step(steps: Array[SudokuSolver.SolveStep], board: SudokuBoard, focus_cell: int) -> SudokuSolver.SolveStep:
	var best_step: SudokuSolver.SolveStep = null
	var best_score: float = -999999.0

	for step in steps:
		var score: float = 0.0
		var target_idx: int = step.cells[0]

		if focus_cell != -1 and target_idx == focus_cell:
			score += 3000.0
		elif focus_cell != -1 and SudokuBoard.PEERS[focus_cell].has(target_idx):
			score += 150.0

		if step.technique == "Full House":
			score += 1200.0
		elif step.technique == "Naked Single":
			score += 800.0
		elif step.technique == "Hidden Single":
			score += 700.0

		var filled_peers: int = 0
		for p in SudokuBoard.PEERS[target_idx]:
			if not board.is_empty(p):
				filled_peers += 1
		score += filled_peers * 12.0

		var r: int = SudokuBoard.CELL_ROW[target_idx]
		var c: int = SudokuBoard.CELL_COL[target_idx]
		var b: int = SudokuBoard.CELL_BOX[target_idx]

		var r_filled: int = 0
		for p in SudokuBoard.ROW_INDICES[r]: if not board.is_empty(p): r_filled += 1
		var c_filled: int = 0
		for p in SudokuBoard.COL_INDICES[c]: if not board.is_empty(p): c_filled += 1
		var b_filled: int = 0
		for p in SudokuBoard.BOX_INDICES[b]: if not board.is_empty(p): b_filled += 1

		var max_house_fill: int = maxi(r_filled, maxi(c_filled, b_filled))
		score += max_house_fill * 25.0

		if score > best_score:
			best_score = score
			best_step = step

	return best_step
