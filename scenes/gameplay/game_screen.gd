class_name GameScreen
extends Control

const SoundManager = preload("res://scripts/services/sound_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SolutionDialog = preload("res://scenes/gameplay/dialogs/solution_dialog.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const GameActionDock = preload("res://scenes/ui/game_action_dock.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")

## Main Gameplay Screen
## Orchestrates SudokuGrid, SmartNumpad, Timer, Input, and Dialogs.

signal back_to_menu_requested()
signal settings_requested()

var game_state: GameState
var game_timer: GameTimer
## smart_candidates_enabled as last applied to the board, to react only when it changes
var _smart_candidates_applied: bool = false

# UI Elements
var bg: ColorRect
var margin_container: MarginContainer
var root_vbox: VBoxContainer
var header_bar: HBoxContainer
var back_btn: Button
var title_container: VBoxContainer
var info_label: Label
var timer_label: Label
var pause_btn: Button
var timer_capsule: PanelContainer

var grid_container: AspectRatioContainer
var sudoku_grid: SudokuGrid
var top_spacer: Control
var mid_spacer: Control
var numpad_spacer: Control
var bottom_spacer: Control

var check_btn: Button
var action_dock: GameActionDock
var action_container: PanelContainer
var action_bar: HBoxContainer
var undo_btn: Button
var redo_btn: Button
var erase_btn: Button
var notes_btn: Button
var hint_btn: Button

var numpad: SmartNumpad
var dock_center: CenterContainer

# Landscape (side-by-side) layout
var body_row: HBoxContainer
var side_panel: VBoxContainer
var _landscape: bool = false

# Overlays
var pause_overlay: Control
var pause_panel: PanelContainer
var pause_title: Label
var pause_info_label: Label
var resume_btn: Button
var share_puzzle_btn: Button
var export_save_btn: Button
var solution_btn: Button
var pause_settings_btn: Button
var pause_toast_label: Label
var pause_menu_btn: Button

# Hint Modal
var hint_dialog: AppModal

# Completion Modal
var complete_dialog: AppModal
var complete_summary: ResultSummary
var complete_replay_btn: Button
## Pending background request for "New <level> Puzzle", 0 when none
var _new_puzzle_req: int = 0

# Solution Modal
var solution_dialog: SolutionDialog

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	game_timer = GameTimer.new()
	game_timer.second_ticked.connect(_on_timer_ticked)
	add_child(game_timer)
	_build_ui()
	_update_locale_texts()
	SettingsScreen.add_listener(_on_settings_changed)
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	SettingsScreen.remove_listener(_on_settings_changed)
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		# Leaving the app pauses the clock and saves, as the OS may kill a backgrounded app
		if visible and game_state != null and not game_state.is_completed:
			if not game_state.is_paused:
				toggle_pause()
			_save_progress()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if visible and game_state != null and not game_state.is_completed:
			_save_progress()

func _ready() -> void:
	_apply_responsive_layout()
	var is_standalone := (get_tree() != null and (get_tree().current_scene == self or get_parent() == get_tree().root))
	if game_state == null and is_standalone:
		# If launched standalone, start a default medium game
		var default_puzzle := SudokuGenerator.generate(SudokuGenerator.generate_new_seed(), DifficultyAnalyzer.LEVEL_MEDIUM)
		var state := GameState.new()
		state.init_from_puzzle(default_puzzle)
		setup_game(state)

func _apply_responsive_layout() -> void:
	if margin_container == null:
		return
	_set_landscape(ResponsiveManager.is_game_landscape(ResponsiveManager.get_viewport_size(self)))
	ResponsiveManager.apply_game_layout(
		self,
		margin_container,
		grid_container,
		top_spacer,
		mid_spacer,
		numpad_spacer,
		bottom_spacer,
		numpad
	)
	_fit_dock()

## Gives the action dock the width left after the side margins (landscape: its side panel)
func _fit_dock() -> void:
	if action_dock == null:
		return
	var avail: float = ResponsiveManager.LANDSCAPE_SIDE_PANEL_W if _landscape else \
		ResponsiveManager.get_viewport_size(self).x - float(margin_container.get_theme_constant("margin_left") + margin_container.get_theme_constant("margin_right"))
	action_dock.fit_to_width(maxf(avail, 120.0))

## Moves the board and controls between the stacked (portrait) and side-by-side (landscape) trees
func _set_landscape(on: bool) -> void:
	if on == _landscape or root_vbox == null or grid_container == null:
		return
	_landscape = on

	if body_row == null:
		body_row = HBoxContainer.new()
		body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_row.alignment = BoxContainer.ALIGNMENT_CENTER
		body_row.add_theme_constant_override("separation", int(ResponsiveManager.LANDSCAPE_GAP))
		side_panel = VBoxContainer.new()
		side_panel.custom_minimum_size.x = ResponsiveManager.LANDSCAPE_SIDE_PANEL_W
		side_panel.alignment = BoxContainer.ALIGNMENT_CENTER
		side_panel.add_theme_constant_override("separation", 16)
		body_row.add_child(side_panel)
		root_vbox.add_child(body_row)

	var stacked: Array = [top_spacer, grid_container, mid_spacer, check_btn, dock_center, numpad_spacer, numpad, bottom_spacer]
	if on:
		for sp in [top_spacer, mid_spacer, numpad_spacer, bottom_spacer]:
			sp.visible = false
		grid_container.reparent(body_row, false)
		body_row.move_child(grid_container, 0)
		grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for n in [check_btn, dock_center, numpad]:
			n.reparent(side_panel, false)
		numpad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body_row.visible = true
		root_vbox.move_child(body_row, 1)
	else:
		body_row.visible = false
		var idx: int = 1
		for n in stacked:
			if n.get_parent() != root_vbox:
				n.reparent(root_vbox, false)
			root_vbox.move_child(n, idx)
			idx += 1
		grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		numpad.size_flags_vertical = Control.SIZE_FILL
		for sp in [top_spacer, mid_spacer, numpad_spacer, bottom_spacer]:
			sp.visible = true

func _build_ui() -> void:
	# Main background
	# Soft glows behind the controls; kept faint so the grid stays the visual centre
	var ambient_bg := AmbientBackdrop.new()
	ambient_bg.intensity = 0.55
	ambient_bg.color = ThemeManager.get_color("bg")
	bg = ambient_bg
	add_child(bg)

	margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	add_child(margin_container)

	root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 0)
	margin_container.add_child(root_vbox)

	# --- 1. Top Header (Editorial Headline + Technical Precision Timer) ---
	header_bar = HBoxContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 44)
	header_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	header_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header_bar)

	back_btn = Button.new()
	back_btn.text = ""
	back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.theme_type_variation = "IconButton"
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(_on_back_pressed)
	header_bar.add_child(back_btn)

	title_container = VBoxContainer.new()
	title_container.size_flags_horizontal = SIZE_EXPAND_FILL
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 0)
	header_bar.add_child(title_container)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.text = "Sudoku"
	info_label.theme_type_variation = "EditorialHeader"
	info_label.add_theme_font_size_override("font_size", 16)
	title_container.add_child(info_label)


	timer_capsule = PanelContainer.new()
	timer_capsule.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header_bar.add_child(timer_capsule)

	var timer_box := HBoxContainer.new()
	timer_box.add_theme_constant_override("separation", 6)
	timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_capsule.add_child(timer_box)

	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.theme_type_variation = "TechnicalLabel"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_box.add_child(timer_label)

	pause_btn = Button.new()
	pause_btn.text = ""
	pause_btn.tooltip_text = LocalizationManager.translate("PAUSE_TITLE")
	pause_btn.icon = ThemeManager.get_icon("pause")
	pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_btn.add_theme_constant_override("icon_max_width", 18)
	pause_btn.custom_minimum_size = Vector2(44, 44)
	pause_btn.theme_type_variation = "IconButton"
	pause_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_btn.pressed.connect(toggle_pause)
	timer_box.add_child(pause_btn)
	# The timer makes the right side wider than the back button; keep the level centred
	ResponsiveManager.balance_header(header_bar, title_container)

	# --- 2. Top Spacer (Airy breathing room between Header and Grid) ---
	top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 24)
	root_vbox.add_child(top_spacer)

	# --- 3. Sudoku Grid (1:1 Ratio, Visual Center of Puzzle Experience) ---
	grid_container = AspectRatioContainer.new()
	grid_container.size_flags_horizontal = SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = SIZE_SHRINK_CENTER
	grid_container.ratio = 1.0
	grid_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	root_vbox.add_child(grid_container)

	sudoku_grid = SudokuGrid.new()
	sudoku_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	sudoku_grid.size_flags_vertical = SIZE_EXPAND_FILL
	sudoku_grid.cell_selected.connect(_on_grid_cell_selected)
	grid_container.add_child(sudoku_grid)

	# --- 4. Mid Spacer (Intimate proximity between Grid and Toolbar) ---
	mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(0, 24)
	root_vbox.add_child(mid_spacer)

	# --- 5. Check Button (Calm, Centered Action - No Overbearing Blue Block) ---
	check_btn = Button.new()
	check_btn.text = LocalizationManager.translate("BTN_CHECK")
	check_btn.custom_minimum_size = Vector2(210, ResponsiveManager.TOUCH_TARGET_MIN)
	check_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	check_btn.visible = false
	check_btn.pressed.connect(_on_check_pressed)
	root_vbox.add_child(check_btn)

	# --- 6. Action Dock (Unified Floating Restrained Liquid Glass Component) ---
	dock_center = CenterContainer.new()
	dock_center.size_flags_horizontal = SIZE_EXPAND_FILL
	dock_center.mouse_filter = MOUSE_FILTER_PASS
	root_vbox.add_child(dock_center)

	action_dock = GameActionDock.new()
	action_dock.custom_minimum_size = Vector2(300, ResponsiveManager.HEIGHT_ACTION_DOCK)
	action_dock.undo_pressed.connect(_on_undo_pressed)
	action_dock.redo_pressed.connect(_on_redo_pressed)
	action_dock.notes_toggled.connect(_on_action_dock_notes_toggled)
	action_dock.hint_pressed.connect(_on_hint_pressed)
	action_dock.fill_notes_pressed.connect(_on_fill_notes_pressed)
	dock_center.add_child(action_dock)

	# Compatibility proxies & aliases
	action_container = action_dock
	action_bar = action_dock.action_bar
	undo_btn = action_dock.undo_btn
	redo_btn = action_dock.redo_btn
	notes_btn = action_dock.notes_btn
	hint_btn = action_dock.hint_btn

	# Keep erase_btn initialized for keyboard Backspace/Delete & logic compatibility
	erase_btn = Button.new()
	erase_btn.text = LocalizationManager.translate("BTN_ERASE")
	erase_btn.pressed.connect(_on_erase_pressed)

	# --- 7. Spacer between Action Dock & Numpad ---
	numpad_spacer = Control.new()
	numpad_spacer.custom_minimum_size = Vector2(0, 10)
	root_vbox.add_child(numpad_spacer)

	# --- 8. Smart Numpad (Harmoniously Proportioned Input Palette) ---
	numpad = SmartNumpad.new()
	numpad.custom_minimum_size = Vector2(0, 248)
	numpad.size_flags_horizontal = SIZE_EXPAND_FILL
	numpad.number_pressed.connect(_on_numpad_number_pressed)
	root_vbox.add_child(numpad)

	# --- 9. Bottom Safe Area Spacer ---
	bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 24)
	root_vbox.add_child(bottom_spacer)

	_apply_theme_polish()

	# --- 6. Pause Overlay (AppModal) ---
	var pause_modal := AppModal.new()
	pause_modal.title = LocalizationManager.translate("PAUSE_TITLE")
	pause_modal.primary_btn.visible = false
	pause_modal.cancel_btn.visible = false
	pause_modal.show_close_button = false
	pause_modal.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_modal.ambient_background = true
	pause_modal.canceled.connect(toggle_pause)
	add_child(pause_modal)

	pause_overlay = pause_modal
	pause_panel = pause_modal.modal_panel
	pause_title = pause_modal.title_label
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	pause_info_label = Label.new()
	pause_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_info_label.theme_type_variation = "Subtitle"
	pause_info_label.add_theme_font_size_override("font_size", 13)
	pause_info_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	pause_modal.body_vbox.add_child(pause_info_label)

	pause_toast_label = Label.new()
	pause_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_toast_label.theme_type_variation = "Caption"
	pause_toast_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	pause_toast_label.visible = false
	pause_modal.body_vbox.add_child(pause_toast_label)

	resume_btn = Button.new()
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	resume_btn.theme_type_variation = "PrimaryButton"
	resume_btn.icon = ThemeManager.get_icon("play")
	resume_btn.add_theme_constant_override("icon_max_width", 18)
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resume_btn.pressed.connect(toggle_pause)
	pause_modal.actions_vbox.add_child(resume_btn)

	share_puzzle_btn = Button.new()
	share_puzzle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_puzzle_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	share_puzzle_btn.theme_type_variation = "SecondaryButton"
	share_puzzle_btn.icon = ThemeManager.get_icon("upload")
	share_puzzle_btn.add_theme_constant_override("icon_max_width", 18)
	share_puzzle_btn.add_theme_font_size_override("font_size", 14)
	share_puzzle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	share_puzzle_btn.pressed.connect(_on_share_puzzle_pressed)
	pause_modal.actions_vbox.add_child(share_puzzle_btn)

	export_save_btn = Button.new()
	export_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_save_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	export_save_btn.theme_type_variation = "SecondaryButton"
	export_save_btn.icon = ThemeManager.get_icon("save")
	export_save_btn.add_theme_constant_override("icon_max_width", 18)
	export_save_btn.add_theme_font_size_override("font_size", 14)
	export_save_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	export_save_btn.pressed.connect(_on_export_save_pressed)
	pause_modal.actions_vbox.add_child(export_save_btn)

	solution_btn = Button.new()
	solution_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solution_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	solution_btn.theme_type_variation = "SecondaryButton"
	solution_btn.icon = ThemeManager.get_icon("lightbulb")
	solution_btn.add_theme_constant_override("icon_max_width", 18)
	solution_btn.add_theme_font_size_override("font_size", 14)
	solution_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	solution_btn.pressed.connect(_on_view_solution_pressed)
	pause_modal.actions_vbox.add_child(solution_btn)

	pause_settings_btn = Button.new()
	pause_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	pause_settings_btn.theme_type_variation = "SecondaryButton"
	pause_settings_btn.icon = ThemeManager.get_icon("settings")
	pause_settings_btn.add_theme_constant_override("icon_max_width", 18)
	pause_settings_btn.add_theme_font_size_override("font_size", 14)
	pause_settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_settings_btn.pressed.connect(_on_pause_settings_pressed)
	pause_modal.actions_vbox.add_child(pause_settings_btn)

	pause_menu_btn = Button.new()
	pause_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_menu_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	pause_menu_btn.theme_type_variation = "GhostButton"
	pause_menu_btn.icon = ThemeManager.get_icon("chevron-left")
	pause_menu_btn.add_theme_constant_override("icon_max_width", 18)
	pause_menu_btn.add_theme_font_size_override("font_size", 14)
	pause_menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_menu_btn.pressed.connect(func():
		if pause_overlay is AppModal:
			(pause_overlay as AppModal).close_modal()
		_on_back_pressed()
	)
	pause_modal.actions_vbox.add_child(pause_menu_btn)

	# --- 7. Hint Dialog (AppModal) ---
	hint_dialog = AppModal.new()
	hint_dialog.max_modal_width = 380.0
	add_child(hint_dialog)

	# --- 8. Completion Dialog (AppModal) ---
	# Three ways on: the next puzzle at the same level, this puzzle again, or the menu
	complete_dialog = AppModal.new()
	complete_dialog.max_modal_width = 380.0
	complete_dialog.show_close_button = false
	complete_dialog.dismissible_backdrop = false
	complete_dialog.cancel_on_back = true
	complete_summary = ResultSummary.new()
	complete_dialog.body_vbox.add_child(complete_summary)
	# The next puzzle may need a moment to generate; keep the result open until it is ready
	complete_dialog.primary_btn.pressed.disconnect(complete_dialog._on_confirmed)
	complete_dialog.primary_btn.pressed.connect(_on_complete_new_puzzle)
	complete_dialog.canceled.connect(_on_complete_menu)
	complete_replay_btn = complete_dialog.add_button(LocalizationManager.translate("BTN_MASTER_AGAIN"), true, "replay")
	complete_dialog.custom_action.connect(_on_complete_custom_action)
	add_child(complete_dialog)

	# --- 9. Solution Dialog (AppModal) ---
	solution_dialog = SolutionDialog.new()
	solution_dialog.solution_applied.connect(_on_solution_applied)
	add_child(solution_dialog)

	_update_locale_texts()

