extends SceneTree

## Wide screens (a tablet in landscape, a 12.9" tablet in portrait, a large window) use two
## columns: Statistics and Settings put their sections side by side, History and Saved games
## show their rows two to a line, and the menu puts the resume card beside the actions in
## landscape. Phones and portrait tablets keep one column, and turning the device switches back.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const AdaptiveColumns = preload("res://scenes/ui/adaptive_columns.gd")

const WIDE := Vector2(1280, 800)
const TALL := Vector2(800, 1280)

var tests_passed: int = 0
var tests_failed: int = 0

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

func _run() -> void:
	print("========================================")
	print("🧪 RUNNING TABLET COLUMN TESTS")
	print("========================================")
	AppSettings.animations_enabled = false
	test_when_two_columns()
	await test_adaptive_columns()
	await test_statistics()
	await test_settings()
	await test_lists()
	await test_menu()
	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

func test_when_two_columns() -> void:
	print("\n--- Test 1: Which screens get two columns ---")
	assert_true(ResponsiveManager.content_columns(Vector2(390, 844)) == 1 and ResponsiveManager.content_columns(Vector2(360, 640)) == 1, "Phones: one")
	assert_true(ResponsiveManager.content_columns(TALL) == 1, "10-inch tablet in portrait: one (wider) column")
	assert_true(ResponsiveManager.content_columns(WIDE) == 2 and ResponsiveManager.content_columns(Vector2(1024, 768)) == 2, "Tablets in landscape: two")
	assert_true(ResponsiveManager.content_columns(Vector2(1024, 1366)) == 2, "12.9-inch tablet in portrait: two")

func test_adaptive_columns() -> void:
	print("\n--- Test 2: The column container ---")
	var cols := AdaptiveColumns.new()
	cols.separation = 20
	root.add_child(cols)
	var parts: Array[Control] = []
	for h in [100.0, 50.0, 80.0]:
		var c := Control.new()
		c.custom_minimum_size = Vector2(10, h)
		cols.add_child(c)
		parts.append(c)
	AdaptiveColumns.set_column(parts[2], 1)
	cols.size = Vector2(1000, 0)
	await _frames(2)
	assert_true(parts[1].position.y == 120.0 and parts[2].position.y == 190.0 and parts[0].size.x == 1000.0,
		"One column: stacked in order, full width")
	cols.columns = 2
	await _frames(2)
	assert_true(parts[2].position == Vector2(510, 0) and parts[2].size.x == 490.0 and parts[1].position == Vector2(0, 120),
		"Two columns: the right-hand part at the top of its own column (%s)" % str(parts[2].position))
	assert_true(cols.get_combined_minimum_size().y == 170.0, "Height of the taller column (%.0f)" % cols.get_combined_minimum_size().y)
	cols.queue_free()

func _screen_at(screen: Control, r: Vector2) -> void:
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = r
	screen._apply_responsive_layout()

func test_statistics() -> void:
	print("\n--- Test 3: Statistics ---")
	var stats := StatisticsScreen.new()
	root.add_child(stats)
	_screen_at(stats, WIDE)
	stats.refresh_stats()
	await _frames(4)
	var cards: Array = stats.stats_vbox.get_children()
	var overview: Control = cards[0]
	var ach: Control = stats.stats_vbox.find_child("AchievementsCard", false, false)
	assert_true(stats.stats_vbox.columns == 2, "Two columns on a landscape tablet")
	assert_true(ach.global_position.x > overview.global_position.x + overview.size.x and is_equal_approx(ach.global_position.y, overview.global_position.y),
		"Achievements beside the overview, from the top")
	_screen_at(stats, TALL)
	await _frames(4)
	assert_true(stats.stats_vbox.columns == 1 and ach.global_position.y > overview.global_position.y + overview.size.y
		and is_equal_approx(ach.global_position.x, overview.global_position.x), "Turned to portrait: one column again")
	stats.queue_free()
	await _frames(1)

