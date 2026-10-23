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
const MAX_ATTEMPTS: int = 14
## Upper bound for parallel attempt threads
const MAX_WORKERS: int = 6
## Cap on extra clues removed after attempts that came out easier than requested
const MAX_CLUE_BIAS: int = 3
## Max remove/add-back nudges per attempt when steering toward the requested level
const STEER_ITERATIONS: int = 60
## Removal candidates compared per steering step
const STEER_CANDIDATES: int = 4
## Board meta flag set by the carve when the puzzle cannot lose another clue
const META_MINIMAL: String = "carve_minimal"
const LEVEL_ORDER: Array[String] = [
	DifficultyAnalyzer.LEVEL_EASY,
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]

## Medium, Hard and Expert come from a bank of puzzles generated and rated ahead of time
## (tools/build_puzzle_bank.gd), each shown in a disguise drawn from the seed (_disguise). Live
## generation of these levels takes seconds on a desktop and longer on a phone, and at Expert it
## must reject most candidates; a bank puzzle is ready at once and already known to be at its
## level and solvable without guessing. Easy is quick to generate and stays live.
const BANK_LEVELS: Array[String] = [
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]
const BANK_DIR: String = "res://assets/puzzles/"
## Keeps bank picks independent of the live generator's use of the same seed
const BANK_SALT: int = 0x5EED_BA4C
## Disguises tried before falling back to live generation (the rating very rarely changes)
const BANK_TRIES: int = 4
static var _banks: Dictionary = {}
static var _bank_lock := Mutex.new()

## One independent generation attempt; attempts only depend on (seed, attempt index), which is
## what lets them run in parallel and still reproduce the sequential result exactly.
class AttemptResult extends RefCounted:
	var puzzle: GeneratedPuzzle = null
	var distance: int = 1 << 30
	var cancelled: bool = false

class StopFlag extends RefCounted:
	var stopped: bool = false

## Worker threads used when a caller asks for parallel attempts but gives no explicit count
static func default_worker_count() -> int:
	return clampi(OS.get_processor_count() - 1, 1, MAX_WORKERS)

## Generates a puzzle deterministically for the given seed and difficulty: from the bank for
## the levels it holds, live otherwise (see generate_live).
## Attempt k draws its own RNG stream from (seed, k). A puzzle is only accepted when the
## analyzer rates it at the requested level; if no attempt matches, the attempt closest to the
## target is returned with its true score. With workers > 1 the attempts run in batches on
## the worker thread pool; the result is identical to workers = 1, only faster.
static func generate(
	seed_val: int,
	target_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM,
	is_cancelled_callback: Callable = Callable(),
	workers: int = 1
) -> GeneratedPuzzle:
	if BANK_LEVELS.has(target_difficulty):
		if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
			return null
		var banked := _from_bank(seed_val, target_difficulty)
		if banked != null:
			return banked
	return generate_live(seed_val, target_difficulty, is_cancelled_callback, workers)

