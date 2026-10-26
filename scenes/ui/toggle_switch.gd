class_name ToggleSwitch
extends CheckBox

## An on/off switch: a pill with a round knob that slides across when it is turned, the track
## filling with the accent colour. It is a CheckBox underneath (same `button_pressed`, `toggled`
## and `disabled`), so the Settings rows and everything that reads them work as before.
## With animations off the knob moves at once.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

const TRACK_WIDTH: float = 46.0
const TRACK_HEIGHT: float = 28.0
## Space between the track's edge and the knob
const KNOB_GAP: float = 2.0
const SLIDE_TIME: float = 0.2

## 0 = off, 1 = on; between the two while the knob moves
var position_t: float = 0.0 :
	set(v):
		position_t = v
		queue_redraw()

var _tween: Tween = null

func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The CheckBox's own box and styles are not wanted: this draws everything itself
	var none := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, none)
	var blank := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "radio_checked", "radio_unchecked"]:
		add_theme_icon_override(icon, blank)
	add_theme_constant_override("h_separation", 0)
	toggled.connect(_on_toggled)

func _enter_tree() -> void:
	ThemeManager.add_listener(queue_redraw)
	position_t = 1.0 if button_pressed else 0.0

func _exit_tree() -> void:
	ThemeManager.remove_listener(queue_redraw)
	if _tween != null:
		_tween.kill()

func _on_toggled(on: bool) -> void:
	var target: float = 1.0 if on else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_inside_tree() or not is_visible_in_tree() or not AppSettings.animations_enabled:
		position_t = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position_t", target, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _get_minimum_size() -> Vector2:
	return Vector2(TRACK_WIDTH, TRACK_HEIGHT)

func _draw() -> void:
	var track := Rect2((size.x - TRACK_WIDTH) * 0.5, (size.y - TRACK_HEIGHT) * 0.5, TRACK_WIDTH, TRACK_HEIGHT)
	var off_colour: Color = Color(ThemeManager.get_color("text_secondary"), 0.32)
	var on_colour: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var fill: Color = off_colour.lerp(on_colour, position_t)
	if disabled:
		fill.a *= 0.5
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = fill
	track_style.set_corner_radius_all(int(TRACK_HEIGHT))
	track_style.anti_aliasing = true
	track_style.anti_aliasing_size = ThemeManager.edge_aa()
	draw_style_box(track_style, track)

	var knob_side: float = TRACK_HEIGHT - 2.0 * KNOB_GAP
	var travel: float = TRACK_WIDTH - 2.0 * KNOB_GAP - knob_side
	var knob := Rect2(track.position.x + KNOB_GAP + travel * position_t, track.position.y + KNOB_GAP, knob_side, knob_side)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.5 if disabled else 1.0)
	knob_style.set_corner_radius_all(int(knob_side))
	knob_style.anti_aliasing = true
	knob_style.anti_aliasing_size = ThemeManager.edge_aa()
	knob_style.shadow_color = Color(0, 0, 0, 0.0 if disabled else 0.28)
	knob_style.shadow_size = 3
	knob_style.shadow_offset = Vector2(0, 1)
	draw_style_box(knob_style, knob)
