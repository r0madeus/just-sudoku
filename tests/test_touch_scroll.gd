extends SceneTree

## Lists scroll like a phone's: the content follows the finger, glides on after a flick, and a
## finger that scrolls never ticks the box or opens the list it started on. Before, a drag on a
## checkbox in Settings ticked it, lists only scrolled from the gaps between controls, and the
## wheel-like steps felt nothing like a touch screen.

const TouchScroll = preload("res://scenes/ui/touch_scroll.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const ResumeCard = preload("res://scenes/menus/resume_card.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")

const ROWS: int = 40
const ROW_H: float = 60.0

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
	print("\n=== TOUCH SCROLL ===")
	await _test_list()
	await _test_modal_and_nesting()
	await _test_resume_card()
	await _test_buttons()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _button(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)

## A finger from `from` straight up or down by `dy`, in `steps` moves, one per frame
func _drag(from: Vector2, dy: float, steps: int = 8, lift: bool = true) -> void:
	_button(true, from)
	for i in range(1, steps + 1):
		await process_frame
		_move(from + Vector2(0, dy * i / steps))
	if lift:
		_button(false, from + Vector2(0, dy))

func _tap(pos: Vector2) -> void:
	_button(true, pos)
	_button(false, pos)

## A full-screen list of checkboxes
func _list(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for i in ROWS:
		var cb := CheckBox.new()
		cb.text = "Row %d" % i
		cb.custom_minimum_size = Vector2(0, ROW_H)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(cb)
	TouchScroll.attach(scroll)
	return scroll

func _ticked(scroll: ScrollContainer) -> int:
	var n := 0
	for cb in scroll.get_child(0).get_children():
		if cb.button_pressed:
			n += 1
	return n

func _ts(scroll: ScrollContainer) -> TouchScroll:
	return TouchScroll.attach(scroll)

func _test_list() -> void:
	var scroll := _list(root)
	await _frames(3)
	var ts := _ts(scroll)
	_check("Attaching twice keeps one scroller", TouchScroll.attach(scroll) == ts and ts.max_scroll() > 0.0)
	var first: CheckBox = scroll.get_child(0).get_child(0)
	var at := first.get_global_rect().get_center()

	_tap(at)
	await process_frame
	_check("A tap ticks the box under the finger", first.button_pressed and _ticked(scroll) == 1)
	_tap(at)
	await process_frame
	_check("and a second tap unticks it", not first.button_pressed)

	await _drag(at + Vector2(0, 300), -300.0)
	var after_drag: int = scroll.scroll_vertical
	_check("A drag scrolls with the finger (%d px for 300, less the touch slop)" % after_drag,
		after_drag >= 300 - TouchScroll.SLOP - 1 and after_drag <= 300)
	_check("and ticks nothing it passed over", _ticked(scroll) == 0)

	await _frames(2)
	_check("A flick keeps gliding after the finger is lifted", scroll.scroll_vertical > after_drag and ts.velocity > 0.0)
	var gliding: int = scroll.scroll_vertical
	_button(true, at)
	await process_frame
	_check("A finger on a gliding list stops it", ts.velocity == 0.0)
	await _frames(3)
	_check("right where it was", absi(scroll.scroll_vertical - gliding) <= 60)
	_button(false, at)
	await process_frame
	_check("and that touch ticks nothing", _ticked(scroll) == 0)

	# A slow, steady drag: no glide after it
	scroll.scroll_vertical = 0
	_button(true, at + Vector2(0, 200))
	for i in range(1, 11):
		await create_timer(0.03).timeout
		_move(at + Vector2(0, 200 - 2.0 * i))
	await create_timer(0.12).timeout
	_move(at + Vector2(0, 180))
	_button(false, at + Vector2(0, 180))
	_check("A drag that stops before lifting does not glide", ts.velocity == 0.0)

	# Held still past the tap timeout, then moved: the press is taken back
	scroll.scroll_vertical = 0
	await process_frame
	_button(true, at)
	await create_timer(TouchScroll.TAP_TIMEOUT + 0.1).timeout
	_check("A finger held still presses the control (it shows it is held)", ts.state == TouchScroll.State.PRESSED and first.is_pressed() == false)
	await _drag(at, -200.0, 6, false)
	_button(false, at + Vector2(0, -200))
	await process_frame
	_check("but moving on still scrolls", scroll.scroll_vertical > 100)
	_check("and the held box is not ticked", _ticked(scroll) == 0)

	# Held still and lifted: a tap all the same (once the last flick has stopped)
	ts.velocity = 0.0
	scroll.scroll_vertical = 0
	await process_frame
	_button(true, at)
	await create_timer(TouchScroll.TAP_TIMEOUT + 0.1).timeout
	_button(false, at)
	await process_frame
	_check("A slow tap still ticks", first.button_pressed)
	first.button_pressed = false

	# The far end: the glide stops there and the scroll stays in range
	scroll.scroll_vertical = int(ts.max_scroll()) - 50
	await _drag(at + Vector2(0, 300), -300.0, 4)
	await _frames(20)
	_check("A flick past the end stops at the end (%d of %d)" % [scroll.scroll_vertical, int(ts.max_scroll())],
		scroll.scroll_vertical == int(ts.max_scroll()) and ts.velocity == 0.0)

	# A list that fits leaves the controls alone
	for cb in scroll.get_child(0).get_children().slice(5):
		cb.queue_free()
	await _frames(3)
	_button(true, at)
	_check("A list with nothing to scroll does not hold presses back", ts.state == TouchScroll.State.IDLE)
	_button(false, at)
	await process_frame
	_check("its taps go straight through", first.button_pressed)
	scroll.queue_free()
	await process_frame

func _test_modal_and_nesting() -> void:
	var scroll := _list(root)
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_to_group(AppModal.GROUP)
	root.add_child(modal)
	var inner := _list(modal)
	inner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inner.custom_minimum_size = Vector2(300, 300)
	inner.position = Vector2(20, 200)
	inner.size = Vector2(300, 300)
	await _frames(3)
	var at := Vector2(10, 100)
	await _drag(at + Vector2(0, 300), -300.0)
	_check("A list under an open dialog does not scroll", scroll.scroll_vertical == 0 and _ts(scroll).state == TouchScroll.State.IDLE)
	await _drag(Vector2(100, 450), -150.0)
	_check("but a list inside the dialog does", inner.scroll_vertical > 100)

	modal.visible = false
	# A list inside another list: the inner one moves, the outer one stays
	var nested := _list(scroll.get_child(0))
	nested.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nested.custom_minimum_size = Vector2(300, 240)
	scroll.get_child(0).move_child(nested, 0)
	await _frames(3)
	var on_nested := nested.get_global_rect().get_center() + Vector2(0, 60)
	await _drag(on_nested, -100.0)
	_check("Inside a list in a list the inner one scrolls (%d) and the outer one stays (%d)" % [nested.scroll_vertical, scroll.scroll_vertical],
		nested.scroll_vertical > 50 and scroll.scroll_vertical == 0)
	await _frames(30)
	scroll.queue_free()
	modal.queue_free()
	await process_frame

func _test_resume_card() -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var card := ResumeCard.new()
	holder.add_child(card)
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(4242, DifficultyAnalyzer.LEVEL_EASY))
	card.set_game(state)
	await _frames(3)
	var count := [0]
	card.pressed.connect(func(): count[0] += 1)
	var at := card.get_global_rect().get_center()
	# A phone sends a touch and an emulated mouse press for the same finger
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = at
	root.push_input(touch, true)
	_button(true, at)
	_check("The game card does not open as the finger lands", count[0] == 0)
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch, true)
	_button(false, at)
	await process_frame
	_check("but once when it is lifted (%d)" % count[0], count[0] == 1)
	_button(true, at)
	_button(false, at + Vector2(0, card.size.y + 40))
	await process_frame
	_check("A finger that slides off the card before lifting does not open it", count[0] == 1)
	holder.queue_free()
	await process_frame

func _test_buttons() -> void:
	var numpad := SmartNumpad.new()
	root.add_child(numpad)
	await _frames(2)
	var digit_buttons := numpad.find_children("*", "Button", true, false)
	_check("Number pad digits go in as the finger lands",
		not digit_buttons.is_empty() and digit_buttons.all(func(b): return b.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS))
	numpad.queue_free()
	var settings := SettingsScreen.new()
	root.add_child(settings)
	await process_frame
	var options: Array[OptionButton] = [settings.lang_option, settings.theme_option, settings.font_option, settings.text_size_option]
	_check("Settings lists open when the finger is lifted",
		options.all(func(o): return o.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE))
	var scrolls := settings.find_children("*", "ScrollContainer", true, false)
	_check("and Settings scrolls by touch",
		not scrolls.is_empty() and scrolls[0].get_children(true).any(func(c): return c is TouchScroll))
	settings.queue_free()
	await process_frame
