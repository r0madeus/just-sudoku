class_name BackupManager
extends RefCounted

## One backup of everything the game keeps: history (and so statistics and achievements), saved
## games, the Daily Sudoku days, settings and theme. Everything lives as JSON under user://saves/,
## so a backup is those files, by path, in one JSON document. As a file it is that document; for
## the clipboard it is gzipped and base64-encoded behind TEXT_PREFIX.
## Restoring replaces what is on the device, after keeping a copy of it in PREVIOUS_FILE.

const SAVES_DIR: String = "user://saves/"
const FORMAT: String = "just-sudoku-backup"
const VERSION: int = 1
const TEXT_PREFIX: String = "JSUDOKU-BACKUP-1:"
## What was on the device before the last restore (outside saves/, so restoring never backs itself up)
const PREVIOUS_FILE: String = "user://before_restore.json"
## Larger than any real backup by far; stops a wrong paste from being decompressed endlessly
const MAX_BYTES: int = 64 * 1024 * 1024

const ERR_EMPTY: String = "BACKUP_ERR_EMPTY"
const ERR_NOT_BACKUP: String = "BACKUP_ERR_NOT_BACKUP"
const ERR_NEWER: String = "BACKUP_ERR_NEWER"
const ERR_DAMAGED: String = "BACKUP_ERR_DAMAGED"

const HistoryManager = preload("res://scripts/data/history_manager.gd")

## Every .json file under saves/, as {relative path: text}
static func collect_files() -> Dictionary:
	var files: Dictionary = {}
	_collect(SAVES_DIR, "", files)
	return files

static func _collect(dir_path: String, rel: String, files: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path + sub + "/", rel + sub + "/", files)
	for f in dir.get_files():
		if f.ends_with(".json"):
			files[rel + f] = FileAccess.get_file_as_string(dir_path + f)

static func build() -> Dictionary:
	return {
		"format": FORMAT,
		"version": VERSION,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"created": int(Time.get_unix_time_from_system()),
		"files": collect_files(),
	}

## The backup as a file: plain JSON, readable and diffable
static func to_file_text(backup: Dictionary = {}) -> String:
	return JSON.stringify(backup if not backup.is_empty() else build())

## The backup as one line of text for the clipboard
static func to_clipboard_text(backup: Dictionary = {}) -> String:
	var raw := to_file_text(backup).to_utf8_buffer()
	return TEXT_PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))

## Reads a backup from either form. {"ok": true, "backup": {...}} or {"ok": false, "error": key}
static func parse(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return {"ok": false, "error": ERR_EMPTY}
	var json_text := clean
	if clean.begins_with(TEXT_PREFIX):
		var packed := Marshalls.base64_to_raw(clean.substr(TEXT_PREFIX.length()).strip_edges())
		if packed.is_empty():
			return {"ok": false, "error": ERR_DAMAGED}
		var raw := packed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_GZIP)
		if raw.is_empty():
			return {"ok": false, "error": ERR_DAMAGED}
		json_text = raw.get_string_from_utf8()
	var data = _json(json_text)
	if not data is Dictionary or data.get("format", "") != FORMAT:
		return {"ok": false, "error": ERR_NOT_BACKUP if not clean.begins_with(TEXT_PREFIX) else ERR_DAMAGED}
	if int(data.get("version", 0)) > VERSION:
		return {"ok": false, "error": ERR_NEWER}
	var files = data.get("files")
	if not files is Dictionary:
		return {"ok": false, "error": ERR_DAMAGED}
	for path in files.keys():
		if not _is_safe_path(str(path)) or not files[path] is String or _json(files[path]) == null:
			return {"ok": false, "error": ERR_DAMAGED}
	return {"ok": true, "backup": data}

## A relative path to a .json file inside saves/: no "..", no absolute path, no other scheme
static func _is_safe_path(path: String) -> bool:
	if not path.ends_with(".json") or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	for part in path.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true

## What a backup holds, to show before restoring it
static func summarize(backup: Dictionary) -> Dictionary:
	var files: Dictionary = backup.get("files", {})
	var history = _json(files.get("history.json", "[]"))
	var daily = _json(files.get("daily.json", "{}"))
	var saved := 0
	for path in files.keys():
		if str(path).begins_with("games/"):
			saved += 1
	return {
		"created": int(backup.get("created", 0)),
		"games": history.size() if history is Array else 0,
		"saved": saved,
		"daily": (daily.get("completed_dates", []) as Array).size() if daily is Dictionary else 0,
	}

## Replaces everything in saves/ with the backup's files. The device's own data is kept in
## PREVIOUS_FILE first. Settings, theme and history caches are reloaded afterwards.
static func restore(backup: Dictionary) -> bool:
	var files: Dictionary = backup.get("files", {})
	var previous := FileAccess.open(PREVIOUS_FILE, FileAccess.WRITE)
	if previous == null:
		return false
	previous.store_string(to_file_text())
	previous.close()

	_remove_json(SAVES_DIR)
	for path in files.keys():
		var full: String = SAVES_DIR + str(path)
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		var f := FileAccess.open(full, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(files[path])
		f.close()

	HistoryManager.clear_cache()
	ThemeManager.load_settings()
	AppSettings.load_config()
	# load_config does not tell anyone; saving the settings it just read does, with nothing changed
	AppSettings.save_config()
	return true

static func _remove_json(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_json(dir_path + sub + "/")
	for f in dir.get_files():
		if f.ends_with(".json"):
			dir.remove(f)

## JSON.parse_string logs every failure; a pasted text that is not a backup is not an error
static func _json(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null

static func file_name() -> String:
	return "just-sudoku-%s.json" % Time.get_date_string_from_system()

static func save_to_path(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_file_text())
	f.close()
	return true

static func read_path(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_BYTES:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
