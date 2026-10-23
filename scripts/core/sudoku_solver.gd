class_name SudokuSolver
extends RefCounted

## Human-like logical Sudoku solver implementing standard deductions
## Provides step-by-step reasoning, technique detection, and backtracking fallback.

class SolveStep extends RefCounted:
	var technique: String = ""
	var category: String = "" # "Basic", "Medium", "Advanced"
	var difficulty_weight: int = 1
	var cells: Array[int] = []
	var secondary_cells: Array[int] = []
	var digit: int = 0 # If placing a number, 1..9, else 0
	var eliminations: Dictionary = {} # cell_idx (int) -> Array[int] (eliminated digits)
	## The explanation as a dictionary key and its values ({"cell": idx}, {"unit": idx} and
	## {"digits": [..]} are written out too), so it reads in the language on screen when shown
	var text_key: String = ""
	var text_args: Array = []
	var _text_literal: String = ""
	var explanation: String:
		get:
			return _text_literal if text_key.is_empty() else SudokuSolver.describe(text_key, text_args)
		set(value):
			_text_literal = value
			text_key = ""
	var focus_unit: int = -1 # ALL_UNITS index the deduction happens in, -1 if not tied to one unit

	func get_target_coord() -> String:
		if cells.is_empty():
			return ""
		return SudokuSolver.format_cell(cells[0])

	func get_formatted_coords() -> String:
		var res: Array[String] = []
		for idx in cells:
			res.append(SudokuSolver.format_cell(idx))
		return ", ".join(res)

	func set_text(key: String, args: Array = []) -> void:
		text_key = key
		text_args = args

	func _to_string() -> String:
		return "[%s] %s" % [technique, explanation]

# Precomputed all unit combinations (9 rows, 9 cols, 9 boxes = 27 units)
static var ALL_UNITS: Array = []

static func _static_init() -> void:
	ALL_UNITS.clear()
	for r in range(SudokuBoard.SIZE):
		ALL_UNITS.append(SudokuBoard.ROW_INDICES[r])
	for c in range(SudokuBoard.SIZE):
		ALL_UNITS.append(SudokuBoard.COL_INDICES[c])
	for b in range(SudokuBoard.SIZE):
		ALL_UNITS.append(SudokuBoard.BOX_INDICES[b])

## Fast backtracking solver returning a fully solved board, or null if unsolvable
static func solve_fast(board: SudokuBoard) -> SudokuBoard:
	var copy := board.clone()
	copy.reset_candidates_from_grid()
	if _backtrack_solve(copy):
		return copy
	return null

static func _backtrack_solve(board: SudokuBoard) -> bool:
	var best_idx: int = -1
	var min_c: int = 10

	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var c_size: int = board.get_candidate_count(idx)
			if c_size == 0:
				return false
			if c_size < min_c:
				min_c = c_size
				best_idx = idx
				if min_c == 1:
					break

	if best_idx == -1:
		return true

	var digits: Array[int] = board.get_candidates(best_idx)
	for d in digits:
		var saved_candidates: PackedInt32Array = board.candidates.duplicate()
		board.set_cell(best_idx, d, false)
		board.reset_candidates_from_grid()

		if _backtrack_solve(board):
			return true

		board.set_cell(best_idx, 0, false)
		board.candidates = saved_candidates

	return false

