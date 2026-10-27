extends SceneTree

## Smaller touches of motion and tidiness: the Glass effects switch slides before the screen redraws,
## the drop-downs and the Customize Theme button in Settings share one width, the tabs of the
## solution viewer slide a pill between them, the Fill notes button is a toggle, and a digit with all
## nine copies placed blinks (the cells and its key).

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
	print("\n=== MOTION AND TIDINESS ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = true
	await _test_glass_switch()
	await _test_settings_widths()
	await _test_segmented_pill()
	await _test_solution_tabs()
	await _test_fill_notes_toggle()
	await _test_digit_blink()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_glass_switch() -> void:
	var screen := SettingsScreen.new()
	screen.size = Vector2(390, 844)
	root.add_child(screen)
	await _frames(3)
	var redraws: Array[int] = [0]
	var counter := func(): redraws[0] += 1
	ThemeManager.add_listener(counter)
	var before: bool = AppSettings.glass_effects
	screen.glass_check.button_pressed = not before
	_check("The setting is saved at once", AppSettings.glass_effects == not before)
	_check("but the screen is not redrawn in the same frame, so the knob can slide first", redraws[0] == 0)
	await create_timer(ToggleSwitch.SLIDE_TIME + 0.15).timeout
	_check("it is redrawn once the slide is over", redraws[0] == 1)
	screen.glass_check.button_pressed = before
	await create_timer(ToggleSwitch.SLIDE_TIME + 0.15).timeout
	ThemeManager.remove_listener(counter)
	screen.queue_free()
	await process_frame

func _test_settings_widths() -> void:
	for size in [Vector2(360, 640), Vector2(390, 844)]:
		var screen := SettingsScreen.new()
		screen.size = size
		root.add_child(screen)
		await _frames(3)
		var widths: Array[float] = []
		for ctl in [screen.lang_option, screen.theme_option, screen.font_option, screen.text_size_option, screen.custom_theme_btn]:
			widths.append(ctl.custom_minimum_size.x)
		var same := true
		for w in widths:
			same = same and is_equal_approx(w, widths[0])
		_check("%s: the drop-downs and the Customize Theme button are one width %s" % [size, str(widths)], same)
		_check("and that is wide enough for the button's text (%.0f of %.0f)" % [screen.custom_theme_btn.get_minimum_size().x, widths[0]],
			screen.custom_theme_btn.get_minimum_size().x <= widths[0] + 0.5)
		LocalizationManager.set_locale("tr")
		await _frames(2)
		var tr_same := true
		for ctl in [screen.lang_option, screen.theme_option, screen.font_option, screen.text_size_option, screen.custom_theme_btn]:
			tr_same = tr_same and is_equal_approx(ctl.custom_minimum_size.x, screen.theme_option.custom_minimum_size.x)
		_check("%s: and still after switching to Turkish" % size, tr_same)
		LocalizationManager.set_locale("en")
		screen.queue_free()
		await process_frame

func _test_segmented_pill() -> void:
	var holder := Control.new()
	holder.size = Vector2(300, 60)
	root.add_child(holder)
	var seg := SegmentedControl.new()
	seg.add_segment("a", "One")
	seg.add_segment("b", "Two")
	holder.add_child(seg)
	await _frames(3)
	seg.select_index(0)
	_check("The first choice puts the pill in place at once", is_equal_approx(seg.pill_t, 1.0))
	seg.select_index(1)
	_check("A later choice starts the slide (%.2f)" % seg.pill_t, seg.pill_t < 1.0)
	var target := Rect2(seg.buttons[1].position, seg.buttons[1].size)
	_check("with the pill still on the first segment", seg._pill_rect().position.is_equal_approx(seg.buttons[0].position))
	seg.pill_t = 0.5
	var mid := seg._pill_rect()
	_check("halfway it is between the two", mid.position.x > seg.buttons[0].position.x and mid.position.x < target.position.x)
	await create_timer(SegmentedControl.SLIDE_TIME + 0.5).timeout
	_check("and it arrives", is_equal_approx(seg.pill_t, 1.0) and seg._pill_rect().position.is_equal_approx(target.position))
	AppSettings.animations_enabled = false
	seg.select_index(0)
	_check("With animations off it jumps", is_equal_approx(seg.pill_t, 1.0))
	AppSettings.animations_enabled = true
	holder.queue_free()
	await process_frame

func _test_solution_tabs() -> void:
	var dialog := SolutionDialog.new()
	root.add_child(dialog)
	dialog.open_solution(SudokuGenerator.generate(5551212, DifficultyAnalyzer.LEVEL_EASY).puzzle)
	await _frames(3)
	_check("The viewer's two tabs are a segmented control", dialog.mode_tabs is SegmentedControl and dialog.mode_tabs.buttons.size() == 2)
	_check("it starts on step by step", dialog.mode_tabs.get_selected_index() == 0 and dialog.current_mode == SolutionDialog.Mode.STEP_BY_STEP)
	dialog.mode_tabs.buttons[1].pressed.emit()
	_check("a tap on the second tab shows the full solution", dialog.current_mode == SolutionDialog.Mode.FULL_SOLUTION and dialog.full_info_panel.visible)
	_check("the new panel starts transparent and fades in (alpha %.2f)" % dialog.full_info_panel.modulate.a, dialog.full_info_panel.modulate.a < 0.5)
	await create_timer(0.6).timeout
	_check("and is fully visible after", is_equal_approx(dialog.full_info_panel.modulate.a, 1.0))
	dialog.switch_view_mode(SolutionDialog.Mode.STEP_BY_STEP)
	_check("switching from code moves the tabs too", dialog.mode_tabs.get_selected_index() == 0)
	dialog.queue_free()
	await process_frame

func _new_state(seed_val: int) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, DifficultyAnalyzer.LEVEL_EASY))
	return state

