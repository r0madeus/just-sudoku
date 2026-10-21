extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const ImportPuzzleDialog = preload("res://scenes/menus/dialogs/import_puzzle_dialog.gd")

func _init() -> void:
	print("\n==============================================")
	print("   JUST SUDOKU - PUZZLE SHARING & IMPORT TEST  ")
	print("==============================================")

	# Assertions below match Turkish error text, so pin the locale instead of inheriting the system one
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)

	var stats := { "total": 0, "passed": 0 }

	var run_test := func(name: String, test_callable: Callable) -> void:
		stats.total += 1
		print("Test %d: %s..." % [stats.total, name])
		var result: bool = test_callable.call()
		if result:
			stats.passed += 1
			print("  -> PASSED")
		else:
			printerr("  -> FAILED: %s" % name)

	# 1. Export text formatting
	run_test.call("PuzzleShareService formats friendly share text", func() -> bool:
		var board := SudokuBoard.new()
		board.from_string_flat("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79", true)
		var text := PuzzleShareService.export_puzzle_share_text(12345678, "Medium", board)

		return text.contains("Just Sudoku") and text.contains("12345678") and text.contains("Medium") and text.contains("53..7")
	)

	# 2. Parsing formatted share text
	run_test.call("PuzzleShareService parses formatted share text", func() -> bool:
		var share_text := "Just Sudoku\nZorluk: Kolay (Easy)\nSeed: 987654321\nKod: 53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
		var res := PuzzleShareService.parse_import_string(share_text)

		if not res.get("success", false) or res.get("type") != "puzzle_code":
			return false
		var st: GameState = res.get("game_state")
		return st != null and st.initial_puzzle.get_cell(0) == 5 and st.initial_puzzle.get_cell(1) == 3
	)

	# 3. Parsing raw 81-character puzzle string
	run_test.call("PuzzleShareService parses and validates raw 81-char string", func() -> bool:
		var raw_code := "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
		var res := PuzzleShareService.parse_import_string(raw_code)

		if not res.get("success", false):
			return false
		var st: GameState = res.get("game_state")
		return st != null and SudokuValidator.is_board_complete_and_valid(st.solution)
	)

	# 4. Rejecting invalid puzzle strings with conflicts
	run_test.call("PuzzleShareService rejects invalid puzzle with row conflict", func() -> bool:
		# First row has two 5s
		var invalid_code := "550070000600195000098000060800060003400803001700020006060000280000419005000080079"
		var res := PuzzleShareService.parse_import_string(invalid_code)
		return res.get("success", true) == false and res.get("error", "").contains("çakışma")
	)

	# 5. Rejecting invalid puzzle strings with multiple solutions
	run_test.call("PuzzleShareService rejects puzzle with multiple solutions", func() -> bool:
		# Almost empty board
		var non_unique := "530000000000000000000000000000000000000000000000000000000000000000000000000000000"
		var res := PuzzleShareService.parse_import_string(non_unique)
		return res.get("success", true) == false and res.get("error", "").contains("çözüm")
	)

	# 6. Parsing Seed numbers
	run_test.call("PuzzleShareService parses raw Seed number", func() -> bool:
		var seed_str := "44556677"
		var res := PuzzleShareService.parse_import_string(seed_str, DifficultyAnalyzer.LEVEL_HARD)

		if not res.get("success", false) or res.get("type") != "seed":
			return false
		var st: GameState = res.get("game_state")
		return st != null and st.seed_value == 44556677 and st.difficulty == DifficultyAnalyzer.LEVEL_HARD
	)

	# 7. Save JSON export and import round-trip
	run_test.call("PuzzleShareService parses full Save Game JSON round-trip", func() -> bool:
		var gen := SudokuGenerator.generate(119988, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)
		state.elapsed_time = 145.0
		state.mistakes_count = 2

		# Find first empty cell and set number
		for i in range(81):
			if state.current_board.is_empty(i):
				state.set_number(i, 4, false)
				break

		var json_str := SaveManager.export_game_to_string(state)
		var res := PuzzleShareService.parse_import_string(json_str)

		if not res.get("success", false) or res.get("type") != "save_json":
			return false
		var restored: GameState = res.get("game_state")
		return restored != null and restored.elapsed_time == 145.0 and restored.mistakes_count == 2
	)

	# 8. ImportPuzzleDialog UI validation
	run_test.call("ImportPuzzleDialog updates validation status and OK button state", func() -> bool:
		var dlg := ImportPuzzleDialog.new()
		root.add_child(dlg)

		# Initial empty state: OK button must be disabled
		dlg.input_edit.text = ""
		dlg._validate_input()
		var ok_disabled_initially := dlg.get_ok_button().disabled

		# Valid 81-char string: OK button enabled
		dlg.input_edit.text = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
		dlg._validate_input()
		var ok_enabled_valid := not dlg.get_ok_button().disabled

		# Invalid string: OK button disabled
		dlg.input_edit.text = "garbage_text_123_not_a_valid_puzzle"
		dlg._validate_input()
		var ok_disabled_invalid := dlg.get_ok_button().disabled

		dlg.queue_free()
		return ok_disabled_initially and ok_enabled_valid and ok_disabled_invalid
	)

	print("\n==============================================")
	print("   TEST RESULTS: %d / %d PASSED               " % [stats.passed, stats.total])
	print("==============================================")

	if stats.passed == stats.total:
		print(">>> ALL PUZZLE SHARING & IMPORT TESTS PASSED! <<<\n")
		quit.call_deferred(0)
	else:
		printerr(">>> SHARING TESTS FAILED! <<<\n")
		quit.call_deferred(1)
