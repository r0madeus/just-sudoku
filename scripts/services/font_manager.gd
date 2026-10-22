class_name FontManager
extends Node

## Typography and Font Family Manager (GDD §39, §43)
## Manages embedded font families with SystemFont fallbacks and dynamic hot-swapping.

const FONT_MODERN_SANS: String = "Modern Sans"
const FONT_ROUNDED_SANS: String = "Rounded Sans"
const FONT_CLASSIC_SERIF: String = "Classic Serif"

const FONT_FAMILIES: Array[String] = [
	FONT_MODERN_SANS,
	FONT_ROUNDED_SANS,
	FONT_CLASSIC_SERIF
]

static var current_font_name: String = FONT_MODERN_SANS
static var _font_cache: Dictionary = {}
static var _listeners: Array[Callable] = []

static func _static_init() -> void:
	_init_font_cache()

## Bundled with the game, so each family looks the same on every device. The system font lists
## used before named fonts Android does not have (no rounded or serif one among them): there
## "Rounded" showed Roboto and "Classic" whatever serif the phone had.
const FONT_PATH_NUNITO: String = "res://assets/fonts/Nunito[wght].ttf"

static func _init_font_cache() -> void:
	# 1. Modern Sans: Inter, clean geometric sans-serif
	_font_cache[FONT_MODERN_SANS] = _bundled(ThemeManager.FONT_PATH_INTER, ["Inter", "Roboto", "sans-serif"])
	# 2. Rounded Sans: Nunito, soft and friendly
	_font_cache[FONT_ROUNDED_SANS] = _bundled(FONT_PATH_NUNITO, ["Nunito", "Quicksand", "sans-serif"])
	# 3. Classic Serif: Source Serif 4, book style
	_font_cache[FONT_CLASSIC_SERIF] = _bundled(ThemeManager.FONT_PATH_SERIF_REGULAR, ["Noto Serif", "Georgia", "serif"])

## The bundled font, with the system's font of that kind behind it for any rare symbol it lacks
## (and in its place if the file were missing)
static func _bundled(path: String, system_names: Array[String]) -> Font:
	var system := SystemFont.new()
	system.font_names = PackedStringArray(system_names)
	var font: Font = load(path) as Font if ResourceLoader.exists(path) else null
	if font == null:
		return system
	# Variable fonts start at their axis default, which for Nunito is ExtraLight (200): pin Regular
	var regular := FontVariation.new()
	regular.base_font = font
	var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("weight")
	if font.get_supported_variation_list().has(weight_tag):
		regular.variation_opentype = {weight_tag: 400}
	regular.fallbacks = [system]
	return regular

static func add_listener(cb: Callable) -> void:
	if not _listeners.has(cb):
		_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _listeners:
		if cb.is_valid():
			cb.call()

static func get_font(family_name: String) -> Font:
	if _font_cache.has(family_name):
		return _font_cache[family_name]
	if _font_cache.has(FONT_MODERN_SANS):
		return _font_cache[FONT_MODERN_SANS]
	# Fallback if cache not initialized yet
	_init_font_cache()
	return _font_cache.get(FONT_MODERN_SANS, null)

static func get_current_font() -> Font:
	return get_font(current_font_name)

static func set_font(family_name: String) -> bool:
	if not FONT_FAMILIES.has(family_name):
		return false
	if current_font_name == family_name:
		return true

	current_font_name = family_name
	_notify_listeners()
	return true

static func get_family_display_name(family_name: String) -> String:
	match family_name:
		FONT_MODERN_SANS: return "Modern Sans"
		FONT_ROUNDED_SANS: return "Rounded Sans"
		FONT_CLASSIC_SERIF: return "Classic Serif"
		_: return family_name

static func get_bundled_inter() -> Font:
	return ThemeManager.get_font_inter()

static func get_bundled_serif_regular() -> Font:
	return ThemeManager.get_font_serif_regular()

static func get_bundled_serif_semibold() -> Font:
	return ThemeManager.get_font_serif_semibold()

static func get_bundled_mono() -> Font:
	return ThemeManager.get_font_mono()

