class_name DailyManager
extends RefCounted

## Handles offline deterministic Daily Sudoku and streak tracking (GDD §34, §35)

const DAILY_FILE: String = "user://saves/daily.json"
const DAILY_GAME_PREFIX: String = "user://saves/daily_game_"
const DAILY_SALT: int = 0x5D3F19A2B4C8E701
## How far back the archive goes: older days are not offered (and their seeds not looked up)
const ARCHIVE_DAYS: int = 366

## What the archive shows for a day
enum DayStatus { NONE, IN_PROGRESS, DONE, DONE_LATE }

# Seed -> "YYYY-MM-DD" for the archive's days, rebuilt when the date changes
static var _seed_dates: Dictionary = {}
static var _seed_dates_for: String = ""

static func get_today_dict() -> Dictionary:
	return Time.get_date_dict_from_system()

static func get_date_string(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]

static func get_today_date_string() -> String:
	var d := get_today_dict()
	return get_date_string(d["year"], d["month"], d["day"])

static func get_seed_for_date(year: int, month: int, day: int) -> int:
	var date_int: int = year * 10000 + month * 100 + day
	# Mix with Knuth 63-bit multiplier for a rich deterministic seed
	var mixed: int = (date_int ^ DAILY_SALT) & 0x7FFFFFFFFFFFFFFF
	var rng := SudokuGenerator.DeterministicRNG.new(mixed)
	return int(rng.next_int() & 0x7FFFFFFF)

static func get_today_seed() -> int:
	var d := get_today_dict()
	return get_seed_for_date(d["year"], d["month"], d["day"])

## Noon of a date in UTC, so whole days apart are whole multiples of 86400 whatever the time zone
static func _noon_unix(year: int, month: int, day: int) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})

