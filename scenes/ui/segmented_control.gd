class_name SegmentedControl
extends PanelContainer

## Generic SegmentedControl Component
## Unified single-selection segmented control with theme awareness,
## equal-width distribution, and responsive adaptation.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

signal item_selected(id: String, index: int)

var hbox: HBoxContainer
var buttons: Array[Button] = []
var items: Array[Dictionary] = [] # Array of {"id": String, "text": String}
var selected_id: String = ""
var selected_index: int = -1

const SLIDE_TIME: float = 0.22

## The accent pill behind the chosen segment. It slides to the next one: 0 = where it was,
## 1 = on the chosen segment (which it follows if the control is resized)
var pill_t: float = 1.0 :
	set(v):
		pill_t = v
		if hbox != null:
			hbox.queue_redraw()
var _pill_from: Rect2 = Rect2()
var _tween: Tween = null

func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	theme_type_variation = "SegmentedDock"
	_build_ui()
	_apply_theme_style()
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)
	if _tween != null:
		_tween.kill()

func _apply_theme_style() -> void:
	var surface_col: Color = ThemeManager.get_color("surface")
	var border_col: Color = ThemeManager.get_color("border_subtle")
	var sb := ThemeManager.create_flat_stylebox(
		surface_col,
		ThemeManager.RADIUS_PILL_SM,
		ThemeManager.BORDER_HAIRLINE,
		border_col,
		3, 3
	)
	add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", ThemeManager.SPACE_2XS)
	# Drawn before the buttons, so the pill sits behind their text
	hbox.draw.connect(_draw_pill)
	hbox.resized.connect(hbox.queue_redraw)
	add_child(hbox)

func clear_segments() -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	items.clear()
	selected_index = -1
	selected_id = ""

func add_segment(id: String, text: String) -> void:
	var idx := items.size()
	items.append({"id": id, "text": text})

	var btn := Button.new()
	btn.text = text
	btn.set_meta("id", id)
	btn.set_meta("diff", id)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, ThemeManager.HEIGHT_SEGMENT)
	btn.theme_type_variation = "SegmentButton"
	ThemeManager.set_font_size(btn, ThemeManager.FONT_SIZE_SUBTITLE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): select_index(idx))
	hbox.add_child(btn)
	buttons.append(btn)

func select_id(id: String) -> void:
	for i in range(items.size()):
		if items[i]["id"] == id:
			select_index(i)
			return

func select_index(idx: int) -> void:
	if idx < 0 or idx >= items.size():
		return
	var first: bool = selected_index < 0
	if not first and idx != selected_index:
		_pill_from = _pill_rect()
	selected_index = idx
	selected_id = items[idx]["id"]
	_update_button_visuals()
	_slide_pill(first or _pill_from.size == Vector2.ZERO)
	item_selected.emit(selected_id, selected_index)

func set_segment_text(id: String, text: String) -> void:
	for i in range(items.size()):
		if items[i]["id"] == id:
			items[i]["text"] = text
			if i < buttons.size():
				buttons[i].text = text
			break

func get_selected_id() -> String:
	return selected_id

func get_selected_index() -> int:
	return selected_index

## Every segment is a plain button; the chosen one has white text over the pill that is drawn behind
func _update_button_visuals() -> void:
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		btn.theme_type_variation = "GhostButton"
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			if i == selected_index:
				btn.add_theme_color_override(c, Color.WHITE)
			else:
				btn.remove_theme_color_override(c)
	if hbox != null:
		hbox.queue_redraw()

func _slide_pill(instant: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if instant or not is_inside_tree() or not is_visible_in_tree() or not AppSettings.animations_enabled:
		pill_t = 1.0
		return
	pill_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "pill_t", 1.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Where the pill is now: on the chosen segment, or part of the way from the previous one
func _pill_rect() -> Rect2:
	if selected_index < 0 or selected_index >= buttons.size():
		return Rect2()
	var target := Rect2(buttons[selected_index].position, buttons[selected_index].size)
	if pill_t >= 1.0 or _pill_from.size == Vector2.ZERO:
		return target
	return Rect2(_pill_from.position.lerp(target.position, pill_t), _pill_from.size.lerp(target.size, pill_t))

func _draw_pill() -> void:
	var rect := _pill_rect()
	if rect.size == Vector2.ZERO:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	style.set_corner_radius_all(ThemeManager.RADIUS_CAPSULE)
	style.anti_aliasing = true
	style.anti_aliasing_size = ThemeManager.edge_aa()
	hbox.draw_style_box(style, rect)

func _on_theme_changed() -> void:
	_apply_theme_style()
	_update_button_visuals()
