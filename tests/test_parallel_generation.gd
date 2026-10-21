extends SceneTree

## Parallel attempts must reproduce the sequential result exactly (same seed -> same puzzle),
## whatever the worker count, and a cancelled request must return null without hanging.

var passed: int = 0
var failed: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		printerr("  ✗ FAIL: ", msg)

func _init() -> void:
	print("--- PARALLEL GENERATION DETERMINISM ---")
	for level in [DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD, DifficultyAnalyzer.LEVEL_EXPERT]:
		for seed_val in [11, 222]:
			var seq := SudokuGenerator.generate(seed_val, level, Callable(), 1)
			var par2 := SudokuGenerator.generate(seed_val, level, Callable(), 2)
			var par6 := SudokuGenerator.generate(seed_val, level, Callable(), 6)
			var same: bool = seq.puzzle.values == par2.puzzle.values and seq.puzzle.values == par6.puzzle.values \
				and seq.difficulty_score == par6.difficulty_score and seq.solution.values == par6.solution.values
			_check(same, "%s seed %d: workers 1, 2 and 6 give the identical puzzle" % [level, seed_val])

	var cancelled := SudokuGenerator.generate(5, DifficultyAnalyzer.LEVEL_HARD, func() -> bool: return true, 4)
	_check(cancelled == null, "Cancelled parallel generation returns null")

	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
