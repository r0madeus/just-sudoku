class_name MiniBoard
extends Control

## Small, non-interactive 9x9 Sudoku preview (resume card, decorative home mark).
## `set_board` shows a real game; `set_decorative` shows a fixed sample, drawn quieter.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")

const SAMPLE: String = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

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

	var radius: int = 10
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(ThemeManager.get_color("cell_bg"), 0.55 if _decorative else 0.85)
	bg.set_corner_radius_all(radius)
	bg.corner_detail = 12
	draw_style_box(bg, Rect2(origin, Vector2(side, side)))

	var minor: Color = ThemeManager.get_color("grid_minor")
	var major: Color = ThemeManager.get_color("grid_major")
	if _decorative:
		minor.a *= 0.6
		major.a *= 0.6
	for i in range(1, 9):
		var is_major: bool = i % 3 == 0
		var col: Color = major if is_major else minor
		var w: float = 1.4 if is_major else 0.8
		var p: float = i * cell
		draw_line(origin + Vector2(p, 4.0), origin + Vector2(p, side - 4.0), col, w, true)
		draw_line(origin + Vector2(4.0, p), origin + Vector2(side - 4.0, p), col, w, true)

	var font: Font = ThemeManager.get_font_inter()
	var font_size: int = int(cell * 0.62)
	var given_col: Color = ThemeManager.get_color("text_given")
	var user_col: Color = ThemeManager.get_color("text_user")
	if _decorative:
		given_col = Color(ThemeManager.get_color("text_secondary"), 0.75)
	for idx in range(81):
		var v: int = _values[idx]
		if v == 0:
			continue
		var r: int = idx / 9
		var c: int = idx % 9
		var col: Color = given_col if _given[idx] == 1 else user_col
		var text_pos := origin + Vector2(c * cell, r * cell + cell * 0.5 + font_size * 0.36)
		draw_string(font, text_pos, str(v), HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, col)
