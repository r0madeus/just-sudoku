extends SceneTree

## Achievements (GDD §36): worked out from the history and the Daily dates, never from a game
## finished by showing the solution; a new one is named on the result screen, and Statistics
## lists all of them with their date or progress.

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")

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
	print("🧪 RUNNING ACHIEVEMENT TESTS")
	print("========================================")
	SettingsScreen.animations_enabled = false
	var prev_locale := LocalizationManager.get_locale()
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)
	# The player's own history and Daily dates are put back afterwards
	var saved_records: Array[Dictionary] = HistoryManager.load_all_records(true).duplicate(true)
	var saved_daily: Dictionary = DailyManager.load_daily_data()

	test_counts_and_dates()
	test_conditions()
	test_streaks()
	test_newly_unlocked()
	test_texts()
	await test_result_names_new_achievement()
	await test_statistics_card()

	HistoryManager.save_all_records(saved_records)
	DailyManager.save_daily_data(saved_daily)
	LocalizationManager.set_locale(prev_locale)
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func _rec(level: String, when: int, extra: Dictionary = {}) -> Dictionary:
	var r := {"difficulty": level, "timestamp": when, "score": 70, "mistakes": 1, "hints": 0}
	r.merge(extra, true)
	return r

func test_counts_and_dates() -> void:
	print("\n--- Test 1: Solve counts, dated by the game that earned them ---")
	var st := AchievementManager.evaluate([], [])
	assert_true(st.size() == AchievementManager.ALL.size() and AchievementManager.unlocked_count(st) == 0, "Nothing earned with no games")

	var records: Array = []
	for i in range(12):
		records.append(_rec("easy", 1000 + i))
	st = AchievementManager.evaluate(records, [])
	assert_true(st["first_solve"]["unlocked"] and st["first_solve"]["date"] == 1000, "First solve, dated by the first game")
	assert_true(st["solves_10"]["unlocked"] and st["solves_10"]["date"] == 1009, "10 solves, dated by the tenth game")
	assert_true(not st["solves_50"]["unlocked"] and st["solves_50"]["progress"] == 12, "50 solves: 12 / 50 (%d)" % st["solves_50"]["progress"])

	records.insert(0, _rec("expert", 900, {"assisted": true, "mistakes": 0, "score": 99, "is_daily": true}))
	st = AchievementManager.evaluate(records, [])
	assert_true(not st["first_expert"]["unlocked"] and not st["high_score"]["unlocked"] and not st["daily_first"]["unlocked"]
		and st["first_solve"]["date"] == 1000 and st["solves_50"]["progress"] == 12,
		"A shown solution earns nothing and is not counted")

func test_conditions() -> void:
	print("\n--- Test 2: Levels, clean solves, high score ---")
	var records: Array = [
		_rec("easy", 1), _rec("medium", 2), _rec("hard", 3, {"hints": 1}),
		_rec("expert", 4, {"mistakes": 0, "hints": 1}), _rec("medium", 5, {"mistakes": 0, "score": 95}),
	]
	var st := AchievementManager.evaluate(records, [])
	assert_true(st["first_hard"]["date"] == 3 and st["first_expert"]["date"] == 4, "First Hard and first Expert")
	assert_true(st["all_levels"]["unlocked"] and st["all_levels"]["date"] == 4, "Every level, on the fourth level's game")
	assert_true(st["clean_solve"]["date"] == 5, "Flawless needs no mistake and no hint (a hint is not clean)")
	assert_true(not st["clean_expert"]["unlocked"], "An Expert with a hint is not Flawless Expert")
	assert_true(st["high_score"]["date"] == 5, "Score 95 counts from 95")

	st = AchievementManager.evaluate([_rec("easy", 1), _rec("hard", 2)], [])
	assert_true(not st["all_levels"]["unlocked"] and st["all_levels"]["progress"] == 2, "Two levels of four: progress 2")
	st = AchievementManager.evaluate([_rec("EXPERT", 7, {"mistakes": 0})], [])
	assert_true(st["clean_expert"]["unlocked"] and st["first_expert"]["unlocked"], "Flawless Expert (level names in any case)")

func test_streaks() -> void:
	print("\n--- Test 3: Daily streaks from the Daily dates ---")
	var dates: Array = []
	var start: int = Time.get_unix_time_from_datetime_string("2026-01-25T12:00:00")
	for i in range(9):
		if i == 3:
			continue # a missed day breaks the run
		dates.append(Time.get_date_string_from_unix_time(start + i * 86400))
	var st := AchievementManager.evaluate([], dates)
	assert_true(st["daily_first"]["unlocked"], "First Daily from the dates alone")
	assert_true(not st["streak_7"]["unlocked"] and st["streak_7"]["progress"] == 5, "A gap restarts the run (longest 5)")

	dates.append(Time.get_date_string_from_unix_time(start + 9 * 86400))
	dates.append(Time.get_date_string_from_unix_time(start + 10 * 86400))
	dates.reverse() # order of the file does not matter
	st = AchievementManager.evaluate([], dates)
	assert_true(st["streak_7"]["unlocked"], "Seven days in a row")
	assert_true(AchievementManager.date_text(st["streak_7"]["date"]) == LocalizationManager.format_date(2026, 2, 4),
		"Dated by the seventh day in the player's time zone (%s)" % AchievementManager.date_text(st["streak_7"]["date"]))
	assert_true(not st["streak_30"]["unlocked"] and st["streak_30"]["progress"] == 7, "30-day streak: 7 / 30")

	# Across a month and a year end
	dates = ["2025-12-30", "2025-12-31", "2026-01-01"]
	assert_true(AchievementManager.evaluate([], dates)["streak_7"]["progress"] == 3, "Runs continue across the new year")