## Finds the best human-logic next step for an active game board.
## - Analyzes the actual board state with complete candidates.
## - Prioritizes the player's selected cell if deduction exists.
## - Prioritizes easiest human deductions (Full House, Naked Single, Box Hidden Single) over complex ones.
## - Within a technique tier, prioritizes the most constrained houses (most filled numbers).
## - Uses backtracking strictly as a fallback.
## - Returns a single logical step with localized human-friendly explanation.
static func find_best_hint(board: SudokuBoard, focus_cell: int = -1, solution: SudokuBoard = null) -> SolveStep:
	if board.get_empty_cell_count() == 0:
		return null

	var working := board.clone()
	working.reset_candidates_from_grid()

	# 1. Collect all Single placement steps (Full House, Naked Single, Hidden Single)
	var single_steps: Array[SolveStep] = []

	# 1a. Full House (Unit with 8 numbers filled -> 1 empty cell remaining)
	for u_idx in range(ALL_UNITS.size()):
		var unit: Array = ALL_UNITS[u_idx]
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
				var step := SolveStep.new()
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
				var step := SolveStep.new()
				step.technique = "Naked Single"
				step.category = "Basic"
				step.difficulty_weight = 1
				step.cells = [idx]
				step.digit = d
				step.set_text("EXPL_NAKED_SINGLE", [{"cell": idx}, d])
				single_steps.append(step)

	# 1c. Hidden Singles
	for u_idx in range(ALL_UNITS.size()):
		var unit: Array = ALL_UNITS[u_idx]
		for d in range(1, 10):
			var matching_cells: Array[int] = []
			for idx in unit:
				if working.get_cell(idx) == 0 and working.has_candidate(idx, d):
					matching_cells.append(idx)
			if matching_cells.size() == 1:
				var target_idx: int = matching_cells[0]
				var step := SolveStep.new()
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
	var locked_step := _find_locked_candidates(working)
	if locked_step != null:
		return locked_step

	# 3. Medium: Naked & Hidden Pairs
	var pair_step := _find_naked_pairs(working)
	if pair_step == null:
		pair_step = _find_hidden_pairs(working)
	if pair_step != null:
		return pair_step

	# 4. Medium: Triples
	var triple_step := _find_naked_triples(working)
	if triple_step == null:
		triple_step = _find_hidden_triples(working)
	if triple_step != null:
		return triple_step

	# 5. Advanced: Wings & Fish
	var adv_step: SolveStep = null
	adv_step = _find_x_wing(working)
	if adv_step == null: adv_step = _find_xy_wing(working)
	if adv_step == null: adv_step = _find_xyz_wing(working)
	if adv_step == null: adv_step = _find_swordfish(working)
	if adv_step != null:
		return adv_step

	# 6. Fallback: Backtracking / Solution
	var solved_board: SudokuBoard = solution
	if solved_board == null:
		solved_board = solve_fast(working)

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
			var step := SolveStep.new()
			step.technique = "Solution Hint"
			step.category = "Advanced"
			step.difficulty_weight = 6
			step.cells = [target_idx]
			step.digit = target_digit
			step.set_text("EXPL_DIRECT", [{"cell": target_idx}, target_digit])
			return step

	return null

## Unit a first-level hint points at: the step's own unit, else the box of its first cell
static func get_focus_unit(step: SolveStep) -> int:
	if step == null:
		return -1
	if step.focus_unit >= 0:
		return step.focus_unit
	var idx: int = -1
	if not step.cells.is_empty():
		idx = step.cells[0]
	elif not step.eliminations.is_empty():
		idx = int(step.eliminations.keys()[0])
	if idx < 0:
		return -1
	return 18 + SudokuBoard.CELL_BOX[idx]

static func get_unit_name(unit_idx: int) -> String:
	if unit_idx < 9:
		return LocalizationManager.translate("UNIT_ROW") % (unit_idx + 1)
	elif unit_idx < 18:
		return LocalizationManager.translate("UNIT_COL") % (unit_idx - 9 + 1)
	return LocalizationManager.translate("UNIT_BOX") % (unit_idx - 18 + 1)

## A cell in the language on screen ("R4C7", "4. satır 7. sütun")
static func format_cell(idx: int) -> String:
	return LocalizationManager.translate("CELL_COORD") % [SudokuBoard.CELL_ROW[idx] + 1, SudokuBoard.CELL_COL[idx] + 1]

## An explanation key and its values as text in the language on screen
static func describe(key: String, args: Array) -> String:
	var values: Array = []
	for a in args:
		if a is Dictionary and a.has("cell"):
			values.append(format_cell(a["cell"]))
		elif a is Dictionary and a.has("unit"):
			values.append(get_unit_name(a["unit"]))
		elif a is Dictionary and a.has("digits"):
			values.append(", ".join(a["digits"].map(func(d): return str(d))))
		else:
			values.append(a)
	var fmt := LocalizationManager.translate(key)
	return fmt % values if not values.is_empty() else fmt