func setup_game(state: GameState) -> void:
	game_state = state
	sudoku_grid.bind_game_state(game_state)
	if not game_state.game_completed.is_connected(_on_game_completed):
		game_state.game_completed.connect(_on_game_completed)
	if not game_state.digit_completed.is_connected(_on_digit_completed):
		game_state.digit_completed.connect(_on_digit_completed)
	if not game_state.units_completed.is_connected(_on_units_completed):
		game_state.units_completed.connect(_on_units_completed)
	sudoku_grid.set_hint_focus(-1)
	_smart_candidates_applied = SettingsScreen.smart_candidates_enabled
	if SettingsScreen.show_wrong_immediately:
		game_state.check_board()

	var diff_text := LocalizationManager.get_difficulty_name(game_state.difficulty)
	if game_state.seed_value == DailyManager.get_today_seed():
		info_label.text = LocalizationManager.translate("BTN_DAILY_SUDOKU") + " • " + diff_text
	else:
		info_label.text = diff_text
	# A pause overlay left open by the previous game must not cover the new one
	if pause_overlay != null and pause_overlay.visible:
		_hide_pause_overlay()
	game_timer.start(game_state.elapsed_time)
	if game_state.is_completed:
		# A finished game (e.g. today's Daily reopened) shows its final time, without a clock
		game_timer.stop()
	if timer_label != null:
		timer_label.text = GameTimer.format_seconds(game_state.elapsed_time)

	sudoku_grid.refresh_all_cells()
	_update_action_buttons()
	sudoku_grid.select_cell(0)

