extends SceneTree

## Medium, Hard and Expert come from a bank of pre-rated puzzles shown in a disguise drawn from
## the seed. Every bank puzzle must be at its level and solvable without guessing (before the
## bank, 29 of 30 Expert puzzles needed more than the solver's techniques, and a hint there
## could only reveal a digit); a seed must always give the same puzzle; generation must be quick;
## and replaying a finished game must show the puzzle that was played.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")

## Bank puzzles fully re-checked per level (spread over the file), to keep the suite quick
const SAMPLE: int = 25

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

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING PUZZLE BANK TESTS")
	print("========================================")
	SettingsScreen.animations_enabled = false
	test_bank_files()
	test_bank_puzzles_are_at_their_level()
	test_generated_puzzles()
	test_disguise_keeps_the_puzzle()
	test_solver_is_sound()
	test_solver_does_not_depend_on_orientation()
	test_swordfish_both_ways()
	test_live_expert_needs_no_guessing()
	await test_replay_shows_the_played_puzzle()
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func test_bank_files() -> void:
	print("\n--- Test 1: A bank for each level it serves ---")
	for level in SudokuGenerator.BANK_LEVELS:
		var bank := SudokuGenerator.bank(level)
		var seen := {}
		var bad := 0
		for p in bank:
			seen[p] = true
			if p.length() != 81 or not RegEx.create_from_string("^[1-9.]{81}$").search(p):
				bad += 1
		assert_true(bank.size() >= 200, "%s bank holds %d puzzles" % [level, bank.size()])
		assert_true(bad == 0 and seen.size() == bank.size(), "%s: every line is one 81-cell puzzle, none twice" % level)
	assert_true(SudokuGenerator.bank(DifficultyAnalyzer.LEVEL_EASY).is_empty(), "Easy has no bank: it is generated live")

func test_bank_puzzles_are_at_their_level() -> void:
	print("\n--- Test 2: Bank puzzles are at their level and need no guessing ---")
	for level in SudokuGenerator.BANK_LEVELS:
		var bank := SudokuGenerator.bank(level)
		var step: int = maxi(1, bank.size() / SAMPLE)
		var wrong: Array = []
		for i in range(0, bank.size(), step):
			var board := SudokuBoard.new()
			board.from_string_flat(bank[i], true)
			var a := DifficultyAnalyzer.analyze(board)
			if a.level != level or not a.solved_logically or not SudokuValidator.has_unique_solution(board):
				wrong.append("#%d %s%s" % [i, a.level, "" if a.solved_logically else " (stuck)"])
		assert_true(wrong.is_empty(), "%s: %d sampled puzzles all at the level, unique, solvable by logic %s" % [level, ceili(float(bank.size()) / step), str(wrong)])

func test_generated_puzzles() -> void:
	print("\n--- Test 3: What a seed gives at each level ---")
	for level in SudokuGenerator.BANK_LEVELS:
		var grids := {}
		var slow := 0
		var bad: Array = []
		for k in range(8):
			var seed_val: int = 31337 + k * 7919
			var t0 := Time.get_ticks_msec()
			var gen := SudokuGenerator.generate(seed_val, level)
			if Time.get_ticks_msec() - t0 > 500:
				slow += 1
			var a := DifficultyAnalyzer.analyze(gen.puzzle)
			if gen.difficulty != level or a.level != level or not a.solved_logically:
				bad.append(seed_val)
			# The solution fits the givens and is a full valid grid
			for i in range(81):
				if gen.puzzle.get_cell(i) != 0 and gen.puzzle.get_cell(i) != gen.solution.get_cell(i):
					bad.append("givens %d" % seed_val)
					break
			if not SudokuValidator.is_board_complete_and_valid(gen.solution):
				bad.append("solution %d" % seed_val)
			grids[gen.puzzle.to_string_flat()] = true
		assert_true(bad.is_empty(), "%s: 8 seeds, each at the level, solvable by logic, with a valid solution %s" % [level, str(bad)])
		assert_true(grids.size() == 8, "%s: 8 seeds, 8 different grids" % level)
		assert_true(slow == 0, "%s: each ready within 0.5 s (%d slower)" % [level, slow])
		var again := SudokuGenerator.generate(31337, level)
		var first := SudokuGenerator.generate(31337, level)
		assert_true(again.puzzle.to_string_flat() == first.puzzle.to_string_flat(), "%s: the same seed always gives the same puzzle" % level)
	var easy := SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_EASY)
	assert_true(easy != null and easy.difficulty == DifficultyAnalyzer.LEVEL_EASY, "Easy still comes from the live generator")