static func _pick_best_single_step(steps: Array[SolveStep], board: SudokuBoard, focus_cell: int) -> SolveStep:
	var best_step: SolveStep = null
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

## Finds the next logical human deduction step
static func find_next_step(board: SudokuBoard) -> SolveStep:
	var step: SolveStep = null

	# 1. Basic: Naked Single
	step = _find_naked_single(board)
	if step != null: return step

	# 2. Basic: Hidden Single
	step = _find_hidden_single(board)
	if step != null: return step

	# 3. Medium: Locked Candidates (Pointing & Claiming)
	step = _find_locked_candidates(board)
	if step != null: return step

	# 4. Medium: Naked Pair
	step = _find_naked_pairs(board)
	if step != null: return step

	# 5. Medium: Hidden Pair
	step = _find_hidden_pairs(board)
	if step != null: return step

	# 6. Medium: Naked Triple
	step = _find_naked_triples(board)
	if step != null: return step

	# 7. Medium: Hidden Triple
	step = _find_hidden_triples(board)
	if step != null: return step

	# 8. Advanced: X-Wing
	step = _find_x_wing(board)
	if step != null: return step

	# 9. Advanced: XY-Wing
	step = _find_xy_wing(board)
	if step != null: return step

	# 10. Advanced: XYZ-Wing
	step = _find_xyz_wing(board)
	if step != null: return step

	# 11. Advanced: Swordfish
	step = _find_swordfish(board)
	if step != null: return step

	# 12. Advanced: Simple Coloring (chains of one digit)
	step = _find_simple_coloring(board)
	if step != null: return step

	# 13. Advanced: XY-Chain (chains of two-candidate cells)
	step = _find_xy_chain(board)
	if step != null: return step

	return null

const MAX_LOGICAL_STEPS: int = 150

## Solves as much of the board as possible using human logic techniques
static func solve_logical(board: SudokuBoard) -> Dictionary:
	var working := board.clone()
	working.reset_candidates_from_grid()

	var steps: Array[SolveStep] = []
	var technique_counts: Dictionary = {}
	var total_weight: int = 0

	while working.get_empty_cell_count() > 0 and steps.size() < MAX_LOGICAL_STEPS:
		var step := find_next_step(working)
		if step == null:
			# Stuck: requires techniques beyond current logical solver or backtracking
			break

		steps.append(step)
		total_weight += step.difficulty_weight
		technique_counts[step.technique] = technique_counts.get(step.technique, 0) + 1

		# Apply step
		if step.digit != 0 and step.cells.size() == 1:
			var idx: int = step.cells[0]
			working.set_cell(idx, step.digit, false)
			working.reset_candidates_from_grid()
		else:
			for idx_key in step.eliminations.keys():
				var idx: int = int(idx_key)
				for d in step.eliminations[idx_key]:
					working.remove_candidate(idx, d)

	var is_solved: bool = working.get_empty_cell_count() == 0 and SudokuValidator.is_board_complete_and_valid(working)

	return {
		"solved": is_solved,
		"steps": steps,
		"technique_counts": technique_counts,
		"total_weight": total_weight,
		"remaining_empty": working.get_empty_cell_count()
	}