func _on_settings_changed() -> void:
	if game_state != null and game_state.current_board != null:
		# Any setting saves and notifies; only a change of this one may rewrite the notes
		if SettingsScreen.smart_candidates_enabled != _smart_candidates_applied:
			_smart_candidates_applied = SettingsScreen.smart_candidates_enabled
			if SettingsScreen.smart_candidates_enabled:
				game_state.current_board.reset_candidates_from_grid()
			else:
				game_state.current_board.clear_all_candidates()
		# Turning on "show wrong digits" reveals (and counts) the ones already on the board
		if SettingsScreen.show_wrong_immediately and not game_state.is_completed:
			game_state.check_board()
		sudoku_grid.refresh_all_cells()
		numpad.update_smart_states(game_state.current_board, sudoku_grid.selected_idx)

func _on_timer_ticked(total_sec: int) -> void:
	if game_state != null and not game_state.is_paused and not game_state.is_completed:
		game_state.elapsed_time = game_timer.elapsed_time
		timer_label.text = GameTimer.format_seconds(game_state.elapsed_time)

func toggle_pause() -> void:
	if game_state == null or game_state.is_completed:
		return

	game_state.is_paused = not game_state.is_paused
	if game_state.is_paused:
		game_timer.pause()
		if pause_btn != null:
			pause_btn.icon = ThemeManager.get_icon("play")
		if pause_info_label != null:
			pause_info_label.text = "%s • %s" % [
				LocalizationManager.get_difficulty_name(game_state.difficulty),
				LocalizationManager.translate("PUZZLE_NUMBER") % game_state.seed_value
			]
		if pause_toast_label != null:
			pause_toast_label.visible = false
		if pause_overlay is AppModal:
			(pause_overlay as AppModal).open_modal()
		else:
			pause_overlay.visible = true
	else:
		game_timer.resume()
		_hide_pause_overlay()