## The generator itself: carving and steering until the analyzer rates the puzzle at the level.
## Builds the puzzle bank, and serves Easy and any level whose bank is missing.
static func generate_live(
	seed_val: int,
	target_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM,
	is_cancelled_callback: Callable = Callable(),
	workers: int = 1
) -> GeneratedPuzzle:
	var best: GeneratedPuzzle = null
	var best_distance: int = 1 << 30
	workers = clampi(workers, 1, MAX_WORKERS)
	if workers > 1:
		# Shared lazy tables must exist before threads start touching them
		SudokuValidator.SolutionCounter.warm_up()

	if workers == 1:
		for attempt in range(MAX_ATTEMPTS):
			var single := AttemptResult.new()
			_run_attempt(single, seed_val, attempt, target_difficulty, is_cancelled_callback)
			if single.cancelled:
				return null
			if single.puzzle != null and single.distance < best_distance:
				best_distance = single.distance
				best = single.puzzle
			if single.distance == 0:
				return best
		return best

	# Rolling window: keep `workers` attempts in flight, but fold results strictly in attempt
	# order, so the outcome never depends on which thread finishes first. Once the earliest
	# success is folded, the still-running later attempts are told to stop.
	var stop := StopFlag.new()
	var guarded_cancel := func() -> bool:
		return stop.stopped or (is_cancelled_callback.is_valid() and is_cancelled_callback.call())
	var results: Array[AttemptResult] = []
	var task_ids: Array[int] = []
	var next_launch: int = 0
	var cancelled: bool = false
	var waited: int = -1

	for fold in range(MAX_ATTEMPTS):
		while next_launch < MAX_ATTEMPTS and next_launch < fold + workers:
			var res := AttemptResult.new()
			var idx: int = next_launch
			results.append(res)
			task_ids.append(WorkerThreadPool.add_task(func() -> void:
				_run_attempt(res, seed_val, idx, target_difficulty, guarded_cancel)
			))
			next_launch += 1

		WorkerThreadPool.wait_for_task_completion(task_ids[fold])
		waited = fold
		var done: AttemptResult = results[fold]
		if done.cancelled:
			cancelled = true
			break
		if done.puzzle != null and done.distance < best_distance:
			best_distance = done.distance
			best = done.puzzle
		if done.distance == 0:
			break

	stop.stopped = true
	for i in range(waited + 1, task_ids.size()):
		WorkerThreadPool.wait_for_task_completion(task_ids[i])
	return null if cancelled else best

static func _run_attempt(
	out: AttemptResult,
	seed_val: int,
	attempt: int,
	target_difficulty: String,
	is_cancelled_callback: Callable
) -> void:
	if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
		out.cancelled = true
		return

	var rng := DeterministicRNG.new(_attempt_seed(seed_val, attempt))
	var full_board := _generate_full_board(rng)
	if full_board == null:
		return

	# Later attempts remove extra clues up front; steering handles the other direction
	var clue_bias: int = mini(attempt / 2, MAX_CLUE_BIAS)
	var puzzle := _carve_clues(full_board, target_difficulty, rng, is_cancelled_callback, clue_bias)
	if puzzle == null:
		out.cancelled = true
		return

	var analysis: DifficultyAnalyzer.AnalysisResult = _steer_to_level(
		puzzle, full_board, target_difficulty, rng, is_cancelled_callback)
	if analysis == null:
		out.cancelled = true
		return

	var gen := GeneratedPuzzle.new()
	gen.puzzle = puzzle
	gen.solution = full_board
	gen.seed_value = seed_val
	gen.difficulty = target_difficulty
	gen.difficulty_score = analysis.difficulty_score
	gen.estimated_seconds = analysis.estimated_seconds
	gen.top_techniques = analysis.top_techniques
	out.puzzle = gen
	out.distance = absi(_level_index(analysis) - LEVEL_ORDER.find(target_difficulty))

## A playable puzzle from an 81-character grid ("." or "0" for empty): rated, solved and
## carrying `seed_val`. Null when the grid has no solution. Uniqueness is the caller's to check.
static func from_grid(flat: String, seed_val: int) -> GeneratedPuzzle:
	var board := SudokuBoard.new()
	board.from_string_flat(flat, true)
	var solution := SudokuSolver.solve_fast(board)
	if solution == null:
		return null
	var analysis := DifficultyAnalyzer.analyze(board)
	var gen := GeneratedPuzzle.new()
	gen.puzzle = board
	gen.solution = solution
	gen.seed_value = seed_val
	gen.difficulty = analysis.level
	gen.difficulty_score = analysis.difficulty_score
	gen.estimated_seconds = analysis.estimated_seconds
	gen.top_techniques = analysis.top_techniques
	return gen

