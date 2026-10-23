class_name SolutionDialog
extends "res://scenes/ui/app_modal.gd"

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")

## Solution Viewer Dialog (GDD §22, §49)
## Displays Full Solution and Step-by-Step interactive logical walkthrough.
## Powered by unified AppModal architecture.

signal solution_applied(solved_board: SudokuBoard)

enum Mode {
	STEP_BY_STEP,
	FULL_SOLUTION
}

var current_mode: int = Mode.STEP_BY_STEP

# Solution Data
var initial_puzzle: SudokuBoard
var current_board: SudokuBoard
var steps: Array[SudokuSolver.SolveStep] = []
var snapshots: Array[SudokuBoard] = []
var solved_board: SudokuBoard = null
var current_step_idx: int = 0

# UI Controls
var mode_tabs: HBoxContainer
var btn_step_mode: Button
var btn_full_mode: Button

var grid_aspect: AspectRatioContainer
var grid_frame: Panel
var grid_lines: Control
var cells: Array[Dictionary] = []

# Step-by-Step UI
var step_nav_bar: HBoxContainer
var btn_first: Button
var btn_prev: Button
var step_counter_label: Label
var btn_next: Button
var btn_last: Button

## Holds the step view and the full-solution view, at one height
var detail_box: VBoxContainer
## The explanation, scrolled when it is longer than DESC_LINES
var desc_scroll: ScrollContainer
var step_info_panel: PanelContainer
var step_coord_badge: Label
var step_tech_badge: Label
var step_desc_label: Label

# Full Solution UI
var full_info_panel: PanelContainer
var full_givens_label: Label
var full_solved_label: Label
var full_unique_label: Label
var apply_btn: Button

func _init() -> void:
	super()
	max_modal_width = 440.0
	_build_ui()
	_update_locale_texts()
	_apply_theme_styles()

	confirmed.connect(_on_close_pressed)
	canceled.connect(_on_close_pressed)
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_apply_theme_styles)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_apply_theme_styles)

