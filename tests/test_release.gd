extends SceneTree

## What a release depends on stays in step: one version everywhere (project, Android export,
## CHANGELOG, store notes, F-Droid recipe), store texts within the stores' limits, the privacy
## promises in the export settings, and the version shown in Settings

const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

const STORE_DIR: String = "res://fastlane/metadata/android/"
const LOCALES: Array[String] = ["en-US", "tr-TR"]

var _passed: int = 0
var _failed: int = 0

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
	print("\n=== RELEASE ===")
	var preset := _android_preset()
	var version := SettingsScreen.app_version()
	var code := int(preset.get("version/code", 0))
	_test_versions(preset, version, code)
	_test_store(code)
	_test_privacy(preset)
	await _test_settings_label(version)
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

## The Android preset's options as {key: value}
func _android_preset() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for section in cfg.get_sections():
		if section.ends_with(".options") and cfg.get_value(section.trim_suffix(".options"), "platform", "") == "Android":
			var out := {}
			for key in cfg.get_section_keys(section):
				out[key] = cfg.get_value(section, key)
			var base := section.trim_suffix(".options")
			for key in cfg.get_section_keys(base):
				out["preset/" + key] = cfg.get_value(base, key)
			return out
	return {}

func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges()

func _test_versions(preset: Dictionary, version: String, code: int) -> void:
	_check("The project has a version (%s)" % version, RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(version) != null)
	_check("The Android export has the same version name", preset.get("version/name", "") == version)
	_check("and a version code (%d)" % code, code >= 1)
	_check("CHANGELOG.md has a section for %s" % version,
		FileAccess.get_file_as_string("res://CHANGELOG.md").contains("\n## [%s]" % version))
	var recipe := FileAccess.get_file_as_string("res://docs/fdroid/io.github.r0madeus.justsudoku.yml")
	_check("The F-Droid recipe builds this version",
		recipe.contains("versionName: %s\n" % version) and recipe.contains("versionCode: %d\n" % code)
		and recipe.contains("commit: v%s\n" % version) and recipe.contains("CurrentVersion: %s\n" % version))
	# fdroiddata names the recipe after the package
	_check("for the package the export makes", FileAccess.file_exists(
		"res://docs/fdroid/%s.yml" % preset.get("package/unique_name", "-")))

func _test_store(code: int) -> void:
	for locale in LOCALES:
		var dir := STORE_DIR + locale + "/"
		var title := _text(dir + "title.txt")
		var short := _text(dir + "short_description.txt")
		var full := _text(dir + "full_description.txt")
		_check("%s: a title of at most 50 characters" % locale, not title.is_empty() and title.length() <= 50)
		_check("%s: a short description of at most 80 (%d)" % [locale, short.length()], not short.is_empty() and short.length() <= 80)
		_check("%s: a full description of at most 4000 (%d)" % [locale, full.length()], full.length() > 200 and full.length() <= 4000)
		var notes := _text(dir + "changelogs/%d.txt" % code)
		_check("%s: notes for version code %d, at most 500 characters (%d)" % [locale, code, notes.length()],
			not notes.is_empty() and notes.length() <= 500)
		var icon := Image.load_from_file(ProjectSettings.globalize_path(dir + "images/icon.png"))
		_check("%s: a 512 px icon" % locale, icon != null and icon.get_size() == Vector2i(512, 512))
		var phone := DirAccess.get_files_at(dir + "images/phoneScreenshots")
		_check("%s: phone screenshots (%d)" % [locale, phone.size()], phone.size() >= 4)
		var tablet := DirAccess.get_files_at(dir + "images/tenInchScreenshots")
		_check("%s: tablet screenshots (%d)" % [locale, tablet.size()], tablet.size() >= 1)
	_check("Godot leaves the store images alone (no .import files)", FileAccess.file_exists("res://fastlane/.gdignore"))

## README and PRIVACY.md promise these; the export settings are what makes them true
func _test_privacy(preset: Dictionary) -> void:
	var granted: Array[String] = []
	for key in preset.keys():
		if String(key).begins_with("permissions/") and typeof(preset[key]) == TYPE_BOOL and preset[key]:
			granted.append(String(key).trim_prefix("permissions/"))
	_check("The only permission is vibration (%s)" % str(granted), Array(granted) == ["vibrate"])
	_check("No internet permission", preset.get("permissions/internet", true) == false)
	_check("Android backup is off", preset.get("user_data_backup/allow", true) == false)
	var excluded := String(preset.get("preset/exclude_filter", ""))
	for folder in ["fastlane/*", "tests/*", "tools/*"]:
		_check("The APK leaves out " + folder, excluded.contains(folder))
	_check("The privacy note is there", FileAccess.file_exists("res://PRIVACY.md"))

func _test_settings_label(version: String) -> void:
	var screen := SettingsScreen.new()
	root.add_child(screen)
	await process_frame
	_check("Settings shows the version", screen.version_label != null and screen.version_label.text == "Just Sudoku " + version)
	screen.queue_free()
	await process_frame
