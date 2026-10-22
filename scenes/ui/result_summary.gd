class_name ResultSummary
extends VBoxContainer

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const AchievementManager = preload("res://scripts/data/achievement_manager.gd")

## Body of the "Puzzle Solved" dialog: the score large, time / mistakes / hints below it, and
## up to two lines that put the solve in context (record, average, Daily streak), and any
## achievement this game earned.

## Within this many seconds of the average counts as "right on your average"
const AVERAGE_TOLERANCE: float = 5.0
## Comparing with the average needs a few solves first, or one lucky game sets the bar
const MIN_SOLVES_FOR_AVERAGE: int = 3

var score_box: VBoxContainer
var score_label: Label
var score_caption: Label
var stats_row: HBoxContainer
var highlight_labels: Array[Label] = []
var achievement_row: HBoxContainer
var achievement_icon: TextureRect
var achievement_label: Label
var _stat_values: Array[Label] = []
var _stat_captions: Array[Label] = []

func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", ThemeManager.SPACE_MD)
	_build()

func _enter_tree() -> void:
	ThemeManager.add_listener(_apply_theme)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_apply_theme)

func _build() -> void:
	score_box = VBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_theme_constant_override("separation", 0)
	add_child(score_box)

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.theme_type_variation = "EditorialHeader"
	score_label.add_theme_font_size_override("font_size", 52)
	score_box.add_child(score_label)

	score_caption = Label.new()
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_caption.theme_type_variation = "Caption"
	score_caption.add_theme_font_size_override("font_size", 11)
	score_box.add_child(score_caption)

	stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	add_child(stats_row)
	for i in range(3):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		stats_row.add_child(col)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.theme_type_variation = "TechnicalLabel"
		value.add_theme_font_size_override("font_size", 20)
		col.add_child(value)
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.theme_type_variation = "Caption"
		caption.add_theme_font_size_override("font_size", 10)
		col.add_child(caption)
		_stat_values.append(value)
		_stat_captions.append(caption)

	for i in range(2):
		var line := Label.new()
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.theme_type_variation = "Body"
		line.add_theme_font_size_override("font_size", 14)
		line.visible = false
		add_child(line)
		highlight_labels.append(line)

	achievement_row = HBoxContainer.new()
	achievement_row.alignment = BoxContainer.ALIGNMENT_CENTER
	achievement_row.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	achievement_row.visible = false
	add_child(achievement_row)
	achievement_icon = TextureRect.new()
	achievement_icon.texture = ThemeManager.get_icon("award")
	achievement_icon.custom_minimum_size = Vector2(18, 18)
	achievement_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	achievement_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	achievement_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	achievement_row.add_child(achievement_icon)
	achievement_label = Label.new()
	achievement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	achievement_label.theme_type_variation = "Body"
	achievement_label.add_theme_font_size_override("font_size", 14)
	achievement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	achievement_row.add_child(achievement_label)
	_apply_theme()

## Fills the card. `highlights` come from build_highlights(); the score is hidden when the
## solution was shown, since it was not earned. `achievements` are the ids this game unlocked.
func show_result(summary: Dictionary, highlights: Array[String], achievements: Array[String] = []) -> void:
	var assisted: bool = summary.get("assisted", false)
	score_box.visible = not assisted
	score_label.text = str(int(summary.get("score", 0)))
	score_caption.text = LocalizationManager.upper(LocalizationManager.translate("RESULT_SCORE")) + " / 100"

	var values := [
		LocalizationManager.format_duration(float(summary.get("time", 0.0))),
		str(int(summary.get("mistakes", 0))),
		str(int(summary.get("hints", 0))),
	]
	var captions := ["RESULT_TIME", "RESULT_MISTAKES", "RESULT_HINTS"]
	for i in range(3):
		_stat_values[i].text = values[i]
		_stat_captions[i].text = LocalizationManager.upper(LocalizationManager.translate(captions[i]))

	for i in range(highlight_labels.size()):
		highlight_labels[i].visible = i < highlights.size()
		highlight_labels[i].text = highlights[i] if i < highlights.size() else ""

	achievement_row.visible = not achievements.is_empty()
	var titles: Array = achievements.map(func(id): return AchievementManager.title(id))
	var key := "ACH_NEW" if achievements.size() == 1 else "ACH_NEW_MANY"
	achievement_label.text = LocalizationManager.translate(key) % " · ".join(titles) if not achievements.is_empty() else ""
	_apply_theme()
	_fit_achievement_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_achievement_label()

