extends SceneTree

## The Linux downloads: the export preset, the menu entry, the store description (AppStream), the
## packaging script and the workflow that builds and attaches them. The
## packages themselves are built and started by CI (.github/workflows/linux.yml); what is checked
## here is that every file they are made from is there, agrees with the others and is current.

const APP_ID := "io.github.r0madeus.JustSudoku"
const PKG := "res://packaging/linux/"

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
	print("\n=== LINUX PACKAGING ===")
	_test_preset()
	_test_desktop_entry()
	_test_metainfo()
	_test_script_and_workflow()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _version() -> String:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	return str(cfg.get_value("application", "config/version", ""))

func _test_preset() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var base := ""
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Linux":
			base = section
	_check("There is a Linux export preset", base != "")
	_check("for 64-bit, as one file with the data inside",
		cfg.get_value(base + ".options", "binary_format/architecture", "") == "x86_64" and cfg.get_value(base + ".options", "binary_format/embed_pck", false) == true)
	_check("leaving out the same files as the other builds", cfg.get_value(base, "exclude_filter", "").contains("tests/*"))
	_check("It exports to build/, which is not committed", str(cfg.get_value(base, "export_path", "")).begins_with("build/"))
	_check("The packaging folder is not part of the game (Godot skips it)", FileAccess.file_exists("res://packaging/.gdignore"))

func _test_desktop_entry() -> void:
	var entry := _text(PKG + APP_ID + ".desktop")
	var lines := {}
	for l in entry.split("\n"):
		if l.contains("=") and not l.begins_with("#"):
			lines[l.split("=")[0]] = l.substr(l.find("=") + 1)
	_check("The menu entry starts the game and uses the app's icon", lines.get("Exec", "") == "JustSudoku" and lines.get("Icon", "") == APP_ID)
	_check("is an application with a name, in the Game category", lines.get("Type", "") == "Application" and lines.get("Name", "") == "Just Sudoku"
		and str(lines.get("Categories", "")).contains("Game;"))
	_check("and says what it is in Turkish too", lines.has("Comment[tr]") and lines.has("Keywords[tr]"))
	_check("Both icons it names are there", FileAccess.file_exists(PKG + APP_ID + ".svg") and FileAccess.file_exists(PKG + APP_ID + ".png"))
	var img := Image.new()
	_check("the PNG is 512 px", img.load(ProjectSettings.globalize_path(PKG + APP_ID + ".png")) == OK and img.get_width() == 512 and img.get_height() == 512)

func _test_metainfo() -> void:
	var xml := _text(PKG + APP_ID + ".metainfo.xml")
	var parser := XMLParser.new()
	_check("The store description is well-formed XML", parser.open(ProjectSettings.globalize_path(PKG + APP_ID + ".metainfo.xml")) == OK)
	var id := ""
	var releases: Dictionary = {}
	var shots: Array[String] = []
	var element := ""
	var licence := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				element = parser.get_node_name()
				if element == "release":
					releases[parser.get_named_attribute_value_safe("version")] = parser.get_named_attribute_value_safe("date")
			XMLParser.NODE_TEXT:
				var t := parser.get_node_data().strip_edges()
				if t.is_empty():
					continue
				if element == "id" and id.is_empty():
					id = t
				elif element == "image":
					shots.append(t)
				elif element == "project_license":
					licence = t
	_check("It is for this app (%s)" % id, id == APP_ID and xml.contains("<launchable type=\"desktop-id\">%s.desktop</launchable>" % APP_ID))
	_check("under the licence the project has (%s)" % licence, licence == "GPL-3.0-only" and _text("res://docs/fdroid/io.github.r0madeus.justsudoku.yml").contains("License: GPL-3.0-only"))
	var version := _version()
	_check("and has a release entry for the current version (%s)" % version, releases.has(version))
	var changelog := _text("res://CHANGELOG.md")
	_check("dated as in the CHANGELOG", releases.has(version) and changelog.contains("## [%s] - %s" % [version, releases[version]]))
	_check("It rates its content (no content to rate)", xml.contains("<content_rating type=\"oars-1.1\"/>"))
	_check("It asks for no network (no <internet> requirement)", not xml.contains("<internet"))
	var all_there := not shots.is_empty()
	for url in shots:
		var rel: String = url.replace("https://raw.githubusercontent.com/r0madeus/just-sudoku/main/", "")
		all_there = all_there and rel != url and FileAccess.file_exists("res://" + rel)
	_check("Its screenshots are files of this repository (%d)" % shots.size(), all_there)

func _test_script_and_workflow() -> void:
	var script := _text("res://tools/build_linux_packages.sh")
	_check("The packaging script makes a tar.gz and an AppImage, with checksums", script.contains(".tar.gz") and script.contains(".AppImage") and script.contains("sha256sum"))
	var pinned := RegEx.create_from_string("appimagetool_sha256=[0-9a-f]{64}")
	_check("and checks the AppImage tool it downloads against a pinned checksum", pinned.search(script) != null and script.contains("sha256sum -c"))
	_check("The AppImage has what it needs to start (AppRun, icon, menu entry)", script.contains("AppRun") and script.contains(".DirIcon") and script.contains("$app_id.desktop"))
	_check("The script can leave the AppImage out (to be tried where the tool must not be run)", script.contains("--no-appimage"))
	var flow := _text("res://.github/workflows/linux.yml")
	_check("A workflow builds it for every pull request and for version tags", flow.contains("pull_request:") and flow.contains("tags: [\"v*\"]"))
	_check("exporting with the Linux preset", flow.contains("--export-release Linux"))
	_check("checking the menu entry and the store description", flow.contains("desktop-file-validate") and flow.contains("appstreamcli validate"))
	_check("starting the game, the AppImage and the tar.gz", flow.contains("Start the exported game") and flow.contains("Start the AppImage") and flow.contains("Start the game from the tar.gz"))
	_check("and attaching all of it to the release", flow.contains("action-gh-release") and flow.contains("*.AppImage") and flow.contains("*.tar.gz"))
