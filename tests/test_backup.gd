extends SceneTree

## Full backup and restore: everything under user://saves/ in one backup, as a file or as text for
## the clipboard; damaged or foreign text is refused; restoring replaces the data, keeps a copy of
## what was there, reloads settings, and the game left open behind Settings does not save over it

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const BackupManager = preload("res://scripts/data/backup_manager.gd")
const BackupSection = preload("res://scenes/menus/backup_section.gd")
const AppRoot = preload("res://scenes/app_root.gd")

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
	print("\n=== BACKUP AND RESTORE ===")
	_seed_data()
	_test_contents()
	_test_round_trips()
	_test_refusals()
	_test_restore()
	await _test_section()
	await _test_app_drops_open_game()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _new_state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	return state

func _add_records(n: int) -> void:
	for i in n:
		HistoryManager.add_record({"game_id": "g%d" % i, "seed": 1000 + i, "difficulty": "Medium", "score": 80, "time": 300.0})

## History, a game in progress, a Daily day, settings and a theme
func _seed_data() -> void:
	_add_records(3)
	var state := _new_state(9001)
	state.set_cell_color([0], 4)
	SaveManager.save_active_game(state)
	DailyManager.mark_date_completed(2026, 3, 14)
	SettingsScreen.digit_first = true
	SettingsScreen.save_config()
	ThemeManager.set_theme("Sepia")
	ThemeManager.save_settings()

func _test_contents() -> void:
	var files := BackupManager.collect_files()
	for f in ["history.json", "config.json", "settings.json", "daily.json", "active_game.json", "games_index.json"]:
		_check("The backup holds " + f, files.has(f))
	var slots := files.keys().filter(func(p): return str(p).begins_with("games/"))
	_check("The backup holds the saved game itself", slots.size() == 1)
	var s := BackupManager.summarize(BackupManager.build())
	_check("The summary counts the history, the saved game and the Daily day",
		s.games == 3 and s.saved == 1 and s.daily == 1 and s.created > 0)

func _test_round_trips() -> void:
	var backup := BackupManager.build()
	var from_file := BackupManager.parse(BackupManager.to_file_text(backup))
	_check("A backup file reads back the same", from_file.ok and from_file.backup.files == backup.files)
	var clip := BackupManager.to_clipboard_text(backup)
	_check("The clipboard form is one line behind its prefix",
		clip.begins_with(BackupManager.TEXT_PREFIX) and not clip.contains("\n"))
	_check("It is smaller than the file", clip.length() < BackupManager.to_file_text(backup).length())
	var from_clip := BackupManager.parse("  \n" + clip + "\n ")
	_check("Clipboard text reads back the same, spaces around it or not",
		from_clip.ok and from_clip.backup.files == backup.files)

func _error_of(text: String) -> String:
	var r := BackupManager.parse(text)
	return "" if r.ok else r.error

func _test_refusals() -> void:
	var good := BackupManager.build()
	_check("Empty text is refused", _error_of("   ") == BackupManager.ERR_EMPTY)
	_check("Other text is not a backup", _error_of("hello") == BackupManager.ERR_NOT_BACKUP)
	_check("A shared puzzle is not a backup", _error_of(".".repeat(81)) == BackupManager.ERR_NOT_BACKUP)
	_check("Other JSON is not a backup", _error_of(JSON.stringify({"format": "x", "files": {}})) == BackupManager.ERR_NOT_BACKUP)
	var newer := good.duplicate(true)
	newer.version = BackupManager.VERSION + 1
	_check("A backup from a newer version is refused", _error_of(JSON.stringify(newer)) == BackupManager.ERR_NEWER)
	var clip := BackupManager.to_clipboard_text(good)
	_check("Cut-off clipboard text is damaged", _error_of(clip.substr(0, clip.length() / 2)) == BackupManager.ERR_DAMAGED)
	_check("Garbage behind the prefix is damaged", _error_of(BackupManager.TEXT_PREFIX + "@@@") == BackupManager.ERR_DAMAGED)
	for bad_path in ["../escape.json", "/abs.json", "games/../../x.json", "user://x.json", "notes.txt", "a//b.json"]:
		var bad := good.duplicate(true)
		bad.files[bad_path] = "{}"
		_check("A file outside saves/ is refused: " + bad_path, _error_of(JSON.stringify(bad)) == BackupManager.ERR_DAMAGED)
	var broken := good.duplicate(true)
	broken.files["history.json"] = "[{"
	_check("A file that is not JSON is damaged", _error_of(JSON.stringify(broken)) == BackupManager.ERR_DAMAGED)
	var no_files := good.duplicate(true)
	no_files.erase("files")
	_check("A backup without files is damaged", _error_of(JSON.stringify(no_files)) == BackupManager.ERR_DAMAGED)