## Computes a complete, continuous step-by-step solution from start to finish
## accompanied by snapshot boards for O(1) instantaneous step navigation (GDD §22)
static func get_full_step_by_step_solution(board: SudokuBoard) -> Dictionary:
	var working := board.clone()
	working.reset_candidates_from_grid()

	var steps: Array[SolveStep] = []
	var snapshots: Array[SudokuBoard] = []

	# Snapshot 0: Initial starting board
	snapshots.append(working.clone())

	# 1. Step through using human-like logical deduction techniques
	while working.get_empty_cell_count() > 0 and steps.size() < MAX_LOGICAL_STEPS:
		var step := find_next_step(working)
		if step == null:
			break

		steps.append(step)

		# Apply step to working board
		if step.digit != 0 and step.cells.size() == 1:
			var idx: int = step.cells[0]
			working.set_cell(idx, step.digit, false)
			working.reset_candidates_from_grid()
		else:
			for idx_key in step.eliminations.keys():
				var idx: int = int(idx_key)
				for d in step.eliminations[idx_key]:
					working.remove_candidate(idx, d)

		snapshots.append(working.clone())

	# 2. If any cells remain (e.g. extreme expert techniques or bifurcation needed),
	# fallback to unique solution to ensure 100% completion guaranteed for the viewer
	if working.get_empty_cell_count() > 0:
		var fast_solved := solve_fast(board)
		if fast_solved != null:
			for idx in range(SudokuBoard.CELL_COUNT):
				if working.get_cell(idx) == 0:
					var target_val: int = fast_solved.get_cell(idx)
					var fallback_step := SolveStep.new()
					fallback_step.technique = "Advanced Logical Deduction"
					fallback_step.category = "Advanced"
					fallback_step.difficulty_weight = 3
					fallback_step.cells = [idx]
					fallback_step.digit = target_val
					fallback_step.set_text("EXPL_DEDUCTION", [{"cell": idx}, target_val])
					steps.append(fallback_step)

					working.set_cell(idx, target_val, false)
					working.reset_candidates_from_grid()
					snapshots.append(working.clone())

	var solved_board: SudokuBoard = working.clone()

	return {
		"steps": steps,
		"snapshots": snapshots,
		"solved_board": solved_board
	}

# --- Technique Implementations ---

static func _find_naked_single(board: SudokuBoard) -> SolveStep:
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var cands: Array[int] = board.get_candidates(idx)
			if cands.size() == 1:
				var step := SolveStep.new()
				step.technique = "Naked Single"
				step.category = "Basic"
				step.difficulty_weight = 1
				step.cells = [idx]
				step.digit = cands[0]
				step.set_text("EXPL_NAKED_SINGLE", [{"cell": idx}, step.digit])
				return step
	return null

static func _find_hidden_single(board: SudokuBoard) -> SolveStep:
	for u_idx in range(ALL_UNITS.size()):
		var unit: Array = ALL_UNITS[u_idx]
		for d in range(1, 10):
			var matching_cells: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					matching_cells.append(idx)
			if matching_cells.size() == 1:
				var target_idx: int = matching_cells[0]
				var step := SolveStep.new()
				step.technique = "Hidden Single"
				step.category = "Basic"
				step.difficulty_weight = 2
				step.cells = [target_idx]
				step.digit = d
				step.focus_unit = u_idx
				step.set_text("EXPL_HIDDEN_SINGLE", [{"unit": u_idx}, d, {"cell": target_idx}])
				return step
	return null

static func _find_locked_candidates(board: SudokuBoard) -> SolveStep:
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
						var step := SolveStep.new()
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
						var step := SolveStep.new()
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
						var step := SolveStep.new()
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
						var step := SolveStep.new()
						step.technique = "Locked Candidates"
						step.category = "Medium"
						step.difficulty_weight = 3
						step.cells = in_col
						step.eliminations = elims
						step.set_text("EXPL_CLAIMING", [{"unit": 9 + c}, d, d])
						return step

	return null

static func _find_naked_pairs(board: SudokuBoard) -> SolveStep:
	for unit in ALL_UNITS:
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
						var step := SolveStep.new()
						step.technique = "Naked Pair"
						step.category = "Medium"
						step.difficulty_weight = 4
						step.cells = [idx1, idx2]
						step.eliminations = elims
						step.set_text("EXPL_NAKED_PAIR", [{"cell": idx1}, {"cell": idx2}, cands[0], cands[1]])
						return step
	return null

static func _find_hidden_pairs(board: SudokuBoard) -> SolveStep:
	for unit in ALL_UNITS:
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
						var step := SolveStep.new()
						step.technique = "Hidden Pair"
						step.category = "Medium"
						step.difficulty_weight = 5
						step.cells = [idx1, idx2]
						step.eliminations = elims
						step.set_text("EXPL_HIDDEN_PAIR", [d1, d2, {"cell": idx1}, {"cell": idx2}])
						return step
	return null