func _hide_pause_overlay() -> void:
	if pause_btn != null:
		pause_btn.icon = ThemeManager.get_icon("pause")
	if pause_overlay is AppModal:
		(pause_overlay as AppModal).close_modal()
	else:
		pause_overlay.visible = false

func _show_pause_toast(msg: String) -> void:
	if pause_toast_label == null:
		return
	pause_toast_label.text = msg
	pause_toast_label.visible = true
	var t := create_tween()
	if t != null:
		t.tween_interval(1.8)
		t.tween_callback(func():
			if is_instance_valid(pause_toast_label):
				pause_toast_label.visible = false
		)

func _on_share_puzzle_pressed() -> void:
	if game_state != null and game_state.initial_puzzle != null:
		var text := PuzzleShareService.export_puzzle_share_text(
			game_state.seed_value,
			game_state.difficulty,
			game_state.initial_puzzle
		)
		PuzzleShareService.copy_to_clipboard(text)
		_show_pause_toast(LocalizationManager.translate("TOAST_PUZZLE_COPIED"))

func _on_export_save_pressed() -> void:
	if game_state != null:
		var text := SaveManager.export_game_to_string(game_state)
		PuzzleShareService.copy_to_clipboard(text)
		_show_pause_toast(LocalizationManager.translate("TOAST_SAVE_COPIED"))