## As wide as its text when that fits, so a short line sits centred like the lines above it;
## otherwise it fills the row and wraps, and never widens the dialog
func _fit_achievement_label() -> void:
	if achievement_label == null or achievement_label.text.is_empty():
		return
	var font: Font = achievement_label.get_theme_font("font")
	var font_size: int = achievement_label.get_theme_font_size("font_size")
	var text_w: float = ceilf(font.get_string_size(achievement_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 1.0
	var room: float = size.x - achievement_icon.custom_minimum_size.x - ThemeManager.SPACE_SM
	var fits: bool = size.x > 0.0 and text_w <= room
	var flags: int = SIZE_FILL if fits else SIZE_EXPAND_FILL
	var min_w: float = text_w if fits else 0.0
	if achievement_label.size_flags_horizontal != flags:
		achievement_label.size_flags_horizontal = flags
	if achievement_label.custom_minimum_size.x != min_w:
		achievement_label.custom_minimum_size.x = min_w

## Context lines for a finished game, most important first (at most two):
## a shown solution says so and nothing else; a replay compares with the best score for that
## puzzle; a first solve compares with the player's record and average at that level, which
## `bench` holds as it was before this game (HistoryManager.get_level_benchmarks()).
## A Daily shows its streak as the second line.
static func build_highlights(summary: Dictionary, bench: Dictionary, prev_best_for_seed: Dictionary,
		daily_streak: int = 0) -> Array[String]:
	var lines: Array[String] = []
	if summary.get("assisted", false):
		lines.append(LocalizationManager.translate("RESULT_ASSISTED"))
		return lines

	var time: float = float(summary.get("time", 0.0))
	if summary.get("is_replay", false):
		if not prev_best_for_seed.is_empty():
			var prev_score: int = int(prev_best_for_seed.get("score", 0))
			var score: int = int(summary.get("score", 0))
			if score > prev_score:
				lines.append(LocalizationManager.translate("NEW_BEST_SCORE"))
			else:
				lines.append(LocalizationManager.translate("SCORE_BEST_COMPARISON") % [prev_score, score])
	else:
		var count: int = int(bench.get("count", 0))
		if count == 0:
			lines.append(LocalizationManager.translate("RESULT_FIRST_AT_LEVEL"))
		elif time < float(bench.get("best_time", 0.0)):
			lines.append(LocalizationManager.translate("RESULT_FASTEST"))
		if count >= MIN_SOLVES_FOR_AVERAGE:
			var diff: float = time - float(bench.get("avg_time", 0.0))
			if absf(diff) < AVERAGE_TOLERANCE:
				lines.append(LocalizationManager.translate("RESULT_ON_AVG"))
			elif diff < 0.0:
				lines.append(LocalizationManager.translate("RESULT_FASTER_THAN_AVG") % LocalizationManager.format_duration_words(-diff))
			else:
				lines.append(LocalizationManager.translate("RESULT_SLOWER_THAN_AVG") % LocalizationManager.format_duration_words(diff))

	# A Daily keeps its streak line, after the headline
	if summary.get("is_daily", false) and daily_streak > 0:
		lines.resize(mini(lines.size(), 1))
		lines.append(LocalizationManager.translate("RESULT_DAILY") % LocalizationManager.format_streak(daily_streak))
	return lines.slice(0, 2)

func _apply_theme() -> void:
	if score_label == null:
		return
	var accent: Color = ThemeManager.get_color("accent")
	var secondary: Color = ThemeManager.get_color("text_secondary")
	var primary: Color = ThemeManager.get_color("text_given")
	score_label.add_theme_color_override("font_color", accent)
	score_caption.add_theme_color_override("font_color", secondary)
	for v in _stat_values:
		v.add_theme_color_override("font_color", primary)
	for c in _stat_captions:
		c.add_theme_color_override("font_color", secondary)
	for i in range(highlight_labels.size()):
		# The first line is the headline (record, new best); the second is supporting context
		highlight_labels[i].add_theme_color_override("font_color", accent if i == 0 else secondary)
	achievement_icon.modulate = accent
	achievement_label.add_theme_color_override("font_color", primary)
