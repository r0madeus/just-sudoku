extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const SolutionDialog = preload("res://scenes/gameplay/dialogs/solution_dialog.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING SOLUTION SYSTEM (FULL & STEP-BY-STEP) TESTS")
	print("========================================")

	test_step_by_step_generation_easy()
	test_step_by_step_generation_medium_hard()
	test_solve_step_formatting_and_coords()
	test_solution_dialog_ui_and_navigation()
	test_solution_dialog_mode_switching()
	test_solution_application_to_game_state()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")

	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func test_step_by_step_generation_easy() -> void:
	print("\n--- Test 1: Step-by-Step Generation (Easy Puzzle) ---")
	var gen := SudokuGenerator.generate(10203040, DifficultyAnalyzer.LEVEL_EASY)
	assert_true(gen != null, "Easy puzzle generated")

	var sol := SudokuSolver.get_full_step_by_step_solution(gen.puzzle)
	assert_true(sol.has("steps") and sol.has("snapshots") and sol.has("solved_board"), "Solution contains steps, snapshots, and solved_board")

	var steps: Array = sol["steps"]
	var snapshots: Array = sol["snapshots"]
	var solved: SudokuBoard = sol["solved_board"]

	assert_true(steps.size() > 0, "Steps generated (count: %d)" % steps.size())
	assert_true(snapshots.size() == steps.size() + 1, "Snapshots count equals steps count + 1")

	# Snapshot 0 must be initial board
	var snap0: SudokuBoard = snapshots[0]
	assert_true(snap0.get_empty_cell_count() == gen.puzzle.get_empty_cell_count(), "Snapshot 0 matches initial empty count")

	# Final snapshot must be fully solved and valid
	var snap_last: SudokuBoard = snapshots[snapshots.size() - 1]
	assert_true(snap_last.get_empty_cell_count() == 0, "Last snapshot has 0 empty cells")
	assert_true(SudokuValidator.is_board_complete_and_valid(snap_last), "Last snapshot is complete and valid")
	assert_true(SudokuValidator.is_board_complete_and_valid(solved), "solved_board is complete and valid")

func test_step_by_step_generation_medium_hard() -> void:
	print("\n--- Test 2: Step-by-Step Generation (Medium & Hard Puzzles) ---")
	var idx := 0
	for diff in [DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD]:
		idx += 1
		var gen := SudokuGenerator.generate(55667788 + idx * 100, diff)
		var sol := SudokuSolver.get_full_step_by_step_solution(gen.puzzle)
		var steps: Array = sol["steps"]
		var snapshots: Array = sol["snapshots"]
		var solved: SudokuBoard = sol["solved_board"]

		assert_true(steps.size() >= 30, "Puzzle diff %s generated %d steps" % [diff, steps.size()])
		assert_true(snapshots.size() == steps.size() + 1, "Snapshots match step progression")
		assert_true(SudokuValidator.is_board_complete_and_valid(solved), "Solved board is 100%% valid for diff %s" % diff)

func test_solve_step_formatting_and_coords() -> void:
	print("\n--- Test 3: SolveStep Coordinate & Technique Formatting ---")
	var step := SudokuSolver.SolveStep.new()
	step.technique = "Hidden Single"
	step.cells = [SudokuBoard.get_index(3, 6)] # R4C7 (0-indexed 3, 6)
	step.digit = 8
	step.explanation = "R4C7 is the only candidate in block."

	LocalizationManager.set_locale("en")
	assert_true(step.get_target_coord() == "R4C7", "Coordinate formatting R4C7 correct")
	assert_true(step.get_formatted_coords() == "R4C7", "Formatted coords matches")

	# Multi-cell test (e.g. Naked Pair in R1C1 and R1C2)
	var pair_step := SudokuSolver.SolveStep.new()
	pair_step.technique = "Naked Pair"
	pair_step.cells = [0, 1]
	assert_true(pair_step.get_formatted_coords() == "R1C1, R1C2", "Multi-cell pair coordinates format correctly")

	# Localization of technique name
	LocalizationManager.set_locale("tr")
	var tr_tech := LocalizationManager.get_technique_name("Hidden Single")
	assert_true(tr_tech == "Gizli Tekli", "TR technique name translated correctly (%s)" % tr_tech)
	assert_true(step.get_target_coord() == "4. satır 7. sütun", "TR coordinate reads as row and column (%s)" % step.get_target_coord())

	LocalizationManager.set_locale("en")
	var en_tech := LocalizationManager.get_technique_name("Hidden Single")
	assert_true(en_tech == "Hidden Single", "EN technique name translated correctly")

