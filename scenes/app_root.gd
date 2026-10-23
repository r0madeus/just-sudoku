class_name AppRoot
extends Control

const SoundManager = preload("res://scripts/services/sound_manager.gd")
const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const PuzzlePrefetcher = preload("res://scripts/services/puzzle_prefetcher.gd")

## Main Application Root Controller
## Coordinates top-level navigation, screen transitions, and launch flow (GDD §6)

## Everything but the menu is made when it is first needed, or a moment after the menu is on
## show (_start_warm_up). Loading the scripts was most of the start-up time, and the menu needs
## few of them. Nothing here may name these screens' classes, or they would load with this script.
const LAZY_NODES: Dictionary = {
	"game_screen": "res://scenes/gameplay/game_screen.gd",
	"new_game_dialog": "res://scenes/menus/new_game_dialog.gd",
	"settings_screen": "res://scenes/menus/settings_screen.gd",
	"load_game_screen": "res://scenes/menus/load_game_screen.gd",
	"daily_archive_screen": "res://scenes/menus/daily_archive_screen.gd",
	"history_screen": "res://scenes/menus/history_screen.gd",
	"statistics_screen": "res://scenes/menus/statistics_screen.gd",
	"techniques_screen": "res://scenes/menus/techniques_screen.gd",
	"import_puzzle_dialog": "res://scenes/menus/dialogs/import_puzzle_dialog.gd",
	"custom_theme_dialog": "res://scenes/menus/dialogs/custom_theme_dialog.gd",
}
const DIALOGS: Array[String] = ["new_game_dialog", "import_puzzle_dialog", "custom_theme_dialog"]
## Seconds after start-up before the rest are made, one every WARM_UP_STEP: after the menu's
## first frames, so its entrance does not stutter
const WARM_UP_DELAY: float = 0.6
const WARM_UP_STEP: float = 0.05

var main_menu: MainMenu
var game_screen: Control:
	get: return _node("game_screen")
var load_game_screen: Control:
	get: return _node("load_game_screen")
var history_screen: Control:
	get: return _node("history_screen")
var statistics_screen: Control:
	get: return _node("statistics_screen")
var techniques_screen: Control:
	get: return _node("techniques_screen")
var settings_screen: Control:
	get: return _node("settings_screen")
var daily_archive_screen: Control:
	get: return _node("daily_archive_screen")
var new_game_dialog: Control:
	get: return _node("new_game_dialog")
var import_puzzle_dialog: Control:
	get: return _node("import_puzzle_dialog")
var custom_theme_dialog: Control:
	get: return _node("custom_theme_dialog")
## The lazy screens and dialogs made so far, by name
var _made: Dictionary = {}

var root_bg: ColorRect
var current_screen: Control = null
var _transition_tween: Tween = null
var _previous_screen_before_settings: Control = null
## Seconds after coming back from the background to lay the screens out again
const RELAYOUT_DELAYS: Array[float] = [0.25, 1.0]

## Puzzle being made for an archive day, so a second tap does not start another
var _archive_request: int = 0

func _init() -> void:
	AppSettings.load_config()
	ThemeManager.load_settings()
	_instantiate_screens()

func _ready() -> void:
	ResponsiveManager.apply_device_scaling(get_window())
	ResponsiveManager.apply_device_orientation()
	ThemeManager.device_px_scale = ResponsiveManager.device_px_scale(get_window())
	get_window().size_changed.connect(_on_window_resized)
	set_anchors_preset(PRESET_FULL_RECT)
	theme = ThemeManager.build_godot_theme()
	if root_bg != null:
		root_bg.color = ThemeManager.get_color("bg")
	ThemeManager.add_listener(_on_theme_changed)
	FontManager.add_listener(_rebuild_theme)

	SoundManager.init_audio(self)

	_connect_signals()

	# Prepare puzzles in the background (no window, e.g. headless tests: nothing to wait for)
	if DisplayServer.get_name() != "headless":
		PuzzlePrefetcher.start()
	_start_warm_up()

	# GDD §6: Launch behavior (Auto-open last active game if enabled)
	if AppSettings.auto_open_last_game and SaveManager.has_active_game():
		var state := SaveManager.load_active_game()
		if state != null:
			_start_game_session(state)
			return

	_show_screen(main_menu)