func test_disguise_keeps_the_puzzle() -> void:
	print("\n--- Test 4: A disguise changes the look, not the puzzle ---")
	var base: String = SudokuGenerator.bank(DifficultyAnalyzer.LEVEL_EXPERT)[0]
	var rng := SudokuGenerator.DeterministicRNG.new(99)
	var flat := SudokuGenerator._disguise(base, rng)
	var a := SudokuBoard.new()
	a.from_string_flat(base, true)
	var b := SudokuBoard.new()
	b.from_string_flat(flat, true)
	assert_true(flat != base and a.get_empty_cell_count() == b.get_empty_cell_count(), "Different grid, same number of givens")
	assert_true(SudokuValidator.has_unique_solution(b), "Still exactly one solution")
	var ra := DifficultyAnalyzer.analyze(a)
	var rb := DifficultyAnalyzer.analyze(b)
	assert_true(ra.level == rb.level and rb.solved_logically, "Same level (%s / %s)" % [ra.level, rb.level])

## Steps the solver through `flat` and counts deductions that contradict the solution
func _wrong_deductions(flat: String, wrong: Dictionary) -> void:
	var board := SudokuBoard.new()
	board.from_string_flat(flat, true)
	var solution := SudokuSolver.solve_fast(board)
	var work := board.clone()
	work.reset_candidates_from_grid()
	for _i in range(200):
		if work.get_empty_cell_count() == 0:
			return
		var step := SudokuSolver.find_next_step(work)
		if step == null:
			return
		if step.digit != 0 and step.cells.size() == 1:
			if solution.get_cell(step.cells[0]) != step.digit:
				wrong[step.technique] = wrong.get(step.technique, 0) + 1
			work.set_cell(step.cells[0], step.digit, false)
			work.reset_candidates_from_grid()
		else:
			for k in step.eliminations.keys():
				for d in step.eliminations[k]:
					if solution.get_cell(int(k)) == d:
						wrong[step.technique] = wrong.get(step.technique, 0) + 1
					work.remove_candidate(int(k), d)

func test_solver_is_sound() -> void:
	print("\n--- Test 5: Every deduction the solver makes is true ---")
	# A wrong elimination can still end in the right grid by luck, so the bank's ratings alone
	# would not show it (an XYZ-Wing with two identical wings once did exactly that)
	var wrong := {}
	var n := 0
	for level in SudokuGenerator.BANK_LEVELS:
		var bank := SudokuGenerator.bank(level)
		var step: int = maxi(1, bank.size() / SAMPLE)
		for i in range(0, bank.size(), step):
			_wrong_deductions(bank[i], wrong)
			_wrong_deductions(SudokuGenerator._disguise(bank[i], SudokuGenerator.DeterministicRNG.new(i + 1)), wrong)
			n += 2
	assert_true(wrong.is_empty(), "%d puzzles stepped through: no placement or elimination contradicts the solution %s" % [n, str(wrong)])

func test_solver_does_not_depend_on_orientation() -> void:
	print("\n--- Test 6: Turning a puzzle does not change what the solver can do ---")
	# A technique searched only along rows (Swordfish once was) fails on a mirrored grid
	var bank := SudokuGenerator.bank(DifficultyAnalyzer.LEVEL_EXPERT)
	var stuck := 0
	var total := 0
	for i in range(0, bank.size(), maxi(1, bank.size() / 15)):
		for k in range(3):
			var board := SudokuBoard.new()
			board.from_string_flat(SudokuGenerator._disguise(bank[i], SudokuGenerator.DeterministicRNG.new(i * 7 + k)), true)
			if not DifficultyAnalyzer.analyze(board).solved_logically:
				stuck += 1
			total += 1
	assert_true(stuck == 0, "%d disguised Expert puzzles: all still solvable by logic (%d stuck)" % [total, stuck])

