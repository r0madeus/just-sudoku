class_name DailyArchiveScreen
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")

## Daily Sudoku archive: a month calendar of the Dailies, which were solved on the day, solved
## later or started, and any day of the last year to play. Streaks stay what they were: only
## days solved on the day count (DailyManager.mark_archive_completed).

signal back_requested()
## A day of the calendar was picked, "YYYY-MM-DD"
signal day_requested(date_str: String)

## Smallest a day may get: seven of them and their gaps fit a 360 px wide phone
const DAY_SIZE: float = 40.0
const DAY_GAP: int = 3

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title: Label
var content: VBoxContainer

var streak_values: Array[Label] = []
var streak_captions: Array[Label] = []
var prev_btn: Button
var next_btn: Button
var month_label: Label
var weekday_labels: Array[Label] = []
var days_grid: GridContainer
## The day buttons of the month on show, by date
var day_buttons: Dictionary = {}
var legend_labels: Array[Label] = []
var legend_swatches: Array[Panel] = []
var note_label: Label

## Month on show
var year: int = 0
var month: int = 0
var _dirty: bool = true
var _started: bool = false

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var today := DailyManager.get_today_dict()
	year = today["year"]
	month = today["month"]

func _ready() -> void:
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)
	_started = true

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _dirty and _started:
		refresh()

func _apply_responsive_layout() -> void:
	if margin != null:
		ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH, true)

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	_apply_text_colors()
	if is_visible_in_tree():
		refresh()
	else:
		_dirty = true

## Opens on the month of today, as it is now
func show_current_month() -> void:
	var today := DailyManager.get_today_dict()
	year = today["year"]
	month = today["month"]
	refresh()

func _build_ui() -> void:
	var ambient_bg := AmbientBackdrop.new()
	ambient_bg.intensity = 0.7
	ambient_bg.color = ThemeManager.get_color("bg")
	bg = ambient_bg
	add_child(bg)

	margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header)

	back_btn = Button.new()
	back_btn.theme_type_variation = "IconButton"
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func(): back_requested.emit())
	header.add_child(back_btn)

	title = Label.new()
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "Header"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	header.add_child(spacer)

	root_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	_build_streaks()
	_build_calendar()
	_build_legend()
	_apply_text_colors()

func _build_streaks() -> void:
	var card := GlassPanel.card()
	content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	for i in 3:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.theme_type_variation = "Header"
		col.add_child(value)
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.theme_type_variation = "Caption"
		ThemeManager.set_font_size(caption, 12)
		col.add_child(caption)
		streak_values.append(value)
		streak_captions.append(caption)

func _build_calendar() -> void:
	var card := GlassPanel.card()
	content.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)
	prev_btn = _nav_button("chevron-left", -1)
	nav.add_child(prev_btn)
	month_label = Label.new()
	month_label.size_flags_horizontal = SIZE_EXPAND_FILL
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.theme_type_variation = "EditorialHeader"
	ThemeManager.set_font_size(month_label, 16)
	nav.add_child(month_label)
	next_btn = _nav_button("chevron-right", 1)
	nav.add_child(next_btn)

	days_grid = GridContainer.new()
	days_grid.columns = 7
	days_grid.add_theme_constant_override("h_separation", DAY_GAP)
	days_grid.add_theme_constant_override("v_separation", DAY_GAP)
	vbox.add_child(days_grid)
	for i in 7:
		var wd := Label.new()
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wd.size_flags_horizontal = SIZE_EXPAND_FILL
		wd.theme_type_variation = "Caption"
		ThemeManager.set_font_size(wd, 11)
		days_grid.add_child(wd)
		weekday_labels.append(wd)

func _nav_button(icon: String, step: int) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "IconButton"
	btn.icon = ThemeManager.get_icon(icon)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 18)
	btn.custom_minimum_size = Vector2(44, 44)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): change_month(step))
	return btn

func _build_legend() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 6)
	vbox.add_child(flow)
	for i in 3:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		flow.add_child(item)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var lbl := Label.new()
		lbl.theme_type_variation = "Caption"
		ThemeManager.set_font_size(lbl, 12)
		item.add_child(lbl)
		legend_swatches.append(swatch)
		legend_labels.append(lbl)
	note_label = Label.new()
	note_label.theme_type_variation = "Caption"
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeManager.set_font_size(note_label, 12)
	vbox.add_child(note_label)

func _apply_text_colors() -> void:
	var secondary := ThemeManager.get_color("text_secondary")
	for l in streak_captions + weekday_labels + legend_labels + [note_label]:
		if l != null:
			l.add_theme_color_override("font_color", secondary)

func _update_locale_texts() -> void:
	title.text = LocalizationManager.translate("ARCHIVE_TITLE")
	back_btn.tooltip_text = LocalizationManager.translate("BTN_BACK")
	prev_btn.tooltip_text = LocalizationManager.translate("ARCHIVE_PREV_MONTH")
	next_btn.tooltip_text = LocalizationManager.translate("ARCHIVE_NEXT_MONTH")
	for i in 7:
		weekday_labels[i].text = LocalizationManager.translate("WEEKDAY_SHORT_%d" % (i + 1))
	var captions := ["ARCHIVE_STREAK", "ARCHIVE_LONGEST", "ARCHIVE_SOLVED"]
	for i in 3:
		streak_captions[i].text = LocalizationManager.translate(captions[i])
	var legends := ["ARCHIVE_LEGEND_DONE", "ARCHIVE_LEGEND_LATE", "ARCHIVE_LEGEND_STARTED"]
	for i in 3:
		legend_labels[i].text = LocalizationManager.translate(legends[i])
	note_label.text = LocalizationManager.translate("ARCHIVE_NOTE")
	if is_visible_in_tree() and _started:
		refresh()
	else:
		_dirty = true

