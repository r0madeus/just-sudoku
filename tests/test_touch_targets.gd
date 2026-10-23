extends SceneTree

## Touch targets: phones and tablets lay the UI out in dp (1 logical px = 1 dp), and on every
## screen and dialog each tappable control is at least 44 x 44 dp and stays on screen, on a
## regular 411 x 731 dp phone, a small 360 x 640 dp one and an 800 dp wide tablet, upright
## and turned to landscape.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var app: AppRoot

func _init() -> void:
	_run.call_deferred()

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _interactive(c: Control) -> bool:
	if c is BaseButton or c is LineEdit or c is TextEdit or c is Slider:
		return c.mouse_filter != Control.MOUSE_FILTER_IGNORE
	return false

func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _name(c: Control) -> String:
	var t: String = c.text if c is Button else ""
	if t == "" and c.tooltip_text != "":
		t = c.tooltip_text
	return "%s '%s'" % [c.get_class(), t.left(24)]

## Only the top layer can be tapped while a dialog is open
func _check(ctx: String) -> void:
	await _frames(8)
	var scope: Array = []
	for m in get_nodes_in_group(AppModal.GROUP):
		if m.is_visible_in_tree():
			scope.append(m)
	if scope.is_empty():
		scope = [app]
	var view := Rect2(Vector2.ZERO, app.size).grow(1.0)
	var small: Array = []
	var outside: Array = []
	for sc in scope:
		for n in sc.find_children("*", "Control", true, false):
			var c := n as Control
			if not c.is_visible_in_tree() or c.size.x <= 0.0 or not _interactive(c):
				continue
			var target := c
			# A settings checkbox is toggled by tapping anywhere on its row
			if c is CheckBox and c.get_parent() != null and c.get_parent().get_parent() is SettingRow:
				target = c.get_parent().get_parent()
			if target.size.x < ResponsiveManager.TOUCH_TARGET_MIN - 0.5 or target.size.y < ResponsiveManager.TOUCH_TARGET_MIN - 0.5:
				small.append("%s %.0fx%.0f" % [_name(c), target.size.x, target.size.y])
			if not _in_scroll(c) and not view.encloses(c.get_global_rect()):
				outside.append(_name(c))
	assert_true(small.is_empty() and outside.is_empty(), "%s at %dx%d: targets ≥ 44 dp and on screen %s" % [
		ctx, int(app.size.x), int(app.size.y), str(small + outside) if not (small + outside).is_empty() else ""])

func _close_modals() -> void:
	for m in get_nodes_in_group(AppModal.GROUP):
		if m.visible and m.has_method("close_modal"):
			m.close_modal()
	await _frames(3)

func test_dp_scaling() -> void:
	print("\n--- Test 1: Phones and tablets lay out in dp ---")
	for density in [2.625, 2.0, 1.5]:
		ResponsiveManager.apply_device_scaling(root, density)
		await _frames(2)
		var scale: float = root.get_final_transform().get_scale().x
		assert_true(absf(scale - density) < 0.02, "Density %.3f: 1 logical px = %.3f device px" % [density, scale])
	# Desktop keeps the project's base size
	assert_true(OS.has_feature("android") or OS.has_feature("ios") or ResponsiveManager.screen_density() == 0.0, "Desktop is not rescaled")

func _tour() -> void:
	await _check("Menu")
	app.new_game_dialog.open_dialog()
	await _check("New game")
	await _close_modals()
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_MEDIUM))
	app._start_game_session(state)
	await _check("Game")
	app.game_screen.action_dock.set_notes_active(true)
	await _check("Game, notes mode")
	app.game_screen.action_dock.set_notes_active(false)
	app.game_screen._on_hint_pressed()
	await _check("Hint")
	await _close_modals()
	app.game_screen.toggle_pause()
	await _check("Pause")
	app.game_screen.toggle_pause()
	await _close_modals()
	var sd: SolutionDialog = app.game_screen.solution_dialog
	sd.open_solution(state.initial_puzzle, state.current_board)
	sd.set_step(5)
	await _check("Solution")
	sd.switch_view_mode(SolutionDialog.Mode.FULL_SOLUTION)
	await _check("Full solution")
	await _close_modals()
	app._show_screen(app.main_menu)
	app.main_menu.refresh_buttons()
	await _check("Menu with a game to resume")
	app._show_screen(app.load_game_screen)
	app.load_game_screen.refresh_list()
	await _check("Saved games")
	var items := app.load_game_screen.find_children("*", "GameRecordItem", true, false)
	if items.size() > 0:
		items[0].open_actions()
		await _check("Saved game actions")
		await _close_modals()
	app.import_puzzle_dialog.open_dialog()
	await _check("Import")
	await _close_modals()
	app._show_screen(app.history_screen)
	app.history_screen.refresh_history()
	await _check("History")
	app._show_screen(app.statistics_screen)
	app.statistics_screen.refresh_stats()
	await _check("Statistics")
	app.techniques_screen.show_list()
	app._show_screen(app.techniques_screen)
	await _check("Techniques")
	app.techniques_screen.open_lesson("X-Wing")
	await _check("Technique lesson")
	app.techniques_screen.show_list()
	app._show_screen(app.settings_screen)
	await _check("Settings")
	app.custom_theme_dialog.open_dialog()
	await _check("Custom theme")
	await _close_modals()
	app._show_screen(app.main_menu)
	await _frames(3)

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING TOUCH TARGET TESTS")
	print("========================================")
	SettingsScreen.auto_open_last_game = false
	SettingsScreen.animations_enabled = false
	HistoryManager.add_record({"game_id": "touch_1", "seed": 101, "difficulty": "Hard", "score": 88,
		"time": 420.0, "mistakes": 1, "hints": 0, "is_replay": false})
	var st := GameState.new()
	st.init_from_puzzle(SudokuGenerator.generate(777, DifficultyAnalyzer.LEVEL_HARD))
	st.game_id = "touch_saved"
	SaveManager.save_game_slot(st)
	app = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(6)

	await test_dp_scaling()
	for width in [411.0, 360.0, 800.0]:
		print("\n--- Every screen on a %d dp wide %s ---" % [int(width), "tablet" if width >= 600.0 else "phone"])
		ResponsiveManager.apply_device_scaling(root, root.size.x / width)
		await _frames(4)
		await _tour()

	print("\n--- Every screen on a tablet turned to landscape (1280 x 800 dp) ---")
	root.size = Vector2i(root.size.y, roundi(root.size.y * 800.0 / 1280.0))
	ResponsiveManager.apply_device_scaling(root, root.size.x / 1280.0)
	await _frames(6)
	await _tour()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)
