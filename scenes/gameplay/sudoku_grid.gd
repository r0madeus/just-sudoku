class_name SudokuGrid
extends Control

## 9x9 Responsive Sudoku Grid component
## Positions 81 SudokuCells, draws crisp 3x3 block & cell borders, and manages highlights.

signal cell_selected(idx: int, val: int)
## A cell was pressed (the selection has already moved to it)
signal cell_tapped(idx: int)
## More than one cell is selected now, or no longer
signal multi_selection_changed(cells: Array[int])

class GridOverlay extends Control:
	var grid_ref: SudokuGrid = null

	func _draw() -> void:
		if grid_ref != null:
			grid_ref._draw_grid_lines(self)

var cells: Array[SudokuCell] = []
var selected_idx: int = -1
var game_state: GameState = null
var lines_overlay: GridOverlay = null
## Unit (SudokuSolver.ALL_UNITS index) outlined by a first-level hint, -1 for none
var hint_focus_unit: int = -1
## Cells picked by dragging over the board (or Ctrl/Shift-click), selected_idx among them.
## Empty when only selected_idx is selected.
var multi_cells: Array[int] = []
## Dragging over cells adds them to the selection
var multi_select_enabled: bool = true
## Digit whose cells are highlighted instead of the selected cell's (digit-first input), 0 for none
var highlight_digit: int = 0
## Candidates drawn struck through, cell index -> digit bitmask (a lesson showing what a technique
## removes); empty in a game
var strike_marks: Dictionary = {}

var _pressing: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2.ZERO
	clip_contents = false
	_create_cells()

func _create_cells() -> void:
	if lines_overlay != null and is_instance_valid(lines_overlay):
		lines_overlay.queue_free()
		lines_overlay = null

	for c in cells:
		c.queue_free()
	cells.clear()

	for i in range(SudokuBoard.CELL_COUNT):
		var cell := SudokuCell.new()
		cell.cell_index = i
		# The board reads presses and drags itself, so a drag can run over many cells
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(cell)
		cells.append(cell)

	# Dedicated lines overlay rendering ON TOP of cells so highlights never occlude 3x3 boundaries
	lines_overlay = GridOverlay.new()
	lines_overlay.grid_ref = self
	lines_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(lines_overlay)

	_layout_cells()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cells()
		queue_redraw()

func _layout_cells() -> void:
	if cells.size() != SudokuBoard.CELL_COUNT:
		return

	var grid_size: float = minf(size.x, size.y)
	var cell_w: float = grid_size / 9.0
	var cell_h: float = grid_size / 9.0

	var offset_x: float = (size.x - grid_size) * 0.5
	var offset_y: float = (size.y - grid_size) * 0.5

	for idx in range(SudokuBoard.CELL_COUNT):
		var r: int = SudokuBoard.CELL_ROW[idx]
		var c: int = SudokuBoard.CELL_COL[idx]
		var cell: SudokuCell = cells[idx]
		cell.position = Vector2(offset_x + c * cell_w, offset_y + r * cell_h)
		cell.size = Vector2(cell_w, cell_h)

	if lines_overlay != null:
		lines_overlay.position = Vector2.ZERO
		lines_overlay.size = size
		lines_overlay.queue_redraw()

func bind_game_state(p_state: GameState) -> void:
	if game_state != null and game_state.cell_changed.is_connected(_on_cell_changed):
		game_state.cell_changed.disconnect(_on_cell_changed)
	game_state = p_state
	if game_state != null and not game_state.cell_changed.is_connected(_on_cell_changed):
		game_state.cell_changed.connect(_on_cell_changed)
	refresh_all_cells()

func _on_cell_changed(idx: int, _val: int, _mask: int) -> void:
	refresh_highlights()

func select_cell(idx: int) -> void:
	if idx < 0 or idx >= SudokuBoard.CELL_COUNT:
		selected_idx = -1
	else:
		selected_idx = idx
	_set_multi([])

	refresh_highlights()

	var val: int = 0
	if game_state != null and selected_idx != -1:
		val = game_state.current_board.get_cell(selected_idx)
	cell_selected.emit(selected_idx, val)

## The cells a number or colour applies to: the multi-selection, else the selected cell
func get_target_cells() -> Array[int]:
	if not multi_cells.is_empty():
		return multi_cells.duplicate()
	var one: Array[int] = []
	if selected_idx != -1:
		one.append(selected_idx)
	return one

func is_multi_selection() -> bool:
	return multi_cells.size() > 1

func _set_multi(cells_sel: Array[int]) -> void:
	var was_multi := is_multi_selection()
	multi_cells = cells_sel
	if was_multi or is_multi_selection():
		multi_selection_changed.emit(multi_cells.duplicate())

