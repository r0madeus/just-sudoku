class_name MiniBoard
extends Control

## Small, non-interactive 9x9 Sudoku preview (resume card, decorative home mark).
## `set_board` shows a real game; `set_decorative` shows a fixed sample, drawn quieter.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")

const SAMPLE: String = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
## Below this cell size digits are drawn as dots
const THUMBNAIL_CELL_PX: float = 9.0

var _values: PackedInt32Array = PackedInt32Array()
var _given: PackedByteArray = PackedByteArray()
var _decorative: bool = true

func _init() -> void:
	custom_minimum_size = Vector2(148, 148)
	mouse_filter = MOUSE_FILTER_IGNORE
	set_decorative()
	ThemeManager.add_listener(queue_redraw)

func _exit_tree() -> void:
	ThemeManager.remove_listener(queue_redraw)

func set_board(current: SudokuBoard, initial: SudokuBoard) -> void:
	_decorative = false
	_values.resize(81)
	_given.resize(81)
	for i in range(81):
		_values[i] = current.get_cell(i)
		_given[i] = 1 if initial.get_cell(i) != 0 else 0
	queue_redraw()

## From 81-character strings (index / history entries); a missing or broken `current` falls
## back to the decorative sample
func set_strings(current: String, initial: String = "") -> void:
	if current.length() != 81:
		set_decorative()
		return
	_decorative = false
	_values.resize(81)
	_given.resize(81)
	for i in range(81):
		var ch := current[i]
		_values[i] = int(ch) if ch >= "1" and ch <= "9" else 0
		var g := initial[i] if initial.length() == 81 else ch
		_given[i] = 1 if g >= "1" and g <= "9" else 0
	queue_redraw()

func set_decorative() -> void:
	_decorative = true
	_values.resize(81)
	_given.resize(81)
	for i in range(81):
		_values[i] = int(SAMPLE[i])
		_given[i] = 1
	queue_redraw()

func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0.0:
		return
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var cell: float = side / 9.0

	var radius: int = mini(10, int(side * 0.12))
	var bg := StyleBoxFlat.new()
	bg.anti_aliasing_size = ThemeManager.edge_aa()
	bg.bg_color = Color(ThemeManager.get_color("cell_bg"), 0.55 if _decorative else 0.85)
	bg.set_corner_radius_all(radius)
	bg.corner_detail = 12
	draw_style_box(bg, Rect2(origin, Vector2(side, side)))

	var minor: Color = ThemeManager.get_color("grid_minor")
	var major: Color = ThemeManager.get_color("grid_major")
	if _decorative:
		minor.a *= 0.6
		major.a *= 0.6
	var thumbnail: bool = cell < THUMBNAIL_CELL_PX
	for i in range(1, 9):
		var is_major: bool = i % 3 == 0
		if thumbnail and not is_major:
			continue
		var col: Color = major if is_major else minor
		var w: float = 1.4 if is_major else 0.8
		if thumbnail:
			# At thumbnail size the box lines would dominate the digits
			col.a *= 0.45
			w = 1.0
		var p: float = i * cell
		draw_line(origin + Vector2(p, 4.0), origin + Vector2(p, side - 4.0), col, w, true)
		draw_line(origin + Vector2(4.0, p), origin + Vector2(side - 4.0, p), col, w, true)

	var font: Font = ThemeManager.get_font_inter()
	var font_size: int = int(cell * 0.62)
	var given_col: Color = ThemeManager.get_color("text_given")
	var user_col: Color = ThemeManager.get_color("text_user")
	if _decorative:
		given_col = Color(ThemeManager.get_color("text_secondary"), 0.75)
	# List thumbnails: a digit a few pixels tall is noise, so filled cells become dots
	if thumbnail:
		# Starting digits recede, the player's own digits carry the accent
		var dot: float = maxf(0.9, cell * 0.2)
		var given_dot := Color(given_col, given_col.a * 0.45)
		for idx in range(81):
			if _values[idx] == 0:
				continue
			var center := origin + Vector2((idx % 9 + 0.5) * cell, (idx / 9 + 0.5) * cell)
			draw_circle(center, dot, given_dot if _given[idx] == 1 else user_col, true, -1.0, true)
		return
	for idx in range(81):
		var v: int = _values[idx]
		if v == 0:
			continue
		var r: int = idx / 9
		var c: int = idx % 9
		var col: Color = given_col if _given[idx] == 1 else user_col
		var text_pos := origin + Vector2(c * cell, r * cell + cell * 0.5 + font_size * 0.36)
		draw_string(font, text_pos, str(v), HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, col)
