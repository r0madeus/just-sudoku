extends SceneTree

## Daily Sudoku archive: dates and seeds of past days, streaks that only count days solved on the
## day, the calendar, and playing a past day from it to the end

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const AchievementManager = preload("res://scripts/data/achievement_manager.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
const DailyArchiveScreen = preload("res://scenes/menus/daily_archive_screen.gd")
const AppRoot = preload("res://scenes/app_root.gd")

var _passed: int = 0
var _failed: int = 0
var today: String = ""

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	print("\n=== DAILY SUDOKU ARCHIVE ===")
	today = DailyManager.get_today_date_string()
	AppSettings.animations_enabled = false
	_test_dates()
	_test_seeds()
	_test_streaks()
	_test_names()
	await _test_play_past_day()
	await _test_calendar()
	await _test_calendar_motion()
	await _test_app_flow()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_dates() -> void:
	_check("A day after the end of February in a leap year", DailyManager.add_days("2028-02-28", 1) == "2028-02-29")
	_check("and in another year", DailyManager.add_days("2027-02-28", 1) == "2027-03-01")
	_check("Back over New Year", DailyManager.add_days("2027-01-01", -1) == "2026-12-31")
	_check("Days between two dates", DailyManager.days_between("2026-10-01", "2026-11-01") == 31)
	_check("Today is in the archive", DailyManager.is_in_archive(today))
	_check("So is a day a year back", DailyManager.is_in_archive(DailyManager.add_days(today, -(DailyManager.ARCHIVE_DAYS - 1))))
	_check("but not one before that", not DailyManager.is_in_archive(DailyManager.add_days(today, -DailyManager.ARCHIVE_DAYS)))
	_check("nor tomorrow", not DailyManager.is_in_archive(DailyManager.add_days(today, 1)))
	_check("The archive screen knows each month's length",
		DailyArchiveScreen.days_in_month(2028, 2) == 29 and DailyArchiveScreen.days_in_month(2026, 2) == 28
		and DailyArchiveScreen.days_in_month(2026, 4) == 30 and DailyArchiveScreen.days_in_month(2026, 12) == 31)

func _test_seeds() -> void:
	_check("Today's seed is today's Daily", DailyManager.date_for_seed(DailyManager.get_today_seed()) == today)
	var past := DailyManager.add_days(today, -40)
	_check("A past day's seed gives that day back", DailyManager.date_for_seed(DailyManager.get_seed_for_date_string(past)) == past)
	var old := DailyManager.add_days(today, -DailyManager.ARCHIVE_DAYS - 3)
	_check("A day older than the archive is not a Daily any more", DailyManager.date_for_seed(DailyManager.get_seed_for_date_string(old)) == "")
	_check("Other puzzles are no Daily", DailyManager.date_for_seed(12345) == "")

func _reset_daily() -> void:
	DailyManager.save_daily_data({"completed_dates": [], "current_streak": 0, "longest_streak": 0, "last_completed_date": ""})

func _test_streaks() -> void:
	_reset_daily()
	DailyManager.mark_completed(today)
	_check("Solving today starts a streak", DailyManager.get_current_streak() == 1)
	var data := DailyManager.load_daily_data()
	data.last_completed_date = DailyManager.add_days(today, -3)
	data.current_streak = 5
	data.longest_streak = 5
	DailyManager.save_daily_data(data)
	_check("A streak with a missed day is over", DailyManager.get_current_streak() == 0)
	data.last_completed_date = DailyManager.add_days(today, -1)
	DailyManager.save_daily_data(data)
	_check("Solved yesterday: the streak still stands today", DailyManager.get_current_streak() == 5)

	_reset_daily()
	var past := DailyManager.add_days(today, -10)
	DailyManager.mark_completed(past)
	data = DailyManager.load_daily_data()
	_check("A past day solved from the archive does not start a streak",
		DailyManager.get_current_streak() == 0 and int(data.longest_streak) == 0 and data.completed_dates.is_empty())
	_check("It is kept as solved later", data.archive_dates == [past])
	DailyManager.mark_completed(past)
	_check("Solving it again changes nothing", DailyManager.load_daily_data().archive_dates.size() == 1)
	_check("Days solved count both kinds", DailyManager.solved_dates().size() == 1)
	_check("No achievement for a Daily solved later",
		not AchievementManager.evaluate([], DailyManager.load_daily_data().completed_dates)["daily_first"].unlocked)
	DailyManager.mark_completed(today)
	_check("Statuses: on the day, later, nothing",
		DailyManager.get_day_status(today) == DailyManager.DayStatus.DONE
		and DailyManager.get_day_status(past) == DailyManager.DayStatus.DONE_LATE
		and DailyManager.get_day_status(DailyManager.add_days(today, -2)) == DailyManager.DayStatus.NONE)
	var started := DailyManager.add_days(today, -5)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(DailyManager.get_seed_for_date_string(started), DifficultyAnalyzer.LEVEL_MEDIUM))
	DailyManager.save_daily_game(state, started)
	_check("A day with a saved game is started", DailyManager.get_day_status(started) == DailyManager.DayStatus.IN_PROGRESS)
	_check("Its game loads back", DailyManager.load_daily_game(started).seed_value == state.seed_value)
	_reset_daily()

