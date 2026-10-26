extends SceneTree

## A touch screen sends each tap twice: as a touch and as the mouse event Godot makes from it.
## A Button counted both, so a digit key put its digit down and took it out again (a tap on a
## key did nothing) and a check box switched twice. One tap is one press.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")

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

## A finger tapping at `pos` (the app's own coordinates), the way a phone delivers it
func _tap(pos: Vector2) -> void:
	var at: Vector2 = root.get_final_transform() * pos
	var down_mouse := InputEventMouseButton.new()
	down_mouse.button_index = MOUSE_BUTTON_LEFT
	down_mouse.pressed = true
	down_mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	down_mouse.position = at
	down_mouse.global_position = at
	var down_touch := InputEventScreenTouch.new()
	down_touch.index = 0
	down_touch.pressed = true
	down_touch.position = at
	var up_mouse := down_mouse.duplicate() as InputEventMouseButton
	up_mouse.pressed = false
	up_mouse.button_mask = 0
	var up_touch := down_touch.duplicate() as InputEventScreenTouch
	up_touch.pressed = false
	root.push_input(down_mouse)
	root.push_input(down_touch)
	await _frames(2)
	root.push_input(up_mouse)
	root.push_input(up_touch)
	await _frames(3)

func _run() -> void:
	await process_frame
	print("\n=== ONE TAP, ONE PRESS ===")
	if DisplayServer.get_name() == "headless":
		print("  (no display: nothing to tap)")
		quit(0)
		return
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(7474, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	app.main_menu.continue_pressed.emit()
	await _frames(20)
	var screen = app.game_screen
	var grid = screen.sudoku_grid
	var empty := -1
	for i in 81:
		if screen.game_state.current_board.get_cell(i) == 0:
			empty = i
			break
	await _tap(grid.cells[empty].get_global_rect().get_center())
	_check("Tapping an empty cell selects it", grid.selected_idx == empty)
	var digit: int = screen.game_state.solution.get_cell(empty) if "solution" in screen.game_state else 0
	if digit == 0:
		for d in range(1, 10):
			if not screen.numpad.num_buttons[d - 1].disabled:
				digit = d
				break
	var key: Button = screen.numpad.num_buttons[digit - 1]
	await _tap(key.get_global_rect().get_center())
	_check("One tap on a digit key puts the digit in (%d)" % screen.game_state.current_board.get_cell(empty),
		screen.game_state.current_board.get_cell(empty) == digit)

	# Any button: one tap, one press
	var presses := {"n": 0}
	var plain := Button.new()
	plain.text = "x"
	plain.position = Vector2(150, 450)
	plain.size = Vector2(120, 60)
	plain.pressed.connect(func(): presses["n"] += 1)
	app.add_child(plain)
	await _frames(2)
	await _tap(plain.get_global_rect().get_center())
	_check("and a plain button is pressed once, not twice (%d)" % presses["n"], presses["n"] == 1)
	var box := CheckBox.new()
	box.text = "y"
	box.position = Vector2(150, 520)
	app.add_child(box)
	await _frames(2)
	await _tap(box.get_global_rect().get_center() - Vector2(box.size.x * 0.3, 0))
	_check("a check box switches once", box.button_pressed)
	SaveManager.clear_active_game()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
