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
	var version := AppSettings.app_version()
	var code := int(preset.get("version/code", 0))
	_test_versions(preset, version, code)
	_test_store(code)
	_test_privacy(preset)
	_test_launcher_icon(preset)
	_test_one_icon_everywhere(preset)
	_test_web_export()
	_test_windows_export()
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

## The browser build: a Web preset that needs no special headers (single-threaded), and the
## workflow that builds it and publishes it
func _test_web_export() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var base := ""
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Web":
			base = section
	_check("There is a Web export preset", base != "")
	_check("without threads, so any static host can serve it", cfg.get_value(base + ".options", "variant/thread_support", true) == false)
	_check("leaving out the same files as the Android build", cfg.get_value(base, "exclude_filter", "").contains("tests/*")
		and cfg.get_value(base, "include_filter", "").contains("assets/puzzles/*.txt"))
	_check("It exports to build/, which is not committed", str(cfg.get_value(base, "export_path", "")).begins_with("build/")
		and FileAccess.get_file_as_string("res://.gitignore").contains("build/"))
	var opts := base + ".options"
	_check("It can be installed as an app (a web app manifest and a service worker for offline play), upright",
		cfg.get_value(opts, "progressive_web_app/enabled", false) == true and cfg.get_value(opts, "progressive_web_app/orientation", 0) == 2)
	var icons_ok := true
	for px in [144, 180, 512]:
		icons_ok = icons_ok and cfg.get_value(opts, "progressive_web_app/icon_%dx%d" % [px, px], "") == "res://assets/launcher/pwa_%dx%d.png" % [px, px] \
			and FileAccess.file_exists("res://assets/launcher/pwa_%dx%d.png" % [px, px])
	_check("with its three install icons", icons_ok)
	var flow := FileAccess.get_file_as_string("res://.github/workflows/web.yml")
	_check("A workflow builds it for every pull request", flow.contains("pull_request:") and flow.contains("--export-release Web"))
	_check("and publishes it on GitHub Pages only from main", flow.contains("deploy-pages") and flow.contains("github.ref == 'refs/heads/main'"))

## The Windows build: one exe with the data inside, zipped onto the release by its workflow
func _test_windows_export() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var base := ""
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Windows Desktop":
			base = section
	_check("There is a Windows export preset", base != "")
	_check("for 64-bit, as one exe", cfg.get_value(base + ".options", "binary_format/architecture", "") == "x86_64"
		and cfg.get_value(base + ".options", "binary_format/embed_pck", false) == true)
	_check("leaving out the same files as the other builds", cfg.get_value(base, "exclude_filter", "").contains("tests/*"))
	var flow := FileAccess.get_file_as_string("res://.github/workflows/windows.yml")
	_check("Its workflow builds it for every pull request and attaches the zip to a release",
		flow.contains("pull_request:") and flow.contains("--export-release \"Windows Desktop\"") and flow.contains("action-gh-release"))

func _scaled(img: Image, px: int) -> Image:
	var copy := img.duplicate() as Image
	copy.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return copy

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

func _png(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))

