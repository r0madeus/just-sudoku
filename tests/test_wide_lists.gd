extends SceneTree

## On a wide window the lists are two columns, but a single row (one saved game, one history entry)
## spans the whole width, so its buttons are at the far edge and not in the middle of the screen.
## And the solution viewer has one way to close it: the X in the corner.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const SolutionDialog = preload("res://scenes/gameplay/dialogs/solution_dialog.gd")

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

func _record(i: int) -> Dictionary:
	return {"game_id": "wide_%d" % i, "seed": str(900 + i), "difficulty": "Easy", "score": 80, "time": 300.0,
		"mistakes": 0, "hints": 0, "is_daily": false, "timestamp": int(Time.get_unix_time_from_system()) - i * 86400, "puzzle": ""}

func _run() -> void:
	await process_frame
	print("\n=== WIDE LISTS AND ONE CLOSE ===")
	_test_rule()
	_test_solution_close()
	if DisplayServer.get_name() != "headless":
		await _test_screens()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_rule() -> void:
	var wide := Vector2(1280, 800)
	var phone := Vector2(390, 844)
	_check("A wide window: one row is one column", ResponsiveManager.list_columns(wide, 1) == 1)
	_check("two rows are two", ResponsiveManager.list_columns(wide, 2) == 2)
	_check("and many rows stay at two", ResponsiveManager.list_columns(wide, 9) == 2)
	_check("A phone is always one column", ResponsiveManager.list_columns(phone, 9) == 1)
	_check("No rows is one column too", ResponsiveManager.list_columns(wide, 0) == 1)

func _test_solution_close() -> void:
	var dialog := SolutionDialog.new()
	root.add_child(dialog)
	_check("The solution viewer has its X in the corner", dialog.close_btn != null and dialog.close_btn.visible)
	_check("and no second Close button at the bottom", not dialog.primary_btn.visible and not dialog.cancel_btn.visible)
	dialog.queue_free()

func _test_screens() -> void:
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	for i in 3:
		var st := GameState.new()
		st.init_from_puzzle(SudokuGenerator.generate(7000 + i, DifficultyAnalyzer.LEVEL_EASY))
		SaveManager.save_game_slot(st)
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	ResponsiveManager.apply_device_scaling(root, float(root.size.x) / 1100.0)
	await _frames(4)
	var saved := SaveManager.list_active_games()
	_check("Three saved games are listed for a wide window", saved.size() == 3)
	app.main_menu.load_game_requested.emit()
	await create_timer(1.0).timeout
	var list = app.load_game_screen.list_vbox
	_check("two columns for three saved games (%d)" % list.columns, list.columns == 2)
	for g in saved.slice(1):
		SaveManager.delete_game_slot(String(g.get("game_id", "")))
	app.load_game_screen.refresh_list()
	await create_timer(1.0).timeout
	_check("one column for one saved game (%d)" % list.columns, list.columns == 1)
	var item = list.get_child(0)
	_check("and its buttons are at the card's far edge (%d of %d)" % [int(item.resume_btn.get_global_rect().end.x), int(list.get_global_rect().end.x)],
		item.resume_btn.get_global_rect().end.x > list.get_global_rect().end.x - 40.0)

	HistoryManager.save_all_records([_record(0)])
	app.history_screen.refresh_history()
	await create_timer(1.0).timeout
	_check("One history entry: one column (%d)" % app.history_screen.list_vbox.columns, app.history_screen.list_vbox.columns == 1)
	HistoryManager.save_all_records([_record(0), _record(1), _record(2)])
	app.history_screen.refresh_history()
	await create_timer(1.0).timeout
	_check("three entries: two columns (%d)" % app.history_screen.list_vbox.columns, app.history_screen.list_vbox.columns == 2)
	HistoryManager.save_all_records([])
	for g in SaveManager.list_active_games():
		SaveManager.delete_game_slot(String(g.get("game_id", "")))
	app.queue_free()
	await process_frame