func test_solution_dialog_ui_and_navigation() -> void:
	print("\n--- Test 4: SolutionDialog UI & Step Navigation ---")
	var dialog := SolutionDialog.new()
	var gen := SudokuGenerator.generate(12341234, DifficultyAnalyzer.LEVEL_EASY)

	dialog.open_solution(gen.puzzle)

	assert_true(dialog.cells.size() == 81, "Dialog has 81 9x9 visual cells")
	assert_true(dialog.steps.size() > 0, "Dialog loaded steps")
	assert_true(dialog.current_step_idx == 0, "Initial step index is 0")
	assert_true(dialog.btn_first.disabled and dialog.btn_prev.disabled, "First and Prev buttons disabled at step 0")
	assert_true(not dialog.btn_next.disabled and not dialog.btn_last.disabled, "Next and Last buttons enabled at step 0")

	# Step forward
	dialog.set_step(1)
	assert_true(dialog.current_step_idx == 1, "Stepped to index 1")
	assert_true(not dialog.btn_prev.disabled, "Prev button now enabled")

	# Jump to end
	dialog.set_step(dialog.steps.size())
	assert_true(dialog.current_step_idx == dialog.steps.size(), "Jumped to last step")
	assert_true(dialog.btn_next.disabled and dialog.btn_last.disabled, "Next and Last disabled at end")

	# Jump to start
	dialog.set_step(0)
	assert_true(dialog.current_step_idx == 0, "Jumped back to step 0")

	# Clamp safety
	dialog.set_step(-5)
	assert_true(dialog.current_step_idx == 0, "Clamped lower bound")
	dialog.set_step(99999)
	assert_true(dialog.current_step_idx == dialog.steps.size(), "Clamped upper bound")

	dialog.queue_free()

func test_solution_dialog_mode_switching() -> void:
	print("\n--- Test 5: SolutionDialog Mode Switching ---")
	var dialog := SolutionDialog.new()
	var gen := SudokuGenerator.generate(44332211, DifficultyAnalyzer.LEVEL_EASY)

	dialog.open_solution(gen.puzzle)
	assert_true(dialog.current_mode == SolutionDialog.Mode.STEP_BY_STEP, "Starts in STEP_BY_STEP mode")
	assert_true(dialog.step_nav_bar.visible and dialog.step_info_panel.visible, "Step navigation and info panel visible")
	assert_true(not dialog.full_info_panel.visible, "Full info panel hidden")

	# Switch to Full Solution
	dialog.switch_view_mode(SolutionDialog.Mode.FULL_SOLUTION)
	assert_true(dialog.current_mode == SolutionDialog.Mode.FULL_SOLUTION, "Switched to FULL_SOLUTION mode")
	assert_true(not dialog.step_nav_bar.visible and not dialog.step_info_panel.visible, "Step controls hidden in full mode")
	assert_true(dialog.full_info_panel.visible, "Full info panel visible")

	# All 81 visual cells should have non-empty text
	var all_filled := true
	for c in dialog.cells:
		if c["label"].text.is_empty():
			all_filled = false
			break
	assert_true(all_filled, "All 81 cells rendered with numbers in Full Solution mode")

	# Switch back to Step-by-Step
	dialog.switch_view_mode(SolutionDialog.Mode.STEP_BY_STEP)
	assert_true(dialog.current_mode == SolutionDialog.Mode.STEP_BY_STEP, "Switched back to STEP_BY_STEP")

	dialog.queue_free()

func test_solution_application_to_game_state() -> void:
	print("\n--- Test 6: Apply Solution to Active GameState ---")
	var game_screen := GameScreen.new()
	var gen := SudokuGenerator.generate(88776655, DifficultyAnalyzer.LEVEL_MEDIUM)

	var state := GameState.new()
	state.init_from_puzzle(gen)
	game_screen.setup_game(state)

	assert_true(game_screen.solution_btn != null, "GameScreen has solution_btn in pause overlay")
	assert_true(game_screen.solution_dialog != null, "GameScreen has solution_dialog instance")

	# Simulate solution application
	var solved := SudokuSolver.solve_fast(gen.puzzle)
	assert_true(solved != null, "Fast solver produced solved board")

	game_screen._on_solution_applied(solved)

	assert_true(state.is_completed, "GameState marked as completed after solution applied")
	assert_true(state.current_board.get_empty_cell_count() == 0, "Current board has 0 empty cells")
	assert_true(SudokuValidator.is_board_complete_and_valid(state.current_board), "Current board is complete and valid")

	game_screen.queue_free()
