class_name StatisticsScreen
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")

## Performance and Progression Statistics Screen (GDD §33, §44)
## Swiss Editorial layout: High data-density typographic callouts and hairline dividers,
## completely eliminating bulky card-inside-card dashboard containers.

signal back_requested()

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title: Label
var stats_vbox: VBoxContainer
var _stats_dirty: bool = true

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree() and _stats_dirty:
			refresh_stats()

func _apply_responsive_layout() -> void:
	if margin == null:
		return
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH)

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if is_visible_in_tree():
		refresh_stats()
	else:
		_stats_dirty = true

func _build_ui() -> void:
	# Soft accent glows behind the content, so glass cards have something to refract
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

	# --- 1. Editorial Header ---
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header)

	back_btn = Button.new()
	back_btn.text = ""
	back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
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
	header.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	header.add_child(spacer)

	var header_sep := HSeparator.new()
	root_vbox.add_child(header_sep)

	# --- 2. Scrollable Data Canvas ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)

	stats_vbox = VBoxContainer.new()
	stats_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	stats_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(stats_vbox)

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if title != null:
		title.text = LocalizationManager.translate("STATS_TITLE")
	if is_visible_in_tree():
		refresh_stats()
	else:
		_stats_dirty = true

func refresh_stats() -> void:
	_stats_dirty = false
	if stats_vbox == null:
		return
	for c in stats_vbox.get_children():
		c.queue_free()

	var details := StatisticsManager.get_detailed_statistics()
	var summary: Dictionary = details.get("summary", {})
	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)
	var completed_count: int = int(summary.get("completed_games", 0))

	var is_dark := ThemeManager.is_dark_theme()
	var surface_col := ThemeManager.get_color("surface")
	var text_given := ThemeManager.get_color("text_given")
	var text_sec := ThemeManager.get_color("text_secondary")
	var accent_col := ThemeManager.get_color("accent")

	# -------------------------------------------------------------------------
	# 1. Section 1: Overview Callouts (Swiss Editorial, 4 Big Metrics)
	# -------------------------------------------------------------------------
	var hero_card := GlassPanel.card(20.0, 18, 14)
	stats_vbox.add_child(hero_card)
	var hero_vbox := VBoxContainer.new()
	hero_vbox.add_theme_constant_override("separation", 12)
	hero_card.add_child(hero_vbox)

	var hero_header_row := HBoxContainer.new()
	hero_vbox.add_child(hero_header_row)

	var hero_title := Label.new()
	hero_title.text = LocalizationManager.upper(LocalizationManager.translate("STAT_ALL_TIME"))
	hero_title.theme_type_variation = "Caption"
	hero_title.add_theme_font_size_override("font_size", 11)
	hero_title.add_theme_color_override("font_color", text_sec)
	hero_header_row.add_child(hero_title)

	var comp_rate: float = float(summary.get("completion_rate", 100.0 if completed_count > 0 else 0.0))

	# Row 1: Games Completed & Completion Rate
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 16)
	hero_vbox.add_child(row1)

	_add_stat_callout(row1, LocalizationManager.format_number(completed_count), LocalizationManager.translate("STAT_COMPLETED_GAMES"), "check")
	_add_stat_callout(row1, "%d%%" % int(comp_rate), LocalizationManager.translate("STAT_COMPLETION_RATE"), "chart-column-big")

	# Row 2: Average Time & Best Score
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	hero_vbox.add_child(row2)

	var avg_time_str := GameTimer.format_seconds(summary.get("average_time", 0.0))
	_add_stat_callout(row2, avg_time_str, LocalizationManager.translate("STAT_AVG_TIME"), "clock-3", true)
	_add_stat_callout(row2, "%d" % summary.get("best_score", 0), LocalizationManager.translate("STAT_BEST_SCORE"), "")

	# Hairline divider
	var div1 := HSeparator.new()
	stats_vbox.add_child(div1)

	# -------------------------------------------------------------------------
	# 2. Section 2: Daily Challenge Streaks (Restrained Liquid Glass Panel)
	# -------------------------------------------------------------------------
	var streak_panel := GlassPanel.card(20.0, 18, 14)
	stats_vbox.add_child(streak_panel)

	var streak_vbox := VBoxContainer.new()
	streak_vbox.add_theme_constant_override("separation", 10)
	streak_panel.add_child(streak_vbox)

	var streak_header := HBoxContainer.new()
	streak_header.alignment = BoxContainer.ALIGNMENT_BEGIN
	streak_header.add_theme_constant_override("separation", 8)
	streak_vbox.add_child(streak_header)

	var streak_icon := TextureRect.new()
	streak_icon.texture = ThemeManager.get_icon("clock-3")
	streak_icon.custom_minimum_size = Vector2(16, 16)
	streak_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	streak_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	streak_icon.modulate = accent_col
	streak_header.add_child(streak_icon)

	var streak_title := Label.new()
	streak_title.text = LocalizationManager.upper(LocalizationManager.translate("STAT_DAILY_STREAK_BANNER"))
	streak_title.theme_type_variation = "Caption"
	streak_title.add_theme_font_size_override("font_size", 11)
	streak_title.add_theme_color_override("font_color", text_sec)
	streak_header.add_child(streak_title)

	var streak_metrics_row := HBoxContainer.new()
	streak_metrics_row.alignment = BoxContainer.ALIGNMENT_CENTER
	streak_vbox.add_child(streak_metrics_row)

	var cur_streak: int = int(summary.get("current_streak", 0))
	var long_streak: int = int(details.get("longest_streak", 0))

	_add_stat_callout(
		streak_metrics_row,
		LocalizationManager.format_days(cur_streak),
		LocalizationManager.translate("STAT_CURRENT_STREAK"),
		"",
		false
	)
	_add_stat_callout(
		streak_metrics_row,
		LocalizationManager.format_days(long_streak),
		LocalizationManager.translate("STAT_LONGEST_STREAK"),
		"",
		false
	)

	var streak_desc := Label.new()
	streak_desc.text = LocalizationManager.translate("STAT_DAILY_STREAK_DESC")
	streak_desc.theme_type_variation = "Caption"
	streak_desc.add_theme_font_size_override("font_size", 11)
	streak_desc.add_theme_color_override("font_color", text_sec)
	streak_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	streak_vbox.add_child(streak_desc)

	var div2 := HSeparator.new()
	stats_vbox.add_child(div2)

	# -------------------------------------------------------------------------
	# 3. Section 3: Performance by Difficulty (Swiss Hairline Data Grid)
	# -------------------------------------------------------------------------
	var diff_section_vbox := VBoxContainer.new()
	diff_section_vbox.add_theme_constant_override("separation", 14)
	stats_vbox.add_child(diff_section_vbox)

	var diff_title := Label.new()
	diff_title.text = LocalizationManager.upper(LocalizationManager.translate("STAT_DIFFICULTIES"))
	diff_title.theme_type_variation = "Caption"
	diff_title.add_theme_font_size_override("font_size", 11)
	diff_title.add_theme_color_override("font_color", text_sec)
	diff_section_vbox.add_child(diff_title)

	var diff_dict: Dictionary = details.get("difficulties", {})

	for d_name in [DifficultyAnalyzer.LEVEL_EASY, DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD, DifficultyAnalyzer.LEVEL_EXPERT]:
		if not diff_dict.has(d_name):
			continue
		var entry: Dictionary = diff_dict[d_name]
		var count: int = int(entry.get("count", 0))

		var item_vbox := VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 8)
		diff_section_vbox.add_child(item_vbox)

		# Header: Difficulty name & completed count
		var header_hbox := HBoxContainer.new()
		header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_vbox.add_child(header_hbox)

		var d_lbl := Label.new()
		d_lbl.text = LocalizationManager.get_difficulty_name(d_name)
		d_lbl.theme_type_variation = "Subheader"
		d_lbl.add_theme_font_size_override("font_size", 15)
		d_lbl.add_theme_color_override("font_color", text_given)
		header_hbox.add_child(d_lbl)

		var count_lbl := Label.new()
		count_lbl.text = LocalizationManager.translate("STAT_GAMES_COUNT") % count
		count_lbl.theme_type_variation = "Caption"
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", text_sec)
		count_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_hbox.add_child(count_lbl)

		if count > 0:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.size_flags_horizontal = SIZE_EXPAND_FILL
			grid.add_theme_constant_override("h_separation", 24)
			grid.add_theme_constant_override("v_separation", 8)
			item_vbox.add_child(grid)

			_add_key_value(grid, LocalizationManager.translate("STAT_BEST_TIME_LABEL"), GameTimer.format_seconds(entry.get("best_time", 0.0)), true)
			_add_key_value(grid, LocalizationManager.translate("STAT_AVG_TIME_LABEL"), GameTimer.format_seconds(entry.get("avg_time", 0.0)), true)
			_add_key_value(grid, LocalizationManager.translate("STAT_BEST_SCORE_LABEL"), "%d" % entry.get("best_score", 0), false)
			_add_key_value(grid, LocalizationManager.translate("STAT_AVG_MISTAKES_LABEL"), "%.1f" % entry.get("avg_mistakes", 0.0), false)
			_add_key_value(grid, LocalizationManager.translate("STAT_AVG_HINTS_LABEL"), "%.1f" % entry.get("avg_hints", 0.0), false)
		else:
			var empty_diff := Label.new()
			empty_diff.text = LocalizationManager.translate("HISTORY_EMPTY")
			empty_diff.theme_type_variation = "Caption"
			empty_diff.add_theme_font_size_override("font_size", 12)
			empty_diff.add_theme_color_override("font_color", text_sec)
			item_vbox.add_child(empty_diff)

		var diff_sep := HSeparator.new()
		diff_section_vbox.add_child(diff_sep)

