extends SceneTree

## Small things that looked broken on a phone: the pause button showing "play" in a running game
## after leaving through the pause sheet, the language row titled in two languages, and the
## solution dialog changing size between steps and between its two views

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameScreen = preload("res://scenes/gameplay/game_screen.gd")
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

func _run() -> void:
	await process_frame
	print("\n=== STEADY UI ===")
	SettingsScreen.animations_enabled = false
	await _test_pause_icon()
	await _test_language_title()
	await _test_solution_dialog_size()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _state(seed_val: int, level: String = DifficultyAnalyzer.LEVEL_EASY) -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(seed_val, level))
	return state

func _shows(screen: GameScreen, icon: String) -> bool:
	return screen.pause_btn.icon == ThemeManager.get_icon(icon)

func _test_pause_icon() -> void:
	var screen := GameScreen.new()
	root.add_child(screen)
	await process_frame
	var state := _state(5151)
	screen.setup_game(state)
	_check("A running game shows the pause button", _shows(screen, "pause"))
	screen.toggle_pause()
	_check("A paused game shows play", _shows(screen, "play") and state.is_paused)
	# Pause → Menu, then back to the same game
	screen.pause_menu.menu_requested.emit()
	screen.setup_game(state)
	_check("Back from the menu the game runs again", not state.is_paused and screen.game_timer.is_running)
	_check("and shows the pause button, not play", _shows(screen, "pause"))
	screen.toggle_pause()
	screen.setup_game(_state(6161))
	_check("A new game set up while one was paused shows pause", _shows(screen, "pause") and not screen.pause_overlay.visible)
	screen.toggle_pause()
	screen.toggle_pause()
	_check("Pausing and resuming ends on pause", _shows(screen, "pause"))
	screen.queue_free()
	await process_frame

func _test_language_title() -> void:
	var settings := SettingsScreen.new()
	root.add_child(settings)
	await process_frame
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	_check("In Turkish the language row is titled Dil", settings.lang_row.title_label.text == "Dil")
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)
	_check("In English it is titled Language", settings.lang_row.title_label.text == "Language")
	settings.queue_free()
	await process_frame

func _test_solution_dialog_size() -> void:
	var dialog := SolutionDialog.new()
	dialog.theme = ThemeManager.build_godot_theme()
	root.add_child(dialog)
	var state := _state(7272, DifficultyAnalyzer.LEVEL_HARD)
	dialog.open_solution(state.initial_puzzle)
	await _frames(4)
	var size0: Vector2 = dialog.modal_panel.size
	var heights: Array[float] = []
	var longest := 0
	for i in range(dialog.steps.size() + 1):
		dialog.set_step(i)
		await process_frame
		heights.append(dialog.modal_panel.size.y)
		longest = maxi(longest, dialog.step_desc_label.text.length())
	var steady := heights.all(func(h): return absf(h - size0.y) < 1.0)
	_check("Stepping through %d steps keeps the dialog's size (longest explanation %d characters)" % [dialog.steps.size(), longest], steady)
	dialog.switch_view_mode(SolutionDialog.Mode.FULL_SOLUTION)
	await _frames(2)
	_check("The full solution view is the same size (%s vs %s)" % [dialog.modal_panel.size, size0],
		dialog.modal_panel.size.distance_to(size0) < 1.0)
	dialog.switch_view_mode(SolutionDialog.Mode.STEP_BY_STEP)
	await _frames(2)
	_check("and so is the way back", dialog.modal_panel.size.distance_to(size0) < 1.0)
	_check("A long explanation scrolls inside its lines",
		dialog.desc_scroll.custom_minimum_size.y >= dialog.step_desc_label.get_line_height() * SolutionDialog.DESC_LINES - 1.0)
	dialog.queue_free()
	await process_frame
