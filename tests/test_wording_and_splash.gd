extends SceneTree

## Plain wording: a saved game says how much of it is "complete" (not "filled"); the Daily Sudoku
## card says its name and, only when there is one, the streak. And the page the browser version
## loads in shows the game's name, in its own face, instead of a bare progress bar.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")

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

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await process_frame
	print("\n=== WORDING AND SPLASH ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	_test_wording()
	await _test_daily_card()
	_test_shell()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_wording() -> void:
	LocalizationManager.set_locale("en")
	_check("English: the resume card says complete", LocalizationManager.translate("RESUME_PROGRESS") % 31 == "31% complete")
	_check("and so does the saved games list", LocalizationManager.translate("PROGRESS_LABEL") % LocalizationManager.format_percentage(31) == "31% complete")
	LocalizationManager.set_locale("tr")
	_check("Türkçe: tamamlandı, not dolu", LocalizationManager.translate("RESUME_PROGRESS") % 31 == "%31 tamamlandı")
	_check("also in the saved games list", LocalizationManager.translate("PROGRESS_LABEL") % LocalizationManager.format_percentage(31) == "%31 tamamlandı")
	var leftover := ""
	for loc in ["en", "tr"]:
		LocalizationManager.set_locale(loc)
		for key in ["RESUME_PROGRESS", "PROGRESS_LABEL"]:
			var text: String = LocalizationManager.translate(key).to_lower()
			if text.contains("filled") or text.contains("dolu") or text.contains("progress") or text.contains("ilerleme"):
				leftover += loc + ":" + key + " "
	_check("No 'filled', 'dolu' or 'progress' wording is left (%s)" % leftover, leftover.is_empty())
	_check("The Daily card's description line is gone from both languages", LocalizationManager.translate("DAILY_SUBTITLE") == "DAILY_SUBTITLE")
	LocalizationManager.set_locale("en")

func _test_daily_card() -> void:
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	var menu = app.main_menu
	DailyManager.save_daily_data({"completed_dates": [], "current_streak": 0, "longest_streak": 0, "last_completed_date": ""})
	menu.refresh_buttons()
	await _frames(3)
	_check("With no streak the Daily card is its name alone", not menu.daily_meta_label.visible and menu.daily_title_label.visible)
	var now := int(Time.get_unix_time_from_system())
	var dates: Array = []
	for d in range(3, 0, -1):
		dates.append(Time.get_date_string_from_unix_time(now - d * 86400))
	DailyManager.save_daily_data({"completed_dates": dates, "current_streak": 3, "longest_streak": 3, "last_completed_date": dates.back()})
	menu.refresh_buttons()
	await _frames(3)
	_check("With a streak the line under it shows the streak (%s)" % menu.daily_meta_label.text,
		menu.daily_meta_label.visible and menu.daily_meta_label.text == LocalizationManager.format_streak(DailyManager.get_current_streak()))
	DailyManager.save_daily_data({"completed_dates": [], "current_streak": 0, "longest_streak": 0, "last_completed_date": ""})
	app.queue_free()
	await process_frame

func _test_shell() -> void:
	var shell := FileAccess.get_file_as_string("res://web/shell.html")
	_check("The browser page's loading screen shows the name", shell.contains("id=\"status-name\"") and shell.contains("Just Sudoku<i></i>"))
	_check("in DM Serif Display, which comes with the page (a few letters, embedded)", shell.contains("font-family: 'DM Serif Display'") and shell.contains("data:font/woff2;base64,"))
	_check("with the blue full stop, and no splash image", shell.contains("#2563eb") and not shell.contains("$GODOT_SPLASH\""))
	_check("It is still Godot's page: the engine, the config and the progress line are there",
		shell.contains("$GODOT_URL") and shell.contains("$GODOT_CONFIG") and shell.contains("status-progress"))
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var uses := false
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Web":
			uses = cfg.get_value(section + ".options", "html/custom_html_shell", "") == "res://web/shell.html"
	_check("The Web export uses it", uses)
