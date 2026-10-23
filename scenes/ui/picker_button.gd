class_name PickerButton
extends OptionButton

const AppModal = preload("res://scenes/ui/app_modal.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")

## A dropdown that opens the app's own sheet instead of Godot's popup menu: the choices in a
## glass panel like every other dialog, rows as tall as the buttons, the current one ticked.
## The popup menu looked like a desktop menu (small rows, radio dots, its own frame), and it did
## not follow the app's theme. Everything else is still an OptionButton, so add_item, selected,
## select() and item_selected work as before.

## The label naming this setting; the sheet takes its title from it when it opens
var title_source: Label = null
## The open sheet, if any
var sheet: AppModal = null

var _press_inside: bool = false

func _gui_input(event: InputEvent) -> void:
	# Handled here, so OptionButton never opens its popup menu. Opens when the finger is lifted
	# on the button, so a scroll that starts on it does not open it.
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_press_inside = true
		elif _press_inside:
			_press_inside = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				open_picker()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		open_picker()

## The highest Control above this button: the sheet covers the whole app, not a card or a dialog
func _host() -> Node:
	var host: Node = self
	while host.get_parent() is Control:
		host = host.get_parent()
	return host

func open_picker() -> void:
	if sheet != null and is_instance_valid(sheet) and sheet.visible:
		return
	sheet = AppModal.new()
	sheet.title = title_source.text if title_source != null and not title_source.text.is_empty() else text
	sheet.max_modal_width = 340.0
	# A choice is made by tapping it; the close button and the backdrop cancel
	sheet.actions_vbox.visible = false
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	sheet.body_vbox.add_child(list)
	var check := ThemeManager.get_icon_sized("check", 18)
	for i in item_count:
		var row := Button.new()
		row.theme_type_variation = "PickerItem"
		row.text = get_item_text(i)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.custom_minimum_size = Vector2(0, 52)
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		row.toggle_mode = true
		row.button_pressed = i == selected
		row.icon = check if i == selected else null
		row.disabled = is_item_disabled(i)
		row.pressed.connect(_choose.bind(i))
		list.add_child(row)
	sheet.visibility_changed.connect(func():
		if sheet != null and is_instance_valid(sheet) and not sheet.visible:
			sheet.queue_free()
			sheet = null
	)
	_host().add_child(sheet)
	sheet.open_modal()

func _choose(index: int) -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.close_modal()
	if index == selected:
		return
	select(index)
	item_selected.emit(index)
