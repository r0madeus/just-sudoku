class_name DailyCalendar
extends Control

## The daily sudoku's calendar: a small page with the month on its coloured header and today's
## day number on it, drawn instead of a stock icon so it can show the real date. When the menu
## comes up the page turns (the day number flips in); a press makes it dip; when today's puzzle
## is solved a tick is drawn on it. With animations off it just shows its final state.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

const SIDE: float = 32.0
const CORNER: float = 8.0
const HEADER_H: float = 10.0
const FLIP_TIME: float = 0.42
const POP_TIME: float = 0.22
const TICK_TIME: float = 0.3

const MONTHS_EN: Array[String] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const MONTHS_TR: Array[String] = ["OCA", "ŞUB", "MAR", "NİS", "MAY", "HAZ", "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA"]

var day: int = 1
var month: int = 1
var done: bool = false

## 1 = the day number is fully shown; 0 = edge-on (the page is turning)
var flip_t: float = 1.0 :
	set(v):
		flip_t = v
		queue_redraw()
## 1 = at rest; dips below on a press
var pop_scale: float = 1.0 :
	set(v):
		pop_scale = v
		queue_redraw()
## 0..1 progress of the tick
var tick_t: float = 0.0 :
	set(v):
		tick_t = v
		queue_redraw()

var _flip_tween: Tween = null
var _pop_tween: Tween = null
var _tick_tween: Tween = null

func _init() -> void:
	custom_minimum_size = Vector2(SIDE, SIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_date(1, 1)

func set_date(new_month: int, new_day: int) -> void:
	month = clampi(new_month, 1, 12)
	day = clampi(new_day, 1, 31)
	queue_redraw()

## Today's date, and whether today's puzzle is solved (the tick animates in when it becomes so)
func show_today(date: Dictionary, solved: bool) -> void:
	set_date(int(date.get("month", 1)), int(date.get("day", 1)))
	if solved == done:
		return
	done = solved
	if _tick_tween != null:
		_tick_tween.kill()
	if not done or not AppSettings.animations_enabled or not is_inside_tree():
		tick_t = 1.0 if done else 0.0
		return
	tick_t = 0.0
	_tick_tween = create_tween()
	_tick_tween.tween_property(self, "tick_t", 1.0, TICK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The page turns: the day number squeezes to an edge and opens again on the (new) date
func play_flip() -> void:
	if _flip_tween != null:
		_flip_tween.kill()
	if not AppSettings.animations_enabled:
		flip_t = 1.0
		return
	flip_t = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "flip_t", 1.0, FLIP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A press: the page dips and comes back
func play_pop() -> void:
	if _pop_tween != null:
		_pop_tween.kill()
	if not AppSettings.animations_enabled:
		pop_scale = 1.0
		return
	pop_scale = 0.86
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "pop_scale", 1.0, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _enter_tree() -> void:
	ThemeManager.add_listener(queue_redraw)

func _exit_tree() -> void:
	ThemeManager.remove_listener(queue_redraw)

func _draw() -> void:
	var centre := size * 0.5
	var side := minf(minf(size.x, size.y), SIDE) * pop_scale
	var page := Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side))
	var accent: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var paper: Color = ThemeManager.get_color("surface_elevated")
	var ink: Color = ThemeManager.get_color("text_given")
	var edge: Color = ThemeManager.get_color("border_subtle")

	# The paper, then the header over its top, both with the page's rounded corners
	var body := StyleBoxFlat.new()
	body.bg_color = paper
	body.set_corner_radius_all(int(CORNER))
	body.border_color = edge
	body.set_border_width_all(1)
	body.draw(get_canvas_item(), page)
	var head := StyleBoxFlat.new()
	head.bg_color = accent
	head.corner_radius_top_left = int(CORNER)
	head.corner_radius_top_right = int(CORNER)
	head.draw(get_canvas_item(), Rect2(page.position, Vector2(side, HEADER_H * pop_scale)))

	var font := get_theme_default_font()
	var months := MONTHS_TR if LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR else MONTHS_EN
	var month_size := 8
	var month_text: String = months[month - 1]
	var mw := font.get_string_size(month_text, HORIZONTAL_ALIGNMENT_LEFT, -1, month_size).x
	draw_string(font, Vector2(centre.x - mw * 0.5, page.position.y + HEADER_H * pop_scale - 2.5), month_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, month_size, Color.WHITE)

	# The day number, squeezed vertically about its middle while the page turns
	var day_size := 15
	var day_text := str(day)
	var dw := font.get_string_size(day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, day_size).x
	var area_mid := page.position.y + HEADER_H * pop_scale + (side - HEADER_H * pop_scale) * 0.5
	var squeeze := clampf(flip_t, 0.02, 1.4)
	draw_set_transform(Vector2(centre.x, area_mid), 0.0, Vector2(1.0, squeeze))
	var shown := ink
	shown.a = clampf(flip_t * 1.6, 0.0, 1.0)
	draw_string(font, Vector2(-dw * 0.5, day_size * 0.36), day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, day_size, shown)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Solved: a green disc with a tick on the lower right corner, drawn in as tick_t grows
	if tick_t > 0.0:
		var good: Color = ThemeManager.get_color("success", Color(0.2, 0.7, 0.4))
		var c := page.end - Vector2(3, 3)
		var r := 7.5 * tick_t
		draw_circle(c, r + 1.5 * tick_t, paper)
		draw_circle(c, r, good)
		if tick_t > 0.5:
			var k := (tick_t - 0.5) * 2.0
			var a := c + Vector2(-3.0, 0.2)
			var b := c + Vector2(-0.8, 2.4)
			var d := c + Vector2(3.2, -2.4)
			draw_line(a, a.lerp(b, minf(k * 2.0, 1.0)), Color.WHITE, 1.6, true)
			if k > 0.5:
				draw_line(b, b.lerp(d, (k - 0.5) * 2.0), Color.WHITE, 1.6, true)