static func parse_date(date_str: String) -> Dictionary:
	var parts := date_str.split("-")
	if parts.size() != 3:
		return {}
	return {"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int()}

## The date `days` days after date_str (negative: before)
static func add_days(date_str: String, days: int) -> String:
	var d := parse_date(date_str)
	if d.is_empty():
		return ""
	var t := Time.get_datetime_dict_from_unix_time(_noon_unix(d.year, d.month, d.day) + days * 86400)
	return get_date_string(t["year"], t["month"], t["day"])

## Whole days from a to b (positive when b is later)
static func days_between(a: String, b: String) -> int:
	var da := parse_date(a)
	var db := parse_date(b)
	if da.is_empty() or db.is_empty():
		return 0
	return roundi((_noon_unix(db.year, db.month, db.day) - _noon_unix(da.year, da.month, da.day)) / 86400.0)

static func get_seed_for_date_string(date_str: String) -> int:
	var d := parse_date(date_str)
	return get_seed_for_date(d.year, d.month, d.day) if not d.is_empty() else 0

## Today or a day of the archive; false for later days and for days too far back
static func is_in_archive(date_str: String) -> bool:
	var back := days_between(date_str, get_today_date_string())
	return back >= 0 and back < ARCHIVE_DAYS

## The Daily date a seed belongs to (today or a day of the archive), "" for any other puzzle
static func date_for_seed(seed_val: int) -> String:
	var today := get_today_date_string()
	if _seed_dates_for != today:
		_seed_dates.clear()
		for back in range(ARCHIVE_DAYS):
			var date := add_days(today, -back)
			var s := get_seed_for_date_string(date)
			if not _seed_dates.has(s):
				_seed_dates[s] = date
		_seed_dates_for = today
	return _seed_dates.get(seed_val, "")

static func load_daily_data() -> Dictionary:
	if not FileAccess.file_exists(DAILY_FILE):
		return {
			"completed_dates": [],
			"current_streak": 0,
			"longest_streak": 0,
			"last_completed_date": ""
		}
	var file := FileAccess.open(DAILY_FILE, FileAccess.READ)
	if file == null:
		return {}
	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		return json.data
	return {}

static func save_daily_data(data: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute("user://saves/"):
		DirAccess.make_dir_recursive_absolute("user://saves/")
	var file := FileAccess.open(DAILY_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func is_date_completed(date_str: String) -> bool:
	var data := load_daily_data()
	var completed: Array = data.get("completed_dates", [])
	return completed.has(date_str)

static func is_today_completed() -> bool:
	return is_date_completed(get_today_date_string())

## The run of days still going: the last Daily was solved today or yesterday, otherwise it is over
static func get_current_streak() -> int:
	var data := load_daily_data()
	var last: String = data.get("last_completed_date", "")
	if last.is_empty() or days_between(last, get_today_date_string()) > 1:
		return 0
	return int(data.get("current_streak", 0))

static func get_longest_streak() -> int:
	var data := load_daily_data()
	return int(data.get("longest_streak", 0))

static func mark_date_completed(year: int, month: int, day: int) -> void:
	var date_str := get_date_string(year, month, day)
	var data := load_daily_data()
	var completed: Array = data.get("completed_dates", [])

	if completed.has(date_str):
		return # Already counted

	completed.append(date_str)
	data["completed_dates"] = completed

	# Check streak
	var last_date: String = data.get("last_completed_date", "")
	var current_streak: int = int(data.get("current_streak", 0))
	var longest_streak: int = int(data.get("longest_streak", 0))

	# Compute difference in days
	var is_consecutive: bool = false
	if not last_date.is_empty():
		var parts := last_date.split("-")
		if parts.size() == 3:
			var prev_year: int = parts[0].to_int()
			var prev_month: int = parts[1].to_int()
			var prev_day: int = parts[2].to_int()

			# Using unix time diff
			var current_unix: int = Time.get_unix_time_from_datetime_dict({
				"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0
			})
			var prev_unix: int = Time.get_unix_time_from_datetime_dict({
				"year": prev_year, "month": prev_month, "day": prev_day, "hour": 12, "minute": 0, "second": 0
			})
			var diff_days: int = int(round(float(current_unix - prev_unix) / 86400.0))
			if diff_days == 1:
				is_consecutive = true

	if is_consecutive:
		current_streak += 1
	else:
		current_streak = 1

	longest_streak = maxi(longest_streak, current_streak)

	data["current_streak"] = current_streak
	data["longest_streak"] = longest_streak
	data["last_completed_date"] = date_str

	save_daily_data(data)

static func mark_today_completed() -> void:
	var d := get_today_dict()
	mark_date_completed(d["year"], d["month"], d["day"])

## A past day solved from the archive. It is shown as done, but streaks (and the achievements
## built on them) only count Dailies solved on their own day.
static func mark_archive_completed(date_str: String) -> void:
	var data := load_daily_data()
	var completed: Array = data.get("completed_dates", [])
	var late: Array = data.get("archive_dates", [])
	if completed.has(date_str) or late.has(date_str):
		return
	late.append(date_str)
	data["archive_dates"] = late
	save_daily_data(data)

## Marks the Daily of date_str solved: on the day itself it counts for the streak
static func mark_completed(date_str: String) -> void:
	if date_str == get_today_date_string():
		mark_today_completed()
	else:
		mark_archive_completed(date_str)

## Every day solved, on the day or later from the archive
static func solved_dates() -> Array:
	var data := load_daily_data()
	var all: Array = data.get("completed_dates", []).duplicate()
	for d in data.get("archive_dates", []):
		if not all.has(d):
			all.append(d)
	return all

static func get_day_status(date_str: String, data: Dictionary = {}) -> DayStatus:
	if data.is_empty():
		data = load_daily_data()
	if data.get("completed_dates", []).has(date_str):
		return DayStatus.DONE
	if data.get("archive_dates", []).has(date_str):
		return DayStatus.DONE_LATE
	if has_daily_game(date_str):
		return DayStatus.IN_PROGRESS
	return DayStatus.NONE

static func get_today_daily_game_path() -> String:
	return get_daily_game_path(get_today_date_string())

static func get_daily_game_path(date_str: String) -> String:
	return DAILY_GAME_PREFIX + date_str + ".json"

static func has_today_game() -> bool:
	return has_daily_game(get_today_date_string())

static func has_daily_game(date_str: String) -> bool:
	return FileAccess.file_exists(get_daily_game_path(date_str))

static func save_today_game(state: GameState) -> bool:
	return save_daily_game(state, get_today_date_string())

static func save_daily_game(state: GameState, date_str: String) -> bool:
	if state == null or date_str.is_empty():
		return false
	if not DirAccess.dir_exists_absolute("user://saves/"):
		DirAccess.make_dir_recursive_absolute("user://saves/")
	var path := get_daily_game_path(date_str)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.serialize(), "\t"))
	file.close()
	return true

static func load_today_game() -> GameState:
	return load_daily_game(get_today_date_string())

static func load_daily_game(date_str: String) -> GameState:
	var path := get_daily_game_path(date_str)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var state := GameState.new()
		if state.deserialize(json.data):
			return state
	return null