func _build_ui() -> void:
	cancel_btn.visible = false
	primary_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)

	# 1. Mode Selector Tabs
	mode_tabs = HBoxContainer.new()
	mode_tabs.add_theme_constant_override("separation", 6)
	mode_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body_vbox.add_child(mode_tabs)

	btn_step_mode = Button.new()
	btn_step_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_step_mode.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_SEGMENT)
	btn_step_mode.theme_type_variation = "PrimaryButton"
	ThemeManager.set_font_size(btn_step_mode, 13)
	btn_step_mode.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_step_mode.pressed.connect(func(): switch_view_mode(Mode.STEP_BY_STEP))
	mode_tabs.add_child(btn_step_mode)

	btn_full_mode = Button.new()
	btn_full_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_full_mode.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_SEGMENT)
	btn_full_mode.theme_type_variation = "SecondaryButton"
	ThemeManager.set_font_size(btn_full_mode, 13)
	btn_full_mode.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_full_mode.pressed.connect(func(): switch_view_mode(Mode.FULL_SOLUTION))
	mode_tabs.add_child(btn_full_mode)

	# 2. 9x9 Responsive Solution Grid
	grid_aspect = AspectRatioContainer.new()
	grid_aspect.custom_minimum_size = Vector2(GRID_MIN_SIDE, GRID_MIN_SIDE)
	grid_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_aspect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_aspect.ratio = 1.0
	body_vbox.add_child(grid_aspect)

	# Drawn like the game board: cells placed on exact ninths, lines on a layer above aligned to
	# device pixels, and the rounded frame clipping the cell colours at the corners
	grid_frame = Panel.new()
	grid_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	grid_frame.resized.connect(_layout_grid_cells)
	grid_aspect.add_child(grid_frame)

	cells.clear()
	var cell_sb := ThemeManager.create_flat_stylebox(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0)
	for i in range(SudokuBoard.CELL_COUNT):
		var cell_panel := PanelContainer.new()
		cell_panel.add_theme_stylebox_override("panel", cell_sb)
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_frame.add_child(cell_panel)

		var bg_rect := ColorRect.new()
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell_panel.add_child(bg_rect)

		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ThemeManager.set_font_size(lbl, 14)
		cell_panel.add_child(lbl)

		cells.append({
			"panel": cell_panel,
			"bg": bg_rect,
			"label": lbl
		})

	grid_lines = Control.new()
	grid_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_lines.draw.connect(func():
		GridLines.draw_board(grid_lines, Rect2(Vector2.ZERO, grid_lines.size),
			ThemeManager.get_color("grid_minor"), ThemeManager.get_color("grid_major"))
	)
	grid_frame.add_child(grid_lines)

	# Both views below the board share one area of fixed height, so switching between them, or
	# between steps with longer and shorter explanations, never resizes the dialog
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	body_vbox.add_child(detail_box)

	# 3. Step Navigation Bar
	step_nav_bar = HBoxContainer.new()
	step_nav_bar.add_theme_constant_override("separation", 6)
	step_nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_box.add_child(step_nav_bar)

	btn_first = Button.new()
	btn_first.custom_minimum_size = Vector2(44, 44)
	btn_first.text = ""
	btn_first.icon = ThemeManager.get_icon("rotate-ccw")
	btn_first.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_first.add_theme_constant_override("icon_max_width", 16)
	btn_first.theme_type_variation = "IconButton"
	btn_first.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_first.pressed.connect(func(): set_step(0))
	step_nav_bar.add_child(btn_first)

	btn_prev = Button.new()
	btn_prev.custom_minimum_size = Vector2(76, 44)
	btn_prev.theme_type_variation = "SecondaryButton"
	btn_prev.icon = ThemeManager.get_icon("chevron-left")
	btn_prev.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(btn_prev, 12)
	btn_prev.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_prev.pressed.connect(func(): set_step(current_step_idx - 1))
	step_nav_bar.add_child(btn_prev)

	step_counter_label = Label.new()
	step_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_counter_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(step_counter_label, 12)
	step_nav_bar.add_child(step_counter_label)

	btn_next = Button.new()
	btn_next.custom_minimum_size = Vector2(76, 44)
	btn_next.theme_type_variation = "SecondaryButton"
	btn_next.icon = ThemeManager.get_icon("chevron-right")
	btn_next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn_next.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(btn_next, 12)
	btn_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_next.pressed.connect(func(): set_step(current_step_idx + 1))
	step_nav_bar.add_child(btn_next)

	btn_last = Button.new()
	btn_last.custom_minimum_size = Vector2(44, 44)
	btn_last.text = ""
	btn_last.icon = ThemeManager.get_icon("check")
	btn_last.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_last.add_theme_constant_override("icon_max_width", 16)
	btn_last.theme_type_variation = "IconButton"
	btn_last.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_last.pressed.connect(func(): set_step(steps.size()))
	step_nav_bar.add_child(btn_last)

	# 4. Step Info Card
	step_info_panel = PanelContainer.new()
	step_info_panel.custom_minimum_size = Vector2(0, 76)
	step_info_panel.theme_type_variation = "SurfacePanel"
	step_info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(step_info_panel)

	var s_vbox := VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 2)
	step_info_panel.add_child(s_vbox)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	s_vbox.add_child(badge_row)

	step_coord_badge = Label.new()
	step_coord_badge.theme_type_variation = "StatValue"
	ThemeManager.set_font_size(step_coord_badge, 13)
	badge_row.add_child(step_coord_badge)

	step_tech_badge = Label.new()
	step_tech_badge.theme_type_variation = "Subtitle"
	ThemeManager.set_font_size(step_tech_badge, 12)
	badge_row.add_child(step_tech_badge)

	# A fixed number of lines; a longer explanation scrolls inside them
	desc_scroll = ScrollContainer.new()
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s_vbox.add_child(desc_scroll)

	step_desc_label = Label.new()
	step_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_desc_label.theme_type_variation = "Body"
	step_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.set_font_size(step_desc_label, 12)
	desc_scroll.add_child(step_desc_label)

	# 5. Full Solution Card
	full_info_panel = PanelContainer.new()
	full_info_panel.custom_minimum_size = Vector2(0, 76)
	full_info_panel.visible = false
	full_info_panel.theme_type_variation = "SurfacePanel"
	full_info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(full_info_panel)

	var f_vbox := VBoxContainer.new()
	f_vbox.add_theme_constant_override("separation", 4)
	full_info_panel.add_child(f_vbox)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 16)
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	f_vbox.add_child(stat_row)

	full_givens_label = Label.new()
	full_givens_label.theme_type_variation = "Body"
	ThemeManager.set_font_size(full_givens_label, 12)
	stat_row.add_child(full_givens_label)

	full_solved_label = Label.new()
	full_solved_label.theme_type_variation = "Body"
	ThemeManager.set_font_size(full_solved_label, 12)
	stat_row.add_child(full_solved_label)

	full_unique_label = Label.new()
	full_unique_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_unique_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(full_unique_label, 11)
	f_vbox.add_child(full_unique_label)

	apply_btn = Button.new()
	apply_btn.custom_minimum_size = Vector2(0, ResponsiveManager.TOUCH_TARGET_MIN)
	apply_btn.theme_type_variation = "PrimaryButton"
	ThemeManager.set_font_size(apply_btn, 13)
	apply_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_btn.pressed.connect(_on_apply_solution_pressed)
	f_vbox.add_child(apply_btn)