# The managers keep listeners in static arrays, which outlive the scene and are only cleared
# after the script runtime is gone; a lambda still registered then crashes the exit
## Keeps edge anti-aliasing at one device pixel when a desktop window is resized
func _on_window_resized() -> void:
	ThemeManager.device_px_scale = ResponsiveManager.device_px_scale(get_window())

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)
	FontManager.remove_listener(_rebuild_theme)
	# Background generation (prefetch, New Game preview) must be finished before the engine exits
	PuzzlePrefetcher.stop()
	AsyncPuzzleGenerator.shutdown()
	SoundManager.shutdown()

func _on_theme_changed() -> void:
	_rebuild_theme()
	if root_bg != null:
		root_bg.color = ThemeManager.get_color("bg")

func _rebuild_theme() -> void:
	theme = ThemeManager.build_godot_theme()

func _notification(what: int) -> void:
	# Android back button (quit_on_go_back is off): modal -> screen -> menu -> quit
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_relayout_after_resume()

## Back from the background, the size and safe area Android reports can be wrong for a moment
## and are corrected without a resize: lay the screens out again now and once things settled
func _relayout_after_resume() -> void:
	if not is_inside_tree():
		return
	AppSettings.follow_system_changes()
	ResponsiveManager.relayout(get_window())
	for delay in RELAYOUT_DELAYS:
		get_tree().create_timer(delay).timeout.connect(func():
			if is_inside_tree():
				ResponsiveManager.relayout(get_window())
		)

## One step "back": closes the topmost modal, else leaves the current screen, else quits from the menu
func handle_back() -> void:
	var open_modals: Array = []
	for m in get_tree().get_nodes_in_group(AppModal.GROUP):
		if is_instance_valid(m) and m.visible:
			open_modals.append(m)
	if not open_modals.is_empty():
		var top = open_modals[open_modals.size() - 1]
		if top.dismissible_backdrop or top.cancel_on_back:
			top._on_canceled()
		return

	if _showing("game_screen"):
		game_screen._on_back_pressed()
	elif _showing("techniques_screen"):
		techniques_screen.handle_back()
	elif current_screen != null and current_screen != main_menu:
		current_screen.back_requested.emit()
	else:
		get_tree().quit()

func _showing(key: String) -> bool:
	return current_screen != null and current_screen == _made.get(key)

## A lazy screen or dialog, made now if it was not yet
func _node(key: String) -> Control:
	var node: Control = _made.get(key)
	if node != null:
		return node
	node = load(LAZY_NODES[key]).new()
	_made[key] = node
	if not DIALOGS.has(key):
		# Screens start hidden and _show_screen reveals one: a screen that believes it is on
		# show builds its lists (when the language is set during start-up, for one)
		node.visible = false
	add_child(node)
	_keep_dialogs_on_top()
	_connect_node(key, node)
	return node

func _keep_dialogs_on_top() -> void:
	for key in DIALOGS:
		if _made.has(key):
			move_child(_made[key], get_child_count() - 1)

## Makes the screens and dialogs not made yet, one at a time, so the first tap on one does not
## wait for it to load
func _start_warm_up() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(func():
		for key in LAZY_NODES:
			if not _made.has(key):
				_node(key)
				timer.start(WARM_UP_STEP)
				return
		timer.queue_free()
	)
	add_child(timer, false, INTERNAL_MODE_BACK)
	timer.start(WARM_UP_DELAY)

func _instantiate_screens() -> void:
	root_bg = ColorRect.new()
	root_bg.set_anchors_preset(PRESET_FULL_RECT)
	root_bg.mouse_filter = MOUSE_FILTER_IGNORE
	root_bg.color = ThemeManager.get_color("bg")
	add_child(root_bg)

	main_menu = MainMenu.new()
	main_menu.visible = false
	add_child(main_menu)

func _connect_signals() -> void:
	main_menu.continue_pressed.connect(_on_continue_pressed)
	main_menu.new_game_requested.connect(func(): new_game_dialog.open_dialog())
	main_menu.load_game_requested.connect(func(): load_game_screen.refresh_list(); _show_screen(load_game_screen))
	main_menu.daily_sudoku_requested.connect(_on_daily_sudoku_requested)
	main_menu.daily_archive_requested.connect(func():
		daily_archive_screen.show_current_month()
		_show_screen(daily_archive_screen)
	)
	# Build before showing: showing first would build it twice (on becoming visible, then here)
	main_menu.history_requested.connect(func(): history_screen.refresh_history(); _show_screen(history_screen))
	main_menu.statistics_requested.connect(func(): statistics_screen.refresh_stats(); _show_screen(statistics_screen))
	main_menu.techniques_requested.connect(func(): techniques_screen.show_list(); _show_screen(techniques_screen))
	main_menu.settings_requested.connect(func():
		_previous_screen_before_settings = main_menu
		_show_screen(settings_screen)
	)

