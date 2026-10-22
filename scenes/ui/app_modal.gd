class_name AppModal
extends Control

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")

## Unified AppModal Component
## Standard in-engine modal dialog with dimming backdrop, responsive clamping,
## consistent typography, button hierarchy, and Global Theme integration.

signal confirmed()
signal canceled()
signal custom_action(action_id: String)

## Every modal joins this group so the Android back button can dismiss the topmost open one
const GROUP: String = "app_modals"

# Configuration properties
var max_modal_width: float = 380.0
var dismissible_backdrop: bool = true
## The Android back button cancels the modal even when tapping the backdrop does not
var cancel_on_back: bool = false

var show_close_button: bool = true :
	get:
		return show_close_button
	set(val):
		show_close_button = val
		if close_btn != null:
			close_btn.visible = val

var title_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT :
	get:
		return title_label.horizontal_alignment if title_label != null else title_alignment
	set(val):
		title_alignment = val
		if title_label != null:
			title_label.horizontal_alignment = val

## Frosts whatever is behind the modal (cheap mip-level blur) instead of only dimming it
var blur_background: bool = true :
	get:
		return blur_background
	set(val):
		blur_background = val
		_update_backdrop_material()

## Replaces the scrim with a glowing AmbientBackdrop (for modals that cover content that must
## stay hidden, like the paused grid) so the glass panel has something to refract
var ambient_background: bool = false :
	get:
		return ambient_background
	set(val):
		ambient_background = val
		if ambient != null:
			ambient.visible = val
		if backdrop != null:
			backdrop.visible = not val

# Backwards compatibility properties
var title: String = "" :
	get:
		return title_label.text if title_label != null else ""
	set(val):
		title = val
		if title_label != null:
			title_label.text = val

var dialog_text: String = "" :
	get:
		return message_label.text if message_label != null else ""
	set(val):
		dialog_text = val
		if message_label != null:
			message_label.text = val
			message_label.visible = not val.is_empty()

var ok_button_text: String = "" :
	get:
		return primary_btn.text if primary_btn != null else ""
	set(val):
		ok_button_text = val
		if primary_btn != null:
			primary_btn.text = val

var cancel_button_text: String = "" :
	get:
		return cancel_btn.text if cancel_btn != null else ""
	set(val):
		cancel_button_text = val
		if cancel_btn != null:
			cancel_btn.text = val

# Core UI Nodes
var backdrop: ColorRect
var ambient: AmbientBackdrop
var center_container: CenterContainer
var modal_panel: PanelContainer
var modal_vbox: VBoxContainer

# Header
var header_hbox: HBoxContainer
var title_label: Label
var close_btn: Button

# Body / Content Container
var body_vbox: VBoxContainer
var message_label: Label

# Footer / Action Container
var actions_vbox: VBoxContainer
var primary_btn: Button
var cancel_btn: Button
var extra_buttons: Array[Button] = []

func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	z_index = 60
	add_to_group(GROUP)
	_build_base_ui()
	_update_base_locale_texts()
	LocalizationManager.add_listener(_update_base_locale_texts)
	ThemeManager.add_listener(_on_base_theme_changed)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_base_locale_texts)
	ThemeManager.remove_listener(_on_base_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _ready() -> void:
	_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if dismissible_backdrop:
			_on_canceled()
			get_viewport().set_input_as_handled()

func get_ok_button() -> Button:
	return primary_btn

func get_cancel_button() -> Button:
	return cancel_btn

func add_button(btn_text: String, before_cancel: bool = false, action_id: String = "") -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.theme_type_variation = "SecondaryButton"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func():
		custom_action.emit(action_id)
	)
	if before_cancel and cancel_btn != null and cancel_btn.get_parent() == actions_vbox:
		actions_vbox.add_child(btn)
		actions_vbox.move_child(btn, cancel_btn.get_index())
	else:
		actions_vbox.add_child(btn)
	extra_buttons.append(btn)
	return btn

var _modal_tween: Tween = null

