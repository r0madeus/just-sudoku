class_name StatisticsManager
extends RefCounted

## Computes primary and detailed statistics derived from History & Daily (GDD §33)

static func get_summary_statistics() -> Dictionary:
	var records := HistoryManager.load_all_records()
	var total_completed: int = records.size()

	var total_time: float = 0.0
	var best_score: int = 0
	var daily_streak: int = DailyManager.get_current_streak()

	for r in records:
		total_time += float(r.get("time", 0.0))
		best_score = maxi(best_score, int(r.get("score", 0)))

	var avg_time: float = total_time / maxf(1.0, float(total_completed))

	return {
		"completed_games": total_completed,
		"current_streak": daily_streak,
		"average_time": avg_time,
		"best_score": best_score,
		"completion_rate": 100.0 if total_completed > 0 else 0.0
	}

static func get_detailed_statistics() -> Dictionary:
	var records := HistoryManager.load_all_records()
	var summary := get_summary_statistics()

	var diff_stats: Dictionary = {
		DifficultyAnalyzer.LEVEL_EASY: { "count": 0, "total_time": 0.0, "total_mistakes": 0, "total_hints": 0, "best_time": 999999.0, "best_score": 0 },
		DifficultyAnalyzer.LEVEL_MEDIUM: { "count": 0, "total_time": 0.0, "total_mistakes": 0, "total_hints": 0, "best_time": 999999.0, "best_score": 0 },
		DifficultyAnalyzer.LEVEL_HARD: { "count": 0, "total_time": 0.0, "total_mistakes": 0, "total_hints": 0, "best_time": 999999.0, "best_score": 0 },
		DifficultyAnalyzer.LEVEL_EXPERT: { "count": 0, "total_time": 0.0, "total_mistakes": 0, "total_hints": 0, "best_time": 999999.0, "best_score": 0 },
	}

	for r in records:
		var d: String = r.get("difficulty", DifficultyAnalyzer.LEVEL_MEDIUM)
		if diff_stats.has(d):
			var entry: Dictionary = diff_stats[d]
			entry["count"] += 1
			var t: float = float(r.get("time", 0.0))
			entry["total_time"] += t
			entry["total_mistakes"] += int(r.get("mistakes", 0))
			entry["total_hints"] += int(r.get("hints", 0))
			entry["best_score"] = maxi(entry["best_score"], int(r.get("score", 0)))
			if t < entry["best_time"]:
				entry["best_time"] = t

	# Compute averages
	for d in diff_stats.keys():
		var entry: Dictionary = diff_stats[d]
		var c: float = maxf(1.0, float(entry["count"]))
		entry["avg_time"] = entry["total_time"] / c
		entry["avg_mistakes"] = float(entry["total_mistakes"]) / c
		entry["avg_hints"] = float(entry["total_hints"]) / c
		if entry["count"] == 0:
			entry["best_time"] = 0.0

	return {
		"summary": summary,
		"difficulties": diff_stats,
		"longest_streak": DailyManager.get_longest_streak()
	}