## An empty board where digit 5 forms a Swordfish: in three base lines it has only the three
## cross positions 1, 4 and 7 (two each), and it is also a candidate elsewhere on those crosses
func _swordfish_board(by_rows: bool) -> SudokuBoard:
	var board := SudokuBoard.new()
	var all: int = 0
	for d in range(1, 10):
		all |= 1 << d
	for idx in range(81):
		board.candidates[idx] = all
	var spots := {0: [1, 4], 3: [4, 7], 6: [1, 7]}
	for line in spots:
		for cross in range(9):
			if not spots[line].has(cross):
				var idx: int = SudokuBoard.get_index(line, cross) if by_rows else SudokuBoard.get_index(cross, line)
				board.candidates[idx] &= ~(1 << 5)
	return board

func test_swordfish_both_ways() -> void:
	print("\n--- Test 7: Swordfish is found along rows and along columns ---")
	for by_rows in [true, false]:
		var step := SudokuSolver._find_swordfish(_swordfish_board(by_rows))
		var target: int = SudokuBoard.get_index(2, 4) if by_rows else SudokuBoard.get_index(4, 2)
		assert_true(step != null and step.technique == "Swordfish" and step.eliminations.has(target),
			"Swordfish with base %s found, and 5 removed from the crossing lines" % ("rows" if by_rows else "columns"))

func test_live_expert_needs_no_guessing() -> void:
	print("\n--- Test 8: Live generation never settles for a puzzle that needs guessing ---")
	# Builds the bank and serves a level whose bank is missing; most raw Expert candidates are
	# stuck for the solver, so this is where accepting them would slip back in
	var stuck := 0
	for k in range(3):
		var gen := SudokuGenerator.generate_live(880000 + k * 7919, DifficultyAnalyzer.LEVEL_EXPERT)
		if not DifficultyAnalyzer.analyze(gen.puzzle).solved_logically:
			stuck += 1
	assert_true(stuck == 0, "3 live Expert puzzles, all solvable by logic (%d stuck)" % stuck)

func test_replay_shows_the_played_puzzle() -> void:
	print("\n--- Test 9: Replay shows the puzzle that was played ---")
	var saved: Array[Dictionary] = HistoryManager.load_all_records(true).duplicate(true)
	# A record whose stored grid is not what its seed generates today (as after a bank change)
	var played := SudokuGenerator.generate_live(2024, DifficultyAnalyzer.LEVEL_HARD)
	var today := SudokuGenerator.generate(555, DifficultyAnalyzer.LEVEL_HARD)
	assert_true(played.puzzle.to_string_flat() != today.puzzle.to_string_flat(), "Setup: the stored grid differs from today's for that seed")
	var records: Array[Dictionary] = [{"game_id": "r1", "seed": "555", "difficulty": DifficultyAnalyzer.LEVEL_HARD, "score": 80, "time": 300.0,
		"puzzle": played.puzzle.to_string_flat(), "timestamp": 1}]
	HistoryManager.save_all_records(records)
	var app: AppRoot = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(5)
	app._on_history_replay_requested(555, DifficultyAnalyzer.LEVEL_HARD)
	await _frames(5)
	var state = app.game_screen.game_state
	assert_true(state != null and state.initial_puzzle.to_string_flat() == played.puzzle.to_string_flat(), "Replay starts from the stored grid")
	assert_true(state != null and state.is_replay and state.seed_value == 555 and state.difficulty == DifficultyAnalyzer.LEVEL_HARD, "Same seed and level, marked as a replay")
	app.queue_free()
	await _frames(3)
	HistoryManager.save_all_records(saved)
