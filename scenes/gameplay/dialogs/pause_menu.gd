class_name PauseMenu
extends "res://scenes/ui/app_modal.gd"

## The pause sheet over a game: resume, share the puzzle, copy the save, see the solution,
## settings, back to the menu, and a short confirmation line for the copies. It only builds
## the sheet and reports which action was picked; GameScreen does the actions.

signal resume_requested()
signal share_requested()
signal export_requested()
signal solution_requested()
signal settings_requested()
signal menu_requested()

## Level and puzzle number, under the title
var info_label: Label
## "Copied" and the like, for a moment
var toast_label: Label
var resume_btn: Button
var share_puzzle_btn: Button
var export_save_btn: Button
var solution_btn: Button
var settings_btn: Button
var menu_btn: Button

func _init() -> void:
	super()
	primary_btn.visible = false
	cancel_btn.visible = false
	show_close_button = false
	title_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ambient_background = true
	# Back or a tap outside resumes, like the Resume button
	canceled.connect(func(): resume_requested.emit())
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.theme_type_variation = "Subtitle"
	ThemeManager.set_font_size(info_label, 13)
	body_vbox.add_child(info_label)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.theme_type_variation = "Caption"
	toast_label.visible = false
	body_vbox.add_child(toast_label)

	resume_btn = _action("PrimaryButton", "play", ResponsiveManager.HEIGHT_BUTTON_PRIMARY, 16, resume_requested)
	share_puzzle_btn = _action("SecondaryButton", "upload", ResponsiveManager.HEIGHT_BUTTON_SECONDARY, 14, share_requested)
	export_save_btn = _action("SecondaryButton", "save", ResponsiveManager.HEIGHT_BUTTON_SECONDARY, 14, export_requested)
	solution_btn = _action("SecondaryButton", "lightbulb", ResponsiveManager.HEIGHT_BUTTON_SECONDARY, 14, solution_requested)
	settings_btn = _action("SecondaryButton", "settings", ResponsiveManager.HEIGHT_BUTTON_SECONDARY, 14, settings_requested)
	menu_btn = _action("GhostButton", "chevron-left", ResponsiveManager.HEIGHT_BUTTON_SECONDARY, 14, menu_requested)
	_apply_pause_colors()
	update_texts()
	# Registered here like AppModal's own listeners, and dropped with them on leaving the tree
	ThemeManager.add_listener(_apply_pause_colors)
	LocalizationManager.add_listener(update_texts)

func _exit_tree() -> void:
	super()
	ThemeManager.remove_listener(_apply_pause_colors)
	LocalizationManager.remove_listener(update_texts)

func _action(variation: String, icon: String, height: float, font_size: int, chosen: Signal) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, height)
	btn.theme_type_variation = variation
	btn.icon = ThemeManager.get_icon(icon)
	btn.add_theme_constant_override("icon_max_width", 18)
	ThemeManager.set_font_size(btn, font_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): chosen.emit())
	actions_vbox.add_child(btn)
	return btn

func _apply_pause_colors() -> void:
	info_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	toast_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))

func update_texts() -> void:
	title = LocalizationManager.translate("PAUSE_TITLE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume_btn.text = LocalizationManager.translate("BTN_RESUME")
	share_puzzle_btn.text = LocalizationManager.translate("BTN_SHARE_PUZZLE")
	export_save_btn.text = LocalizationManager.translate("BTN_COPY_SAVE")
	solution_btn.text = LocalizationManager.translate("BTN_SOLUTION")
	settings_btn.text = LocalizationManager.translate("BTN_SETTINGS")
	menu_btn.text = LocalizationManager.translate("BTN_MENU")

## Opens the sheet with the game's level and puzzle number
func open_for(info: String) -> void:
	info_label.text = info
	toast_label.visible = false
	open_modal()

## Shows a confirmation for a moment
func show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	if not is_inside_tree():
		return
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_callback(func():
		if is_instance_valid(toast_label):
			toast_label.visible = false
	)