## The bank's puzzles for a level, read once (generation runs on worker threads, hence the lock)
static func bank(level: String) -> PackedStringArray:
	_bank_lock.lock()
	if not _banks.has(level):
		var list := PackedStringArray()
		var text := FileAccess.get_file_as_string(BANK_DIR + level.to_lower() + ".txt")
		for line in text.split("\n", false):
			line = line.strip_edges()
			if line.length() == SudokuBoard.CELL_COUNT:
				list.append(line)
		_banks[level] = list
	var out: PackedStringArray = _banks[level]
	_bank_lock.unlock()
	return out

## A bank puzzle for the seed, disguised, checked and solved; null when the bank is empty or no
## disguise kept the level
static func _from_bank(seed_val: int, level: String) -> GeneratedPuzzle:
	var puzzles := bank(level)
	if puzzles.is_empty():
		return null
	var rng := DeterministicRNG.new(_attempt_seed(seed_val ^ BANK_SALT, 0))
	for _try in range(BANK_TRIES):
		var flat := _disguise(puzzles[rng.next_range(0, puzzles.size() - 1)], rng)
		var puzzle := SudokuBoard.new()
		puzzle.from_string_flat(flat, true)
		var analysis := _analyze(puzzle)
		if not analysis.solved_logically or analysis.level != level:
			continue
		var solution := SudokuSolver.solve_fast(puzzle)
		if solution == null:
			continue
		var gen := GeneratedPuzzle.new()
		gen.puzzle = puzzle
		gen.solution = solution
		gen.seed_value = seed_val
		gen.difficulty = level
		gen.difficulty_score = analysis.difficulty_score
		gen.estimated_seconds = analysis.estimated_seconds
		gen.top_techniques = analysis.top_techniques
		return gen
	return null

## The same puzzle in another guise: digits relabelled, the bands, stacks and the rows and
## columns inside them shuffled, and maybe mirrored on the diagonal. Every deduction carries over
## unchanged, so the solution stays unique and the difficulty the same, while the grid looks new.
static func _disguise(flat: String, rng: DeterministicRNG) -> String:
	var digits: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	rng.shuffle_array(digits)
	var rows := _line_order(rng)
	var cols := _line_order(rng)
	var mirror: bool = rng.next_range(0, 1) == 1
	var out := PackedStringArray()
	out.resize(SudokuBoard.CELL_COUNT)
	for r in range(9):
		for c in range(9):
			var src: int = cols[c] * 9 + rows[r] if mirror else rows[r] * 9 + cols[c]
			var ch: String = flat[src]
			out[r * 9 + c] = str(digits[ch.to_int() - 1]) if ch >= "1" and ch <= "9" else "."
	return "".join(out)

## A shuffled order of the 9 rows (or columns): the three bands in some order, and the three
## lines inside each band in some order, which is what keeps every box a box
static func _line_order(rng: DeterministicRNG) -> Array[int]:
	var bands: Array = [0, 1, 2]
	rng.shuffle_array(bands)
	var order: Array[int] = []
	for b in bands:
		var inner: Array = [0, 1, 2]
		rng.shuffle_array(inner)
		for i in inner:
			order.append(int(b) * 3 + int(i))
	return order

static func _attempt_seed(seed_val: int, attempt: int) -> int:
	# Golden-ratio stride spreads consecutive attempts across the RNG state space
	return (seed_val + attempt * 0x1E3779B97F4A7C15) & 0x7FFFFFFFFFFFFFFF

static func _analyze(puzzle: SudokuBoard) -> DifficultyAnalyzer.AnalysisResult:
	for idx in range(SudokuBoard.CELL_COUNT):
		puzzle.givens[idx] = (puzzle.get_cell(idx) != 0)
	puzzle.reset_candidates_from_grid()
	return DifficultyAnalyzer.analyze(puzzle)

