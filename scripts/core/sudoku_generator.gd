class_name SudokuGenerator
extends RefCounted

## Deterministic runtime Sudoku generator
## Guarantees: Same Seed + Same Difficulty = Exact Same Unique Puzzle

class DeterministicRNG extends RefCounted:
	var state: int

	func _init(p_seed: int = 0) -> void:
		set_seed(p_seed)

	func set_seed(p_seed: int) -> void:
		if p_seed == 0:
			p_seed = 123456789
		state = p_seed & 0x7FFFFFFFFFFFFFFF

	func next_int() -> int:
		# Knuth MMIX 63-bit positive LCG multiplier
		state = (state * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF
		return state

	func next_range(from_val: int, to_val: int) -> int:
		if to_val <= from_val:
			return from_val
		var range_size: int = to_val - from_val + 1
		# Use the high bits: the low bits of a power-of-two LCG have very short periods
		return from_val + int((next_int() >> 16) % range_size)

	func shuffle_array(arr: Array) -> void:
		for i in range(arr.size() - 1, 0, -1):
			var j: int = next_range(0, i)
			var tmp = arr[i]
			arr[i] = arr[j]
			arr[j] = tmp

class GeneratedPuzzle extends RefCounted:
	var puzzle: SudokuBoard
	var solution: SudokuBoard
	var seed_value: int
	var difficulty: String
	var difficulty_score: int
	var estimated_seconds: int
	var top_techniques: Array[String]

	func _to_string() -> String:
		return "Puzzle [Seed: %d | %s (Score %d) | Givens: %d]" % [
			seed_value, difficulty, difficulty_score, SudokuBoard.CELL_COUNT - puzzle.get_empty_cell_count()
		]

static func generate_new_seed() -> int:
	var sys_time: int = Time.get_ticks_usec()
	var unix_time: int = int(Time.get_unix_time_from_system() * 1000.0)
	return abs((sys_time ^ (unix_time << 16)) & 0x7FFFFFFFFFFFFFFF)

## Max carve attempts per request before settling for the closest level found
const MAX_ATTEMPTS: int = 6
## Cap on extra clues removed after attempts that came out easier than requested
const MAX_CLUE_BIAS: int = 3
const LEVEL_ORDER: Array[String] = [
	DifficultyAnalyzer.LEVEL_EASY,
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]

## Generates a puzzle deterministically for the given seed and difficulty.
## Each attempt draws a fresh board from the same RNG stream, and a puzzle is only
## accepted when the analyzer rates it at the requested level. If no attempt
## matches, the attempt closest to the target is returned with its true score.
static func generate(
	seed_val: int,
	target_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM,
	is_cancelled_callback: Callable = Callable()
) -> GeneratedPuzzle:
	var rng := DeterministicRNG.new(seed_val)
	var best: GeneratedPuzzle = null
	var best_distance: int = 1 << 30
	var clue_bias: int = 0

	for attempt in range(MAX_ATTEMPTS):
		if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
			return null

		var full_board := _generate_full_board(rng)
		if full_board == null:
			continue

		var puzzle := _carve_clues(full_board, target_difficulty, rng, is_cancelled_callback, clue_bias)
		if puzzle == null:
			return null

		for idx in range(SudokuBoard.CELL_COUNT):
			puzzle.givens[idx] = (puzzle.get_cell(idx) != 0)
		puzzle.reset_candidates_from_grid()

		var analysis: DifficultyAnalyzer.AnalysisResult = DifficultyAnalyzer.analyze(puzzle)
		var distance: int = absi(LEVEL_ORDER.find(analysis.level) - LEVEL_ORDER.find(target_difficulty))
		if distance < best_distance:
			best_distance = distance
			best = GeneratedPuzzle.new()
			best.puzzle = puzzle
			best.solution = full_board
			best.seed_value = seed_val
			best.difficulty = target_difficulty
			best.difficulty_score = analysis.difficulty_score
			best.estimated_seconds = analysis.estimated_seconds
			best.top_techniques = analysis.top_techniques
		if distance == 0:
			break
		# Too easy: remove more clues on the next attempt
		if LEVEL_ORDER.find(analysis.level) < LEVEL_ORDER.find(target_difficulty):
			clue_bias = mini(clue_bias + 1, MAX_CLUE_BIAS)

	return best

static func _generate_full_board(rng: DeterministicRNG) -> SudokuBoard:
	var board := SudokuBoard.new()

	# Fill 3 independent diagonal 3x3 boxes (boxes 0, 4, 8)
	var digits: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	for b in [0, 4, 8]:
		rng.shuffle_array(digits)
		var indices: Array = SudokuBoard.BOX_INDICES[b]
		for i in range(9):
			board.set_cell(indices[i], digits[i], false)

	board.reset_candidates_from_grid()
	if _fill_remaining(board, rng):
		return board
	return null

static func _fill_remaining(board: SudokuBoard, rng: DeterministicRNG) -> bool:
	var empty_idx: int = -1
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			empty_idx = idx
			break

	if empty_idx == -1:
		return true

	var candidates: Array[int] = board.get_candidates(empty_idx)
	if candidates.is_empty():
		return false

	rng.shuffle_array(candidates)

	for num in candidates:
		var saved_candidates: PackedInt32Array = board.candidates.duplicate()
		board.set_cell(empty_idx, num, false)
		board.reset_candidates_from_grid()

		if _fill_remaining(board, rng):
			return true

		board.set_cell(empty_idx, 0, false)
		board.candidates = saved_candidates

	return false

static func _carve_clues(
	full_board: SudokuBoard,
	target_difficulty: String,
	rng: DeterministicRNG,
	is_cancelled_callback: Callable = Callable(),
	clue_bias: int = 0
) -> SudokuBoard:
	var board := full_board.clone()

	# Target number of clues by difficulty
	var target_clues: int = 38 # Easy
	match target_difficulty:
		DifficultyAnalyzer.LEVEL_EASY:
			target_clues = rng.next_range(36, 40)
		DifficultyAnalyzer.LEVEL_MEDIUM:
			target_clues = rng.next_range(30, 34)
		DifficultyAnalyzer.LEVEL_HARD:
			target_clues = rng.next_range(27, 30)
		DifficultyAnalyzer.LEVEL_EXPERT:
			target_clues = rng.next_range(24, 27)

	target_clues -= clue_bias

	var cell_indices: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		cell_indices.append(idx)
	rng.shuffle_array(cell_indices)

	var current_clues: int = SudokuBoard.CELL_COUNT

	for idx in cell_indices:
		if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
			return null
		if current_clues <= target_clues:
			break

		var saved_val: int = board.get_cell(idx)
		board.set_cell(idx, 0, false)

		if SudokuValidator.has_unique_solution(board):
			current_clues -= 1
		else:
			# Not unique, revert
			board.set_cell(idx, saved_val, false)

	return board