func _test_restore() -> void:
	var backup := BackupManager.build()
	var saved_active := FileAccess.get_file_as_string(SaveManager.ACTIVE_GAME_FILE)

	# Change everything after the backup
	_add_records(4)
	SaveManager.clear_active_game()
	SaveManager.save_active_game(_new_state(9002))
	DirAccess.make_dir_recursive_absolute(BackupManager.SAVES_DIR + "games/")
	var extra := FileAccess.open(BackupManager.SAVES_DIR + "games/extra.json", FileAccess.WRITE)
	extra.store_string("{}")
	extra.close()
	SettingsScreen.digit_first = false
	SettingsScreen.save_config()
	ThemeManager.set_theme("Dark")
	ThemeManager.save_settings()
	HistoryManager.load_all_records()

	_check("Restoring succeeds", BackupManager.restore(backup))
	_check("The history is the backup's, without a forced reload", HistoryManager.load_all_records().size() == 3)
	_check("The game in progress is the backup's", FileAccess.get_file_as_string(SaveManager.ACTIVE_GAME_FILE) == saved_active)
	_check("The game's colours came back with it", SaveManager.load_active_game().get_cell_color(0) == 4)
	_check("Files the backup does not have are gone", not FileAccess.file_exists(BackupManager.SAVES_DIR + "games/extra.json"))
	_check("Settings are reloaded", SettingsScreen.digit_first)
	_check("The theme is reloaded", ThemeManager.current_theme_name == "Sepia")
	_check("The Daily day is back", DailyManager.is_date_completed("2026-03-14"))
	_check("Every file matches the backup", BackupManager.collect_files() == backup.files)

	var before := BackupManager.parse(FileAccess.get_file_as_string(BackupManager.PREVIOUS_FILE))
	_check("What was on the device is kept as a backup of its own",
		before.ok and before.backup.files.has("games/extra.json") and BackupManager.summarize(before.backup).games == 7)
	_check("The copy is kept outside saves/, so it is not in later backups",
		not BackupManager.collect_files().keys().any(func(p): return str(p).contains("before_restore")))

func _test_section() -> void:
	var section := BackupSection.new()
	root.add_child(section)
	await process_frame
	_check("Without a file picker only the clipboard is offered", not section.has_file_dialog)
	_check("Not a backup: no question, an error", section.restore_from_text("hello") == null and section.status_lbl.visible)
	_check("The error says why", section.status_lbl.text == LocalizationManager.translate("BACKUP_ERR_NOT_BACKUP"))

	section.backup_to_clipboard()
	var clip := DisplayServer.clipboard_get()
	# Headless runs may have no clipboard; the text itself is what matters
	var text := clip if clip.begins_with(BackupManager.TEXT_PREFIX) else BackupManager.to_clipboard_text()
	_check("Copying says where the backup went", section.status_lbl.text == LocalizationManager.translate("BACKUP_COPIED"))

	_add_records(2)
	var restored := [false]
	section.data_restored.connect(func(): restored[0] = true)
	var modal := section.restore_from_text(text)
	_check("A backup asks before it replaces anything", modal != null and HistoryManager.load_all_records().size() == 5)
	_check("The question says what the backup holds", modal != null and modal.dialog_text.contains("3"))
	modal.canceled.emit()
	_check("Cancelling changes nothing", HistoryManager.load_all_records().size() == 5 and not restored[0])
	modal = section.restore_from_text(text)
	modal.primary_btn.pressed.emit()
	_check("Agreeing restores it", HistoryManager.load_all_records().size() == 3 and restored[0])
	_check("and says so", section.status_lbl.text == LocalizationManager.translate("BACKUP_RESTORED"))
	section.queue_free()
	await process_frame

func _test_app_drops_open_game() -> void:
	var backup := BackupManager.build()
	var app := AppRoot.new()
	root.add_child(app)
	await process_frame
	var state := _new_state(9003)
	app._start_game_session(state)
	app.game_screen.settings_requested.emit()
	_check("Settings opened from a game", app.current_screen == app.settings_screen)
	BackupManager.restore(backup)
	app.settings_screen.data_restored.emit()
	_check("After a restore the open game is let go", app.game_screen.game_state == null)
	app.game_screen.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app.game_screen._on_back_pressed()
	_check("and it does not save over the restored game",
		FileAccess.get_file_as_string(SaveManager.ACTIVE_GAME_FILE) == backup.files["active_game.json"])
	app.settings_screen.back_requested.emit()
	_check("Back from Settings goes to the menu, not to the dropped game", app.current_screen == app.main_menu)
	app.queue_free()
	await process_frame