## One-off confirmation over `host`; `on_confirm` runs only when the player accepts.
## `destructive` paints the confirm button in the conflict color (deleting, giving up a game).
## The modal frees itself once it has closed.
static func ask(host: Node, title_text: String, body: String, confirm_text: String,
		on_confirm: Callable, destructive: bool = false) -> AppModal:
	var modal := AppModal.new()
	modal.title = title_text
	modal.dialog_text = body
	modal.ok_button_text = confirm_text
	modal.cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	modal.confirmed.connect(on_confirm)
	host.add_child(modal)
	if destructive and modal.primary_btn != null:
		var sb := ThemeManager.create_flat_stylebox(ThemeManager.get_color("text_conflict"), ThemeManager.RADIUS_PILL)
		for state in ["normal", "hover", "pressed", "focus"]:
			modal.primary_btn.add_theme_stylebox_override(state, sb)
		modal.primary_btn.add_theme_color_override("font_color", Color.WHITE)
		modal.primary_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	modal.visibility_changed.connect(func():
		if not modal.visible:
			modal.queue_free()
	)
	modal.open_modal()
	return modal

func open_modal() -> void:
	visible = true
	_apply_responsive_layout()
	if _modal_tween != null and _modal_tween.is_valid():
		_modal_tween.kill()

	if SettingsScreen.animations_enabled and is_inside_tree():
		modulate.a = 0.0
		if modal_panel != null:
			modal_panel.pivot_offset = modal_panel.size * 0.5
			modal_panel.scale = Vector2(0.95, 0.95)
		_modal_tween = create_tween().set_parallel(true)
		if _modal_tween != null:
			_modal_tween.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if modal_panel != null:
				_modal_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0
		if modal_panel != null:
			modal_panel.scale = Vector2.ONE

func close_modal() -> void:
	if _modal_tween != null and _modal_tween.is_valid():
		_modal_tween.kill()

	if SettingsScreen.animations_enabled and is_inside_tree() and visible:
		_modal_tween = create_tween().set_parallel(true)
		if _modal_tween != null:
			_modal_tween.tween_property(self, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			if modal_panel != null:
				_modal_tween.tween_property(modal_panel, "scale", Vector2(0.97, 0.97), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_modal_tween.chain().tween_callback(func():
				visible = false
				modulate.a = 1.0
				if modal_panel != null:
					modal_panel.scale = Vector2.ONE
			)
		else:
			visible = false
			modulate.a = 1.0
			if modal_panel != null:
				modal_panel.scale = Vector2.ONE
	else:
		visible = false
		modulate.a = 1.0
		if modal_panel != null:
			modal_panel.scale = Vector2.ONE

# Compatibility aliases
func open_dialog() -> void:
	open_modal()

func close_dialog() -> void:
	close_modal()

func popup_centered(_size: Vector2 = Vector2.ZERO) -> void:
	open_modal()

func _apply_responsive_layout() -> void:
	if modal_panel == null:
		return
	ResponsiveManager.apply_modal_layout(self, modal_panel, modal_vbox, max_modal_width)
	if backdrop != null and backdrop.material is ShaderMaterial and size.x > 0.0:
		(backdrop.material as ShaderMaterial).set_shader_parameter("rect_width", size.x)

func _build_base_ui() -> void:
	# Screen-reading shaders share one copy of the screen, taken where the first of them draws
	# (usually a glass card on the screen below). Without fresh copies the frosted scrim would
	# blur a screen missing whatever was drawn after that card, and the dialog's glass would
	# show the screen without the scrim, or through the pause cover onto the puzzle.
	add_child(_screen_copy())

	# 1. Semi-transparent backdrop (Quiet Precision calm scrim)
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if dismissible_backdrop and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_canceled()
	)
	add_child(backdrop)

	ambient = AmbientBackdrop.new()
	ambient.visible = ambient_background
	ambient.mouse_filter = MOUSE_FILTER_STOP
	add_child(ambient)

	add_child(_screen_copy())

	# 2. Centering Container
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(PRESET_FULL_RECT)
	center_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center_container)

	# 3. Modal Panel: liquid glass over the frosted scrim
	var glass := GlassPanel.new()
	glass.corner_radius = 24.0
	glass.pad_h = 20
	glass.pad_v = 20
	glass.mouse_filter = MOUSE_FILTER_STOP
	modal_panel = glass
	center_container.add_child(modal_panel)

	modal_vbox = VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", ThemeManager.SPACE_MD)
	modal_panel.add_child(modal_vbox)

	# 4. Header (Title + Close X)
	header_hbox = HBoxContainer.new()
	header_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_child(header_hbox)

	title_label = Label.new()
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	title_label.theme_type_variation = "Header"
	title_label.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZE_HEADER)
	header_hbox.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = ""
	close_btn.tooltip_text = LocalizationManager.translate("BTN_CLOSE")
	close_btn.icon = ThemeManager.get_icon("x")
	close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.add_theme_constant_override("icon_max_width", 18)
	close_btn.theme_type_variation = "IconButton"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_canceled)
	close_btn.visible = show_close_button
	header_hbox.add_child(close_btn)

	# 5. Body Container
	body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	modal_vbox.add_child(body_vbox)

	message_label = Label.new()
	message_label.size_flags_horizontal = SIZE_EXPAND_FILL
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_label.theme_type_variation = "Body"
	message_label.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZE_BODY)
	message_label.visible = false
	body_vbox.add_child(message_label)

	# 6. Actions Container
	actions_vbox = VBoxContainer.new()
	actions_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	actions_vbox.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	modal_vbox.add_child(actions_vbox)

	primary_btn = Button.new()
	primary_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	primary_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	primary_btn.theme_type_variation = "PrimaryButton"
	primary_btn.add_theme_font_size_override("font_size", 15)
	primary_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	primary_btn.pressed.connect(_on_confirmed)
	actions_vbox.add_child(primary_btn)

	cancel_btn = Button.new()
	cancel_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	cancel_btn.theme_type_variation = "GhostButton"
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.pressed.connect(_on_canceled)
	actions_vbox.add_child(cancel_btn)

	_update_backdrop_material()
	_apply_base_theme_colors()