func _on_pause_settings_pressed() -> void:
	if game_state != null and not game_state.is_completed:
		_save_progress()
	settings_requested.emit()

func _on_grid_cell_selected(idx: int, val: int) -> void:
	if game_state != null and not game_state.is_paused:
		numpad.set_selected_digit(val)
		numpad.update_smart_states(game_state.current_board, idx)
	_update_action_buttons()

func _on_numpad_number_pressed(num: int) -> void:
	if game_state == null or sudoku_grid.selected_idx == -1:
		return

	var idx: int = sudoku_grid.selected_idx
	if numpad.is_notes_mode:
		game_state.toggle_candidate(idx, num)
		SoundManager.play_number_placed()
		Haptics.tap()
	else:
		var ok := game_state.set_number(idx, num, true)
		if ok:
			var conflicts := SudokuValidator.get_conflicts(game_state.current_board)
			if conflicts.has(idx) or game_state.checked_wrong_indices.has(idx):
				SoundManager.play_conflict()
				Haptics.conflict()
			else:
				SoundManager.play_number_placed()
				Haptics.tap()

	_after_player_move()

func _on_erase_pressed() -> void:
	if game_state == null or sudoku_grid.selected_idx == -1:
		return
	game_state.clear_cell(sudoku_grid.selected_idx)
	SoundManager.play_erase()
	Haptics.tap()
	_after_player_move()

func _on_action_dock_notes_toggled(active: bool) -> void:
	numpad.set_notes_mode(active)
	if game_state != null:
		numpad.update_smart_states(game_state.current_board, sudoku_grid.selected_idx)

func _on_notes_toggle_pressed() -> void:
	if action_dock != null:
		action_dock.set_notes_active(not action_dock.is_notes_mode)
		_on_action_dock_notes_toggled(action_dock.is_notes_mode)
	else:
		numpad.toggle_notes_mode()
		notes_btn.text = LocalizationManager.translate("BTN_NOTES_ON") if numpad.is_notes_mode else LocalizationManager.translate("BTN_NOTES")
		numpad.update_smart_states(game_state.current_board, sudoku_grid.selected_idx)

func _on_fill_notes_pressed() -> void:
	if game_state != null and game_state.fill_notes():
		sudoku_grid.refresh_all_cells()
		SoundManager.play_number_placed()
		Haptics.tap()
		_after_player_move()

func _on_undo_pressed() -> void:
	if game_state != null and game_state.undo():
		_after_player_move()

func _on_redo_pressed() -> void:
	if game_state != null and game_state.redo():
		_after_player_move()

func _on_check_pressed() -> void:
	if game_state == null:
		return
	var wrong_cells := game_state.check_board()
	sudoku_grid.refresh_highlights()
	if wrong_cells.is_empty():
		info_label.text = LocalizationManager.translate("CHECK_ALL_CORRECT")
	else:
		info_label.text = LocalizationManager.plural("CHECK_MISTAKES_FOUND", wrong_cells.size())

func _on_digit_completed(digit: int) -> void:
	if sudoku_grid != null:
		sudoku_grid.play_digit_completed_pulse(digit)

func _on_units_completed(origin_idx: int, units: Array) -> void:
	if sudoku_grid != null:
		sudoku_grid.play_units_completed(origin_idx, units)
	SoundManager.play_unit_complete()
	Haptics.unit_completed()