## The signals of a lazy screen or dialog, connected when it is made
func _connect_node(key: String, node: Control) -> void:
	match key:
		"game_screen":
			node.back_to_menu_requested.connect(func(): main_menu.refresh_buttons(); _show_screen(main_menu))
			node.settings_requested.connect(func():
				_previous_screen_before_settings = game_screen
				_show_screen(settings_screen)
			)
		"new_game_dialog":
			node.start_game_requested.connect(_on_new_puzzle_generated)
			node.import_puzzle_requested.connect(func(): import_puzzle_dialog.open_dialog())
		"import_puzzle_dialog":
			node.puzzle_imported.connect(_on_puzzle_imported)
		"settings_screen":
			node.custom_theme_requested.connect(func(): custom_theme_dialog.open_dialog())
			node.data_restored.connect(_on_data_restored)
			node.back_requested.connect(func():
				if _previous_screen_before_settings != null:
					var prev: Control = _previous_screen_before_settings
					_previous_screen_before_settings = null
					_show_screen(prev)
				else:
					_show_screen(main_menu)
			)
		"load_game_screen":
			node.import_requested.connect(func(): import_puzzle_dialog.open_dialog())
			node.back_requested.connect(func(): main_menu.refresh_buttons(); _show_screen(main_menu))
			node.game_selected.connect(_on_load_game_slot_selected)
		"daily_archive_screen":
			node.back_requested.connect(func(): main_menu.refresh_buttons(); _show_screen(main_menu))
			node.day_requested.connect(_open_daily_date)
		"history_screen":
			node.back_requested.connect(func(): _show_screen(main_menu))
			node.replay_requested.connect(_on_history_replay_requested)
		"statistics_screen":
			node.back_requested.connect(func(): _show_screen(main_menu))
		"techniques_screen":
			node.back_requested.connect(func(): _show_screen(main_menu))
			node.practice_requested.connect(_on_new_puzzle_generated)

