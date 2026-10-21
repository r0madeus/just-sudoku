class_name SaveManager
extends RefCounted

## Manages persistent storage, safe writes, crash recovery, and multi-game slots
## Implements GDD §27, §28, §29, §30 (Snapshot + Move Log & 3-state backup)

const SAVES_DIR: String = "user://saves/"
const GAMES_DIR: String = "user://saves/games/"
const ACTIVE_GAME_FILE: String = "user://saves/active_game.json"
const BACKUP_1_FILE: String = "user://saves/active_game.bak1.json"
const BACKUP_2_FILE: String = "user://saves/active_game.bak2.json"
const INDEX_FILE: String = "user://saves/games_index.json"

static func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	if not DirAccess.dir_exists_absolute(GAMES_DIR):
		DirAccess.make_dir_recursive_absolute(GAMES_DIR)

## Writes string to file safely using temporary swap and rotates backups
static func safe_write_active(data_dict: Dictionary) -> bool:
	_ensure_directories()
	var json_str: String = JSON.stringify(data_dict, "\t")
	var tmp_file: String = ACTIVE_GAME_FILE + ".tmp"

	# Write to tmp
	var file := FileAccess.open(tmp_file, FileAccess.WRITE)
	if file == null:
		printerr("SaveManager: Failed to open temp file for writing")
		return false
	file.store_string(json_str)
	file.flush()
	file.close()

	# Rotate backups: active_game -> bak1 -> bak2
	if FileAccess.file_exists(BACKUP_1_FILE):
		DirAccess.copy_absolute(BACKUP_1_FILE, BACKUP_2_FILE)
	if FileAccess.file_exists(ACTIVE_GAME_FILE):
		DirAccess.copy_absolute(ACTIVE_GAME_FILE, BACKUP_1_FILE)

	# Atomic rename/replace
	DirAccess.copy_absolute(tmp_file, ACTIVE_GAME_FILE)
	DirAccess.remove_absolute(tmp_file)
	return true

## Saves the currently active game and updates index
static func save_active_game(game_state: GameState) -> bool:
	if game_state == null:
		return false

	var data: Dictionary = game_state.serialize()
	var success := safe_write_active(data)

	# Also save into games slot
	if success and not game_state.game_id.is_empty():
		var slot_path: String = GAMES_DIR + game_state.game_id + ".json"
		var slot_file := FileAccess.open(slot_path, FileAccess.WRITE)
		if slot_file != null:
			slot_file.store_string(JSON.stringify(data, "\t"))
			slot_file.close()

		_update_index(game_state)

	return success

## Loads the active game with automatic 3-state crash recovery fallback
static func load_active_game() -> GameState:
	_ensure_directories()
	var candidates_to_try: Array[String] = [ACTIVE_GAME_FILE, BACKUP_1_FILE, BACKUP_2_FILE]

	for file_path in candidates_to_try:
		if not FileAccess.file_exists(file_path):
			continue

		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue

		var content: String = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_err = json.parse(content)
		if parse_err == OK and json.data is Dictionary:
			var state := GameState.new()
			if state.deserialize(json.data):
				return state

	return null

static func has_active_game() -> bool:
	return FileAccess.file_exists(ACTIVE_GAME_FILE)

static func clear_active_game() -> void:
	if FileAccess.file_exists(ACTIVE_GAME_FILE):
		DirAccess.remove_absolute(ACTIVE_GAME_FILE)

static func save_game_slot(game_state: GameState) -> bool:
	if game_state == null or game_state.game_id.is_empty():
		return false
	_ensure_directories()
	var slot_path: String = GAMES_DIR + game_state.game_id + ".json"
	var file := FileAccess.open(slot_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(game_state.serialize(), "\t"))
	file.close()
	_update_index(game_state)
	return true

static func load_game_slot(game_id: String) -> GameState:
	_ensure_directories()
	var slot_path: String = GAMES_DIR + game_id + ".json"
	if not FileAccess.file_exists(slot_path):
		return null
	var file := FileAccess.open(slot_path, FileAccess.READ)
	if file == null:
		return null
	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var state := GameState.new()
		if state.deserialize(json.data):
			return state
	return null

static func delete_game_slot(game_id: String) -> bool:
	_ensure_directories()
	var slot_path: String = GAMES_DIR + game_id + ".json"
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)

	# Remove from index
	var index_data: Dictionary = get_games_index()
	if index_data.has(game_id):
		index_data.erase(game_id)
		var file := FileAccess.open(INDEX_FILE, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(index_data, "\t"))
			file.close()
	return true

static func get_games_index() -> Dictionary:
	_ensure_directories()
	if not FileAccess.file_exists(INDEX_FILE):
		return {}
	var file := FileAccess.open(INDEX_FILE, FileAccess.READ)
	if file == null:
		return {}
	var content: String = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		return json.data
	return {}

static func list_active_games() -> Array[Dictionary]:
	var index_data := get_games_index()
	var list: Array[Dictionary] = []
	for game_id in index_data.keys():
		var entry: Dictionary = index_data[game_id]
		if not entry.get("is_completed", false):
			list.append(entry)

	# Sort by last_played desc
	list.sort_custom(func(a, b): return a.get("last_played", 0) > b.get("last_played", 0))
	return list

static func _update_index(game_state: GameState) -> void:
	var index_data := get_games_index()
	var total_cells: int = SudokuBoard.CELL_COUNT
	var filled: int = total_cells - game_state.current_board.get_empty_cell_count()
	var pct: float = (float(filled) / float(total_cells)) * 100.0

	index_data[game_state.game_id] = {
		"game_id": game_state.game_id,
		# Stored as text: JSON numbers are doubles and seeds exceed 2^53
		"seed": str(game_state.seed_value),
		"difficulty": game_state.difficulty,
		"difficulty_score": game_state.difficulty_score,
		"progress_percentage": roundf(pct),
		"elapsed_time": game_state.elapsed_time,
		"mistakes": game_state.mistakes_count,
		"is_completed": game_state.is_completed,
		"last_played": int(Time.get_unix_time_from_system())
	}

	var file := FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(index_data, "\t"))
		file.close()

## Export / Import support (GDD §31)
static func export_game_to_string(game_state: GameState) -> String:
	if game_state == null:
		return ""
	return JSON.stringify(game_state.serialize())

static func import_game_from_string(json_str: String) -> GameState:
	var json = JSON.new()
	if json.parse(json_str) == OK and json.data is Dictionary:
		var state := GameState.new()
		if state.deserialize(json.data):
			return state
	return null
