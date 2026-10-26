extends SceneTree

## The READMEs (English and Turkish): every picture and file they point to exists, the two point to
## each other, and the numbers they quote (test suites, behaviours the mutation audit breaks) are
## the real ones, so they do not go stale as the project grows.

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
	print("\n=== READMES ===")
	var suites := 0
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			suites += 1
	var audit := FileAccess.get_file_as_string("res://tools/mutation_audit.py")
	var mutations := RegEx.create_from_string("(?m)^ \\(\"M\\d+\"").search_all(audit).size()
	for pair in [["README.md", "Runs all (\\d+) test suites", "breaks (\\d+) behaviours"], ["README.tr.md", "(\\d+) test dosyasının", "oyunun (\\d+) davranışını"]]:
		var text := FileAccess.get_file_as_string("res://" + pair[0])
		_check("%s: it is there" % pair[0], not text.is_empty())
		var missing := ""
		var links := RegEx.create_from_string("(?:src=\"|\\]\\()([^\"#)\\s]+)").search_all(text)
		for m in links:
			var target: String = m.get_string(1)
			if target.begins_with("http") or target.begins_with("mailto:"):
				continue
			if not FileAccess.file_exists("res://" + target) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://" + target)):
				missing += target + " "
		_check("%s: every local picture and file it points to exists (%s)" % [pair[0], missing], missing.is_empty() and links.size() > 10)
		var suites_quoted := RegEx.create_from_string(pair[1]).search(text)
		_check("%s: the number of test suites is right (%d)" % [pair[0], suites], suites_quoted != null and int(suites_quoted.get_string(1)) == suites)
		var mutations_quoted := RegEx.create_from_string(pair[2]).search(text)
		_check("%s: and the number of behaviours the audit breaks (%d)" % [pair[0], mutations], mutations_quoted != null and int(mutations_quoted.get_string(1)) == mutations)
		_check("%s: it tells about the Linux downloads" % pair[0], text.contains("docs/linux.md") and text.contains("AppImage") and text.contains("Flatpak"))
		_check("%s: and about the browser version" % pair[0], text.contains("https://r0madeus.github.io/just-sudoku/"))
	var en := FileAccess.get_file_as_string("res://README.md")
	var tr := FileAccess.get_file_as_string("res://README.tr.md")
	_check("Each README links to the other", en.contains("README.tr.md") and tr.contains("README.md"))
	_check("and each has its own pictures, in its own language", en.contains("hero_en.jpg") and tr.contains("hero_tr.jpg"))
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