func _test_fill_notes_toggle() -> void:
	var state := _new_state(16180339)
	_check("A fresh board does not have all its notes", not state.all_notes_filled())
	_check("Fill notes fills them", state.fill_notes() and state.all_notes_filled())
	_check("a second fill has nothing to do", not state.fill_notes())
	_check("Clearing takes all of them off", state.clear_notes() and not state.all_notes_filled())
	var empty_idx := -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			empty_idx = i
			break
	_check("no cell keeps a note", state.current_board.candidates[empty_idx] == 0)
	_check("and clearing again has nothing to do", not state.clear_notes())
	_check("Undo brings the notes back", state.undo() and state.all_notes_filled())

	var screen := GameScreen.new()
	root.add_child(screen)
	var game := _new_state(16180339)
	screen.setup_game(game)
	screen._on_notes_toggle_pressed()
	var btn: Button = screen.action_dock.fill_notes_btn
	btn.pressed.emit()
	await _frames(2)
	_check("The button looks switched on when every cell has notes", screen.action_dock.fill_notes_on and game.all_notes_filled())
	btn.pressed.emit()
	await _frames(2)
	_check("pressing it again takes the notes off", not game.all_notes_filled() and not screen.action_dock.fill_notes_on)
	btn.pressed.emit()
	await _frames(2)
	_check("and again puts them back", game.all_notes_filled() and screen.action_dock.fill_notes_on)
	screen.queue_free()
	await process_frame

func _test_digit_blink() -> void:
	var screen := GameScreen.new()
	screen.size = Vector2(390, 844)
	root.add_child(screen)
	var state := _new_state(14142135)
	screen.setup_game(state)
	await _frames(4)
	var digit := 0
	for idx in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(idx) != 0:
			digit = state.current_board.get_cell(idx)
			break
	var cell = null
	for c in screen.sudoku_grid.cells:
		if c.value == digit:
			cell = c
			break
	cell.animate_digit_completed(0.0)
	var peak := 0.0
	var peaks := 0
	var was_up := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1400:
		await process_frame
		var a: float = cell._flash_rect.color.a if cell._flash_rect != null else 0.0
		peak = maxf(peak, a)
		var up: bool = a > 0.3
		if was_up and not up:
			peaks += 1
		was_up = up
	_check("A completed digit's cell flashes strongly (peak %.2f)" % peak, peak > 0.5)
	_check("more than once (%d blinks seen)" % peaks, peaks >= 2)

	var key: Button = screen.numpad.num_buttons[digit - 1]
	screen.numpad.blink_digit(digit)
	await _frames(4)
	_check("its key lights up too (%s)" % str(key.modulate), key.modulate.r > 1.05)
	await create_timer(1.2).timeout
	_check("and is back to normal after", key.modulate.is_equal_approx(Color.WHITE) and key.scale.is_equal_approx(Vector2.ONE))
	AppSettings.animations_enabled = false
	screen.numpad.blink_digit(digit)
	await _frames(2)
	_check("With animations off nothing blinks", key.modulate.is_equal_approx(Color.WHITE))
	AppSettings.animations_enabled = true
	screen.queue_free()
	await process_frame
