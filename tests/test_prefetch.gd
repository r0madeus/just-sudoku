extends SceneTree

const PuzzlePrefetcher = preload("res://scripts/services/puzzle_prefetcher.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")

## PuzzlePrefetcher: fills a ready puzzle per difficulty (and today's Daily) in the background,
## hands them out instantly, refills the slot, and takes back unused previews.

var passed: int = 0
var failed: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		printerr("  ✗ FAIL: ", msg)

func _wait_until(cond: Callable, timeout_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return false
		await create_timer(0.05).timeout
	return true

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- PUZZLE PREFETCH ---")
	PuzzlePrefetcher.start(DifficultyAnalyzer.LEVEL_EASY)
	var easy_ready: bool = await _wait_until(func(): return PuzzlePrefetcher.is_ready(DifficultyAnalyzer.LEVEL_EASY), 15000)
	_check(easy_ready, "Priority difficulty (Easy) is prepared first")

	var t0 := Time.get_ticks_usec()
	var gen := PuzzlePrefetcher.take(DifficultyAnalyzer.LEVEL_EASY)
	var take_us := Time.get_ticks_usec() - t0
	_check(gen != null and gen.difficulty == DifficultyAnalyzer.LEVEL_EASY, "take() returns the prepared Easy puzzle")
	_check(take_us < 5000, "take() is instant (%d us)" % take_us)
	_check(gen != null and SudokuValidator.has_unique_solution(gen.puzzle), "Prepared puzzle has a unique solution")
	_check(not PuzzlePrefetcher.is_ready(DifficultyAnalyzer.LEVEL_EASY), "Slot is empty right after take()")

	PuzzlePrefetcher.put_back(gen)
	_check(PuzzlePrefetcher.is_ready(DifficultyAnalyzer.LEVEL_EASY), "put_back() returns an unused preview to the cache")
	var again := PuzzlePrefetcher.take(DifficultyAnalyzer.LEVEL_EASY)
	_check(again == gen, "The same puzzle comes back out")

	var refilled: bool = await _wait_until(func(): return PuzzlePrefetcher.is_ready(DifficultyAnalyzer.LEVEL_EASY), 15000)
	_check(refilled, "Slot is refilled in the background after take()")

	var medium_ready: bool = await _wait_until(func(): return PuzzlePrefetcher.is_ready(DifficultyAnalyzer.LEVEL_MEDIUM), 20000)
	_check(medium_ready, "Other difficulties are prepared too (Medium)")

	var wrong_seed := PuzzlePrefetcher.take_daily(1)
	_check(wrong_seed == null, "take_daily() with a different seed returns nothing")

	PuzzlePrefetcher.stop()
	await create_timer(0.3).timeout
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