## Hints reveal in steps, each one costing a little more score: first only the area to look
## at, then the technique and its explanation, and finally applying the move
func _on_hint_pressed() -> void:
	if game_state == null or game_state.is_completed or game_state.is_paused:
		return

	var step := SudokuSolver.find_best_hint(game_state.current_board, sudoku_grid.selected_idx, game_state.solution)
	if step == null:
		game_state.apply_hint()
		_after_player_move()
		return

	var level: int = mini(game_state.get_hint_level(step) + 1, GameState.HINT_LEVEL_TECHNIQUE)
	if level == GameState.HINT_LEVEL_FOCUS and SudokuSolver.get_focus_unit(step) < 0:
		level = GameState.HINT_LEVEL_TECHNIQUE
	_show_hint_level(step, level)

func _show_hint_level(step: SudokuSolver.SolveStep, level: int) -> void:
	game_state.reveal_hint(step, level)
	sudoku_grid.set_hint_focus(SudokuSolver.get_focus_unit(step))
	hint_dialog.title = LocalizationManager.translate("HINT_DIALOG_TITLE")
	hint_dialog.cancel_button_text = LocalizationManager.translate("BTN_CLOSE")

	for conn in hint_dialog.confirmed.get_connections():
		hint_dialog.confirmed.disconnect(conn.callable)

	var captured_step := step
	if level == GameState.HINT_LEVEL_FOCUS:
		var unit_name := SudokuSolver.get_unit_name(SudokuSolver.get_focus_unit(step))
		hint_dialog.dialog_text = LocalizationManager.translate("HINT_FOCUS_TEXT") % unit_name
		# Drop the selection so its row/column tint does not compete with the outlined area
		sudoku_grid.select_cell(-1)
		hint_dialog.ok_button_text = LocalizationManager.translate("HINT_SHOW_TECHNIQUE")
		hint_dialog.confirmed.connect(func():
			_show_hint_level(captured_step, GameState.HINT_LEVEL_TECHNIQUE)
		)
	else:
		if step.cells.size() > 0:
			sudoku_grid.select_cell(step.cells[0])
		var tech_tr := LocalizationManager.get_technique_title(step.technique)
		hint_dialog.dialog_text = "%s\n\n%s" % [tech_tr, step.explanation]
		hint_dialog.ok_button_text = LocalizationManager.translate("HINT_APPLY_MOVE")
		hint_dialog.confirmed.connect(func():
			game_state.apply_hint(captured_step)
			_after_player_move()
		)
	if is_inside_tree():
		hint_dialog.open_modal()

func _after_player_move() -> void:
	sudoku_grid.set_hint_focus(-1)
	_update_action_buttons()
	numpad.update_smart_states(game_state.current_board, sudoku_grid.selected_idx)
	# Auto-save immediately (GDD §30: crash recovery & persistence)
	_save_progress()

## Saves the game with the clock's exact time (the state only syncs once per second)
func _save_progress() -> void:
	if game_state == null:
		return
	if game_state.is_completed:
		# Finished: record it in its slot and the index, but never again as the game to resume
		SaveManager.save_game_slot(game_state)
	else:
		game_state.elapsed_time = game_timer.elapsed_time
		SaveManager.save_active_game(game_state)
	if game_state.seed_value == DailyManager.get_today_seed():
		DailyManager.save_today_game(game_state)

func _update_action_buttons() -> void:
	if game_state == null:
		return
	if action_dock != null:
		action_dock.set_can_undo(game_state.can_undo())
		action_dock.set_can_redo(game_state.can_redo())
	else:
		if undo_btn != null:
			undo_btn.disabled = not game_state.can_undo()
		if redo_btn != null:
			redo_btn.disabled = not game_state.can_redo()
	if check_btn != null and game_state.current_board != null:
		check_btn.visible = (game_state.current_board.get_empty_cell_count() == 0)

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if pause_btn != null:
		pause_btn.tooltip_text = LocalizationManager.translate("PAUSE_TITLE")
	if check_btn != null:
		check_btn.text = LocalizationManager.translate("BTN_CHECK")
		check_btn.icon = ThemeManager.get_icon("check")
		check_btn.add_theme_constant_override("icon_max_width", 16)
	if undo_btn != null:
		undo_btn.text = LocalizationManager.translate("BTN_UNDO")
	if redo_btn != null:
		redo_btn.text = LocalizationManager.translate("BTN_REDO")
	if erase_btn != null:
		erase_btn.text = LocalizationManager.translate("BTN_ERASE")
	if notes_btn != null:
		notes_btn.text = LocalizationManager.translate("BTN_NOTES_ON") if (numpad != null and numpad.is_notes_mode) else LocalizationManager.translate("BTN_NOTES")
	if hint_btn != null:
		hint_btn.text = LocalizationManager.translate("BTN_HINT")
	if pause_title != null:
		pause_title.text = LocalizationManager.translate("PAUSE_TITLE")
		pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if resume_btn != null:
		resume_btn.text = LocalizationManager.translate("BTN_RESUME")
	if share_puzzle_btn != null:
		share_puzzle_btn.text = LocalizationManager.translate("BTN_SHARE_PUZZLE")
	if export_save_btn != null:
		export_save_btn.text = LocalizationManager.translate("BTN_COPY_SAVE")
	if solution_btn != null:
		solution_btn.text = LocalizationManager.translate("BTN_SOLUTION")
	if pause_settings_btn != null:
		pause_settings_btn.text = LocalizationManager.translate("BTN_SETTINGS")
	if pause_menu_btn != null:
		pause_menu_btn.text = LocalizationManager.translate("BTN_MENU")
	if hint_dialog != null:
		hint_dialog.title = LocalizationManager.translate("HINT_DIALOG_TITLE")
		hint_dialog.ok_button_text = LocalizationManager.translate("HINT_APPLY_MOVE")
		hint_dialog.cancel_button_text = LocalizationManager.translate("BTN_CLOSE")
	if complete_dialog != null:
		complete_dialog.title = LocalizationManager.translate("WIN_DIALOG_TITLE")
		complete_dialog.cancel_button_text = LocalizationManager.translate("BTN_MENU")
		if game_state != null and _new_puzzle_req == 0:
			complete_dialog.ok_button_text = LocalizationManager.translate("BTN_NEW_SAME_LEVEL") % \
				LocalizationManager.get_difficulty_name(game_state.difficulty)
	if complete_replay_btn != null:
		complete_replay_btn.text = LocalizationManager.translate("BTN_MASTER_AGAIN")
	if game_state != null and info_label != null:
		var diff_text := LocalizationManager.get_difficulty_name(game_state.difficulty)
		if game_state.seed_value == DailyManager.get_today_seed():
			info_label.text = LocalizationManager.translate("BTN_DAILY_SUDOKU") + " • " + diff_text
		else:
			info_label.text = diff_text

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if sudoku_grid != null:
		sudoku_grid.refresh_all_cells()
	_apply_theme_polish()

