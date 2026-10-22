extends SceneTree

## The app must exit cleanly: a crash on exit kills the process, so each case runs Godot as a
## child process and checks its exit code (0) instead of asserting inside this one.

const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	_run.call_deferred()

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _run_child(args: Array) -> int:
	var full: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	var output: Array = []
	return OS.execute(OS.get_executable_path(), full, output, true)

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING CLEAN EXIT TESTS")
	print("========================================")

	print("\n--- Test 1: The app quits cleanly ---")
	for i in range(3):
		var code := _run_child(["--quit-after", "30"])
		assert_true(code == 0, "Run %d: main scene exits with code 0 (got %d)" % [i + 1, code])

	print("\n--- Test 2: Quitting while a puzzle is being generated ---")
	for i in range(3):
		var code := _run_child(["-s", "res://tests/helpers/quit_during_generation.gd"])
		assert_true(code == 0, "Run %d: exits with code 0 during generation (got %d)" % [i + 1, code])

	print("\n--- Test 3: Finished requests release their pool task ---")
	var done := [false]
	AsyncPuzzleGenerator.request_puzzle_async(4242, DifficultyAnalyzer.LEVEL_EASY, func(_gen): done[0] = true, 1)
	var frames := 0
	while not done[0] and frames < 2000:
		await process_frame
		frames += 1
	assert_true(done[0], "Easy puzzle generated")
	assert_true(AsyncPuzzleGenerator._pool_tasks.is_empty(), "Pool task released after completion")

	print("\n--- Test 4: shutdown() cancels and waits for running requests ---")
	var called := [false]
	AsyncPuzzleGenerator.request_puzzle_async(77, DifficultyAnalyzer.LEVEL_EXPERT, func(_gen): called[0] = true, 1)
	var t0 := Time.get_ticks_msec()
	AsyncPuzzleGenerator.shutdown()
	var waited := Time.get_ticks_msec() - t0
	assert_true(AsyncPuzzleGenerator._pool_tasks.is_empty(), "No pool task left after shutdown")
	assert_true(waited < 3000, "Shutdown returned quickly (%d ms)" % waited)
	for i in range(5):
		await process_frame
	assert_true(not called[0], "A cancelled request never calls back")

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)