func open_solution(initial: SudokuBoard, current: SudokuBoard = null) -> void:
	initial_puzzle = initial.clone()
	current_board = current.clone() if current != null else initial.clone()

	# Compute step-by-step and full solution
	var sol_data := SudokuSolver.get_full_step_by_step_solution(initial_puzzle)
	steps = sol_data["steps"]
	snapshots = sol_data["snapshots"]
	solved_board = sol_data["solved_board"]

	switch_view_mode(Mode.STEP_BY_STEP)
	set_step(0)
	open_modal()

func switch_view_mode(mode: int) -> void:
	current_mode = mode
	var is_step := (mode == Mode.STEP_BY_STEP)

	step_nav_bar.visible = is_step
	step_info_panel.visible = is_step
	full_info_panel.visible = not is_step

	btn_step_mode.theme_type_variation = "PrimaryButton" if is_step else "SecondaryButton"
	btn_full_mode.theme_type_variation = "SecondaryButton" if is_step else "PrimaryButton"

	if is_step:
		set_step(current_step_idx)
	else:
		_render_full_solution()

func set_step(idx: int) -> void:
	current_step_idx = clampi(idx, 0, steps.size())

	btn_first.disabled = (current_step_idx == 0)
	btn_prev.disabled = (current_step_idx == 0)
	btn_next.disabled = (current_step_idx >= steps.size())
	btn_last.disabled = (current_step_idx >= steps.size())

	step_counter_label.text = LocalizationManager.translate("STEP_COUNTER") % [current_step_idx, steps.size()]

	# Board at step `current_step_idx`
	var active_board: SudokuBoard = snapshots[current_step_idx] if current_step_idx < snapshots.size() else solved_board

	var target_cell: int = -1
	var peer_cells: Array[int] = []

	if current_step_idx > 0 and current_step_idx - 1 < steps.size():
		var s: SudokuSolver.SolveStep = steps[current_step_idx - 1]
		if not s.cells.is_empty():
			target_cell = s.cells[0]
			for c_idx in s.cells.slice(1):
				peer_cells.append(c_idx)
		for sec_idx in s.secondary_cells:
			peer_cells.append(sec_idx)

		# "=": every bundled font has it (Nunito, the rounded one, has no arrow)
		step_coord_badge.text = (s.get_target_coord() + " = " + str(s.digit)) if s.digit != 0 else s.get_formatted_coords()
		step_tech_badge.text = "[" + LocalizationManager.get_technique_name(s.technique) + "]"
		step_desc_label.text = s.explanation
	else:
		step_coord_badge.text = LocalizationManager.translate("STEP_INITIAL_BOARD")
		step_tech_badge.text = ""
		step_desc_label.text = LocalizationManager.translate("STEP_INITIAL_DESC")
	desc_scroll.scroll_vertical = 0

	_render_grid(active_board, target_cell, peer_cells)

