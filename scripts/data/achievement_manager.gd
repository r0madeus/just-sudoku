class_name AchievementManager
extends RefCounted

## Achievements (GDD §36): a few quiet milestones, no XP or levels. Nothing is stored for them:
## each one is worked out from the game history and the Daily Sudoku dates, so they never
## disagree with what was played, and players who already had games get theirs too, dated by
## the game that earned them. A game finished by applying the solution does not count.

const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")

## A score this high or higher earns HIGH_SCORE
const HIGH_SCORE: int = 95
const LEVELS: Array[String] = ["easy", "medium", "hard", "expert"]

## In display order. `target` > 1 shows progress ("7 / 10") until the achievement is earned.
const ALL: Array[Dictionary] = [
	{"id": "first_solve", "target": 1},
	{"id": "solves_10", "target": 10},
	{"id": "solves_50", "target": 50},
	{"id": "solves_100", "target": 100},
	{"id": "first_hard", "target": 1},
	{"id": "first_expert", "target": 1},
	{"id": "all_levels", "target": 4},
	{"id": "clean_solve", "target": 1},
	{"id": "clean_expert", "target": 1},
	{"id": "high_score", "target": 1},
	{"id": "daily_first", "target": 1},
	{"id": "streak_7", "target": 7},
	{"id": "streak_30", "target": 30},
]

## Every achievement as {id: {unlocked, date (unix, 0 if unknown), progress, target}}
static func status() -> Dictionary:
	var daily: Dictionary = DailyManager.load_daily_data()
	return evaluate(HistoryManager.load_all_records(), daily.get("completed_dates", []))

## The same from given records and Daily dates ("YYYY-MM-DD"), oldest record first
static func evaluate(records: Array, daily_dates: Array) -> Dictionary:
	var out: Dictionary = {}
	for a in ALL:
		out[a["id"]] = {"unlocked": false, "date": 0, "progress": 0, "target": a["target"]}

	var solves: int = 0
	var levels: Dictionary = {}
	for r in records:
		if r.get("assisted", false):
			continue
		var when: int = int(r.get("timestamp", 0))
		var level: String = String(r.get("difficulty", "")).to_lower()
		var clean: bool = int(r.get("mistakes", 0)) == 0 and int(r.get("hints", 0)) == 0
		solves += 1
		levels[level] = true
		for id in ["first_solve", "solves_10", "solves_50", "solves_100"]:
			_count(out[id], solves, when)
		_count(out["all_levels"], LEVELS.filter(func(l): return levels.has(l)).size(), when)
		if level == "hard":
			_count(out["first_hard"], 1, when)
		if level == "expert":
			_count(out["first_expert"], 1, when)
		if clean:
			_count(out["clean_solve"], 1, when)
		if clean and level == "expert":
			_count(out["clean_expert"], 1, when)
		if int(r.get("score", 0)) >= HIGH_SCORE:
			_count(out["high_score"], 1, when)
		if r.get("is_daily", false):
			_count(out["daily_first"], 1, when)

	# Streaks from the Daily dates: the day a run of consecutive days first reached the length
	# Noon of each day in local time, so date_text() shows that same day
	var local_offset: int = _local_offset()
	var days: Array = []
	for d in daily_dates:
		var unix: int = Time.get_unix_time_from_datetime_string(String(d) + "T12:00:00") - local_offset
		if unix > 0 and not days.has(unix):
			days.append(unix)
	days.sort()
	var run: int = 0
	var prev: int = 0
	for unix in days:
		run = run + 1 if prev > 0 and roundi((unix - prev) / 86400.0) == 1 else 1
		prev = unix
		for id in ["daily_first", "streak_7", "streak_30"]:
			_count(out[id], run if id != "daily_first" else 1, unix)
	return out

## Raises progress to `value` (never lowers it) and unlocks, dated `when`, on reaching the target
static func _count(entry: Dictionary, value: int, when: int) -> void:
	entry["progress"] = maxi(int(entry["progress"]), value)
	if not entry["unlocked"] and entry["progress"] >= int(entry["target"]):
		entry["unlocked"] = true
		entry["date"] = when

## Ids unlocked in `after` but not in `before`, in display order
static func newly_unlocked(before: Dictionary, after: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for a in ALL:
		var id: String = a["id"]
		if after.get(id, {}).get("unlocked", false) and not before.get(id, {}).get("unlocked", false):
			ids.append(id)
	return ids

static func unlocked_count(st: Dictionary) -> int:
	var n: int = 0
	for id in st:
		if st[id]["unlocked"]:
			n += 1
	return n

## The unlock date in the player's format and time zone
static func date_text(unix: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix + _local_offset())
	return LocalizationManager.format_date(d["year"], d["month"], d["day"])

static func _local_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

static func title(id: String) -> String:
	return LocalizationManager.translate("ACH_" + id.to_upper())

static func description(id: String) -> String:
	return LocalizationManager.translate("ACH_" + id.to_upper() + "_DESC")
