extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const SmartNumpad = preload("res://scenes/gameplay/smart_numpad.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")

func _init() -> void:
	print("\n==============================================")
	print("   JUST SUDOKU - UI SCALING & CANDIDATES TEST   ")
	print("==============================================")

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

	# 1. Smart Candidates Default State (GDD §17 & User Request)
	run_test.call("Smart Candidates is OFF by default in Settings", func() -> bool:
		return SettingsScreen.smart_candidates_enabled == false
	)

	run_test.call("New game starts with ZERO candidate clutter on empty cells by default", func() -> bool:
		SettingsScreen.smart_candidates_enabled = false
		var gen := SudokuGenerator.generate(12345678, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)

		var total_candidates: int = 0
		for i in range(81):
			if not state.initial_puzzle.is_given(i):
				total_candidates += state.current_board.candidates[i]
		return total_candidates == 0
	)

	run_test.call("Manual notes work properly when Smart Candidates is OFF", func() -> bool:
		SettingsScreen.smart_candidates_enabled = false
		var gen := SudokuGenerator.generate(12345678, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)

		# Find first empty cell
		var empty_idx: int = -1
		for i in range(81):
			if not state.initial_puzzle.is_given(i):
				empty_idx = i
				break

		state.toggle_candidate(empty_idx, 5)
		return state.current_board.has_candidate(empty_idx, 5)
	)

	run_test.call("Toggling Smart Candidates in Settings calculates all valid candidates", func() -> bool:
		var screen := GameScreen.new()
		root.add_child(screen)

		var gen := SudokuGenerator.generate(87654321, DifficultyAnalyzer.LEVEL_MEDIUM)
		var state := GameState.new()
		state.init_from_puzzle(gen)
		screen.setup_game(state)

		# With smart candidates false, verify 0 candidates
		var empty_idx: int = -1
		for i in range(81):
			if not state.initial_puzzle.is_given(i):
				empty_idx = i
				break

		if state.current_board.candidates[empty_idx] != 0:
			screen.queue_free()
			return false

		# Toggle ON
		SettingsScreen.smart_candidates_enabled = true
		SettingsScreen._notify_listeners()

		var has_cands := (state.current_board.candidates[empty_idx] != 0)

		# Toggle OFF
		SettingsScreen.smart_candidates_enabled = false
		SettingsScreen._notify_listeners()

		var cleared := (state.current_board.candidates[empty_idx] == 0)

		screen.queue_free()
		return has_cands and cleared
	)

	# 2. UI Layout & Scaling Tests
	run_test.call("Smart Numpad buttons expand fill with a touch-sized minimum (>= 60px)", func() -> bool:
		var numpad := SmartNumpad.new()
		root.add_child(numpad)

		if numpad.num_buttons.size() != 9:
			numpad.queue_free()
			return false

		for btn in numpad.num_buttons:
			if btn.custom_minimum_size.x < 60 or btn.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
				numpad.queue_free()
				return false

		numpad.queue_free()
		return true
	)

	run_test.call("GDD §18 Check Button is hidden during game and visible only when board filled", func() -> bool:
		var screen := GameScreen.new()
		root.add_child(screen)

		var gen := SudokuGenerator.generate(11223344, DifficultyAnalyzer.LEVEL_EASY)
		var state := GameState.new()
		state.init_from_puzzle(gen)
		screen.setup_game(state)

		# Initially empty cells exist -> check_btn must be hidden
		if screen.check_btn.visible:
			screen.queue_free()
			return false

		# Fill all cells using the solution
		for i in range(81):
			if state.current_board.is_empty(i):
				state.set_number(i, gen.solution.get_cell(i), false)

		screen._update_action_buttons()
		var is_visible := screen.check_btn.visible

		screen.queue_free()
		return is_visible
	)

	run_test.call("Action Bar has exactly 4 responsive expanding buttons", func() -> bool:
		var screen := GameScreen.new()
		root.add_child(screen)

		var buttons: Array[Node] = screen.action_bar.get_children()
		if buttons.size() != 4:
			screen.queue_free()
			return false

		for b in buttons:
			if b is Button:
				if b.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
					screen.queue_free()
					return false

		screen.queue_free()
		return true
	)

	print("\n==============================================")
	print("   TEST RESULTS: %d / %d PASSED" % [stats.passed, stats.total])
	print("==============================================")

	if stats.passed == stats.total:
		print(">>> ALL SCALING & CANDIDATE REQUIREMENTS VERIFIED! <<<\n")
		quit.call_deferred(0)
	else:
		printerr(">>> FAILURES DETECTED! <<<\n")
		quit.call_deferred(1)
