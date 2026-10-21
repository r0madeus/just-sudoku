extends SceneTree

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const NewGameDialog = preload("res://scenes/menus/new_game_dialog.gd")

func _init() -> void:
	_run_all_tests()

func _run_all_tests() -> void:
	print("\n==============================================")
	print("   JUST SUDOKU - ASYNC GENERATOR TEST SUITE   ")
	print("==============================================")

	var stats := { "total": 0, "passed": 0 }

	# Test 1: Single async puzzle generation
	stats.total += 1
	print("Test %d: Single async puzzle generation via WorkerThreadPool..." % stats.total)
	var t1_done: Dictionary = { "finished": false, "puzzle": null }
	AsyncPuzzleGenerator.request_puzzle_async(
		12345678,
		DifficultyAnalyzer.LEVEL_EASY,
		func(gen: SudokuGenerator.GeneratedPuzzle):
			t1_done.finished = true
			t1_done.puzzle = gen
	)

	var wait_start := Time.get_ticks_msec()
	while not t1_done.finished and (Time.get_ticks_msec() - wait_start) < 8000:
		await create_timer(0.05).timeout

	if t1_done.finished and t1_done.puzzle != null and SudokuValidator.has_unique_solution(t1_done.puzzle.puzzle):
		stats.passed += 1
		print("  -> PASSED (Seed: %d, Difficulty: %s)" % [t1_done.puzzle.seed_value, t1_done.puzzle.difficulty])
	else:
		printerr("  -> FAILED: Single async generation timed out or invalid.")

	# Test 2: Rapid successive requests - Stale cancellation
	stats.total += 1
	print("Test %d: Rapid successive requests cancels stale callbacks..." % stats.total)
	var callback_calls: Array[String] = []

	var req1 := AsyncPuzzleGenerator.request_puzzle_async(
		111111,
		DifficultyAnalyzer.LEVEL_HARD,
		func(gen): callback_calls.append("req1_hard")
	)
	# Immediately cancel req1 and trigger req2
	AsyncPuzzleGenerator.cancel_request(req1)

	var req2 := AsyncPuzzleGenerator.request_puzzle_async(
		222222,
		DifficultyAnalyzer.LEVEL_EXPERT,
		func(gen): callback_calls.append("req2_expert")
	)
	# Immediately cancel req2 and trigger req3
	AsyncPuzzleGenerator.cancel_request(req2)

	var t2_done: Dictionary = { "finished": false }
	var req3 := AsyncPuzzleGenerator.request_puzzle_async(
		333333,
		DifficultyAnalyzer.LEVEL_EASY,
		func(gen):
			callback_calls.append("req3_easy")
			t2_done.finished = true
	)

	wait_start = Time.get_ticks_msec()
	while not t2_done.finished and (Time.get_ticks_msec() - wait_start) < 8000:
		await create_timer(0.05).timeout

	# Let any remaining threads finish dispatching
	await create_timer(0.2).timeout

	if callback_calls.size() == 1 and callback_calls[0] == "req3_easy":
		stats.passed += 1
		print("  -> PASSED: Only final request callback fired (%s)" % str(callback_calls))
	else:
		printerr("  -> FAILED: Expected only req3_easy, but received: %s" % str(callback_calls))

	# Test 3: NewGameDialog async lifecycle & UI states
	stats.total += 1
	print("Test %d: NewGameDialog loading state and async preview update..." % stats.total)
	var dialog := NewGameDialog.new()
	root.add_child(dialog)

	# Before open, generate preview
	dialog._generate_preview()
	var initially_generating: bool = dialog.is_generating
	var initially_loading_visible: bool = dialog.loading_box.visible
	var ok_initially_disabled: bool = dialog.get_ok_button().disabled

	wait_start = Time.get_ticks_msec()
	while dialog.is_generating and (Time.get_ticks_msec() - wait_start) < 8000:
		await create_timer(0.05).timeout

	var finally_ready: bool = not dialog.is_generating
	var finally_content_visible: bool = dialog.preview_content.visible
	var ok_finally_enabled: bool = not dialog.get_ok_button().disabled
	var generated_valid: bool = (dialog.current_generated != null)

	dialog.queue_free()

	if initially_generating and initially_loading_visible and ok_initially_disabled and finally_ready and finally_content_visible and ok_finally_enabled and generated_valid:
		stats.passed += 1
		print("  -> PASSED: NewGameDialog loading indicator and button states verified")
	else:
		printerr("  -> FAILED: Dialog state mismatch: init_gen=%s, init_load=%s, fin_ready=%s, fin_vis=%s, ok_en=%s" % [
			initially_generating, initially_loading_visible, finally_ready, finally_content_visible, ok_finally_enabled
		])

	print("\n==============================================")
	print("   TEST RESULTS: %d / %d PASSED               " % [stats.passed, stats.total])
	print("==============================================")

	if stats.passed == stats.total:
		print(">>> ALL ASYNC GENERATION TESTS PASSED! <<<\n")
		quit(0)
	else:
		printerr(">>> ASYNC TESTS FAILED! <<<\n")
		quit(1)