## Nudges a carved puzzle (in place) until the analyzer rates it at the target level:
## too easy -> remove one more clue that keeps the solution unique,
## too hard -> give a removed clue back. Returns the final analysis, or null if cancelled.
static func _steer_to_level(
	puzzle: SudokuBoard,
	solution: SudokuBoard,
	target_difficulty: String,
	rng: DeterministicRNG,
	is_cancelled_callback: Callable
) -> DifficultyAnalyzer.AnalysisResult:
	var target_idx: int = LEVEL_ORDER.find(target_difficulty)
	var analysis := _analyze(puzzle)

	for _step in range(STEER_ITERATIONS):
		if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
			return null
		var delta: int = _level_index(analysis) - target_idx
		if delta == 0:
			break

		var filled: Array[int] = []
		var empty: Array[int] = []
		for idx in range(SudokuBoard.CELL_COUNT):
			if puzzle.get_cell(idx) != 0:
				filled.append(idx)
			else:
				empty.append(idx)

		if delta < 0:
			if puzzle.get_meta(META_MINIMAL, false):
				break
			# Too easy: try a few unique-preserving removals and keep the one that makes the
			# puzzle hardest without overshooting the target level
			rng.shuffle_array(filled)
			var best_idx: int = -1
			var best_analysis: DifficultyAnalyzer.AnalysisResult = null
			var tried: int = 0
			for idx in filled:
				var saved: int = puzzle.get_cell(idx)
				puzzle.set_cell(idx, 0, false)
				if SudokuValidator.has_unique_solution(puzzle):
					var cand := _analyze(puzzle)
					if _is_harder_candidate(cand, best_analysis, target_idx):
						best_idx = idx
						best_analysis = cand
					tried += 1
				puzzle.set_cell(idx, saved, false)
				if tried >= STEER_CANDIDATES:
					break
				if best_analysis != null and _level_index(best_analysis) == target_idx:
					break
			if best_idx == -1:
				break
			puzzle.set_cell(best_idx, 0, false)
			analysis = best_analysis
			continue
		else:
			# Too hard: give back the clue that lands on the target, else the one that stays
			# closest above it (adding a clue never breaks uniqueness, so no solver check)
			if empty.is_empty():
				break
			rng.shuffle_array(empty)
			var give_idx: int = -1
			var give_analysis: DifficultyAnalyzer.AnalysisResult = null
			var checked: int = 0
			for idx in empty:
				puzzle.set_cell(idx, solution.get_cell(idx), false)
				var cand := _analyze(puzzle)
				puzzle.set_cell(idx, 0, false)
				if _is_closer_from_above(cand, give_analysis, target_idx):
					give_idx = idx
					give_analysis = cand
				checked += 1
				if checked >= STEER_CANDIDATES or _level_index(give_analysis) == target_idx:
					break
			puzzle.set_cell(give_idx, solution.get_cell(give_idx), false)
			puzzle.set_meta(META_MINIMAL, false)
			analysis = give_analysis
			continue

		analysis = _analyze(puzzle)

	return analysis

## Candidate ranking while climbing: landing on the target beats everything, then staying below
## it with more total technique weight, and overshooting is the last resort (lowest overshoot first)
static func _is_harder_candidate(
	cand: DifficultyAnalyzer.AnalysisResult,
	best: DifficultyAnalyzer.AnalysisResult,
	target_idx: int
) -> bool:
	if best == null:
		return true
	var cl: int = _level_index(cand)
	var bl: int = _level_index(best)
	if cl == target_idx or bl == target_idx:
		return cl == target_idx and bl != target_idx
	if (cl < target_idx) != (bl < target_idx):
		return cl < target_idx
	if cl < target_idx:
		return _total_weight(cand) > _total_weight(best)
	return cl < bl

## While adding clues back: hitting the target wins, otherwise stay at the lowest level above it
## (overshooting below the target is the last resort)
static func _is_closer_from_above(
	cand: DifficultyAnalyzer.AnalysisResult,
	best: DifficultyAnalyzer.AnalysisResult,
	target_idx: int
) -> bool:
	if best == null:
		return true
	var cl: int = _level_index(cand)
	var bl: int = _level_index(best)
	if cl == target_idx or bl == target_idx:
		return cl == target_idx and bl != target_idx
	if (cl > target_idx) != (bl > target_idx):
		return cl > target_idx
	if cl > target_idx:
		return cl < bl
	return cl > bl