func test_settings() -> void:
	print("\n--- Test 4: Settings ---")
	var settings := SettingsScreen.new()
	root.add_child(settings)
	_screen_at(settings, WIDE)
	await _frames(4)
	var appearance: Control = settings.card_appearance
	var gameplay: Control = settings.card_gameplay
	var feedback: Control = settings.card_feedback
	assert_true(gameplay.global_position.x > appearance.global_position.x + appearance.size.x
		and feedback.global_position.x == gameplay.global_position.x and feedback.global_position.y > gameplay.global_position.y,
		"Appearance on the left; Gameplay and Feedback on the right")
	_screen_at(settings, TALL)
	await _frames(4)
	assert_true(gameplay.global_position.y > appearance.global_position.y + appearance.size.y, "Portrait: one column")
	settings.queue_free()
	await _frames(1)

func _row_positions(list: GridContainer) -> Array:
	return [list.get_child(0).global_position, list.get_child(1).global_position, list.get_child(2).global_position]

func test_lists() -> void:
	print("\n--- Test 5: History and Saved games rows ---")
	var slots: Array[String] = []
	for i in range(3):
		HistoryManager.add_record({"game_id": "tab_%d" % i, "seed": 700 + i, "difficulty": DifficultyAnalyzer.LEVEL_EASY, "score": 80, "time": 100.0})
		var st := GameState.new()
		st.init_from_puzzle(SudokuGenerator.generate(710 + i, DifficultyAnalyzer.LEVEL_EASY))
		SaveManager.save_game_slot(st)
		slots.append(st.game_id)
	var history := HistoryScreen.new()
	root.add_child(history)
	_screen_at(history, WIDE)
	history.refresh_history()
	await _frames(4)
	var p := _row_positions(history.list_vbox)
	assert_true(history.list_vbox.columns == 2 and is_equal_approx(p[0].y, p[1].y) and p[1].x > p[0].x and p[2].y > p[0].y,
		"History: two rows to a line")
	_screen_at(history, TALL)
	await _frames(4)
	p = _row_positions(history.list_vbox)
	assert_true(history.list_vbox.columns == 1 and p[1].y > p[0].y, "History in portrait: one row to a line")
	history.queue_free()

	var saved := LoadGameScreen.new()
	root.add_child(saved)
	_screen_at(saved, WIDE)
	saved.refresh_list()
	await _frames(4)
	p = _row_positions(saved.list_vbox)
	assert_true(saved.list_vbox.columns == 2 and is_equal_approx(p[0].y, p[1].y), "Saved games: two rows to a line")
	saved.queue_free()
	for id in slots:
		SaveManager.delete_game_slot(id)
	await _frames(1)

func test_menu() -> void:
	print("\n--- Test 6: Menu ---")
	var menu := MainMenu.new()
	root.add_child(menu)
	_screen_at(menu, WIDE)
	await _frames(4)
	assert_true(menu.is_wide and menu.resume_holder.get_parent() == menu.wide_row and menu.actions_vbox.get_parent() == menu.wide_right,
		"Landscape tablet: resume card and actions side by side")
	assert_true(menu.resume_holder.global_position.x < menu.actions_vbox.global_position.x, "Resume card on the left")
	assert_true(menu.nav_glass.global_position.x >= menu.actions_vbox.global_position.x - 1.0, "Navigation under the actions")

	_screen_at(menu, TALL)
	await _frames(4)
	var order: Array = [menu.header_vbox, menu.resume_holder, menu.mid_spacer, menu.actions_vbox, menu.bottom_spacer, menu.nav_section_vbox]
	var ok := not menu.is_wide and not menu.wide_row.visible
	for i in range(order.size()):
		ok = ok and order[i].get_parent() == menu.root_vbox
		if i > 0:
			ok = ok and order[i].get_index() > order[i - 1].get_index()
	assert_true(ok, "Turned to portrait: one column in the original order")
	_screen_at(menu, Vector2(1024, 1366))
	await _frames(2)
	assert_true(not menu.is_wide, "A portrait tablet keeps the single-column menu")
	menu.queue_free()
	await _frames(1)
