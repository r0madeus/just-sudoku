class_name GlassPanel
extends PanelContainer

## Liquid-glass surface: blurs whatever is drawn behind it, bends the backdrop slightly at the
## rim (lens effect), tints it with the theme surface colour and adds a lit rim (light from the
## top-left) plus a soft drop shadow. Content is added as ordinary children.
##
## It only reads convincingly over something that varies, so pair it with AmbientBackdrop or
## real content, and keep it off surfaces that must stay opaque (the Sudoku grid, the numpad).

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

const SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(300.0, 200.0);
uniform float radius = 22.0;
uniform float blur_lod = 2.5;
uniform vec3 tint_color : source_color = vec3(0.1);
uniform float tint_amount = 0.6;
uniform float refraction = 7.0;
uniform float edge_width = 16.0;
uniform float saturation = 1.15;
uniform vec3 rim_light : source_color = vec3(1.0);
uniform float rim_light_amount = 0.4;
uniform vec3 rim_shade : source_color = vec3(0.0);
uniform float rim_shade_amount = 0.2;
uniform float rim_width = 1.4;
uniform float sheen = 0.05;

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float d = sd_round_box(p, rect_size * 0.5, radius);
	float mask = 1.0 - smoothstep(-0.75, 0.25, d);

	// Lens: near the rim the backdrop is sampled from further inside, so it appears bent
	float edge = clamp(1.0 + d / edge_width, 0.0, 1.0);
	vec2 dir = normalize(p + vec2(0.0001));
	vec2 uv = SCREEN_UV - dir * edge * edge * refraction * SCREEN_PIXEL_SIZE;
	vec3 col = textureLod(screen_tex, uv, blur_lod).rgb;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, saturation);
	col = mix(col, tint_color, tint_amount);

	// Rim lit from the top-left, shaded on the opposite side
	vec2 n = normalize(vec2(dFdx(d), dFdy(d)) + vec2(0.0001));
	float facing = dot(n, normalize(vec2(-0.6, -0.8)));
	float band = 1.0 - clamp(-d / rim_width, 0.0, 1.0);
	col += rim_light * band * max(facing, 0.0) * rim_light_amount;
	col = mix(col, rim_shade, band * max(-facing, 0.0) * rim_shade_amount);
	col += rim_light * edge * edge * 0.035;
	col += rim_light * (1.0 - UV.y) * (1.0 - UV.y) * sheen;

	col += (hash(FRAGCOORD.xy) - 0.5) * (2.0 / 255.0);
	COLOR = vec4(col, mask);
}
"""

static var _shader: Shader = null

## Corner radius in pixels
var corner_radius: float = 22.0 :
	set(v):
		corner_radius = v
		_refresh()
## True: modal-level surface (stronger tint, deeper shadow); false: light chrome like the dock
var elevated: bool = true :
	set(v):
		elevated = v
		_refresh()
var pad_h: int = 18 :
	set(v):
		pad_h = v
		_refresh()
var pad_v: int = 18 :
	set(v):
		pad_v = v
		_refresh()
var shadow_size: int = 22 :
	set(v):
		shadow_size = v
		_refresh()
var shadow_offset: Vector2 = Vector2(0, 8) :
	set(v):
		shadow_offset = v
		_refresh()

var glass_rect: ColorRect
var _material: ShaderMaterial

func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = _shader

	glass_rect = ColorRect.new()
	glass_rect.material = _material
	glass_rect.mouse_filter = MOUSE_FILTER_IGNORE
	glass_rect.show_behind_parent = true
	glass_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(glass_rect)
	_refresh()

func _enter_tree() -> void:
	ThemeManager.add_listener(_refresh)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_refresh)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_geometry()
	elif what == NOTIFICATION_SORT_CHILDREN and glass_rect != null:
		# PanelContainer squeezes every child into its padded content rect; the glass has to
		# cover the whole panel, padding included
		fit_child_in_rect(glass_rect, Rect2(Vector2.ZERO, size))

func _update_geometry() -> void:
	if _material == null:
		return
	var has_size: bool = size.x > 0.0 and size.y > 0.0
	_material.set_shader_parameter("rect_size", size if has_size else custom_minimum_size)
	_material.set_shader_parameter("radius", minf(corner_radius, minf(size.x, size.y) * 0.5) if has_size else corner_radius)

func _refresh() -> void:
	if _material == null:
		return
	var is_dark: bool = ThemeManager.get_color("bg").get_luminance() < 0.5
	var surface: Color = ThemeManager.get_color("surface_elevated" if elevated else "surface")

	# Frosted glass is lighter than what is behind it, so light themes tint toward white
	if not is_dark:
		surface = surface.lerp(Color.WHITE, 0.6)
	_material.set_shader_parameter("tint_color", Color(surface.r, surface.g, surface.b))
	_material.set_shader_parameter("tint_amount", (0.74 if elevated else 0.58) if is_dark else (0.82 if elevated else 0.64))
	_material.set_shader_parameter("blur_lod", 3.0 if elevated else 2.5)
	_material.set_shader_parameter("rim_light", Color.WHITE)
	_material.set_shader_parameter("rim_light_amount", 0.34 if is_dark else 0.95)
	var shade: Color = Color.BLACK if is_dark else ThemeManager.get_color("border_subtle").darkened(0.15)
	_material.set_shader_parameter("rim_shade", Color(shade.r, shade.g, shade.b))
	_material.set_shader_parameter("rim_shade_amount", 0.30 if is_dark else 0.22)
	_material.set_shader_parameter("sheen", 0.04 if is_dark else 0.10)
	_update_geometry()

	# Transparent panel style: only supplies the shadow and the content margins
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(int(corner_radius))
	sb.corner_detail = 16
	sb.shadow_color = Color(0, 0, 0, 0.42) if is_dark else Color(0.08, 0.12, 0.20, 0.16)
	sb.shadow_size = shadow_size
	sb.shadow_offset = shadow_offset
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	add_theme_stylebox_override("panel", sb)