func _layout_grid_cells() -> void:
	var side: float = minf(grid_frame.size.x, grid_frame.size.y)
	var cell: float = side / 9.0
	for i in range(cells.size()):
		var panel: Control = cells[i]["panel"]
		panel.position = Vector2((i % 9) * cell, (i / 9) * cell)
		panel.size = Vector2(cell, cell)
	if grid_lines != null:
		grid_lines.queue_redraw()

func _render_grid(board: SudokuBoard, target_idx: int = -1, peer_indices: Array[int] = []) -> void:
	if board == null:
		return

	var cell_bg_col: Color = ThemeManager.get_color("cell_bg")
	var text_given_col: Color = ThemeManager.get_color("text_given")
	var text_user_col: Color = ThemeManager.get_color("text_user")
	var sel_col: Color = ThemeManager.get_color("cell_selected")
	var peer_col: Color = ThemeManager.get_color("cell_peer")

	for i in range(SudokuBoard.CELL_COUNT):
		var val: int = board.get_cell(i)
		var is_initial := (initial_puzzle != null and initial_puzzle.get_cell(i) != 0)
		var c_data: Dictionary = cells[i]
		var bg: ColorRect = c_data["bg"]
		var lbl: Label = c_data["label"]

		if val != 0:
			lbl.text = str(val)
			lbl.add_theme_color_override("font_color", text_given_col if is_initial else text_user_col)
		else:
			lbl.text = ""

		if i == target_idx:
			bg.color = sel_col
		elif peer_indices.has(i):
			bg.color = peer_col
		else:
			bg.color = cell_bg_col

func _render_full_solution() -> void:
	if solved_board == null:
		return

	_render_grid(solved_board)

	var givens_cnt := 0
	if initial_puzzle != null:
		givens_cnt = SudokuBoard.CELL_COUNT - initial_puzzle.get_empty_cell_count()

	full_givens_label.text = LocalizationManager.translate("SOLUTION_SUMMARY_GIVENS") % givens_cnt
	full_solved_label.text = LocalizationManager.translate("SOLUTION_SUMMARY_SOLVED") % (SudokuBoard.CELL_COUNT - givens_cnt)
	full_unique_label.text = LocalizationManager.translate("SOLUTION_UNIQUE_VERIFIED")

func _on_apply_solution_pressed() -> void:
	if solved_board == null:
		return
	# It ends the game, so it asks first
	var board := solved_board
	AppModal.ask(get_parent(), LocalizationManager.translate("BTN_APPLY_SOLUTION"),
		LocalizationManager.translate("SOLUTION_APPLY_CONFIRM"), LocalizationManager.translate("BTN_APPLY"),
		func():
			close_modal()
			solution_applied.emit(board),
		true)

## Narrower than this, Previous / Next show only their arrows so the step row fits a 360 dp phone
const NAV_LABELS_MIN_WIDTH: float = 360.0
var _nav_compact: bool = false

## Board side on a phone; a tablet's wider dialog shows it larger
const GRID_MIN_SIDE: float = 230.0

