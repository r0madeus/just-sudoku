class_name SettingRow
extends HBoxContainer

## Reusable SettingRow Component
## Standardized row layout with title and description on the left,
## and interactive control on the right. Fully responsive on mobile with comfortable touch targets.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

var text_vbox: VBoxContainer
var title_label: Label
var desc_label: Label
var control_holder: HBoxContainer
var control_node: Control
## The control sits under the title instead of beside it (narrow phone, large text)
var stacked: bool = false

## Narrowest the title column may get beside the control before the control moves under it,
## at normal text size (it grows with the text)
const MIN_TITLE_WIDTH: float = 110.0

func _init(p_title: String = "", p_desc: String = "", p_control: Control = null) -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 44)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = MOUSE_FILTER_PASS

	_build_ui()

	if not p_title.is_empty():
		set_title(p_title)
	if not p_desc.is_empty():
		set_description(p_desc)
	if p_control != null:
		set_control(p_control)

	ThemeManager.add_listener(_apply_theme)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_apply_theme)

func _build_ui() -> void:
	text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = SIZE_SHRINK_CENTER
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = MOUSE_FILTER_PASS
	add_child(text_vbox)

	title_label = Label.new()
	title_label.theme_type_variation = "Body"
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = MOUSE_FILTER_PASS
	text_vbox.add_child(title_label)

	desc_label = Label.new()
	desc_label.theme_type_variation = "Caption"
	desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = MOUSE_FILTER_PASS
	desc_label.visible = false
	text_vbox.add_child(desc_label)

	control_holder = HBoxContainer.new()
	control_holder.alignment = BoxContainer.ALIGNMENT_END
	control_holder.size_flags_vertical = SIZE_SHRINK_CENTER
	control_holder.size_flags_horizontal = SIZE_SHRINK_END
	control_holder.mouse_filter = MOUSE_FILTER_PASS
	add_child(control_holder)

	_apply_theme()

func set_title(t: String) -> void:
	if title_label != null:
		title_label.text = t

func set_description(d: String) -> void:
	if desc_label != null:
		desc_label.text = d
		desc_label.visible = not d.is_empty()

func set_control(ctrl: Control) -> void:
	if control_node != null and control_node.get_parent() == control_holder:
		control_holder.remove_child(control_node)
	control_node = ctrl
	if control_node != null:
		if control_node.get_parent() != null:
			control_node.get_parent().remove_child(control_node)
		control_holder.add_child(control_node)
		if control_node is CheckBox:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_stacking.call_deferred()

## A wide control (a picker, a button) next to a long title on a narrow row would squeeze the
## title to a word per line; then the control goes under the title. Check boxes always fit.
func _update_stacking() -> void:
	if control_node == null or control_node is CheckBox or size.x <= 0.0:
		return
	var sep: float = get_theme_constant("separation")
	var want: bool = size.x - control_node.get_combined_minimum_size().x - sep < MIN_TITLE_WIDTH * ThemeManager.text_scale
	if want == stacked:
		return
	stacked = want
	control_holder.get_parent().remove_child(control_holder)
	if stacked:
		text_vbox.add_child(control_holder)
		control_holder.alignment = BoxContainer.ALIGNMENT_BEGIN
		control_holder.size_flags_horizontal = SIZE_EXPAND_FILL
	else:
		add_child(control_holder)
		control_holder.alignment = BoxContainer.ALIGNMENT_END
		control_holder.size_flags_horizontal = SIZE_SHRINK_END
	text_vbox.add_theme_constant_override("separation", 6 if stacked else 2)

func _on_text_size_changed() -> void:
	_update_stacking.call_deferred()

func get_control() -> Control:
	return control_node

## Allow clicking row to toggle checkbox for superior mobile touch ergonomics
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if control_node is CheckBox:
			var cb := control_node as CheckBox
			cb.button_pressed = not cb.button_pressed
			accept_event()

func _apply_theme() -> void:
	if desc_label != null:
		desc_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if title_label != null:
		title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