func _apply_theme_polish() -> void:
	if action_dock != null:
		action_dock._apply_theme_style()

	if check_btn != null:
		var sb_check_n := ThemeManager.create_flat_stylebox(
			ThemeManager.get_color("surface_elevated"),
			ThemeManager.RADIUS_MD,
			ThemeManager.BORDER_THIN,
			ThemeManager.get_color("border_focus"),
			18, 8
		)
		var sb_check_h := ThemeManager.create_flat_stylebox(
			ThemeManager.get_color("button_hover"),
			ThemeManager.RADIUS_MD,
			ThemeManager.BORDER_THIN,
			ThemeManager.get_color("border_focus").lightened(0.15),
			18, 8
		)
		var sb_check_p := ThemeManager.create_flat_stylebox(
			ThemeManager.get_color("button_pressed"),
			ThemeManager.RADIUS_MD,
			ThemeManager.BORDER_THIN,
			ThemeManager.get_color("border_focus"),
			18, 8
		)
		check_btn.add_theme_stylebox_override("normal", sb_check_n)
		check_btn.add_theme_stylebox_override("hover", sb_check_h)
		check_btn.add_theme_stylebox_override("pressed", sb_check_p)
		check_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		check_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_user"))
		check_btn.add_theme_color_override("font_hover_color", ThemeManager.get_color("text_given"))
		check_btn.add_theme_font_size_override("font_size", 14)

	if back_btn != null:
		back_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if info_label != null:
		info_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if timer_label != null:
		timer_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if pause_btn != null:
		pause_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func _on_view_solution_pressed() -> void:
	if game_state != null and game_state.initial_puzzle != null:
		solution_dialog.open_solution(game_state.initial_puzzle, game_state.current_board)

func _on_solution_applied(solved: SudokuBoard) -> void:
	if game_state == null:
		return
	for i in range(SudokuBoard.CELL_COUNT):
		var v: int = solved.get_cell(i)
		game_state.current_board.set_cell(i, v, false)
	game_state.checked_wrong_indices.clear()
	# Leave the pause first: toggle_pause() ignores a finished game, which left the overlay
	# (where Show Solution lives) open over the result
	if game_state.is_paused:
		toggle_pause()
	game_state.is_completed = true
	sudoku_grid.refresh_all_cells()

	var summary := {
		"difficulty": game_state.difficulty,
		"seed": game_state.seed_value,
		"time": game_timer.elapsed_time,
		"mistakes": game_state.mistakes_count,
		"hints": game_state.hints_used,
		"score": 50,
		"date": Time.get_datetime_dict_from_system(),
		"assisted": true,
		"is_replay": game_state.is_replay,
		"game_id": game_state.game_id,
		"puzzle": game_state.initial_puzzle.to_string_flat()
	}
	_on_game_completed(summary)