func _test_names() -> void:
	LocalizationManager.set_locale("tr")
	_check("Turkish short date", LocalizationManager.format_short_date("2026-03-07") == "7 Mar")
	_check("Turkish month", LocalizationManager.format_month_year(2026, 8) == "Ağustos 2026")
	LocalizationManager.set_locale("en")
	_check("English short date", LocalizationManager.format_short_date("2026-03-07") == "Mar 7")
	_check("English month", LocalizationManager.format_month_year(2026, 10) == "October 2026")

func _new_screen() -> GameScreen:
	var screen := GameScreen.new()
	root.add_child(screen)
	await process_frame
	return screen

func _test_play_past_day() -> void:
	_reset_daily()
	var past := DailyManager.add_days(today, -3)
	var gen := SudokuGenerator.generate(DailyManager.get_seed_for_date_string(past), DifficultyAnalyzer.LEVEL_MEDIUM)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	var screen := await _new_screen()
	screen.setup_game(state)
	_check("The title says it is the Daily of that day",
		screen.info_label.text.contains(LocalizationManager.translate("BTN_DAILY_SUDOKU"))
		and screen.info_label.text.contains(LocalizationManager.format_short_date(past)))
	var first_empty := -1
	for i in 81:
		if state.current_board.is_empty(i):
			first_empty = i
			break
	screen.sudoku_grid.select_cell(first_empty)
	screen._apply_key(gen.solution.get_cell(first_empty), screen.sudoku_grid.get_target_cells())
	_check("Moves are saved to that day's game",
		DailyManager.load_daily_game(past) != null and DailyManager.load_daily_game(past).current_board.get_cell(first_empty) != 0)
	var records_before := HistoryManager.load_all_records().size()
	for i in 81:
		if state.current_board.is_empty(i):
			state.set_number(i, gen.solution.get_cell(i), false)
	var data := DailyManager.load_daily_data()
	_check("Solving it marks the day solved later, not on the day",
		data.get("archive_dates", []).has(past) and not data.completed_dates.has(past))
	_check("The streak is untouched", DailyManager.get_current_streak() == 0)
	var records := HistoryManager.load_all_records()
	_check("It goes into the history, not as today's Daily",
		records.size() == records_before + 1 and not records[records.size() - 1].get("is_daily", true))
	_check("The finished game is kept for that day", DailyManager.load_daily_game(past).is_completed)

	# Today's Daily still counts as before
	var today_state := GameState.new()
	today_state.init_from_puzzle(SudokuGenerator.generate(DailyManager.get_today_seed(), DifficultyAnalyzer.LEVEL_MEDIUM))
	screen.setup_game(today_state)
	_check("Today's title has no date", not screen.info_label.text.contains(LocalizationManager.format_short_date(today)))
	for i in 81:
		if today_state.current_board.is_empty(i):
			today_state.set_number(i, today_state.solution.get_cell(i), false)
	_check("Today's Daily counts for the streak", DailyManager.get_current_streak() == 1 and DailyManager.is_today_completed())
	records = HistoryManager.load_all_records()
	_check("and is recorded as the Daily", records[records.size() - 1].get("is_daily", false))
	screen.queue_free()
	await process_frame