## The earliest month with a day in the archive
func _first_month() -> Dictionary:
	var first := DailyManager.parse_date(DailyManager.add_days(DailyManager.get_today_date_string(), -(DailyManager.ARCHIVE_DAYS - 1)))
	return {"year": first.year, "month": first.month}

func change_month(step: int) -> void:
	var m := month + step
	var y := year
	if m < 1:
		m = 12
		y -= 1
	elif m > 12:
		m = 1
		y += 1
	var first := _first_month()
	var today := DailyManager.get_today_dict()
	if y * 12 + m < first.year * 12 + first.month or y * 12 + m > today["year"] * 12 + today["month"]:
		return
	year = y
	month = m
	refresh()

static func days_in_month(y: int, m: int) -> int:
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31

func refresh() -> void:
	_dirty = false
	if days_grid == null:
		return
	var data := DailyManager.load_daily_data()
	streak_values[0].text = str(DailyManager.get_current_streak())
	streak_values[1].text = str(int(data.get("longest_streak", 0)))
	streak_values[2].text = str(DailyManager.solved_dates().size())
	month_label.text = LocalizationManager.format_month_year(year, month)
	var first := _first_month()
	var today := DailyManager.get_today_dict()
	prev_btn.disabled = year * 12 + month <= first.year * 12 + first.month
	next_btn.disabled = year * 12 + month >= today["year"] * 12 + today["month"]

	# Everything after the weekday names is this month's days
	for i in range(days_grid.get_child_count() - 1, 6, -1):
		var c := days_grid.get_child(i)
		days_grid.remove_child(c)
		c.queue_free()
	day_buttons.clear()

	# Monday-first weekday of the 1st: Time counts Sunday as 0
	var first_weekday: int = Time.get_datetime_dict_from_unix_time(
		Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 1, "hour": 12})).weekday
	for i in (first_weekday + 6) % 7:
		var blank := Control.new()
		blank.custom_minimum_size = Vector2(DAY_SIZE, DAY_SIZE)
		days_grid.add_child(blank)
	var today_str := DailyManager.get_today_date_string()
	for d in range(1, days_in_month(year, month) + 1):
		var date := DailyManager.get_date_string(year, month, d)
		var btn := _day_button(d, date, DailyManager.get_day_status(date, data), date == today_str)
		days_grid.add_child(btn)
		day_buttons[date] = btn

	_style_swatch(legend_swatches[0], DailyManager.DayStatus.DONE)
	_style_swatch(legend_swatches[1], DailyManager.DayStatus.DONE_LATE)
	_style_swatch(legend_swatches[2], DailyManager.DayStatus.IN_PROGRESS)

func _day_button(d: int, date: String, status: int, is_today: bool) -> Button:
	var btn := Button.new()
	btn.text = str(d)
	btn.custom_minimum_size = Vector2(DAY_SIZE, DAY_SIZE)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.disabled = not DailyManager.is_in_archive(date)
	ThemeManager.set_font_size(btn, 14)
	var font := ThemeManager.get_font_inter()
	if font != null:
		btn.add_theme_font_override("font", font)
	btn.set_meta("status", status)
	var parts := date.split("-")
	btn.tooltip_text = LocalizationManager.format_date(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())

	var sb := _status_box(status)
	if is_today:
		sb.set_border_width_all(2)
		sb.border_color = ThemeManager.get_color("border_focus") if status != DailyManager.DayStatus.DONE else ThemeManager.get_color("text_given")
	var text_col: Color = ThemeManager.get_color("text_given")
	if status == DailyManager.DayStatus.DONE:
		text_col = ThemeManager.get_color("accent_text")
	elif status == DailyManager.DayStatus.DONE_LATE:
		text_col = ThemeManager.get_color("accent")
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	var dis := sb.duplicate() as StyleBoxFlat
	dis.bg_color = Color.TRANSPARENT
	btn.add_theme_stylebox_override("disabled", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, text_col)
	btn.add_theme_color_override("font_disabled_color", ThemeManager.get_color("button_text_disabled"))
	btn.pressed.connect(func(): day_requested.emit(date))
	return btn

## Solved on the day: filled; solved later: outlined; started: a light fill; otherwise plain
func _status_box(status: int) -> StyleBoxFlat:
	var accent: Color = ThemeManager.get_color("accent")
	match status:
		DailyManager.DayStatus.DONE:
			return ThemeManager.create_flat_stylebox(accent, ThemeManager.RADIUS_SM, 0, Color.TRANSPARENT, 0, 0)
		DailyManager.DayStatus.DONE_LATE:
			return ThemeManager.create_flat_stylebox(Color(accent, 0.12), ThemeManager.RADIUS_SM, 2, accent, 0, 0)
		DailyManager.DayStatus.IN_PROGRESS:
			return ThemeManager.create_flat_stylebox(ThemeManager.get_color("cell_same_num"), ThemeManager.RADIUS_SM, 1, Color(accent, 0.35), 0, 0)
	return ThemeManager.create_flat_stylebox(Color.TRANSPARENT, ThemeManager.RADIUS_SM, 0, Color.TRANSPARENT, 0, 0)

func _style_swatch(swatch: Panel, status: int) -> void:
	var sb := _status_box(status)
	sb.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", sb)
