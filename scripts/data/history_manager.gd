class_name HistoryManager
extends RefCounted

## Stores and manages played games history (GDD §32)

const HISTORY_FILE: String = "user://saves/history.json"

static var _cached_records: Array[Dictionary] = []
static var _cache_valid: bool = false

static func clear_cache() -> void:
	_cached_records.clear()
	_cache_valid = false

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute("user://saves/"):
		DirAccess.make_dir_recursive_absolute("user://saves/")

static func load_all_records(force_reload: bool = false) -> Array[Dictionary]:
	if _cache_valid and not force_reload:
		return _cached_records

	if not FileAccess.file_exists(HISTORY_FILE):
		_cached_records = []
		_cache_valid = true
		return []

	var file := FileAccess.open(HISTORY_FILE, FileAccess.READ)
	if file == null:
		return _cached_records

	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) == OK and json.data is Array:
		var result: Array[Dictionary] = []
		for item in json.data:
			if item is Dictionary:
				result.append(item)
		_cached_records = result
		_cache_valid = true
		return _cached_records

	_cached_records = []
	_cache_valid = true
	return []

static func save_all_records(records: Array[Dictionary]) -> void:
	_cached_records = records.duplicate(true)
	_cache_valid = true
	_ensure_dir()
	var file := FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(records, "\t"))
		file.close()

static func add_record(summary: Dictionary) -> void:
	var records := load_all_records()
	var record := {
		"game_id": summary.get("game_id", ""),
		# Stored as text: JSON numbers are doubles and seeds exceed 2^53
		"seed": str(int(summary.get("seed", 0))),
		"difficulty": summary.get("difficulty", DifficultyAnalyzer.LEVEL_MEDIUM),
		"difficulty_score": summary.get("difficulty_score", 50),
		"score": summary.get("score", 0),
		"time": summary.get("time", 0.0),
		"mistakes": summary.get("mistakes", 0),
		"hints": summary.get("hints", 0),
		"undo_count": summary.get("undo_count", 0),
		"is_replay": summary.get("is_replay", false),
		"is_daily": summary.get("is_daily", false),
		"timestamp": int(Time.get_unix_time_from_system())
	}
	records.append(record)
	save_all_records(records)

## Returns filtered and sorted history items
static func get_filtered_history(
	difficulty_filter: String = "All",
	replay_filter: String = "All", # "All", "Standard", "Replay"
	sort_by: String = "Newest"      # "Newest", "Oldest", "Fastest", "Best Score"
) -> Array[Dictionary]:
	var records := load_all_records()
	var filtered: Array[Dictionary] = []

	for r in records:
		if difficulty_filter != "All" and r.get("difficulty", "") != difficulty_filter:
			continue
		if replay_filter == "Standard" and r.get("is_replay", false):
			continue
		if replay_filter == "Replay" and not r.get("is_replay", false):
			continue
		filtered.append(r)

	match sort_by:
		"Newest":
			filtered.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
		"Oldest":
			filtered.sort_custom(func(a, b): return a.get("timestamp", 0) < b.get("timestamp", 0))
		"Fastest":
			filtered.sort_custom(func(a, b): return a.get("time", 0.0) < b.get("time", 0.0))
		"Best Score":
			filtered.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))

	return filtered

## Returns the best record (highest score, or fastest time) for a given seed (GDD §26)
static func get_best_record_for_seed(seed_val: int) -> Dictionary:
	var records := load_all_records()
	var best: Dictionary = {}
	for r in records:
		if int(r.get("seed", 0)) == seed_val:
			if best.is_empty():
				best = r
			elif int(r.get("score", 0)) > int(best.get("score", 0)):
				best = r
			elif int(r.get("score", 0)) == int(best.get("score", 0)) and float(r.get("time", 999999.0)) < float(best.get("time", 999999.0)):
				best = r
	return best

## Returns a dictionary mapping seed -> best record Dictionary for all seeds in O(N)
static func get_best_records_map() -> Dictionary:
	var records := load_all_records()
	var best_map: Dictionary = {}
	for r in records:
		var s: int = int(r.get("seed", 0))
		if not best_map.has(s):
			best_map[s] = r
		else:
			var cur: Dictionary = best_map[s]
			var r_sc: int = int(r.get("score", 0))
			var c_sc: int = int(cur.get("score", 0))
			if r_sc > c_sc or (r_sc == c_sc and float(r.get("time", 999999.0)) < float(cur.get("time", 999999.0))):
				best_map[s] = r
	return best_map

## Returns all records for a given seed
static func get_records_for_seed(seed_val: int) -> Array[Dictionary]:
	var records := load_all_records()
	var matches: Array[Dictionary] = []
	for r in records:
		if int(r.get("seed", 0)) == seed_val:
			matches.append(r)
	return matches

