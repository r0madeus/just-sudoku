class_name AmbientBackdrop
extends ColorRect

## Page background with a few large, soft colour glows in the theme accent hue. It gives glass
## surfaces something to blur and refract. `color` is the flat base colour (so it is a drop-in
## for the plain ColorRect it replaces); `intensity` scales the glows (0 = flat background).

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

const SHADER_CODE: String = """
shader_type canvas_item;

uniform vec3 glow_a : source_color = vec3(0.15, 0.39, 0.92);
uniform vec3 glow_b : source_color = vec3(0.10, 0.60, 0.85);
uniform vec3 glow_c : source_color = vec3(0.55, 0.30, 0.90);
uniform float strength = 0.25;
uniform float aspect = 0.5625;

float glow(vec2 uv, vec2 center, float radius) {
	vec2 d = (uv - center) / radius;
	return exp(-dot(d, d) * 1.6);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = vec2(UV.x * aspect, UV.y);
	vec3 base = COLOR.rgb;
	float a = glow(uv, vec2(0.10 * aspect, 0.08), 0.62);
	float b = glow(uv, vec2(0.95 * aspect, 0.55), 0.55);
	float c = glow(uv, vec2(0.30 * aspect, 0.98), 0.60);
	vec3 col = base;
	col = mix(col, glow_a, clamp(a * strength, 0.0, 1.0));
	col = mix(col, glow_b, clamp(b * strength * 0.85, 0.0, 1.0));
	col = mix(col, glow_c, clamp(c * strength * 0.75, 0.0, 1.0));
	col += (hash(FRAGCOORD.xy) - 0.5) * (2.0 / 255.0);
	COLOR = vec4(col, 1.0);
}
"""

static var _shader: Shader = null

var intensity: float = 1.0 :
	set(v):
		intensity = v
		_refresh()

var _material: ShaderMaterial

func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = _shader
	material = _material
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_refresh()

func _enter_tree() -> void:
	ThemeManager.add_listener(_on_theme_changed)
	_on_theme_changed()

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.y > 0.0 and _material != null:
		_material.set_shader_parameter("aspect", size.x / size.y)

func _on_theme_changed() -> void:
	color = ThemeManager.get_color("bg")
	_refresh()

func _refresh() -> void:
	if _material == null:
		return
	var accent: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var is_dark: bool = ThemeManager.get_color("bg").get_luminance() < 0.5
	var amoled: bool = ThemeManager.current_theme_name == ThemeManager.THEME_AMOLED

	var hue: float = accent.h
	var sat: float = clampf(accent.s, 0.35, 0.85)
	var val: float = 0.78 if is_dark else 0.95
	_material.set_shader_parameter("glow_a", Color.from_hsv(hue, sat, val))
	_material.set_shader_parameter("glow_b", Color.from_hsv(fposmod(hue - 0.08, 1.0), sat * 0.9, val))
	_material.set_shader_parameter("glow_c", Color.from_hsv(fposmod(hue + 0.10, 1.0), sat * 0.85, val))
	var base_strength: float = 0.20 if is_dark else 0.26
	if amoled:
		base_strength = 0.12
	_material.set_shader_parameter("strength", base_strength * intensity)
