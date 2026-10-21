extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")

func _init() -> void:
	print("\n=== STARTING SUDOKU CORE TESTS ===")
	var stats: Dictionary = { "total": 0, "passed": 0 }

	var run_test = func(name: String, test_callable: Callable):
		stats.total += 1
		print("Running test [%d]: %s..." % [stats.total, name])
		var result = test_callable.call()
		if result:
			stats.passed += 1
			print("  -> PASSED")
		else:
			printerr("  -> FAILED: %s" % name)

	# --- Test 1: SudokuBoard Geometry & Peers ---
	run_test.call("SudokuBoard peers and indices", func() -> bool:
		var board := SudokuBoard.new()
		for i in range(81):
			if SudokuBoard.PEERS[i].size() != 20:
				printerr("Cell %d peers count is %d, expected 20" % [i, SudokuBoard.PEERS[i].size()])
				return false
		return true
	)

	# --- Test 2: SudokuBoard Candidates ---
	run_test.call("SudokuBoard candidates bitmask", func() -> bool:
		var board := SudokuBoard.new()
		board.add_candidate(0, 3)
		board.add_candidate(0, 7)
		if not board.has_candidate(0, 3) or not board.has_candidate(0, 7) or board.has_candidate(0, 5):
			return false
		if board.get_candidate_count(0) != 2:
			return false
		var removed := board.remove_candidate(0, 3)
		if not removed or board.has_candidate(0, 3) or board.get_candidate_count(0) != 1:
			return false
		return true
	)

	# --- Test 3: Conflict Detection ---
	run_test.call("SudokuValidator conflict detection", func() -> bool:
		var board := SudokuBoard.new()
		board.set_cell(0, 5) # R1C1
		board.set_cell(4, 5) # R1C5 (Row conflict)
		var conflicts := SudokuValidator.get_conflicts(board)
		if not conflicts.has(0) or not conflicts.has(4):
			return false
		return true
	)

	# --- Test 4: Known Puzzle Solving & Validation ---
	run_test.call("SudokuValidator and Solver on known puzzle", func() -> bool:
		# Classic easy puzzle
		var puzzle_str: String = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
		var board := SudokuBoard.new()
		board.from_string_flat(puzzle_str)
		if not SudokuValidator.has_unique_solution(board):
			printerr("Puzzle should have unique solution")
			return false

		var solved := SudokuSolver.solve_fast(board)
		if solved == null or not SudokuValidator.is_board_complete_and_valid(solved):
			printerr("Fast solver failed on known puzzle")
			return false
		return true
	)

	# --- Test 5: Logical Solver Deductions ---
	run_test.call("SudokuSolver logical step-by-step", func() -> bool:
		var puzzle_str: String = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
		var board := SudokuBoard.new()
		board.from_string_flat(puzzle_str)
		var next_step := SudokuSolver.find_next_step(board)
		if next_step == null:
			printerr("Logical solver couldn't find a first step")
			return false
		print("    First step found: %s" % str(next_step))
		return true
	)

	# --- Test 6: Deterministic Generator & Seed Consistency ---
	run_test.call("SudokuGenerator determinism (Same Seed = Same Puzzle)", func() -> bool:
		var test_seed: int = 8472915632
		var p1 := SudokuGenerator.generate(test_seed, DifficultyAnalyzer.LEVEL_EASY)
		var p2 := SudokuGenerator.generate(test_seed, DifficultyAnalyzer.LEVEL_EASY)

		var p1_str := p1.puzzle.to_string_flat()
		var p2_str := p2.puzzle.to_string_flat()

		if p1_str != p2_str:
			printerr("Puzzles generated with same seed do not match!\nP1: %s\nP2: %s" % [p1_str, p2_str])
			return false

		if not SudokuValidator.has_unique_solution(p1.puzzle):
			printerr("Generated puzzle does not have a unique solution!")
			return false

		print("    Generated puzzle: %s" % p1_str)
		print("    Difficulty: %s (Score: %d) Top Techs: %s" % [p1.difficulty, p1.difficulty_score, str(p1.top_techniques)])
		return true
	)

	# --- Test 7: Medium / Hard Difficulty Generation ---
	run_test.call("SudokuGenerator Medium difficulty", func() -> bool:
		var test_seed: int = 9988776655
		var p := SudokuGenerator.generate(test_seed, DifficultyAnalyzer.LEVEL_MEDIUM)
		if not SudokuValidator.has_unique_solution(p.puzzle):
			printerr("Medium puzzle must have a unique solution")
			return false
		var clues: int = SudokuBoard.CELL_COUNT - p.puzzle.get_empty_cell_count()
		print("    Medium clues: %d, Score: %d" % [clues, p.difficulty_score])
		return clues <= 36
	)

	print("\n=== TEST RESULTS: %d/%d PASSED ===" % [stats.passed, stats.total])
	if stats.passed == stats.total:
		print(">>> ALL SUDOKU CORE TESTS PASSED SUCCESSFULLY! <<<\n")
		quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		quit(1)
