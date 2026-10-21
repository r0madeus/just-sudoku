class_name DailyManager
extends RefCounted

## Handles offline deterministic Daily Sudoku and streak tracking (GDD §34, §35)

const DAILY_FILE: String = "user://saves/daily.json"
const DAILY_GAME_PREFIX: String = "user://saves/daily_game_"
const DAILY_SALT: int = 0x5D3F19A2B4C8E701

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

static func get_current_streak() -> int:
	var data := load_daily_data()
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

static func get_today_daily_game_path() -> String:
	return DAILY_GAME_PREFIX + get_today_date_string() + ".json"

static func has_today_game() -> bool:
	return FileAccess.file_exists(get_today_daily_game_path())

static func save_today_game(state: GameState) -> bool:
	if state == null:
		return false
	if not DirAccess.dir_exists_absolute("user://saves/"):
		DirAccess.make_dir_recursive_absolute("user://saves/")
	var path := get_today_daily_game_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.serialize(), "\t"))
	file.close()
	return true

static func load_today_game() -> GameState:
	var path := get_today_daily_game_path()
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