func _show_screen(target: Control) -> void:
	if target == null:
		return

	var screens: Array = [main_menu]
	for key in _made:
		if not DIALOGS.has(key):
			screens.append(_made[key])

	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null

	var prev: Control = current_screen
	current_screen = target

	if prev == target or prev == null:
		target.visible = true
		target.modulate.a = 1.0
		for s in screens:
			if s != target:
				s.visible = false
				s.modulate.a = 1.0
		return

	if AppSettings.animations_enabled and is_inside_tree():
		# Keep previous screen fully visible underneath while target fades in over 0.12s
		prev.visible = true
		target.visible = true
		target.modulate.a = 0.0

		# Ensure target renders above previous screen during transition
		move_child(target, get_child_count() - 1)

		_keep_dialogs_on_top()

		for s in screens:
			if s != target and s != prev:
				s.visible = false
				s.modulate.a = 1.0

		_transition_tween = create_tween()
		_transition_tween.tween_property(target, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_callback(func():
			if prev != null and prev != target:
				prev.visible = false
				prev.modulate.a = 1.0
			target.modulate.a = 1.0
		)
	else:
		target.visible = true
		target.modulate.a = 1.0
		for s in screens:
			if s != target:
				s.visible = false
				s.modulate.a = 1.0

## A backup replaced the saved data: the game left open behind Settings is not in it any more
## and must not save itself over it, so Back from Settings leads to the menu
func _on_data_restored() -> void:
	if not _made.has("game_screen"):
		main_menu.refresh_buttons()
		return
	game_screen.close_game()
	if _previous_screen_before_settings == game_screen:
		_previous_screen_before_settings = main_menu
	main_menu.refresh_buttons()

func _start_game_session(state: GameState) -> void:
	game_screen.setup_game(state)
	_show_screen(game_screen)

func _on_continue_pressed() -> void:
	var state := SaveManager.load_active_game()
	if state != null:
		_start_game_session(state)
	else:
		main_menu.refresh_buttons()

func _on_new_puzzle_generated(gen: SudokuGenerator.GeneratedPuzzle) -> void:
	var state := GameState.new()
	state.init_from_puzzle(gen)
	SaveManager.save_active_game(state)
	_start_game_session(state)

func _on_daily_sudoku_requested() -> void:
	var today_seed := DailyManager.get_today_seed()
	# 1. If today's daily puzzle exists (in-progress or completed), resume directly
	if DailyManager.has_today_game():
		var saved_daily := DailyManager.load_today_game()
		if saved_daily != null and saved_daily.seed_value == today_seed:
			# A finished Daily opens to show the result, but is not the game to resume
			if not saved_daily.is_completed:
				SaveManager.save_active_game(saved_daily)
			_start_game_session(saved_daily)
			return

	# 2. Check if active_game is already today's daily puzzle
	if SaveManager.has_active_game():
		var active := SaveManager.load_active_game()
		if active != null and active.seed_value == today_seed:
			DailyManager.save_today_game(active)
			_start_game_session(active)
			return

	# 3. Prepared in the background already? Start instantly
	var prepared := PuzzlePrefetcher.take_daily(today_seed)
	if prepared != null:
		var prepared_state := GameState.new()
		prepared_state.init_from_puzzle(prepared)
		DailyManager.save_today_game(prepared_state)
		SaveManager.save_active_game(prepared_state)
		_start_game_session(prepared_state)
		return

	# 4. Otherwise generate fresh puzzle for today
	main_menu.daily_btn.disabled = true
	main_menu.daily_btn.text = LocalizationManager.translate("DAILY_PREPARING")
	AsyncPuzzleGenerator.request_puzzle_async(
		today_seed,
		DifficultyAnalyzer.LEVEL_MEDIUM,
		func(gen: SudokuGenerator.GeneratedPuzzle):
			main_menu.refresh_buttons()
			if gen != null:
				var state := GameState.new()
				state.init_from_puzzle(gen)
				DailyManager.save_today_game(state)
				SaveManager.save_active_game(state)
				_start_game_session(state)
	)

## A day picked in the archive: its saved game if there is one, else its puzzle, fresh
func _open_daily_date(date_str: String) -> void:
	if date_str == DailyManager.get_today_date_string():
		_on_daily_sudoku_requested()
		return
	if not DailyManager.is_in_archive(date_str) or _archive_request != 0:
		return
	var seed_val := DailyManager.get_seed_for_date_string(date_str)
	var saved := DailyManager.load_daily_game(date_str)
	if saved != null and saved.seed_value == seed_val:
		if not saved.is_completed:
			SaveManager.save_active_game(saved)
		_start_game_session(saved)
		return
	if SaveManager.has_active_game():
		var active := SaveManager.load_active_game()
		if active != null and active.seed_value == seed_val:
			DailyManager.save_daily_game(active, date_str)
			_start_game_session(active)
			return
	_archive_request = AsyncPuzzleGenerator.request_puzzle_async(
		seed_val,
		DifficultyAnalyzer.LEVEL_MEDIUM,
		func(gen: SudokuGenerator.GeneratedPuzzle):
			_archive_request = 0
			if gen != null:
				var state := GameState.new()
				state.init_from_puzzle(gen)
				DailyManager.save_daily_game(state, date_str)
				SaveManager.save_active_game(state)
				_start_game_session(state)
	)

func _on_history_replay_requested(seed_val: int, diff: String) -> void:
	# The record keeps the puzzle itself: replay exactly that, even if this seed and level would
	# generate another one today (the generator or its puzzle bank may have changed since)
	var stored := _stored_puzzle(seed_val, diff)
	if not stored.is_empty():
		var gen := SudokuGenerator.from_grid(stored, seed_val)
		if gen != null:
			gen.difficulty = diff
			var replay_state := GameState.new()
			replay_state.init_from_puzzle(gen)
			replay_state.reset_for_replay()
			SaveManager.save_active_game(replay_state)
			_start_game_session(replay_state)
			return
	AsyncPuzzleGenerator.request_puzzle_async(
		seed_val,
		diff,
		func(gen: SudokuGenerator.GeneratedPuzzle):
			if gen != null:
				var state := GameState.new()
				state.init_from_puzzle(gen)
				state.reset_for_replay()
				SaveManager.save_active_game(state)
				_start_game_session(state)
	)

## The starting grid a history record kept for this seed and level ("" for older records)
func _stored_puzzle(seed_val: int, diff: String) -> String:
	for r in HistoryManager.load_all_records():
		if int(r.get("seed", 0)) == seed_val and String(r.get("difficulty", "")).to_lower() == diff.to_lower():
			var grid := String(r.get("puzzle", ""))
			if grid.length() == SudokuBoard.CELL_COUNT:
				return grid
	return ""

func _on_load_game_slot_selected(game_id: String) -> void:
	var state := SaveManager.load_game_slot(game_id)
	if state != null:
		SaveManager.save_active_game(state)
		_start_game_session(state)

func _on_puzzle_imported(state: GameState) -> void:
	if state != null:
		SaveManager.save_active_game(state)
		_start_game_session(state)

