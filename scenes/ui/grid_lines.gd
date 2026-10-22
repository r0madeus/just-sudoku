class_name GridLines
extends RefCounted

## Draws a 9x9 Sudoku frame and its lines so they stay crisp at any screen scale.
##
## The UI is laid out in dp and scaled to the device (2.625x, 2x, 1.14x ...), and a cell is
## grid/9 wide, so lines land between device pixels and get smeared over two of them, each a
## little differently. Here every line is a filled rectangle whose edges sit on device pixel
## boundaries and whose width is a whole number of device pixels; the inner lines also stop at
## the frame instead of running over its rounded corners.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

## Line widths in layout pixels; the box lines and the frame share one width
const MINOR_WIDTH: float = 1.0
const MAJOR_WIDTH: float = 2.0

## Transform from the item's local coordinates to device pixels
static func device_transform(item: CanvasItem) -> Transform2D:
	return item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()

## `value` (local, along `axis` 0 = x, 1 = y) moved to the nearest device pixel boundary
static func snap(t: Transform2D, value: float, axis: int) -> float:
	var s: float = t.get_scale()[axis]
	var o: float = t.origin[axis]
	if s <= 0.0:
		return value
	return (roundf(o + value * s) - o) / s

## `width` rounded to a whole number of device pixels (at least one)
static func snap_width(t: Transform2D, width: float, axis: int) -> float:
	var s: float = t.get_scale()[axis]
	if s <= 0.0:
		return width
	return maxf(1.0, roundf(width * s)) / s

## Frame and lines of a 9x9 board filling `rect` (local to `item`)
static func draw_board(item: CanvasItem, rect: Rect2, minor_col: Color, major_col: Color,
		radius: int = ThemeManager.RADIUS_MD) -> void:
	var t := device_transform(item)
	var x0 := snap(t, rect.position.x, 0)
	var y0 := snap(t, rect.position.y, 1)
	var x1 := snap(t, rect.end.x, 0)
	var y1 := snap(t, rect.end.y, 1)
	var cell_w := (x1 - x0) / 9.0
	var cell_h := (y1 - y0) / 9.0
	var major_w := snap_width(t, MAJOR_WIDTH, 0)
	var major_h := snap_width(t, MAJOR_WIDTH, 1)

	for i in range(1, 9):
		var major: bool = i % 3 == 0
		var col: Color = major_col if major else minor_col
		var w := major_w if major else snap_width(t, MINOR_WIDTH, 0)
		var h := major_h if major else snap_width(t, MINOR_WIDTH, 1)
		# Inside the frame only, so no line pokes past the rounded border
		var x := snap(t, x0 + i * cell_w - w * 0.5, 0)
		item.draw_rect(Rect2(x, y0 + major_h, w, (y1 - y0) - major_h * 2.0), col)
		var y := snap(t, y0 + i * cell_h - h * 0.5, 1)
		item.draw_rect(Rect2(x0 + major_w, y, (x1 - x0) - major_w * 2.0, h), col)

	var frame := StyleBoxFlat.new()
	frame.anti_aliasing_size = ThemeManager.edge_aa()
	frame.draw_center = false
	frame.border_color = major_col
	frame.set_border_width_all(int(MAJOR_WIDTH))
	frame.set_corner_radius_all(radius)
	frame.corner_detail = 12
	item.draw_style_box(frame, Rect2(x0, y0, x1 - x0, y1 - y0))
