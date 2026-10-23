extends RefCounted

## What a finished game leaves behind: its saved slot marked finished, the Daily day, the history
## record, and what the result screen compares it with. Kept out of GameScreen so the screen only
## shows the result.

const DailyManager = preload("res://scripts/data/daily_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const AchievementManager = preload("res://scripts/data/achievement_manager.gd")

## Records a finished game. `summary` gets "is_daily"; returns {"bench", "prev_best", "streak",
## "new_achievements"}, each as it was before this game, for the result screen.
static func record(state: GameState, summary: Dictionary) -> Dictionary:
	SaveManager.clear_active_game()
	if state != null and state.is_completed:
		# Marks it finished in the index, so it leaves the saved games list
		SaveManager.save_game_slot(state)

	# Achievements as they were before this game is recorded (GDD §36)
	var achievements_before := AchievementManager.status()
	var seed_val: int = int(summary.get("seed", 0))
	# Only a Daily solved on its own day counts as one (streaks, achievements); an archive day
	# is marked done in the calendar
	var daily_date := DailyManager.date_for_seed(seed_val)
	var is_daily: bool = daily_date == DailyManager.get_today_date_string()
	summary["is_daily"] = is_daily
	if not daily_date.is_empty():
		DailyManager.mark_completed(daily_date)
		if state != null:
			DailyManager.save_daily_game(state, daily_date)

	# References as they were before this game, then record it (GDD §25, §26)
	var difficulty: String = summary.get("difficulty", DifficultyAnalyzer.LEVEL_MEDIUM)
	var prev_best := HistoryManager.get_best_record_for_seed(seed_val)
	var bench := HistoryManager.get_level_benchmarks(difficulty)
	HistoryManager.add_record(summary)

	return {
		"bench": bench,
		"prev_best": prev_best,
		"streak": DailyManager.get_current_streak() if is_daily else 0,
		"new_achievements": AchievementManager.newly_unlocked(achievements_before, AchievementManager.status()),
	}
