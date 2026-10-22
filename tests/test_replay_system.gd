extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const HistoryScreen = preload("res://scenes/menus/history_screen.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

class SignalTracker extends RefCounted:
	var received: bool = false
	var seed_val: int = 0
	var diff: String = ""
	func on_replay(s: int, d: String) -> void:
		received = true
		seed_val = s
		diff = d

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING REPLAY & MASTER IT AGAIN SYSTEM TESTS")
	print("========================================")

	test_game_state_reset_for_replay()
	test_history_manager_queries_and_tiebreak()
	test_history_manager_status_filtering()
	test_history_screen_replay_button_and_filter()
	test_game_screen_replay_action_and_score_comparison()

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

func test_game_state_reset_for_replay() -> void:
	print("\n--- Test 1: GameState.reset_for_replay() ---")
	var gen := SudokuGenerator.generate(88776655, DifficultyAnalyzer.LEVEL_EASY)
	assert_true(gen != null, "Puzzle generated for replay test")

	var state := GameState.new()
	state.init_from_puzzle(gen)
	var original_game_id: String = state.game_id
	var initial_empty: int = state.current_board.get_empty_cell_count()

	# Simulate active gameplay
	state.elapsed_time = 185.0
	state.mistakes_count = 2
	state.hints_used = 1

	# Find an editable cell and enter a value
	var target_idx := -1
	for idx in range(SudokuBoard.CELL_COUNT):
		if state.can_edit_cell(idx) and state.current_board.get_cell(idx) == 0:
			target_idx = idx
			break

	assert_true(target_idx != -1, "Found editable empty cell for play simulation")
	state.set_number(target_idx, 5)
	state.toggle_candidate(target_idx, 7)
	assert_true(state.current_board.get_empty_cell_count() < initial_empty, "Board was modified during play")
	assert_true(not state.undo_stack.is_empty(), "Undo stack contains moves")

	# Perform reset_for_replay
	state.reset_for_replay()

	assert_true(state.is_replay == true, "GameState is_replay flag is true")
	assert_true(state.game_id != original_game_id, "New unique game_id generated for replay session")
	assert_true(state.game_id.begins_with("replay_"), "Replay game_id begins with 'replay_' prefix: %s" % state.game_id)
	assert_true(state.elapsed_time == 0.0, "Elapsed time reset to 0.0")
	assert_true(state.mistakes_count == 0, "Mistakes count reset to 0")
	assert_true(state.hints_used == 0, "Hints used reset to 0")
	assert_true(state.undo_stack.is_empty(), "Undo stack cleared")
	assert_true(state.redo_stack.is_empty(), "Redo stack cleared")
	assert_true(state.current_board.get_empty_cell_count() == initial_empty, "Board empty cell count restored to initial puzzle")
	assert_true(state.current_board.get_cell(target_idx) == 0, "Player entered move was cleared")
	assert_true(state.seed_value == gen.seed_value, "Seed preserved: %d" % state.seed_value)
	assert_true(state.difficulty == gen.difficulty, "Difficulty preserved: %s" % state.difficulty)

func test_history_manager_queries_and_tiebreak() -> void:
	print("\n--- Test 2: HistoryManager best record queries and tiebreak ---")
	var test_seed: int = 99991234

	var rec1 := {
		"game_id": "std_1",
		"seed": test_seed,
		"difficulty": "medium",
		"score": 75,
		"time": 200.0,
		"mistakes": 1,
		"hints": 0,
		"is_replay": false
	}
	var rec2 := {
		"game_id": "rep_1",
		"seed": test_seed,
		"difficulty": "medium",
		"score": 92,
		"time": 150.0,
		"mistakes": 0,
		"hints": 0,
		"is_replay": true
	}
	var rec3 := {
		"game_id": "rep_2",
		"seed": test_seed,
		"difficulty": "medium",
		"score": 92,
		"time": 120.0, # Same score 92, but faster time 120 vs 150
		"mistakes": 0,
		"hints": 0,
		"is_replay": true
	}

	HistoryManager.add_record(rec1)
	HistoryManager.add_record(rec2)
	HistoryManager.add_record(rec3)

	var all_for_seed := HistoryManager.get_records_for_seed(test_seed)
	assert_true(all_for_seed.size() >= 3, "Retrieved all records for test seed (found %d)" % all_for_seed.size())

	var best := HistoryManager.get_best_record_for_seed(test_seed)
	assert_true(best.has("score") and int(best["score"]) == 92, "Best record has maximum score (92)")
	assert_true(best.has("time") and is_equal_approx(float(best["time"]), 120.0), "Best record tiebreak picks fastest time (120s)")
	assert_true(best.get("game_id", "") == "rep_2", "Best record picks rep_2")

func test_history_manager_status_filtering() -> void:
	print("\n--- Test 3: HistoryManager status filtering ---")
	var all_records := HistoryManager.get_filtered_history("All", "All")
	var std_records := HistoryManager.get_filtered_history("All", "Standard")
	var rep_records := HistoryManager.get_filtered_history("All", "Replay")

	assert_true(all_records.size() >= std_records.size() + rep_records.size(), "All filter returns all records")

	var all_std_valid := true
	for r in std_records:
		if r.get("is_replay", false) == true:
			all_std_valid = false
			break
	assert_true(all_std_valid, "Standard filter contains zero replay records")

	var all_rep_valid := true
	for r in rep_records:
		if r.get("is_replay", false) != true:
			all_rep_valid = false
			break
	assert_true(all_rep_valid, "Replay filter contains only replay records")

func test_history_screen_replay_button_and_filter() -> void:
	print("\n--- Test 4: HistoryScreen replay action and filtering ---")
	var screen := HistoryScreen.new()
	root.add_child(screen)
	screen.refresh_history()

	assert_true(screen.status_opt != null, "HistoryScreen has status filter OptionButton")
	assert_true(screen.status_opt.item_count == 3, "Status filter has 3 options (All, Standard, Replay)")

	# Verify replay buttons exist on history cards
	var found_replay_btn := false
	if screen.list_vbox.get_child_count() > 0:
		var first_child = screen.list_vbox.get_child(0)
		if first_child is PanelContainer and first_child.get_child_count() > 0:
			var hbox = first_child.get_child(0)
			for c in hbox.get_children():
				if c is Button and (c.text.contains("Tekrar") or c.text.contains("Replay") or c.tooltip_text.contains("Tekrar") or c.tooltip_text.contains("Replay") or c.name == "ReplayButton"):
					found_replay_btn = true
					break
	assert_true(found_replay_btn, "History card has a replay button")

	# Verify signal exists and has correct signature
	assert_true(screen.has_signal("replay_requested"), "HistoryScreen has replay_requested signal")

	# Test connectivity: connect with Callable method binding
	var tracker := SignalTracker.new()
	screen.replay_requested.connect(tracker.on_replay)
	screen.replay_requested.emit(12345, "medium")
	assert_true(tracker.received, "replay_requested signal received by listener")
	assert_true(tracker.seed_val == 12345, "Signal emitted with correct seed: %d" % tracker.seed_val)
	assert_true(tracker.diff == "medium", "Signal emitted with correct difficulty: %s" % tracker.diff)

	screen.queue_free()

func test_game_screen_replay_action_and_score_comparison() -> void:
	print("\n--- Test 5: GameScreen replay dialog action and best score comparison ---")
	var screen := GameScreen.new()
	root.add_child(screen)

	var gen := SudokuGenerator.generate(55443322, DifficultyAnalyzer.LEVEL_EASY)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	screen.setup_game(state)

	assert_true(screen.complete_replay_btn != null, "GameScreen complete dialog has replay button")

	var summary := {
		"game_id": state.game_id,
		"difficulty": state.difficulty,
		"seed": state.seed_value,
		"time": 95.0,
		"mistakes": 0,
		"hints": 0,
		"score": 94,
		"is_replay": false
	}
	screen._on_game_completed(summary)

	assert_true(screen.complete_summary.score_label.text == "94", "Complete dialog shows the score: %s" % screen.complete_summary.score_label.text)

	# Trigger custom action "replay"
	screen._on_complete_custom_action("replay")
	assert_true(screen.game_state.is_replay == true, "After replay action, current game_state is_replay is true")
	assert_true(screen.game_state.elapsed_time == 0.0, "After replay action, elapsed time is 0.0")
	assert_true(screen.game_state.mistakes_count == 0, "After replay action, mistakes count is 0")

	# Complete the replay with comparison
	var replay_summary := {
		"game_id": screen.game_state.game_id,
		"difficulty": screen.game_state.difficulty,
		"seed": screen.game_state.seed_value,
		"time": 80.0,
		"mistakes": 0,
		"hints": 0,
		"score": 98,
		"is_replay": true
	}
	screen._on_game_completed(replay_summary)
	var result_text: String = screen.complete_summary.highlight_labels[0].text
	var comparison_prefix: String = LocalizationManager.translate("SCORE_BEST_COMPARISON").split("%")[0]
	assert_true(result_text.contains(LocalizationManager.translate("NEW_BEST_SCORE")) or result_text.contains(comparison_prefix), "Replay completion contains best score comparison text")

	screen.queue_free()
