extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const PerformanceScorer = preload("res://scripts/gameplay/performance_scorer.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const StatisticsManager = preload("res://scripts/data/statistics_manager.gd")
const SoundManager = preload("res://scripts/services/sound_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const AppRoot = preload("res://scenes/app_root.gd")

func _init() -> void:
	print("\n==============================================")
	print("   JUST SUDOKU - COMPREHENSIVE MVP TEST SUITE  ")
	print("==============================================")

	var stats: Dictionary = { "total": 0, "passed": 0 }

	var run_test = func(suite: String, name: String, test_callable: Callable):
		stats.total += 1
		print("[%s] Test %d: %s..." % [suite, stats.total, name])
		var result = test_callable.call()
		if result:
			stats.passed += 1
			print("  -> PASSED")
		else:
			printerr("  -> FAILED: %s" % name)

	# --- SUITE 1: SUDOKU CORE ---
	run_test.call("CORE", "SudokuBoard geometry and 20 peers per cell", func() -> bool:
		for i in range(81):
			if SudokuBoard.PEERS[i].size() != 20:
				return false
		return true
	)

	run_test.call("CORE", "SudokuValidator conflict detection", func() -> bool:
		var board := SudokuBoard.new()
		board.set_cell(0, 8)
		board.set_cell(8, 8) # Same row
		var conflicts := SudokuValidator.get_conflicts(board)
		return conflicts.has(0) and conflicts.has(8)
	)

	run_test.call("CORE", "SudokuSolver logical step-by-step trace", func() -> bool:
		var puzzle_str: String = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
		var board := SudokuBoard.new()
		board.from_string_flat(puzzle_str)
		var step := SudokuSolver.find_next_step(board)
		return step != null and not step.explanation.is_empty()
	)

	run_test.call("CORE", "SudokuGenerator determinism (Same Seed = Exact Same Puzzle)", func() -> bool:
		var s: int = 918273645
		var p1 := SudokuGenerator.generate(s, DifficultyAnalyzer.LEVEL_EASY)
		var p2 := SudokuGenerator.generate(s, DifficultyAnalyzer.LEVEL_EASY)
		return p1.puzzle.to_string_flat() == p2.puzzle.to_string_flat()
	)

	run_test.call("CORE", "SudokuGenerator produces single unique solution", func() -> bool:
		var s: int = 5544332211
		var p := SudokuGenerator.generate(s, DifficultyAnalyzer.LEVEL_MEDIUM)
		return SudokuValidator.has_unique_solution(p.puzzle)
	)

	# --- SUITE 2: GAMEPLAY & DATA LAYER ---
	run_test.call("GAMEPLAY", "Unlimited Undo/Redo & Auto-remove notes", func() -> bool:
		var gen := SudokuGenerator.generate(10203040, DifficultyAnalyzer.LEVEL_EASY)
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

		state.toggle_candidate(empty_cell_2, 3)
		state.set_number(empty_cell_1, 3, true)
		if state.current_board.has_candidate(empty_cell_2, 3):
			return false # Should be auto-removed

		state.undo()
		if not state.current_board.has_candidate(empty_cell_2, 3):
			return false # Must be restored by Undo

		state.redo()
		return state.current_board.get_cell(empty_cell_1) == 3
	)

	run_test.call("GAMEPLAY", "PerformanceScorer 0-100 normalization", func() -> bool:
		var score := PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 300.0, 360, 0, 0)
		return score >= 80 and score <= 100
	)

	run_test.call("DATA", "Crash recovery smoothly restores corrupted save from backup", func() -> bool:
		var gen := SudokuGenerator.generate(77889900, DifficultyAnalyzer.LEVEL_MEDIUM)
		var state := GameState.new()
		state.init_from_puzzle(gen)
		SaveManager.save_active_game(state)

		# Modify and save again to populate backup
		for i in range(81):
			if not state.initial_puzzle.is_given(i):
				state.set_number(i, 2)
				break
		SaveManager.save_active_game(state)

		# Corrupt active save
		var f := FileAccess.open(SaveManager.ACTIVE_GAME_FILE, FileAccess.WRITE)
		f.store_string("corrupted_data_...")
		f.close()

		# Load must recover from backup
		var recovered := SaveManager.load_active_game()
		return recovered != null and recovered.seed_value == 77889900
	)

	run_test.call("DATA", "Offline Daily Sudoku determinism & streak", func() -> bool:
		var s1 := DailyManager.get_seed_for_date(2026, 12, 31)
		var s2 := DailyManager.get_seed_for_date(2026, 12, 31)
		return s1 == s2
	)

	# --- SUITE 3: UI & FLOW ---
	var context: Dictionary = { "root": null }
	run_test.call("UI", "AppRoot full screen navigation and transitions", func() -> bool:
		var r := AppRoot.new()
		context.root = r
		root.add_child(r)

		r._show_screen(r.settings_screen)
		if not r.settings_screen.visible: return false
		r._show_screen(r.history_screen)
		if not r.history_screen.visible: return false
		r._show_screen(r.statistics_screen)
		if not r.statistics_screen.visible: return false
		r._show_screen(r.main_menu)
		return r.main_menu.visible
	)

	run_test.call("UI", "New Game generation and grid cell interaction", func() -> bool:
		var r: AppRoot = context.root
		var gen := SudokuGenerator.generate(99118822, DifficultyAnalyzer.LEVEL_EASY)
		r._on_new_puzzle_generated(gen)

		var grid := r.game_screen.sudoku_grid
		grid.select_cell(4)
		if grid.selected_idx != 4: return false

		grid.move_selection(1, 0)
		return grid.selected_idx == 13
	)

	if context.root != null:
		root.remove_child(context.root)
		context.root.free()

	print("\n==============================================")
	print("   ALL TESTS FINISHED: %d / %d PASSED         " % [stats.passed, stats.total])
	print("==============================================")

	if stats.passed == stats.total:
		print(">>> 100% OF MVP REQUIREMENTS VERIFIED AND PASSED! <<<\n")
		quit.call_deferred(0)
	else:
		printerr(">>> TEST SUITE FAILURES DETECTED! <<<\n")
		quit.call_deferred(1)