func _on_game_completed(summary: Dictionary) -> void:
	game_timer.stop()
	SoundManager.play_complete()
	Haptics.game_completed()
	SaveManager.clear_active_game()
	if game_state != null and game_state.is_completed:
		# Marks it finished in the index, so it leaves the saved games list
		SaveManager.save_game_slot(game_state)

	var seed_val: int = int(summary.get("seed", 0))
	var is_daily: bool = seed_val == DailyManager.get_today_seed()
	summary["is_daily"] = is_daily
	if is_daily:
		DailyManager.mark_today_completed()
		if game_state != null:
			DailyManager.save_today_game(game_state)

	# References as they were before this game, then record it (GDD §25, §26)
	var difficulty: String = summary.get("difficulty", DifficultyAnalyzer.LEVEL_MEDIUM)
	var prev_best := HistoryManager.get_best_record_for_seed(seed_val)
	var bench := HistoryManager.get_level_benchmarks(difficulty)
	HistoryManager.add_record(summary)

	var streak: int = DailyManager.get_current_streak() if is_daily else 0
	complete_summary.show_result(summary, ResultSummary.build_highlights(summary, bench, prev_best, streak))
	complete_dialog.dialog_text = ""
	_new_puzzle_req = 0
	complete_dialog.primary_btn.disabled = false
	complete_dialog.ok_button_text = LocalizationManager.translate("BTN_NEW_SAME_LEVEL") % \
		LocalizationManager.get_difficulty_name(difficulty)
	if SettingsScreen.animations_enabled and is_inside_tree() and sudoku_grid != null:
		sudoku_grid.play_victory_wave(func():
			if is_inside_tree():
				complete_dialog.popup_centered()
		)
	else:
		if is_inside_tree():
			complete_dialog.popup_centered()

func _on_complete_new_puzzle() -> void:
	if game_state == null or _new_puzzle_req != 0:
		return
	var difficulty: String = game_state.difficulty
	# Usually prepared in the background already (GDD §2.3), so it opens at once
	var ready := PuzzlePrefetcher.take(difficulty)
	if ready != null:
		_start_new_puzzle(ready)
		return
	complete_dialog.primary_btn.disabled = true
	complete_dialog.ok_button_text = LocalizationManager.translate("LOADING_PUZZLE") % \
		LocalizationManager.get_difficulty_name(difficulty)
	_new_puzzle_req = AsyncPuzzleGenerator.request_puzzle_async(
		SudokuGenerator.generate_new_seed(),
		difficulty,
		func(gen: SudokuGenerator.GeneratedPuzzle) -> void:
			_new_puzzle_req = 0
			if gen != null:
				_start_new_puzzle(gen)
	)

func _start_new_puzzle(gen: SudokuGenerator.GeneratedPuzzle) -> void:
	complete_dialog.close_modal()
	var state := GameState.new()
	state.init_from_puzzle(gen)
	SaveManager.save_active_game(state)
	setup_game(state)

func _on_complete_menu() -> void:
	if _new_puzzle_req != 0:
		AsyncPuzzleGenerator.cancel_request(_new_puzzle_req)
		_new_puzzle_req = 0
	_on_back_pressed()

func _on_complete_custom_action(action: String) -> void:
	if action == "replay":
		complete_dialog.close_modal()
		if game_state != null:
			game_state.reset_for_replay()
			SaveManager.save_active_game(game_state)
			if game_state.seed_value == DailyManager.get_today_seed():
				DailyManager.save_today_game(game_state)
			setup_game(game_state)

func _on_back_pressed() -> void:
	if game_state != null and not game_state.is_completed:
		_save_progress()
	# The screen stays in the tree behind the menu; its clock must not keep running there
	game_timer.stop()
	back_to_menu_requested.emit()

# Desktop Keyboard Support (GDD §42)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode = event.keycode

		# Numbers 1..9
		if keycode >= KEY_1 and keycode <= KEY_9:
			var digit: int = keycode - KEY_0
			_on_numpad_number_pressed(digit)
			get_viewport().set_input_as_handled()
		# Numpad 1..9
		elif keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
			var digit: int = keycode - KEY_KP_0
			_on_numpad_number_pressed(digit)
			get_viewport().set_input_as_handled()
		# Delete / Backspace
		elif keycode == KEY_BACKSPACE or keycode == KEY_DELETE:
			_on_erase_pressed()
			get_viewport().set_input_as_handled()
		# Arrow keys
		elif keycode == KEY_UP:
			sudoku_grid.move_selection(-1, 0)
			get_viewport().set_input_as_handled()
		elif keycode == KEY_DOWN:
			sudoku_grid.move_selection(1, 0)
			get_viewport().set_input_as_handled()
		elif keycode == KEY_LEFT:
			sudoku_grid.move_selection(0, -1)
			get_viewport().set_input_as_handled()
		elif keycode == KEY_RIGHT:
			sudoku_grid.move_selection(0, 1)
			get_viewport().set_input_as_handled()
		# Notes toggle
		elif keycode == KEY_N:
			_on_notes_toggle_pressed()
			get_viewport().set_input_as_handled()
		elif keycode == KEY_F:
			_on_fill_notes_pressed()
			get_viewport().set_input_as_handled()
		# Undo / Redo
		elif keycode == KEY_Z and event.ctrl_pressed:
			if event.shift_pressed:
				_on_redo_pressed()
			else:
				_on_undo_pressed()
			get_viewport().set_input_as_handled()
		elif keycode == KEY_Y and event.ctrl_pressed:
			_on_redo_pressed()
			get_viewport().set_input_as_handled()
		# Hint
		elif keycode == KEY_H:
			_on_hint_pressed()
			get_viewport().set_input_as_handled()
		# Pause
		elif keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()