func test_newly_unlocked() -> void:
	print("\n--- Test 4: What a game newly earns ---")
	var before := AchievementManager.evaluate([], [])
	var after := AchievementManager.evaluate([_rec("expert", 1, {"mistakes": 0, "score": 97})], [])
	var ids := AchievementManager.newly_unlocked(before, after)
	assert_true(ids == ["first_solve", "first_expert", "clean_solve", "clean_expert", "high_score"],
		"In display order: %s" % str(ids))
	assert_true(AchievementManager.newly_unlocked(after, after).is_empty(), "Nothing new the second time")

func test_texts() -> void:
	print("\n--- Test 5: Every achievement has a title and a description in both languages ---")
	var missing: Array = []
	for a in AchievementManager.ALL:
		var key := "ACH_" + String(a["id"]).to_upper()
		for k in [key, key + "_DESC"]:
			if not LocalizationManager.DICTIONARY_EN.has(k) or not LocalizationManager.DICTIONARY_TR.has(k):
				missing.append(k)
	assert_true(missing.is_empty(), "No missing texts %s" % str(missing))
	assert_true(ThemeManager.get_icon("award") != null and ThemeManager.get_icon("lock") != null, "Award and lock icons load")

## Plays `state` up to its last empty cell on `screen` and fills it
func _finish(screen: GameScreen, state: GameState) -> void:
	var last := -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			if last != -1:
				state.set_number(last, state.solution.get_cell(last))
			last = i
	screen.sudoku_grid.select_cell(last)
	screen._on_numpad_number_pressed(state.solution.get_cell(last))

func _play_one(seed_val: int) -> GameScreen:
	var screen := GameScreen.new()
	root.add_child(screen)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	screen.setup_game(state)
	_finish(screen, state)
	return screen

func test_result_names_new_achievement() -> void:
	print("\n--- Test 6: The result names an achievement the game earned ---")
	var empty: Array[Dictionary] = []
	HistoryManager.save_all_records(empty)
	DailyManager.save_daily_data({"completed_dates": [], "current_streak": 0, "longest_streak": 0, "last_completed_date": ""})

	var screen := _play_one(7001)
	var summary := screen.complete_summary
	assert_true(screen.complete_dialog.visible and summary.achievement_row.visible, "Achievement line shown on the first solve")
	assert_true(summary.achievement_label.text.contains(AchievementManager.title("first_solve")),
		"Names it: %s" % summary.achievement_label.text)
	screen.queue_free()
	await _frames(2)

	screen = _play_one(7002)
	summary = screen.complete_summary
	assert_true(screen.complete_dialog.visible and not summary.achievement_row.visible, "Nothing new, no line (%s)" % summary.achievement_label.text)
	screen.queue_free()
	await _frames(2)

	# A one-off earn uses the singular
	summary = ResultSummary.new()
	root.add_child(summary)
	var one: Array[String] = ["streak_7"]
	var lines: Array[String] = []
	summary.show_result({"score": 80}, lines, one)
	assert_true(summary.achievement_label.text == LocalizationManager.translate("ACH_NEW") % AchievementManager.title("streak_7"),
		"One achievement: %s" % summary.achievement_label.text)
	summary.queue_free()
	await _frames(1)

func test_statistics_card() -> void:
	print("\n--- Test 7: Statistics lists every achievement ---")
	var stats := StatisticsScreen.new()
	root.add_child(stats)
	await _frames(2)
	stats.refresh_stats()
	await _frames(2)
	var card: Control = stats.stats_vbox.find_child("AchievementsCard", true, false)
	assert_true(card != null, "Achievements card present")
	if card == null:
		return
	var rows: Array = card.find_children("Achievement_*", "", true, false)
	assert_true(rows.size() == AchievementManager.ALL.size(), "%d rows" % rows.size())
	var first: Control = card.find_child("Achievement_first_solve", true, false)
	var side: Label = first.find_child("Side", true, false) if first != null else null
	assert_true(first != null and first.modulate.a == 1.0 and side != null
		and side.text == AchievementManager.date_text(int(Time.get_unix_time_from_system())),
		"Earned: full strength, today's date (%s)" % (side.text if side != null else "none"))
	var ten: Control = card.find_child("Achievement_solves_10", true, false)
	side = ten.find_child("Side", true, false) if ten != null else null
	assert_true(ten != null and ten.modulate.a < 1.0 and side != null and side.text == "2 / 10",
		"Not yet earned: dimmed, with progress (%s)" % (side.text if side != null else "none"))
	var hard: Control = card.find_child("Achievement_first_hard", true, false)
	assert_true(hard != null and hard.find_child("Side", true, false) == null, "A one-off goal shows no progress")
	stats.queue_free()
	await _frames(2)
