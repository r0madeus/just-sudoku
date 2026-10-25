extends SceneTree

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SettingRow = preload("res://scenes/ui/setting_row.gd")
const GameRecordItem = preload("res://scenes/ui/game_record_item.gd")

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING SETTING_ROW & GAME_RECORD_ITEM TESTS")
	print("========================================")

	test_setting_row_properties()
	test_setting_row_checkbox_interaction()
	test_game_record_item_history_mode()
	test_game_record_item_saved_game_mode()

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [passed_count, failed_count])
	print("========================================")

	if failed_count > 0:
		quit(1)
	else:
		quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ PASS: %s" % msg)
		passed_count += 1
	else:
		printerr("  ✗ FAIL: %s" % msg)
		failed_count += 1

func test_setting_row_properties() -> void:
	print("\n--- Test 1: SettingRow Structure & Properties ---")
	var cb := CheckBox.new()
	var row := SettingRow.new("Smart Numpad", "Disables impossible numbers dynamically", cb)
	root.add_child(row)

	assert_true(row.title_label != null, "SettingRow has title_label")
	assert_true(row.title_label.text == "Smart Numpad", "Title matches expected text")
	assert_true(row.desc_label != null, "SettingRow has desc_label")
	assert_true(row.desc_label.text == "Disables impossible numbers dynamically", "Description matches expected text")
	assert_true(row.desc_label.visible == true, "Description is visible when non-empty")
	assert_true(row.get_control() == cb, "Control correctly bound")
	assert_true(row.custom_minimum_size.y >= 44.0, "Touch target height is >= 44px for mobile comfort")

	row.set_description("")
	assert_true(row.desc_label.visible == false, "Description hidden when empty")

	row.queue_free()

func test_setting_row_checkbox_interaction() -> void:
	print("\n--- Test 2: SettingRow Checkbox Touch Interaction ---")
	var cb := CheckBox.new()
	cb.button_pressed = false
	var row := SettingRow.new("UI Animations", "Enable smooth animations", cb)
	root.add_child(row)

	assert_true(cb.button_pressed == false, "Initial checkbox state is false")

	# Simulate clicking the row: pressed and let go on it
	row.size = Vector2(300, 44)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(20, 20)
	row._gui_input(mb)
	assert_true(cb.button_pressed == false, "A press alone does not toggle the checkbox yet")
	var up: InputEventMouseButton = mb.duplicate()
	up.pressed = false
	row._gui_input(up)

	assert_true(cb.button_pressed == true, "Clicking SettingRow toggled checkbox to true")

	row._gui_input(mb)
	row._gui_input(up)
	assert_true(cb.button_pressed == false, "Clicking SettingRow toggled checkbox to false")

	row.queue_free()

func test_game_record_item_history_mode() -> void:
	print("\n--- Test 3: GameRecordItem History Mode ---")
	var item := GameRecordItem.new()
	root.add_child(item)

	var record := {
		"difficulty": "Hard",
		"score": 88,
		"time": 245.0,
		"mistakes": 1,
		"hints": 0,
		"is_replay": true,
		"seed": 98765
	}
	var best_record := {
		"score": 95
	}

	item.setup_history(record, best_record)

	# Verify test contract: child 0 is HBoxContainer and contains Replay button
	assert_true(item.get_child_count() > 0, "Item has children")
	var hbox = item.get_child(0)
	assert_true(hbox is HBoxContainer, "Child 0 is HBoxContainer")

	var found_btn := false
	for c in hbox.get_children():
		if c is Button and (c.text.contains("Tekrar") or c.text.contains("Replay") or c.tooltip_text.contains("Tekrar") or c.tooltip_text.contains("Replay") or c.name == "ReplayButton"):
			found_btn = true
			break
	assert_true(found_btn, "HBoxContainer contains Replay button")

	assert_true(item.diff_label != null and item.diff_label.text.length() > 0, "Difficulty label displayed")
	assert_true(item.replay_badge != null and item.replay_badge.text == LocalizationManager.translate("BADGE_REPLAY"), "Replay badge displayed")
	assert_true(item.best_score_label != null, "Best score comparison displayed")
	assert_true(item.time_label != null, "Time label displayed")
	assert_true(item.mistakes_label != null, "Mistakes label displayed")
	assert_true(item.hints_label != null, "Hints label displayed")

	# Test signal emission
	var res := {"seed": 0, "diff": ""}
	item.replay_pressed.connect(func(s: int, d: String):
		res["seed"] = s
		res["diff"] = d
	)
	item.replay_btn.pressed.emit()
	assert_true(res["seed"] == 98765 and res["diff"] == "Hard", "replay_pressed signal emitted with correct parameters")

	item.queue_free()

func test_game_record_item_saved_game_mode() -> void:
	print("\n--- Test 4: GameRecordItem Saved Game Mode ---")
	var item := GameRecordItem.new()
	root.add_child(item)

	var game_data := {
		"game_id": "game_test_123",
		"difficulty": "Medium",
		"progress_percentage": 55,
		"elapsed_time": 130.0
	}

	item.setup_saved_game(game_data)

	assert_true(item.diff_label != null, "Difficulty label displayed")
	assert_true(item.progress_label != null, "Progress label displayed")
	assert_true(item.time_label != null, "Time label displayed")
	assert_true(item.resume_btn != null, "Resume button exists")
	assert_true(item.more_btn != null, "More (⋯) button exists")
	assert_true(item.thumbnail != null, "Board thumbnail exists")

	# Share and Delete live in the sheet behind "⋯"
	item.more_btn.pressed.emit()
	assert_true(item.share_btn != null, "Share button exists")
	assert_true(item.delete_btn != null, "Delete button exists")

	# Test signals
	var res_play := {"id": ""}
	item.play_pressed.connect(func(id: String): res_play["id"] = id)
	item.resume_btn.pressed.emit()
	assert_true(res_play["id"] == "game_test_123", "play_pressed signal emitted")

	var res_del := {"id": ""}
	item.delete_pressed.connect(func(id: String): res_del["id"] = id)
	item.delete_btn.pressed.emit()
	assert_true(res_del["id"] == "game_test_123", "delete_pressed signal emitted")

	item.queue_free()
