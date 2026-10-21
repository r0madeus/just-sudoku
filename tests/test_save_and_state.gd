extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const PerformanceScorer = preload("res://scripts/gameplay/performance_scorer.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const StatisticsManager = preload("res://scripts/data/statistics_manager.gd")

func _init() -> void:
	print("\n=== STARTING GAMEPLAY & DATA LAYER TESTS ===")
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

	# --- Test 1: GameState Initialization & Cell Editing ---
	run_test.call("GameState init and given cell protection", func() -> bool:
		var gen := SudokuGenerator.generate(11223344, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)

		# Find a given cell
		var given_idx: int = -1
		var empty_idx: int = -1
		for i in range(81):
			if state.initial_puzzle.is_given(i) and given_idx == -1:
				given_idx = i
			elif not state.initial_puzzle.is_given(i) and empty_idx == -1:
				empty_idx = i

		# Try to edit given cell (must fail)
		if state.set_number(given_idx, 9):
			printerr("Given cell should not be editable")
			return false

		# Edit empty cell (must succeed)
		if not state.set_number(empty_idx, 4):
			printerr("Empty cell should be editable")
			return false
		if state.current_board.get_cell(empty_idx) != 4:
			return false
		return true
	)

	# --- Test 2: Undo / Redo & Auto-remove Notes ---
	run_test.call("Unlimited Undo/Redo with auto-remove candidate restoration", func() -> bool:
		var gen := SudokuGenerator.generate(55667788, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)

		var empty_cell_1: int = -1
		var empty_cell_2: int = -1
		for idx in range(81):
			if not state.initial_puzzle.is_given(idx):
				if empty_cell_1 == -1:
					empty_cell_1 = idx
				elif empty_cell_2 == -1 and SudokuBoard.PEERS[empty_cell_1].has(idx):
					empty_cell_2 = idx
					break

		if empty_cell_2 == -1:
			printerr("Couldn't find two empty peers")
			return false

		# Add note 7 to empty_cell_2
		state.toggle_candidate(empty_cell_2, 7)
		if not state.current_board.has_candidate(empty_cell_2, 7):
			return false

		# Place 7 in empty_cell_1 (with auto_remove_notes = true)
		state.set_number(empty_cell_1, 7, true)
		if state.current_board.has_candidate(empty_cell_2, 7):
			printerr("Candidate 7 should be auto-removed from peer cell")
			return false

		# Undo: placing 7 should be undone, and candidate 7 restored in empty_cell_2!
		state.undo()
		if state.current_board.get_cell(empty_cell_1) != 0:
			printerr("Cell 1 was not reverted to 0")
			return false
		if not state.current_board.has_candidate(empty_cell_2, 7):
			printerr("Candidate 7 in cell 2 was not restored by undo!")
			return false

		# Redo: placing 7 re-applied and note removed again
		state.redo()
		if state.current_board.get_cell(empty_cell_1) != 7 or state.current_board.has_candidate(empty_cell_2, 7):
			printerr("Redo failed")
			return false

		return true
	)

	# --- Test 3: Performance Score Calculation ---
	run_test.call("PerformanceScorer logic", func() -> bool:
		var perfect_score := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_HARD, 500.0, 600, 0, 0, 2)
		if perfect_score < 85:
			printerr("Perfect score too low: %d" % perfect_score)
			return false

		var penalized_score := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_HARD, 1200.0, 600, 3, 2, 10)
		if penalized_score >= perfect_score:
			printerr("Penalized score should be strictly lower than perfect score")
			return false

		print("    Perfect Hard Score: %d | Penalized Score: %d" % [perfect_score, penalized_score])
		return true
	)

	# --- Test 4: Save & Crash Recovery ---
	run_test.call("SaveManager safe write and crash recovery fallback", func() -> bool:
		var gen := SudokuGenerator.generate(99001122, DifficultyAnalyzer.LEVEL_MEDIUM)
		var state := GameState.new()
		state.init_from_puzzle(gen)

		# Save 1
		SaveManager.save_active_game(state)
		# Modify state and Save 2 (pushes Save 1 to bak1)
		for i in range(81):
			if not state.initial_puzzle.is_given(i):
				state.set_number(i, 5)
				break
		SaveManager.save_active_game(state)

		# Verify normal load
		var loaded := SaveManager.load_active_game()
		if loaded == null or loaded.seed_value != 99001122:
			printerr("Failed to load active game")
			return false

		# Simulate crash: corrupt active_game.json
		var file := FileAccess.open(SaveManager.ACTIVE_GAME_FILE, FileAccess.WRITE)
		file.store_string("{corrupted_json_syntax...")
		file.close()

		# Load again: should smoothly recover from bak1!
		var recovered := SaveManager.load_active_game()
		if recovered == null:
			printerr("Crash recovery failed to restore from backup!")
			return false
		print("    Crash recovery successfully restored backup with seed: %d" % recovered.seed_value)
		return true
	)

	# --- Test 5: Daily Sudoku Seed & Streak ---
	run_test.call("DailyManager determinism and streak tracking", func() -> bool:
		var seed1 := DailyManager.get_seed_for_date(2026, 10, 3)
		var seed2 := DailyManager.get_seed_for_date(2026, 10, 3)
		var seed_other := DailyManager.get_seed_for_date(2026, 10, 4)

		if seed1 != seed2 or seed1 == seed_other:
			printerr("Daily seeds mismatch")
			return false

		DailyManager.mark_date_completed(2026, 10, 2)
		DailyManager.mark_date_completed(2026, 10, 3)
		var streak := DailyManager.get_current_streak()
		if streak < 2:
			printerr("Daily streak should be at least 2, got %d" % streak)
			return false

		print("    Current Daily Streak: %d" % streak)
		return true
	)

	# --- Test 6: History & Statistics Aggregation ---
	run_test.call("History and Statistics calculations", func() -> bool:
		HistoryManager.add_record({
			"game_id": "test_game_1",
			"seed": 12345,
			"difficulty": DifficultyAnalyzer.LEVEL_EASY,
			"score": 92,
			"time": 240.0,
			"mistakes": 0,
			"hints": 0
		})

		var summary := StatisticsManager.get_summary_statistics()
		if summary["completed_games"] < 1 or summary["best_score"] < 90:
			printerr("Statistics summary invalid")
			return false

		print("    Stats: Completed: %d, Best Score: %d, Avg Time: %.1fs" % [
			summary["completed_games"], summary["best_score"], summary["average_time"]
		])
		return true
	)

	print("\n=== TEST RESULTS: %d/%d PASSED ===" % [stats.passed, stats.total])
	if stats.passed == stats.total:
		print(">>> ALL GAMEPLAY & DATA LAYER TESTS PASSED SUCCESSFULLY! <<<\n")
		quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		quit(1)
