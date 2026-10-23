class_name AppSettings
extends RefCounted

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")

## The player's settings and the file they are kept in. Kept apart from the Settings screen so
## that the game, the grid and the sounds can read them without loading that screen (and all it
## builds) at start-up.

const CONFIG_PATH: String = "user://saves/config.json"

static var auto_open_last_game: bool = true
static var smart_numpad_enabled: bool = true
## Pick a digit first, then tap the cells it goes in
static var digit_first: bool = false
static var auto_remove_notes: bool = true
static var smart_candidates_enabled: bool = false
static var show_conflicts: bool = true
static var show_wrong_immediately: bool = false
static var animations_enabled: bool = true
static var sounds_enabled: bool = true
static var haptics_enabled: bool = true

static var _config_listeners: Array[Callable] = []

static func add_listener(cb: Callable) -> void:
	if not _config_listeners.has(cb):
		_config_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_config_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _config_listeners:
		if cb.is_valid():
			cb.call()

## The version players see and report: project.godot application/config/version, kept equal to
## the Android export's version/name (tests/test_release.gd checks it)
static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

static func save_config() -> void:
	var data := {
		"locale": LocalizationManager.get_locale(),
		"font": FontManager.current_font_name,
		"text_size": ThemeManager.text_size,
		"auto_open": auto_open_last_game,
		"smart_numpad": smart_numpad_enabled,
		"digit_first": digit_first,
		"auto_notes": auto_remove_notes,
		"smart_candidates": smart_candidates_enabled,
		"show_conflicts": show_conflicts,
		"show_wrong": show_wrong_immediately,
		"animations": animations_enabled,
		"sounds": sounds_enabled,
		"haptics": haptics_enabled
	}
	# On a fresh install nothing else may have made the folder yet (no game saved so far)
	DirAccess.make_dir_recursive_absolute(CONFIG_PATH.get_base_dir())
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_notify_listeners()

static func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		LocalizationManager.set_locale(LocalizationManager.detect_system_locale())
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var saved_loc: String = json.data.get("locale", "")
		if saved_loc.is_empty() or not LocalizationManager.SUPPORTED_LOCALES.has(saved_loc):
			saved_loc = LocalizationManager.detect_system_locale()
		LocalizationManager.set_locale(saved_loc)
		var saved_font: String = json.data.get("font", FontManager.FONT_MODERN_SANS)
		FontManager.set_font(saved_font)
		ThemeManager.set_text_size(json.data.get("text_size", ThemeManager.TEXT_SIZE_NORMAL))
		auto_open_last_game = json.data.get("auto_open", true)
		smart_numpad_enabled = json.data.get("smart_numpad", true)
		digit_first = json.data.get("digit_first", false)
		auto_remove_notes = json.data.get("auto_notes", true)
		smart_candidates_enabled = json.data.get("smart_candidates", false)
		show_conflicts = json.data.get("show_conflicts", true)
		show_wrong_immediately = json.data.get("show_wrong", false)
		animations_enabled = json.data.get("animations", true)
		sounds_enabled = json.data.get("sounds", true)
		haptics_enabled = json.data.get("haptics", true)
