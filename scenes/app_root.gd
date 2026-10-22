class_name AppRoot
extends Control

const SoundManager = preload("res://scripts/services/sound_manager.gd")
const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const PuzzlePrefetcher = preload("res://scripts/services/puzzle_prefetcher.gd")
const CustomThemeDialog = preload("res://scenes/menus/dialogs/custom_theme_dialog.gd")

## Main Application Root Controller
## Coordinates top-level navigation, screen transitions, and launch flow (GDD §6)

var main_menu: MainMenu
var game_screen: GameScreen
var load_game_screen: LoadGameScreen
var history_screen: HistoryScreen
var statistics_screen: StatisticsScreen
var settings_screen: SettingsScreen
var new_game_dialog: NewGameDialog
var import_puzzle_dialog: ImportPuzzleDialog
var custom_theme_dialog: CustomThemeDialog

var root_bg: ColorRect
var current_screen: Control = null
var _transition_tween: Tween = null
var _previous_screen_before_settings: Control = null

func _init() -> void:
	SettingsScreen.load_config()
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

	# GDD §6: Launch behavior (Auto-open last active game if enabled)
	if SettingsScreen.auto_open_last_game and SaveManager.has_active_game():
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

	if current_screen == game_screen:
		game_screen._on_back_pressed()
	elif current_screen == settings_screen:
		settings_screen.back_requested.emit()
	elif current_screen == history_screen:
		history_screen.back_requested.emit()
	elif current_screen == statistics_screen:
		statistics_screen.back_requested.emit()
	elif current_screen == load_game_screen:
		load_game_screen.back_requested.emit()
	else:
		get_tree().quit()

func _instantiate_screens() -> void:
	root_bg = ColorRect.new()
	root_bg.set_anchors_preset(PRESET_FULL_RECT)
	root_bg.mouse_filter = MOUSE_FILTER_IGNORE
	root_bg.color = ThemeManager.get_color("bg")
	add_child(root_bg)

	# Screens start hidden and _show_screen reveals one: a screen that believes it is on show
	# builds its lists (when the language is set during start-up, for one)
	main_menu = MainMenu.new()
	main_menu.visible = false
	add_child(main_menu)

	game_screen = GameScreen.new()
	game_screen.visible = false
	add_child(game_screen)

	load_game_screen = LoadGameScreen.new()
	load_game_screen.visible = false
	add_child(load_game_screen)

	history_screen = HistoryScreen.new()
	history_screen.visible = false
	add_child(history_screen)

	statistics_screen = StatisticsScreen.new()
	statistics_screen.visible = false
	add_child(statistics_screen)

	settings_screen = SettingsScreen.new()
	settings_screen.visible = false
	add_child(settings_screen)

	new_game_dialog = NewGameDialog.new()
	add_child(new_game_dialog)

	import_puzzle_dialog = ImportPuzzleDialog.new()
	add_child(import_puzzle_dialog)

	custom_theme_dialog = CustomThemeDialog.new()
	add_child(custom_theme_dialog)

func _connect_signals() -> void:
	# Main Menu
	main_menu.continue_pressed.connect(_on_continue_pressed)
	main_menu.new_game_requested.connect(func(): new_game_dialog.open_dialog())
	main_menu.load_game_requested.connect(func(): load_game_screen.refresh_list(); _show_screen(load_game_screen))
	main_menu.daily_sudoku_requested.connect(_on_daily_sudoku_requested)
	# Build before showing: showing first would build it twice (on becoming visible, then here)
	main_menu.history_requested.connect(func(): history_screen.refresh_history(); _show_screen(history_screen))
	main_menu.statistics_requested.connect(func(): statistics_screen.refresh_stats(); _show_screen(statistics_screen))
	main_menu.settings_requested.connect(func():
		_previous_screen_before_settings = main_menu
		_show_screen(settings_screen)
	)

	# New Game Dialog & Import
	new_game_dialog.start_game_requested.connect(_on_new_puzzle_generated)
	new_game_dialog.import_puzzle_requested.connect(func(): import_puzzle_dialog.open_dialog())
	load_game_screen.import_requested.connect(func(): import_puzzle_dialog.open_dialog())
	import_puzzle_dialog.puzzle_imported.connect(_on_puzzle_imported)

	# Settings Screen Dialogs
	settings_screen.custom_theme_requested.connect(func(): custom_theme_dialog.open_dialog())

	# Screens back buttons & navigation
	game_screen.back_to_menu_requested.connect(func(): main_menu.refresh_buttons(); _show_screen(main_menu))
	game_screen.settings_requested.connect(func():
		_previous_screen_before_settings = game_screen
		_show_screen(settings_screen)
	)
	load_game_screen.back_requested.connect(func(): main_menu.refresh_buttons(); _show_screen(main_menu))
	load_game_screen.game_selected.connect(_on_load_game_slot_selected)
	history_screen.back_requested.connect(func(): _show_screen(main_menu))
	history_screen.replay_requested.connect(_on_history_replay_requested)
	statistics_screen.back_requested.connect(func(): _show_screen(main_menu))
	settings_screen.back_requested.connect(func():
		if _previous_screen_before_settings != null:
			var prev: Control = _previous_screen_before_settings
			_previous_screen_before_settings = null
			_show_screen(prev)
		else:
			_show_screen(main_menu)
	)

func _show_screen(target: Control) -> void:
	if target == null:
		return

	var screens := [main_menu, game_screen, load_game_screen, history_screen, statistics_screen, settings_screen]

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

	if SettingsScreen.animations_enabled and is_inside_tree():
		# Keep previous screen fully visible underneath while target fades in over 0.12s
		prev.visible = true
		target.visible = true
		target.modulate.a = 0.0

		# Ensure target renders above previous screen during transition
		move_child(target, get_child_count() - 1)

		# Keep floating dialogs above screens
		if new_game_dialog != null:
			move_child(new_game_dialog, get_child_count() - 1)
		if import_puzzle_dialog != null:
			move_child(import_puzzle_dialog, get_child_count() - 1)
		if custom_theme_dialog != null:
			move_child(custom_theme_dialog, get_child_count() - 1)

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

func _on_history_replay_requested(seed_val: int, diff: String) -> void:
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

func _on_load_game_slot_selected(game_id: String) -> void:
	var state := SaveManager.load_game_slot(game_id)
	if state != null:
		SaveManager.save_active_game(state)
		_start_game_session(state)

func _on_puzzle_imported(state: GameState) -> void:
	if state != null:
		SaveManager.save_active_game(state)
		_start_game_session(state)