## Where a puzzle sits on LEVEL_ORDER. One the solver cannot finish with the techniques it knows
## counts as above Expert: it may need guessing, its real difficulty is unknown and a hint could
## only reveal a digit there, so every level, Expert included, is steered away from it.
static func _level_index(a: DifficultyAnalyzer.AnalysisResult) -> int:
	return LEVEL_ORDER.find(a.level) if a.solved_logically else LEVEL_ORDER.size()

static func _total_weight(a: DifficultyAnalyzer.AnalysisResult) -> int:
	var w: int = 0
	for st in a.steps:
		w += st.difficulty_weight
	return w

## Bitmask backtracking filler: scans cells in order and tries shuffled digits
class BoardFiller extends RefCounted:
	var cells: PackedInt32Array = PackedInt32Array()
	var row_used: PackedInt32Array = PackedInt32Array()
	var col_used: PackedInt32Array = PackedInt32Array()
	var box_used: PackedInt32Array = PackedInt32Array()
	var rng: DeterministicRNG

	func _init(p_rng: DeterministicRNG) -> void:
		rng = p_rng
		cells.resize(SudokuBoard.CELL_COUNT)
		row_used.resize(9)
		col_used.resize(9)
		box_used.resize(9)

	func place(idx: int, digit: int) -> void:
		var bit: int = 1 << (digit - 1)
		cells[idx] = digit
		row_used[SudokuBoard.CELL_ROW[idx]] |= bit
		col_used[SudokuBoard.CELL_COL[idx]] |= bit
		box_used[SudokuBoard.CELL_BOX[idx]] |= bit

	func fill(from_idx: int = 0) -> bool:
		var idx: int = from_idx
		while idx < SudokuBoard.CELL_COUNT and cells[idx] != 0:
			idx += 1
		if idx == SudokuBoard.CELL_COUNT:
			return true

		var r: int = SudokuBoard.CELL_ROW[idx]
		var c: int = SudokuBoard.CELL_COL[idx]
		var b: int = SudokuBoard.CELL_BOX[idx]
		var free: int = ~(row_used[r] | col_used[c] | box_used[b]) & 0x1FF
		var digits: Array[int] = []
		for d in range(1, 10):
			if free & (1 << (d - 1)) != 0:
				digits.append(d)
		rng.shuffle_array(digits)

		for d in digits:
			var bit: int = 1 << (d - 1)
			cells[idx] = d
			row_used[r] |= bit
			col_used[c] |= bit
			box_used[b] |= bit
			if fill(idx + 1):
				return true
			row_used[r] ^= bit
			col_used[c] ^= bit
			box_used[b] ^= bit
			cells[idx] = 0
		return false

static func _generate_full_board(rng: DeterministicRNG) -> SudokuBoard:
	var filler := BoardFiller.new(rng)

	# Fill 3 independent diagonal 3x3 boxes (boxes 0, 4, 8)
	var digits: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	for b in [0, 4, 8]:
		rng.shuffle_array(digits)
		var indices: Array = SudokuBoard.BOX_INDICES[b]
		for i in range(9):
			filler.place(indices[i], digits[i])

	if not filler.fill():
		return null

	var board := SudokuBoard.new()
	for idx in range(SudokuBoard.CELL_COUNT):
		board.set_cell(idx, filler.cells[idx], false)
	board.reset_candidates_from_grid()
	return board

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
			# Carve to (near) minimal, then give clues back: wing-level puzzles only appear there
			target_clues = rng.next_range(17, 20)
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

	# Every cell was tried and none can go: no further removal can keep the solution unique
	board.set_meta(META_MINIMAL, current_clues > target_clues)
	return board