func _apply_responsive_layout() -> void:
	super()
	if modal_panel == null or btn_prev == null:
		return
	var side: float = roundf(GRID_MIN_SIDE * ResponsiveManager.tablet_factor(ResponsiveManager.get_viewport_size(self)))
	grid_aspect.custom_minimum_size = Vector2(side, side)
	var compact: bool = modal_panel.custom_minimum_size.x < NAV_LABELS_MIN_WIDTH
	if compact != _nav_compact:
		_nav_compact = compact
		_update_nav_labels()
	_fit_detail_height()

## Lines of explanation shown at once
const DESC_LINES: int = 5

## The explanation gets room for DESC_LINES lines at the current text size, and the area under
## the board the height of the taller view, whichever is on show
func _fit_detail_height() -> void:
	if detail_box == null or desc_scroll == null:
		return
	desc_scroll.custom_minimum_size.y = ceilf(step_desc_label.get_line_height() * DESC_LINES)
	var sep: float = detail_box.get_theme_constant("separation")
	var step_h: float = step_nav_bar.get_combined_minimum_size().y + sep + step_info_panel.get_combined_minimum_size().y
	detail_box.custom_minimum_size.y = maxf(step_h, full_info_panel.get_combined_minimum_size().y)

func _on_text_size_changed() -> void:
	_fit_detail_height()

func _update_nav_labels() -> void:
	if btn_prev == null or btn_next == null:
		return
	for pair in [[btn_prev, "BTN_PREV_STEP", HORIZONTAL_ALIGNMENT_LEFT], [btn_next, "BTN_NEXT_STEP", HORIZONTAL_ALIGNMENT_RIGHT]]:
		var b: Button = pair[0]
		var label: String = LocalizationManager.translate(pair[1])
		b.text = "" if _nav_compact else label
		b.tooltip_text = label
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if _nav_compact else pair[2]
		b.custom_minimum_size.x = ResponsiveManager.TOUCH_TARGET_MIN if _nav_compact else 76.0

func _on_close_pressed() -> void:
	close_modal()

func _update_locale_texts() -> void:
	title = LocalizationManager.translate("SOLUTION_TITLE")
	ok_button_text = LocalizationManager.translate("BTN_CLOSE")

	btn_step_mode.text = LocalizationManager.translate("BTN_STEP_BY_STEP")
	btn_full_mode.text = LocalizationManager.translate("BTN_FULL_SOLUTION")
	_update_nav_labels()
	apply_btn.text = LocalizationManager.translate("BTN_APPLY_SOLUTION")
	apply_btn.icon = ThemeManager.get_icon("check")
	apply_btn.add_theme_constant_override("icon_max_width", 16)

	if current_mode == Mode.STEP_BY_STEP:
		set_step(current_step_idx)
	else:
		_render_full_solution()

func _apply_theme_styles() -> void:
	if grid_frame != null:
		grid_frame.add_theme_stylebox_override("panel",
			ThemeManager.create_flat_stylebox(ThemeManager.get_color("cell_bg"), ThemeManager.RADIUS_MD))
	if grid_lines != null:
		grid_lines.queue_redraw()
	if step_coord_badge != null:
		step_coord_badge.add_theme_color_override("font_color", ThemeManager.get_color("accent_blue"))
	if full_unique_label != null:
		full_unique_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))

	var is_step := (current_mode == Mode.STEP_BY_STEP)
	if btn_step_mode != null:
		btn_step_mode.theme_type_variation = "PrimaryButton" if is_step else "SecondaryButton"
	if btn_full_mode != null:
		btn_full_mode.theme_type_variation = "SecondaryButton" if is_step else "PrimaryButton"

	if initial_puzzle != null:
		if current_mode == Mode.STEP_BY_STEP:
			set_step(current_step_idx)
		else:
			_render_full_solution()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or current_mode != Mode.STEP_BY_STEP:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			set_step(current_step_idx - 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			set_step(current_step_idx + 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			set_step(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_END:
			set_step(steps.size())
			get_viewport().set_input_as_handled()
