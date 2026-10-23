class_name SudokuSolver
extends RefCounted

const HintFinder = preload("res://scripts/core/hint_finder.gd")

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

## Finds the best human-logic next step for an active game board (see HintFinder).
static func find_best_hint(board: SudokuBoard, focus_cell: int = -1, solution: SudokuBoard = null) -> SolveStep:
	return HintFinder.find_best_hint(board, focus_cell, solution)


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
	return HintFinder._pick_best_single_step(steps, board, focus_cell)

## Finds the next logical human deduction step
static func find_next_step(board: SudokuBoard) -> SolveStep:
	var step: SolveStep = null

	# 1. Basic: Naked Single
	step = BasicTechniques._find_naked_single(board)
	if step != null: return step

	# 2. Basic: Hidden Single
	step = BasicTechniques._find_hidden_single(board)
	if step != null: return step

	# 3. Medium: Locked Candidates (Pointing & Claiming)
	step = BasicTechniques._find_locked_candidates(board)
	if step != null: return step

	# 4. Medium: Naked Pair
	step = BasicTechniques._find_naked_pairs(board)
	if step != null: return step

	# 5. Medium: Hidden Pair
	step = BasicTechniques._find_hidden_pairs(board)
	if step != null: return step

	# 6. Medium: Naked Triple
	step = BasicTechniques._find_naked_triples(board)
	if step != null: return step

	# 7. Medium: Hidden Triple
	step = BasicTechniques._find_hidden_triples(board)
	if step != null: return step

	# 8. Advanced: X-Wing
	step = FishTechniques._find_x_wing(board)
	if step != null: return step

	# 9. Advanced: XY-Wing
	step = ChainTechniques._find_xy_wing(board)
	if step != null: return step

	# 10. Advanced: XYZ-Wing
	step = ChainTechniques._find_xyz_wing(board)
	if step != null: return step

	# 11. Advanced: Swordfish
	step = FishTechniques._find_swordfish(board)
	if step != null: return step

	# 12. Advanced: Simple Coloring (chains of one digit)
	step = ChainTechniques._find_simple_coloring(board)
	if step != null: return step

	# 13. Advanced: XY-Chain (chains of two-candidate cells)
	step = ChainTechniques._find_xy_chain(board)
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

# --- Technique finders (implemented in scripts/core/techniques/) ---

const BasicTechniques = preload("res://scripts/core/techniques/basic_techniques.gd")
const FishTechniques = preload("res://scripts/core/techniques/fish_techniques.gd")
const ChainTechniques = preload("res://scripts/core/techniques/chain_techniques.gd")

const XY_CHAIN_MAX_CELLS: int = ChainTechniques.XY_CHAIN_MAX_CELLS

static func _find_naked_single(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_naked_single(board)

static func _find_hidden_single(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_hidden_single(board)

static func _find_locked_candidates(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_locked_candidates(board)

static func _find_naked_pairs(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_naked_pairs(board)

static func _find_hidden_pairs(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_hidden_pairs(board)

static func _find_naked_triples(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_naked_triples(board)

static func _find_hidden_triples(board: SudokuBoard) -> SolveStep:
	return BasicTechniques._find_hidden_triples(board)

static func _find_x_wing(board: SudokuBoard) -> SolveStep:
	return FishTechniques._find_x_wing(board)

static func _find_swordfish(board: SudokuBoard) -> SolveStep:
	return FishTechniques._find_swordfish(board)

static func _find_xy_wing(board: SudokuBoard) -> SolveStep:
	return ChainTechniques._find_xy_wing(board)

static func _find_xyz_wing(board: SudokuBoard) -> SolveStep:
	return ChainTechniques._find_xyz_wing(board)

static func _find_simple_coloring(board: SudokuBoard) -> SolveStep:
	return ChainTechniques._find_simple_coloring(board)

static func _find_xy_chain(board: SudokuBoard) -> SolveStep:
	return ChainTechniques._find_xy_chain(board)

static func _swordfish_for(board: SudokuBoard, d: int, by_rows: bool) -> SolveStep:
	return FishTechniques._swordfish_for(board, d, by_rows)

static func _coloring_step(d: int, chain: Array[int], elims: Dictionary, key: String) -> SolveStep:
	return ChainTechniques._coloring_step(d, chain, elims, key)