func _test_calendar() -> void:
	_reset_daily()
	var past := DailyManager.add_days(today, -1)
	DailyManager.mark_completed(past)
	DailyManager.mark_completed(today)
	var screen := DailyArchiveScreen.new()
	root.add_child(screen)
	await process_frame
	screen.show_current_month()
	var t := DailyManager.get_today_dict()
	_check("The calendar opens on this month", screen.year == t.year and screen.month == t.month)
	_check("with a button for each day", screen.day_buttons.size() == DailyArchiveScreen.days_in_month(t.year, t.month))
	_check("The month is named", screen.month_label.text == LocalizationManager.format_month_year(t.year, t.month))
	_check("Today is marked solved on the day", screen.day_buttons[today].get_meta("status") == DailyManager.DayStatus.DONE)
	if screen.day_buttons.has(past):
		_check("Yesterday is marked solved later", screen.day_buttons[past].get_meta("status") == DailyManager.DayStatus.DONE_LATE)
	var tomorrow := DailyManager.add_days(today, 1)
	if screen.day_buttons.has(tomorrow):
		_check("Later days cannot be played", screen.day_buttons[tomorrow].disabled)
	_check("There is no next month yet", screen.next_btn.disabled)
	_check("Streak, longest and days solved are shown",
		screen.streak_values[0].text == "1" and screen.streak_values[2].text == "2")
	var picked := [""]
	screen.day_requested.connect(func(d): picked[0] = d)
	screen.day_buttons[today].pressed.emit()
	_check("Tapping a day asks for it", picked[0] == today)

	var first_wd: int = Time.get_datetime_dict_from_unix_time(
		Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": 1, "hour": 12})).weekday
	_check("The 1st sits under its weekday (Monday first)",
		screen.days_grid.get_child(7 + (first_wd + 6) % 7) == screen.day_buttons[DailyManager.get_date_string(t.year, t.month, 1)])

	for i in 14:
		screen.change_month(-1)
	var oldest := DailyManager.parse_date(DailyManager.add_days(today, -(DailyManager.ARCHIVE_DAYS - 1)))
	_check("Going back stops at the archive's first month", screen.year == oldest.year and screen.month == oldest.month and screen.prev_btn.disabled)
	var too_old := DailyManager.get_date_string(oldest.year, oldest.month, 1)
	if not DailyManager.is_in_archive(too_old):
		_check("Days before the archive cannot be played", screen.day_buttons[too_old].disabled)
	screen.change_month(1)
	_check("and forward again", screen.year * 12 + screen.month == oldest.year * 12 + oldest.month + 1)
	screen.queue_free()
	await process_frame

## The month's days fade in when the screen opens and when the month changes; the days are round
func _test_calendar_motion() -> void:
	var was: bool = AppSettings.animations_enabled
	var screen := DailyArchiveScreen.new()
	root.add_child(screen)
	await process_frame
	AppSettings.animations_enabled = true
	screen.show_current_month()
	await process_frame
	await process_frame
	var some: Button = screen.day_buttons.values()[0]
	_check("Opening the archive fades its days in (they start see-through)", screen._pop_count == screen.day_buttons.size() and some.modulate.a < 1.0)
	await create_timer(1.0).timeout
	_check("and they end at full size", is_equal_approx(some.modulate.a, 1.0))
	screen.change_month(-1)
	await process_frame
	await process_frame
	var other: Button = screen.day_buttons.values()[0]
	_check("Going to another month fades its days in too", other.modulate.a < 1.0 and screen._pop_count == screen.day_buttons.size())
	_check("The days are round (a circle, not a rounded square)", (other.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left >= 20)
	var arrow := screen.prev_btn.get_theme_stylebox("normal") as StyleBoxFlat
	_check("The month arrows are round, softly filled buttons", arrow != null and arrow.bg_color.a > 0.0 and arrow.corner_radius_top_left >= 20)
	AppSettings.animations_enabled = false
	screen.change_month(1)
	await process_frame
	_check("With animations off the days are simply there", (screen.day_buttons.values()[0] as Button).modulate.a == 1.0)
	AppSettings.animations_enabled = was
	screen.queue_free()
	await process_frame

func _test_app_flow() -> void:
	_reset_daily()
	SaveManager.clear_active_game()
	var app := AppRoot.new()
	root.add_child(app)
	await process_frame
	app.main_menu.daily_archive_btn.pressed.emit()
	_check("The calendar button opens the archive", app.current_screen == app.daily_archive_screen)
	var past := DailyManager.add_days(today, -6)
	app.daily_archive_screen.day_requested.emit(past)
	for i in 600:
		if app.current_screen == app.game_screen:
			break
		await process_frame
	_check("A past day opens its puzzle", app.current_screen == app.game_screen
		and app.game_screen.game_state.seed_value == DailyManager.get_seed_for_date_string(past))
	var game_id: String = app.game_screen.game_state.game_id
	_check("and keeps it as that day's game", DailyManager.has_daily_game(past))
	app.game_screen._on_back_pressed()
	_check("Back from it goes to the menu", app.current_screen == app.main_menu)
	app.main_menu.daily_archive_requested.emit()
	app.daily_archive_screen.day_requested.emit(past)
	_check("The same day again continues that game", app.current_screen == app.game_screen
		and app.game_screen.game_state.game_id == game_id)
	app.game_screen._on_back_pressed()
	app.main_menu.daily_archive_requested.emit()
	app.daily_archive_screen.refresh()
	_check("The calendar shows the day as started",
		app.daily_archive_screen.day_buttons.get(past) == null
		or app.daily_archive_screen.day_buttons[past].get_meta("status") == DailyManager.DayStatus.IN_PROGRESS)
	app.handle_back()
	_check("Android back leaves the archive for the menu", app.current_screen == app.main_menu)
	app.queue_free()
	await process_frame