static func _screen_copy() -> BackBufferCopy:
	var copy := BackBufferCopy.new()
	# The whole screen: only full copies come with the blurred mip levels the glass samples
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	return copy

func _update_backdrop_material() -> void:
	if backdrop == null:
		return
	if blur_background:
		if backdrop.material == null:
			var shader_code: String = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius = 8.0;
uniform float rect_width = 390.0;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);

void fragment() {
	// Blur measured in dp, so it is as soft on a 2.6x phone as on a 1x desktop
	float px_scale = 1.0 / max(length(vec2(dFdx(UV.x), dFdy(UV.x))) * rect_width, 1e-4);
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, log2(max(blur_radius * px_scale, 1.0))).rgb;
	COLOR = vec4(mix(blurred, dim_color.rgb, dim_color.a), 1.0);
}
"""
			var sh := Shader.new()
			sh.code = shader_code
			var mat := ShaderMaterial.new()
			mat.shader = sh
			backdrop.material = mat
		_apply_base_theme_colors()
	else:
		backdrop.material = null
		_apply_base_theme_colors()

func _apply_base_theme_colors() -> void:
	var is_dark := ThemeManager.get_color("bg").get_luminance() < 0.5
	# Blurred scrims can be lighter than a flat one: the blur already pushes content back
	var dim_color: Color
	if blur_background:
		dim_color = Color(0, 0, 0, 0.42) if is_dark else Color(0.05, 0.08, 0.12, 0.30)
	else:
		dim_color = Color(0, 0, 0, 0.72) if is_dark else Color(0.05, 0.08, 0.12, 0.65)
	if backdrop != null:
		backdrop.color = dim_color
		if backdrop.material is ShaderMaterial:
			(backdrop.material as ShaderMaterial).set_shader_parameter("dim_color", dim_color)
	if title_label != null:
		title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
		title_label.horizontal_alignment = title_alignment
	if message_label != null:
		message_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if cancel_btn != null:
		cancel_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if close_btn != null:
		close_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func _on_base_theme_changed() -> void:
	_apply_base_theme_colors()

func _update_base_locale_texts() -> void:
	if primary_btn != null and primary_btn.text.is_empty():
		primary_btn.text = LocalizationManager.translate("BTN_START")
	if cancel_btn != null and cancel_btn.text.is_empty():
		cancel_btn.text = LocalizationManager.translate("BTN_CANCEL")
	if close_btn != null:
		close_btn.tooltip_text = LocalizationManager.translate("BTN_CLOSE")

func _on_confirmed() -> void:
	close_modal()
	confirmed.emit()

func _on_canceled() -> void:
	close_modal()
	canceled.emit()
