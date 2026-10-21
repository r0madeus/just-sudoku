extends SceneTree

const AppRoot = preload("res://scenes/app_root.gd")
const MainMenu = preload("res://scenes/menus/main_menu.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const LoadGameScreen = preload("res://scenes/menus/load_game_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")
const StatisticsScreen = preload("res://scenes/menus/statistics_screen.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const NewGameDialog = preload("res://scenes/menus/new_game_dialog.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

func _init() -> void:
	print("\n=== STARTING UI & FLOW TESTS ===")
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

	# --- Test 1: AppRoot Instantiation ---
	var context: Dictionary = { "root": null }

	# --- Test 1: AppRoot Instantiation ---
	run_test.call("AppRoot scene tree instantiation", func() -> bool:
		var r := AppRoot.new()
		context.root = r
		root.add_child(r)
		if r.main_menu == null or r.game_screen == null:
			printerr("AppRoot child screens not initialized")
			return false
		return true
	)

	# --- Test 2: Screen Transitions ---
	run_test.call("Screen transitions to Settings, History, and back", func() -> bool:
		var r: AppRoot = context.root
		r._show_screen(r.settings_screen)
		if not r.settings_screen.visible or r.main_menu.visible:
			return false

		r._show_screen(r.history_screen)
		if not r.history_screen.visible or r.settings_screen.visible:
			return false

		r._show_screen(r.main_menu)
		if not r.main_menu.visible or r.history_screen.visible:
			return false
		return true
	)

	# --- Test 3: New Game Generation via UI Dialog ---
	run_test.call("Start new game from generated puzzle", func() -> bool:
		var r: AppRoot = context.root
		var gen := SudokuGenerator.generate(44556677, DifficultyAnalyzer.LEVEL_EASY)
		r._on_new_puzzle_generated(gen)

		if not r.game_screen.visible:
			printerr("GameScreen should be visible after starting new game")
			return false

		if r.game_screen.game_state.seed_value != 44556677:
			printerr("Seed value mismatch in game screen state")
			return false

		return true
	)

	# --- Test 4: Grid Selection & Keyboard Navigation ---
	run_test.call("SudokuGrid selection and movement", func() -> bool:
		var r: AppRoot = context.root
		var grid: SudokuGrid = r.game_screen.sudoku_grid
		grid.select_cell(0) # R1C1
		if grid.selected_idx != 0:
			return false

		grid.move_selection(1, 1) # Should move to R2C2 (idx 10)
		if grid.selected_idx != 10:
			printerr("Move selection expected idx 10, got %d" % grid.selected_idx)
			return false
		return true
	)

	# Clean up
	if context.root != null:
		root.remove_child(context.root)
		context.root.free()

	print("\n=== TEST RESULTS: %d/%d PASSED ===" % [stats.passed, stats.total])
	if stats.passed == stats.total:
		print(">>> ALL UI & FLOW TESTS PASSED SUCCESSFULLY! <<<\n")
		quit.call_deferred(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		quit.call_deferred(1)