## Android shows the middle 72 dp of the 108 dp adaptive icon through the launcher's mask, and only
## the 66 dp circle in the middle is sure to show: a circular mask cut the corners off the old
## grid. The themed (monochrome) icon is drawn in outlines; nine filled cells read as one square.
func _test_launcher_icon(preset: Dictionary) -> void:
	var fg := _png(preset.get("launcher_icons/adaptive_foreground_432x432", ""))
	var mono := _png(preset.get("launcher_icons/adaptive_monochrome_432x432", ""))
	var bg := _png(preset.get("launcher_icons/adaptive_background_432x432", ""))
	var legacy := _png(preset.get("launcher_icons/main_192x192", ""))
	_check("The adaptive layers are 432 px and the legacy icon 192 px",
		fg != null and mono != null and bg != null and legacy != null and fg.get_size() == Vector2i(432, 432)
		and mono.get_size() == Vector2i(432, 432) and bg.get_size() == Vector2i(432, 432) and legacy.get_size() == Vector2i(192, 192))
	if fg == null or mono == null:
		return
	# The background is a rounded tile: opaque over the whole 72 dp every mask shows, corners
	# included, but not full-bleed. Launchers (seen on a real phone, twice) that draw the 108 dp
	# canvas without a mask show a full-bleed background as a hard-cornered square.
	if bg != null:
		var covered := true
		for y in range(72, 360, 3):
			for x in range(72, 360, 3):
				if bg.get_pixel(x, y).a < 0.99:
					covered = false
		_check("The background covers everything a launcher's mask can show", covered)
		_check("and is a rounded tile, not a full-bleed square", bg.get_pixel(0, 0).a < 0.05 and bg.get_pixel(432 - 1, 432 - 1).a < 0.05)
	var safe_r := 33.0 * 4.0
	var outside := 0
	for layer in [fg, mono]:
		for y in range(0, 432, 2):
			for x in range(0, 432, 2):
				if layer.get_pixel(x, y).a > 0.05 and Vector2(x, y).distance_to(Vector2(216, 216)) > safe_r:
					outside += 1
	_check("Everything on the icon is inside the 66 dp safe circle (%d pixels outside)" % outside, outside == 0)
	var used := mono.get_used_rect()
	var solid := 0
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if mono.get_pixel(x, y).a > 0.5:
				solid += 1
	var share := float(solid) / maxf(1.0, used.get_area())
	_check("The themed icon is mostly outline, not one block (%d%% filled)" % int(share * 100.0), share < 0.45)

## One icon on every platform: the project icon (window, browser tab, Windows exe), the Android
## layers and legacy icon, the store and install icons, and the Linux menu icon all come from
## tools/make_launcher_icons.gd; this fails when one of them is left behind or not used.
func _test_one_icon_everywhere(android: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var windows := ""
	var web := ""
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Windows Desktop":
			windows = section
		if cfg.get_value(section, "platform", "") == "Web":
			web = section
	_check("The project icon is icon.svg", ProjectSettings.get_setting("application/config/icon") == "res://icon.svg")
	_check("The Windows exe carries it (the preset edits the exe's resources and names icon.svg; otherwise it shows Godot's robot)",
		cfg.get_value(windows + ".options", "application/modify_resources", false) == true
		and cfg.get_value(windows + ".options", "application/icon", "") == "res://icon.svg")
	_check("The browser version's tab icon is made from it", cfg.get_value(web + ".options", "html/export_icon", false) == true)
	var project_svg := FileAccess.get_file_as_string("res://icon.svg")
	_check("The Linux menu icon (svg) is the same drawing", FileAccess.get_file_as_string("res://packaging/linux/io.github.r0madeus.JustSudoku.svg") == project_svg)
	var linux_png := _png("res://packaging/linux/io.github.r0madeus.JustSudoku.png")
	var legacy := _png(android.get("launcher_icons/main_192x192", ""))
	var same_linux := false
	if linux_png != null and legacy != null:
		linux_png.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		same_linux = _mean_difference(linux_png, legacy) < 0.02
	_check("and so is the Linux menu icon (png) and the AppImage's", same_linux)
	var store := _png("res://fastlane/metadata/android/en-US/images/icon.png")
	var pwa := _png("res://assets/launcher/pwa_512x512.png")
	_check("The browser's install icon is the legacy drawing: a rounded square, transparent corners",
		pwa != null and legacy != null and pwa.get_pixel(0, 0).a < 0.05 and pwa.get_pixel(256, 256).a > 0.99
		and _mean_difference(_scaled(pwa, 192), legacy) < 0.02)
	_check("The store icon is full bleed (the stores round it)", store != null and store.get_pixel(0, 0).a > 0.99)
	var store_tr := _png("res://fastlane/metadata/android/tr-TR/images/icon.png")
	_check("in both store languages", store != null and store_tr != null and _mean_difference(store, store_tr) < 0.005)

## The mean per-channel difference of two images of one size, from 0 to 1
func _mean_difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var total := 0.0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / (3.0 * ceil(a.get_height() / 2.0) * ceil(a.get_width() / 2.0))

func _test_settings_label(version: String) -> void:
	var screen := SettingsScreen.new()
	root.add_child(screen)
	await process_frame
	_check("Settings shows the version", screen.version_label != null and screen.version_label.text == "Just Sudoku " + version)
	screen.queue_free()
	await process_frame
