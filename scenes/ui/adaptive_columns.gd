class_name AdaptiveColumns
extends Container

## Sections in one column on a phone, in two side by side on a wide screen (a tablet in
## landscape, a large window). Each child says which column it belongs to with
## set_column(child, 0 or 1); in one column they simply stack in child order. Children keep
## their parent either way, so nothing that holds a reference to them has to know.

const COLUMN_META: StringName = &"adaptive_column"

## 1 or 2
var columns: int = 1:
	set(value):
		value = clampi(value, 1, 2)
		if value != columns:
			columns = value
			update_minimum_size()
			queue_sort()

## Space between stacked sections, and between the two columns
var separation: float = 20.0:
	set(value):
		separation = value
		update_minimum_size()
		queue_sort()

static func set_column(child: Control, column: int) -> void:
	child.set_meta(COLUMN_META, column)

func _column_of(c: Control) -> int:
	return int(c.get_meta(COLUMN_META, 0)) if columns == 2 else 0

func _visible_children() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and c.visible and not c.top_level:
			out.append(c)
	return out

func _get_minimum_size() -> Vector2:
	var widths := [0.0, 0.0]
	var heights := [0.0, 0.0]
	var counts := [0, 0]
	for c in _visible_children():
		var col := _column_of(c)
		var ms: Vector2 = c.get_combined_minimum_size()
		widths[col] = maxf(widths[col], ms.x)
		heights[col] += ms.y
		counts[col] += 1
	for col in range(2):
		if counts[col] > 1:
			heights[col] += separation * (counts[col] - 1)
	if columns == 2:
		return Vector2(widths[0] + widths[1] + separation, maxf(heights[0], heights[1]))
	return Vector2(widths[0], heights[0])

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var col_w: float = size.x if columns == 1 else floorf((size.x - separation) * 0.5)
		var y := [0.0, 0.0]
		for c in _visible_children():
			var col := _column_of(c)
			var h: float = c.get_combined_minimum_size().y
			var x: float = 0.0 if col == 0 else size.x - col_w
			fit_child_in_rect(c, Rect2(x, y[col], col_w, h))
			y[col] += h + separation