static func _find_naked_triples(board: SudokuBoard) -> SolveStep:
	for unit in ALL_UNITS:
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
							var step := SolveStep.new()
							step.technique = "Naked Triple"
							step.category = "Medium"
							step.difficulty_weight = 6
							step.cells = [idx1, idx2, idx3]
							step.eliminations = elims
							step.set_text("EXPL_NAKED_TRIPLE", [{"cell": idx1}, {"cell": idx2}, {"cell": idx3}, {"digits": triple_cands}])
							return step
	return null

static func _find_hidden_triples(board: SudokuBoard) -> SolveStep:
	for unit in ALL_UNITS:
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
							var step := SolveStep.new()
							step.technique = "Hidden Triple"
							step.category = "Medium"
							step.difficulty_weight = 7
							step.cells = cells_list
							step.eliminations = elims
							step.set_text("EXPL_HIDDEN_TRIPLE", [d1, d2, d3])
							return step
	return null

static func _find_x_wing(board: SudokuBoard) -> SolveStep:
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
						var step := SolveStep.new()
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
						var step := SolveStep.new()
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

static func _find_xy_wing(board: SudokuBoard) -> SolveStep:
	# XY-Wing: Pivot with (X, Y), Pincer1 with (X, Z), Pincer2 with (Y, Z)
	var bi_value_cells: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0 and board.get_candidate_count(idx) == 2:
			bi_value_cells.append(idx)

	for pivot in bi_value_cells:
		var p_cands: Array[int] = board.get_candidates(pivot)
		var x: int = p_cands[0]
		var y: int = p_cands[1]

		var pincer_x: Array[int] = [] # has x and z
		var pincer_y: Array[int] = [] # has y and z

		for other in bi_value_cells:
			if other != pivot and SudokuBoard.PEERS[pivot].has(other):
				var o_cands: Array[int] = board.get_candidates(other)
				if o_cands.has(x) and not o_cands.has(y):
					pincer_x.append(other)
				elif o_cands.has(y) and not o_cands.has(x):
					pincer_y.append(other)

		for px in pincer_x:
			var px_cands: Array[int] = board.get_candidates(px)
			var z_cand: int = px_cands[0] if px_cands[1] == x else px_cands[1]

			for py in pincer_y:
				var py_cands: Array[int] = board.get_candidates(py)
				if py_cands.has(z_cand):
					# Found XY-Wing! Eliminate z_cand from common peers of px and py
					var elims: Dictionary = {}
					for peer in SudokuBoard.PEERS[px]:
						if peer != pivot and peer != px and peer != py:
							if SudokuBoard.PEERS[py].has(peer) and board.get_cell(peer) == 0:
								if board.has_candidate(peer, z_cand):
									elims[peer] = [z_cand]

					if not elims.is_empty():
						var step := SolveStep.new()
						step.technique = "XY-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 9
						step.cells = [pivot, px, py]
						step.eliminations = elims
						step.set_text("EXPL_XY_WING", [{"cell": pivot}, {"cell": px}, {"cell": py}, z_cand])
						return step
	return null