## Index of the cell under a point in the board's own coordinates, -1 outside the cells
func cell_at(pos: Vector2) -> int:
	var grid_size: float = minf(size.x, size.y)
	if grid_size <= 0.0:
		return -1
	var local := pos - Vector2((size.x - grid_size) * 0.5, (size.y - grid_size) * 0.5)
	if local.x < 0.0 or local.y < 0.0 or local.x >= grid_size or local.y >= grid_size:
		return -1
	var cell_size: float = grid_size / 9.0
	return SudokuBoard.get_index(int(local.y / cell_size), int(local.x / cell_size))

# Mouse events only: on touch screens Godot also sends each touch as a mouse event, so reading
# both would press every cell twice
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_pressing = false
			return
		var idx := cell_at(event.position)
		if idx == -1:
			return
		accept_event()
		if multi_select_enabled and (event.ctrl_pressed or event.shift_pressed or event.meta_pressed):
			_toggle_in_selection(idx)
			return
		_pressing = true
		select_cell(idx)
		cell_tapped.emit(idx)
	elif event is InputEventMouseMotion and _pressing:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_pressing = false
			return
		var idx := cell_at(event.position)
		if idx == -1 or not multi_select_enabled or idx == selected_idx or multi_cells.has(idx):
			return
		accept_event()
		var cells_sel: Array[int] = multi_cells.duplicate()
		if cells_sel.is_empty():
			cells_sel.append(selected_idx)
		cells_sel.append(idx)
		_extend_selection(cells_sel, idx)

## Ctrl/Shift-click: adds a cell to the selection, or takes it out
func _toggle_in_selection(idx: int) -> void:
	if selected_idx == -1:
		select_cell(idx)
		return
	var cells_sel: Array[int] = multi_cells.duplicate()
	if cells_sel.is_empty():
		cells_sel.append(selected_idx)
	if cells_sel.has(idx):
		if cells_sel.size() == 1:
			return
		cells_sel.erase(idx)
		_extend_selection(cells_sel, cells_sel[cells_sel.size() - 1])
	else:
		cells_sel.append(idx)
		_extend_selection(cells_sel, idx)

func _extend_selection(cells_sel: Array[int], primary: int) -> void:
	selected_idx = primary
	_set_multi(cells_sel if cells_sel.size() > 1 else ([] as Array[int]))
	refresh_highlights()
	cell_selected.emit(selected_idx, game_state.current_board.get_cell(selected_idx) if game_state != null else 0)

func set_highlight_digit(digit: int) -> void:
	if highlight_digit == digit:
		return
	highlight_digit = digit
	refresh_highlights()

func set_strike_marks(marks: Dictionary) -> void:
	strike_marks = marks
	refresh_highlights()

func move_selection(d_row: int, d_col: int) -> void:
	if selected_idx == -1:
		select_cell(0)
		return

	var r: int = SudokuBoard.CELL_ROW[selected_idx] + d_row
	var c: int = SudokuBoard.CELL_COL[selected_idx] + d_col
	r = clampi(r, 0, 8)
	c = clampi(c, 0, 8)
	select_cell(SudokuBoard.get_index(r, c))

func refresh_all_cells() -> void:
	refresh_highlights()

func refresh_highlights() -> void:
	if game_state == null or cells.size() != SudokuBoard.CELL_COUNT:
		return

	var conflicts: Array[int] = SudokuValidator.get_conflicts(game_state.current_board)
	var sel_val: int = 0
	var sel_peers: Array = []

	var multi := is_multi_selection()
	if selected_idx != -1:
		sel_val = game_state.current_board.get_cell(selected_idx)
		# Many selected cells have no single row and column to tint
		if not multi:
			sel_peers = SudokuBoard.PEERS[selected_idx]
	if highlight_digit != 0:
		sel_val = highlight_digit

	for idx in range(SudokuBoard.CELL_COUNT):
		var val: int = game_state.current_board.get_cell(idx)
		var is_given: bool = game_state.initial_puzzle.is_given(idx)
		var cands: int = game_state.current_board.candidates[idx]

		var is_sel: bool = (idx == selected_idx) or (multi and multi_cells.has(idx))
		var is_peer: bool = (not is_sel and sel_peers.has(idx))
		var is_same: bool = (not is_sel and sel_val != 0 and val == sel_val)
		var is_conf: bool = conflicts.has(idx) and AppSettings.show_conflicts
		var is_wrong: bool = game_state.checked_wrong_indices.has(idx)

		cells[idx].mark_color = game_state.get_cell_color(idx)
		cells[idx].strike_mask = int(strike_marks.get(idx, 0))
		cells[idx].set_cell_data(val, is_given, cands, is_sel, is_peer, is_same, is_conf, is_wrong)

	if lines_overlay != null:
		lines_overlay.queue_redraw()
	queue_redraw()

