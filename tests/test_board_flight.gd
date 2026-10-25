extends SceneTree

## Tapping the resume card on the home screen grows the card's board into the game's board (the
## menu dissolves and the rest of the game comes in around it); leaving the game shrinks the
## board back into the card. The Continue button and the other ways in keep the slide, and
## nothing flies with animations off or with no game to return to.

const BoardFlight = preload("res://scenes/ui/board_flight.gd")
const AppRoot = preload("res://scenes/app_root.gd")
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

func _run() -> void:
	await process_frame
	print("\n=== BOARD FLIGHT ===")
	if DisplayServer.get_name() == "headless":
		print("  (no display: nothing to see)")
		quit(0)
		return
	AppSettings.auto_open_last_game = false
	await _test_flights()
	await _test_other_ways_in()
	await _test_nothing_to_fly()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _saved_game() -> GameState:
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(7474, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	return state

func _app_on_menu() -> Control:
	AppSettings.animations_enabled = true
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	# Past the start-up fade-in
	await create_timer(AppRoot.REVEAL_LATEST + AppRoot.REVEAL_TIME + 0.3).timeout
	app.main_menu.refresh_buttons()
	await _frames(3)
	return app

func _flight(app: Control) -> BoardFlight:
	for c in app.get_children():
		if c is BoardFlight:
			return c
	return null

func _square(r: Rect2) -> Rect2:
	return AppRoot._square(r)

func _close(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return a.position.distance_to(b.position) <= tolerance and a.size.distance_to(b.size) <= tolerance

## Frames until `flying` is over (or `seconds` pass); the flying board's sizes and last
## rectangle are collected on the way
func _watch(app: Control, seconds: float) -> Dictionary:
	var out := {"sizes": [], "from": Rect2(), "last": Rect2(), "max_flights": 0}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await process_frame
		var count := 0
		for c in app.get_children():
			if c is BoardFlight:
				count += 1
		out["max_flights"] = maxi(out["max_flights"], count)
		var f := _flight(app)
		if f != null:
			if out["sizes"].is_empty():
				# Where it set off from, not where it is by the first frame we see (a slow machine
				# sees it a good way on)
				out["from"] = f._from
			out["sizes"].append(f.size.x)
			out["last"] = f.get_global_rect()
		if not app._board_flying and not out["sizes"].is_empty():
			break
	return out

func _non_decreasing(sizes: Array, tolerance: float = 0.5) -> bool:
	for i in range(1, sizes.size()):
		if sizes[i] < sizes[i - 1] - tolerance:
			return false
	return true

func _non_increasing(sizes: Array, tolerance: float = 0.5) -> bool:
	for i in range(1, sizes.size()):
		if sizes[i] > sizes[i - 1] + tolerance:
			return false
	return true

func _test_flights() -> void:
	_saved_game()
	var app := await _app_on_menu()
	var menu = app.main_menu
	var card = menu.resume_card
	var from: Rect2 = _square(card.mini_board.get_global_rect())
	_check("The home screen has a resume card with a game", card.has_game and card.is_visible_in_tree())

	card.pressed.emit()
	_check("Tapping the card starts a flight: the game is the current screen, hidden for now",
		app._board_flying and app.current_screen == app.game_screen and app.game_screen.modulate.a == 0.0 and app.game_screen.game_state != null)
	app.handle_back()
	_check("Back does nothing while the board flies", app.current_screen == app.game_screen and app._board_flying)
	await _frames(3)
	card.pressed.emit()
	await _frames(1)
	var count := 0
	for c in app.get_children():
		if c is BoardFlight:
			count += 1
	_check("a second tap does not start a second flight (%d)" % count, count == 1)
	var f := _flight(app)
	_check("the board that flies is the card's, from where the card's is", f != null and _close(f._from, from, 1.0))
	_check("the card's own board gives way to it", card.mini_board.modulate.a == 0.0)
	var grid: Control = app.game_screen.sudoku_grid
	_check("and the game's board waits for it", grid.modulate.a == 0.0)
	var seen := await _watch(app, 1.5)
	var sizes: Array = seen["sizes"]
	var to: Rect2 = _square(grid.get_global_rect())
	# Measured from where it set off, not from the first frame a slow machine happens to show
	_check("It grows as it goes (%d px from %d px to %d px)" % [int(sizes[0]), int(seen["from"].size.x), int(sizes[sizes.size() - 1])],
		sizes.size() > 2 and sizes[sizes.size() - 1] > seen["from"].size.x * 1.8 and _non_decreasing(sizes))
	_check("and lands on the game's board", _close(seen["last"], to, 3.0))
	_check("The flight ends: no flying board is left", not app._board_flying and _flight(app) == null)
	_check("the game's board and the card's are back to full", grid.modulate.a == 1.0 and card.mini_board.modulate.a == 1.0)
	_check("the game is on show, the menu out of the way and ready for next time",
		app.game_screen.visible and app.game_screen.modulate.a == 1.0 and not menu.visible and menu.modulate.a == 1.0)

	# Leaving the game: the board shrinks into the card
	app.game_screen._on_back_pressed()
	_check("Leaving the game starts the flight back: the menu is the current screen", app._board_flying and app.current_screen == menu)
	var back := await _watch(app, 1.5)
	var back_sizes: Array = back["sizes"]
	var card_board: Rect2 = _square(card.mini_board.get_global_rect())
	_check("The board shrinks as it goes (%d px from %d px to %d px)" % [int(back_sizes[0]), int(back["from"].size.x), int(back_sizes[back_sizes.size() - 1])],
		back_sizes.size() > 2 and back_sizes[back_sizes.size() - 1] < back["from"].size.x * 0.6 and _non_increasing(back_sizes))
	_check("from the game's board", _close(back["from"], to, 1.0))
	_check("into the card's", _close(back["last"], card_board, 3.0))
	_check("The menu is on show again, the game out of the way",
		menu.visible and menu.modulate.a == 1.0 and not app.game_screen.visible and not app._board_flying and _flight(app) == null)
	_check("the card shows its board again and the game's is ready for next time",
		card.mini_board.modulate.a == 1.0 and app.game_screen.sudoku_grid.modulate.a == 1.0 and app.game_screen.modulate.a == 1.0)
	_check("and offsets and opacity are at rest", menu.offset_left == 0.0 and menu.offset_right == 0.0)
	SaveManager.clear_active_game()
	app.queue_free()
	await process_frame

func _test_other_ways_in() -> void:
	_saved_game()
	var app := await _app_on_menu()
	var menu = app.main_menu
	menu.continue_pressed.emit()
	_check("The Continue button keeps the slide: no board flies", not app._board_flying and _flight(app) == null
		and app.current_screen == app.game_screen)
	_check("the game slides in from the right", app.game_screen.offset_left > AppRoot.TRANSITION_SLIDE * 0.5)
	await create_timer(AppRoot.TRANSITION_TIME + 0.3).timeout
	_check("and rests in its place", app.game_screen.offset_left == 0.0 and app.game_screen.modulate.a == 1.0)
	# However the game was opened, leaving it returns the board to the card
	app.game_screen._on_back_pressed()
	_check("Leaving it still shrinks the board into the card", app._board_flying and app.current_screen == menu)
	await _watch(app, 1.5)
	_check("and ends on the menu", menu.visible and not app._board_flying)
	SaveManager.clear_active_game()
	app.queue_free()
	await process_frame

func _test_nothing_to_fly() -> void:
	# Animations off: at once, as before
	_saved_game()
	AppSettings.animations_enabled = false
	var plain: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(plain)
	await _frames(4)
	plain.main_menu.refresh_buttons()
	await _frames(2)
	plain.main_menu.resume_card.pressed.emit()
	_check("With animations off the card opens the game at once", not plain._board_flying and _flight(plain) == null
		and plain.current_screen == plain.game_screen and plain.game_screen.visible and plain.game_screen.modulate.a == 1.0)
	plain.game_screen._on_back_pressed()
	_check("and leaving it returns at once", not plain._board_flying and _flight(plain) == null
		and plain.current_screen == plain.main_menu and plain.main_menu.visible)
	plain.queue_free()
	await process_frame

	# A finished game has no card to return to: the menu slides in as usual
	_saved_game()
	var app := await _app_on_menu()
	app.main_menu.continue_pressed.emit()
	await create_timer(AppRoot.TRANSITION_TIME + 0.3).timeout
	SaveManager.clear_active_game()
	app.game_screen.game_state.is_completed = true
	app.game_screen._on_back_pressed()
	_check("With no game left to resume nothing flies", not app._board_flying and _flight(app) == null and app.current_screen == app.main_menu)
	_check("the menu comes in from the left", app.main_menu.offset_left < -AppRoot.TRANSITION_SLIDE * 0.5)
	await create_timer(AppRoot.TRANSITION_TIME + 0.3).timeout
	_check("and rests in its place", app.main_menu.offset_left == 0.0 and not app.game_screen.visible)
	app.queue_free()
	await process_frame