static func _find_xyz_wing(board: SudokuBoard) -> SolveStep:
	# Pivot with (X, Y, Z), Pincer1 with (X, Z), Pincer2 with (Y, Z)
	# Pivot and Pincer1 must share a box, and Pincer2 sees pivot.
	var tri_value_cells: Array[int] = []
	var bi_value_cells: Array[int] = []

	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var cnt: int = board.get_candidate_count(idx)
			if cnt == 3:
				tri_value_cells.append(idx)
			elif cnt == 2:
				bi_value_cells.append(idx)

	for pivot in tri_value_cells:
		var p_cands: Array[int] = board.get_candidates(pivot)
		var p_peers: Array = SudokuBoard.PEERS[pivot]

		# Check all pairs of bi-value peers
		var bi_peers: Array[int] = []
		for bvc in bi_value_cells:
			if p_peers.has(bvc):
				bi_peers.append(bvc)

		for i in range(bi_peers.size()):
			var p1: int = bi_peers[i]
			var p1_cands: Array[int] = board.get_candidates(p1)
			# P1 must share 2 candidates with pivot
			if not (p_cands.has(p1_cands[0]) and p_cands.has(p1_cands[1])):
				continue

			for j in range(i + 1, bi_peers.size()):
				var p2: int = bi_peers[j]
				var p2_cands: Array[int] = board.get_candidates(p2)
				if not (p_cands.has(p2_cands[0]) and p_cands.has(p2_cands[1])):
					continue
				# The wings must be XZ and YZ: two wings with the same pair prove nothing (the
				# pivot could be the third digit while both wings are the shared one's partner)
				if p1_cands[0] == p2_cands[0] and p1_cands[1] == p2_cands[1]:
					continue

				# Find common candidate Z between p1 and p2
				var z_cand: int = 0
				for c in p1_cands:
					if p2_cands.has(c):
						z_cand = c
						break

				if z_cand != 0:
					# Both p1 and p2 share candidate z_cand with pivot
					var elims: Dictionary = {}
					for peer in SudokuBoard.PEERS[pivot]:
						if peer != p1 and peer != p2 and board.get_cell(peer) == 0:
							if SudokuBoard.PEERS[p1].has(peer) and SudokuBoard.PEERS[p2].has(peer):
								if board.has_candidate(peer, z_cand):
									elims[peer] = [z_cand]

					if not elims.is_empty():
						var step := SolveStep.new()
						step.technique = "XYZ-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 10
						step.cells = [pivot, p1, p2]
						step.eliminations = elims
						step.set_text("EXPL_XYZ_WING", [{"cell": pivot}, z_cand])
						return step

	return null

static func _find_swordfish(board: SudokuBoard) -> SolveStep:
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
static func _swordfish_for(board: SudokuBoard, d: int, by_rows: bool) -> SolveStep:
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
					var step := SolveStep.new()
					step.technique = "Swordfish"
					step.category = "Advanced"
					step.difficulty_weight = 10
					step.eliminations = elims
					step.set_text("EXPL_SWORDFISH" if by_rows else "EXPL_SWORDFISH_COLS", [d, l1 + 1, l2 + 1, l3 + 1])
					return step
	return null

## Simple Coloring: where a digit has exactly two places in a unit, one of them holds it (a
## strong link). Linked cells are coloured alternately; in each chain one colour is all true.
## Two cells of one colour in the same unit: that colour is false, so its cells lose the digit.
## A cell outside the chain that sees both colours cannot hold the digit.
static func _find_simple_coloring(board: SudokuBoard) -> SolveStep:
	for d in range(1, 10):
		# Strong links for d
		var links: Dictionary = {} # cell -> Array of linked cells
		for unit in ALL_UNITS:
			var at: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					at.append(idx)
			if at.size() == 2:
				if not links.has(at[0]): links[at[0]] = []
				if not links.has(at[1]): links[at[1]] = []
				if not links[at[0]].has(at[1]): links[at[0]].append(at[1])
				if not links[at[1]].has(at[0]): links[at[1]].append(at[0])

		var colored: Dictionary = {} # cell -> 0 or 1
		var starts: Array = links.keys()
		starts.sort()
		for start in starts:
			if colored.has(start):
				continue
			# Colour one chain
			var chain: Array[int] = [start]
			var color: Dictionary = {start: 0}
			var queue: Array[int] = [start]
			while not queue.is_empty():
				var cur: int = queue.pop_front()
				for nb in links[cur]:
					if not color.has(nb):
						color[nb] = 1 - int(color[cur])
						chain.append(nb)
						queue.append(nb)
			for c in chain:
				colored[c] = color[c]
			if chain.size() < 3:
				continue
			chain.sort()

			# Colour wrap: two cells of one colour see each other
			for bad in [0, 1]:
				var clash := false
				for i in range(chain.size()):
					for j in range(i + 1, chain.size()):
						if color[chain[i]] == bad and color[chain[j]] == bad and SudokuBoard.PEERS[chain[i]].has(chain[j]):
							clash = true
							break
					if clash:
						break
				if clash:
					var elims: Dictionary = {}
					for c in chain:
						if color[c] == bad:
							elims[c] = [d]
					return _coloring_step(d, chain, elims, "EXPL_SIMPLE_COLORING_WRAP")

			# Colour trap: an outside cell seeing both colours
			var elims: Dictionary = {}
			for idx in range(SudokuBoard.CELL_COUNT):
				if color.has(idx) or board.get_cell(idx) != 0 or not board.has_candidate(idx, d):
					continue
				var sees := [false, false]
				for c in chain:
					if SudokuBoard.PEERS[idx].has(c):
						sees[int(color[c])] = true
				if sees[0] and sees[1]:
					elims[idx] = [d]
			if not elims.is_empty():
				return _coloring_step(d, chain, elims, "EXPL_SIMPLE_COLORING_TRAP")
	return null