func _draw() -> void:
	# Draw clean board background with rounded corners behind all cells
	var grid_size: float = minf(size.x, size.y)
	var ox: float = (size.x - grid_size) * 0.5
	var oy: float = (size.y - grid_size) * 0.5
	var bg_sb := StyleBoxFlat.new()
	bg_sb.anti_aliasing_size = ThemeManager.edge_aa()
	bg_sb.bg_color = ThemeManager.get_color("cell_bg")
	bg_sb.set_corner_radius_all(ThemeManager.RADIUS_MD)
	draw_style_box(bg_sb, Rect2(ox, oy, grid_size, grid_size))

func _draw_grid_lines(overlay: Control) -> void:
	if overlay == null:
		return
	var grid_size: float = minf(size.x, size.y)
	var cell_size: float = grid_size / 9.0
	var ox: float = (size.x - grid_size) * 0.5
	var oy: float = (size.y - grid_size) * 0.5

	var minor_col: Color = ThemeManager.get_color("grid_minor")
	var major_col: Color = ThemeManager.get_color("grid_major")

	# 1-3. Cell lines, box lines and the rounded frame, aligned to device pixels
	GridLines.draw_board(overlay, Rect2(ox, oy, grid_size, grid_size), minor_col, major_col)

	# 4. Hint focus: accent frame around the row, column or box the hint points at
	if hint_focus_unit >= 0:
		var r0: int = 0
		var c0: int = 0
		var rows: int = 9
		var cols: int = 9
		if hint_focus_unit < 9:
			r0 = hint_focus_unit
			rows = 1
		elif hint_focus_unit < 18:
			c0 = hint_focus_unit - 9
			cols = 1
		else:
			var b: int = hint_focus_unit - 18
			r0 = (b / 3) * 3
			c0 = (b % 3) * 3
			rows = 3
			cols = 3
		var accent: Color = ThemeManager.get_color("accent")
		var focus_sb := StyleBoxFlat.new()
		focus_sb.anti_aliasing_size = ThemeManager.edge_aa()
		focus_sb.bg_color = Color(accent, 0.12)
		focus_sb.border_color = accent
		focus_sb.set_border_width_all(3)
		focus_sb.set_corner_radius_all(ThemeManager.RADIUS_SM)
		overlay.draw_style_box(focus_sb, Rect2(
			ox + c0 * cell_size, oy + r0 * cell_size, cols * cell_size, rows * cell_size))

func set_hint_focus(unit_idx: int) -> void:
	if hint_focus_unit == unit_idx:
		return
	hint_focus_unit = unit_idx
	if lines_overlay != null:
		lines_overlay.queue_redraw()

func play_victory_wave(on_finished: Callable = Callable()) -> void:
	if not AppSettings.animations_enabled or cells.size() != SudokuBoard.CELL_COUNT:
		if on_finished.is_valid():
			on_finished.call()
		return

	var step_delay: float = 0.02
	for idx in range(SudokuBoard.CELL_COUNT):
		var r: int = SudokuBoard.CELL_ROW[idx]
		var c: int = SudokuBoard.CELL_COL[idx]
		var diag: int = r + c
		var delay: float = diag * step_delay
		cells[idx].animate_wave(delay)

	if not is_inside_tree():
		if on_finished.is_valid():
			on_finished.call()
		return

	var t := create_tween()
	if t != null:
		t.tween_interval(0.38)
		t.tween_callback(func():
			if on_finished.is_valid():
				on_finished.call()
		)
	else:
		if on_finished.is_valid():
			on_finished.call()

## Light sweep over each completed row/column/box, rippling out from the cell just filled
func play_units_completed(origin_idx: int, units: Array) -> void:
	if not AppSettings.animations_enabled or cells.size() != SudokuBoard.CELL_COUNT:
		return
	var o_r: int = SudokuBoard.CELL_ROW[origin_idx]
	var o_c: int = SudokuBoard.CELL_COL[origin_idx]
	var flashed: Dictionary = {}
	for unit in units:
		for idx in unit:
			if flashed.has(idx):
				continue
			flashed[idx] = true
			var dist: int = absi(SudokuBoard.CELL_ROW[idx] - o_r) + absi(SudokuBoard.CELL_COL[idx] - o_c)
			cells[idx].animate_unit_completed(dist * 0.035)

func play_digit_completed_pulse(digit: int) -> void:
	if not AppSettings.animations_enabled or cells.size() != SudokuBoard.CELL_COUNT:
		return
	var ripple_delay: float = 0.015
	var count: int = 0
	for idx in range(SudokuBoard.CELL_COUNT):
		if cells[idx].value == digit:
			cells[idx].animate_digit_completed(count * ripple_delay)
			count += 1
