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

func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	theme_type_variation = "SegmentedDock"
	_build_ui()
	_apply_theme_style()
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)

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
	btn.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZE_SUBTITLE)
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
	selected_index = idx
	selected_id = items[idx]["id"]
	_update_button_visuals()
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

func _update_button_visuals() -> void:
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var is_active := (i == selected_index)
		if is_active:
			btn.theme_type_variation = "PrimaryButton"
		else:
			btn.theme_type_variation = "GhostButton"

func _on_theme_changed() -> void:
	_apply_theme_style()
	_update_button_visuals()