static func _coloring_step(d: int, chain: Array[int], elims: Dictionary, key: String) -> SolveStep:
	var step := SolveStep.new()
	step.technique = "Simple Coloring"
	step.category = "Advanced"
	step.difficulty_weight = 11
	step.cells = chain
	step.eliminations = elims
	step.set_text(key, [d, d])
	return step

## Longest XY-Chain followed, in cells; longer chains are rare and slow to search
const XY_CHAIN_MAX_CELLS: int = 12

## XY-Chain: two-candidate cells, each seeing the next and sharing a digit with it. If the first
## cell is not z it is its other digit, which forces the next cell, and so on, until a cell is
## forced to z. So the first or the last cell is z, and any cell seeing both cannot be.
static func _find_xy_chain(board: SudokuBoard) -> SolveStep:
	var bivalue: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0 and board.get_candidate_count(idx) == 2:
			bivalue.append(idx)
	if bivalue.size() < 3:
		return null

	for start in bivalue:
		var sc: Array[int] = board.get_candidates(start)
		for zi in range(2):
			var z: int = sc[zi]
			var first_value: int = sc[1 - zi]
			# Breadth first over (cell, value the chain forces on it); shortest chains first
			var parent: Dictionary = {}
			var depth: Dictionary = {}
			var start_key: int = start * 10 + first_value
			parent[start_key] = -1
			depth[start_key] = 1
			var queue: Array[int] = [start_key]
			while not queue.is_empty():
				var key: int = queue.pop_front()
				var cell: int = key / 10
				var value: int = key % 10
				if depth[key] >= XY_CHAIN_MAX_CELLS:
					continue
				for nb in bivalue:
					if nb == cell or nb == start or not SudokuBoard.PEERS[cell].has(nb) or not board.has_candidate(nb, value):
						continue
					var nc: Array[int] = board.get_candidates(nb)
					var forced: int = nc[0] if nc[1] == value else nc[1]
					var nkey: int = nb * 10 + forced
					if parent.has(nkey):
						continue
					parent[nkey] = key
					depth[nkey] = int(depth[key]) + 1
					if forced == z and int(depth[nkey]) >= 3:
						var elims: Dictionary = {}
						for peer in SudokuBoard.PEERS[start]:
							if peer != nb and SudokuBoard.PEERS[nb].has(peer) and board.get_cell(peer) == 0 and board.has_candidate(peer, z):
								elims[peer] = [z]
						if not elims.is_empty():
							var chain: Array[int] = []
							var k: int = nkey
							while k != -1:
								chain.push_front(k / 10)
								k = parent[k]
							var step := SolveStep.new()
							step.technique = "XY-Chain"
							step.category = "Advanced"
							step.difficulty_weight = 12
							step.cells = chain
							step.eliminations = elims
							step.set_text("EXPL_XY_CHAIN", [{"cell": start}, {"cell": nb}, z, z])
							return step
					queue.append(nkey)
	return null