func _add_stat_callout(parent: Control, val_text: String, label_text: String, icon_name: String = "", is_mono: bool = false) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)

	var val_row := HBoxContainer.new()
	val_row.alignment = BoxContainer.ALIGNMENT_CENTER
	val_row.add_theme_constant_override("separation", 6)
	col.add_child(val_row)

	if not icon_name.is_empty():
		var ico := TextureRect.new()
		ico.texture = ThemeManager.get_icon(icon_name)
		ico.custom_minimum_size = Vector2(16, 16)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.modulate = ThemeManager.get_color("text_secondary")
		val_row.add_child(ico)

	var val_lbl := Label.new()
	val_lbl.text = val_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.theme_type_variation = "StatValue"
	val_lbl.add_theme_font_size_override("font_size", 24)
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if is_mono:
		var mono_font := ThemeManager.get_font_mono()
		if mono_font != null:
			val_lbl.add_theme_font_override("font", mono_font)
	val_row.add_child(val_lbl)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.theme_type_variation = "Caption"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_lbl)

func _add_key_value(parent: Control, label_text: String, val_text: String, is_mono: bool = false) -> void:
	var item_vbox := VBoxContainer.new()
	item_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	item_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(item_vbox)

	var k_lbl := Label.new()
	k_lbl.text = LocalizationManager.upper(label_text)
	k_lbl.theme_type_variation = "Caption"
	k_lbl.add_theme_font_size_override("font_size", 10)
	k_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	item_vbox.add_child(k_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_text
	v_lbl.theme_type_variation = "Body"
	v_lbl.add_theme_font_size_override("font_size", 14)
	v_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if is_mono:
		var mono_font := ThemeManager.get_font_mono()
		if mono_font != null:
			v_lbl.add_theme_font_override("font", mono_font)
	item_vbox.add_child(v_lbl)
