class_name HistoryScreen
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const GameRecordItem = preload("res://scenes/ui/game_record_item.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")

## Past Games History Screen with Swiss Editorial layout (GDD §32, §44)
## Clean filter bar with hairline dividers, compact data-dense list items,
## eliminating heavy card dashboard backgrounds.

signal back_requested()
signal replay_requested(seed_val: int, difficulty: String)

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title: Label
var filter_card: PanelContainer
var status_lbl: Label
var status_opt: OptionButton
var diff_lbl: Label
var diff_opt: OptionButton
var sort_lbl: Label
var sort_opt: OptionButton
var list_vbox: VBoxContainer
var list_card: PanelContainer

const STATUS_KEYS: Array[String] = [
	"All",
	"Standard",
	"Replay"
]

const DIFF_KEYS: Array[String] = [
	"All",
	DifficultyAnalyzer.LEVEL_EASY,
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]

## Narrowest a filter column gets: room for the longest option next to the arrow
const FILTER_MIN_WIDTH: float = 140.0

const SORT_KEYS: Array[String] = [
	"Newest",
	"Oldest",
	"Fastest",
	"Best Score"
]

var _is_built: bool = false
var _history_dirty: bool = true
var _pending_records: Array[Dictionary] = []
var _pending_best_map: Dictionary = {}
var _pager: ListPager
## Rows per page; the next page is built when scrolling gets near the end
const PAGE_SIZE: int = 25

## Set once _ready is done: every screen is still visible during it, before the app shows
## only the menu, so lists are not built then
var _started: bool = false

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_ensure_ui()
	ThemeManager.add_listener(_on_theme_changed)

func _ready() -> void:
	_ensure_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	_started = true

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree() and _history_dirty:
			refresh_history()

func _apply_responsive_layout() -> void:
	if margin == null:
		return
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH)

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if is_visible_in_tree():
		refresh_history()
	else:
		_history_dirty = true

func _ensure_ui() -> void:
	if _is_built:
		return
	_is_built = true
	_build_ui()

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
	root_vbox.add_theme_constant_override("separation", 12)
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

	# --- 2. Clean Editorial Filter Toolbar ---
	filter_card = GlassPanel.card(20.0, 14, 10)
	root_vbox.add_child(filter_card)

	# Three filters in a row where they fit; on a phone Sort moves to its own full-width line,
	# so no picker is too narrow for its longest option ("En İyi Skor")
	var filter_cols := HFlowContainer.new()
	filter_cols.add_theme_constant_override("h_separation", 10)
	filter_cols.add_theme_constant_override("v_separation", 8)
	filter_card.add_child(filter_cols)

	# Column 1: Status Filter
	var col_status := VBoxContainer.new()
	col_status.size_flags_horizontal = SIZE_EXPAND_FILL
	col_status.custom_minimum_size.x = FILTER_MIN_WIDTH
	col_status.add_theme_constant_override("separation", 2)
	filter_cols.add_child(col_status)

	status_lbl = Label.new()
	status_lbl.theme_type_variation = "Caption"
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	col_status.add_child(status_lbl)

	status_opt = OptionButton.new()
	status_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	status_opt.fit_to_longest_item = false
	status_opt.clip_text = true
	status_opt.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_INPUT)
	for s in STATUS_KEYS:
		status_opt.add_item(s)
	status_opt.item_selected.connect(func(_idx): refresh_history())
	col_status.add_child(status_opt)

	# Column 2: Difficulty Filter
	var col_diff := VBoxContainer.new()
	col_diff.size_flags_horizontal = SIZE_EXPAND_FILL
	col_diff.custom_minimum_size.x = FILTER_MIN_WIDTH
	col_diff.add_theme_constant_override("separation", 2)
	filter_cols.add_child(col_diff)

	diff_lbl = Label.new()
	diff_lbl.theme_type_variation = "Caption"
	diff_lbl.add_theme_font_size_override("font_size", 10)
	diff_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	col_diff.add_child(diff_lbl)

	diff_opt = OptionButton.new()
	diff_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	diff_opt.fit_to_longest_item = false
	diff_opt.clip_text = true
	diff_opt.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_INPUT)
	for d in DIFF_KEYS:
		diff_opt.add_item(d)
	diff_opt.item_selected.connect(func(_idx): refresh_history())
	col_diff.add_child(diff_opt)

	# Column 3: Sort Filter
	var col_sort := VBoxContainer.new()
	col_sort.size_flags_horizontal = SIZE_EXPAND_FILL
	col_sort.custom_minimum_size.x = FILTER_MIN_WIDTH
	col_sort.add_theme_constant_override("separation", 2)
	filter_cols.add_child(col_sort)

	sort_lbl = Label.new()
	sort_lbl.theme_type_variation = "Caption"
	sort_lbl.add_theme_font_size_override("font_size", 10)
	sort_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	col_sort.add_child(sort_lbl)

	sort_opt = OptionButton.new()
	sort_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	sort_opt.fit_to_longest_item = false
	sort_opt.clip_text = true
	sort_opt.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_INPUT)
	for s in SORT_KEYS:
		sort_opt.add_item(s)
	sort_opt.item_selected.connect(func(_idx): refresh_history())
	col_sort.add_child(sort_opt)

	var filter_sep := HSeparator.new()
	root_vbox.add_child(filter_sep)

	# --- 3. History List ScrollContainer ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)
	_pager = ListPager.new(scroll, PAGE_SIZE)

	# Rows sit together in one card, like the groups in Settings (one glass surface per list)
	var list_pad := MarginContainer.new()
	list_pad.size_flags_horizontal = SIZE_EXPAND_FILL
	list_pad.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(list_pad)
	list_card = GlassPanel.card(20.0, 14, 4)
	list_card.size_flags_vertical = SIZE_SHRINK_BEGIN
	list_pad.add_child(list_card)

	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 0)
	list_card.add_child(list_vbox)

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if title != null:
		title.text = LocalizationManager.translate("HISTORY_TITLE")
	if status_lbl != null:
		status_lbl.text = LocalizationManager.upper(LocalizationManager.translate("HISTORY_STATUS_FILTER"))
	if diff_lbl != null:
		diff_lbl.text = LocalizationManager.upper(LocalizationManager.translate("HISTORY_DIFF_FILTER"))
	if sort_lbl != null:
		sort_lbl.text = LocalizationManager.upper(LocalizationManager.translate("HISTORY_SORT_FILTER"))

	if status_opt != null:
		var cur_st := status_opt.selected
		status_opt.clear()
		status_opt.add_item(LocalizationManager.translate("STATUS_ALL"))
		status_opt.add_item(LocalizationManager.translate("STATUS_STANDARD"))
		status_opt.add_item(LocalizationManager.translate("STATUS_REPLAY"))
		status_opt.selected = cur_st if cur_st >= 0 else 0

	if diff_opt != null:
		var cur_d := diff_opt.selected
		diff_opt.clear()
		diff_opt.add_item(LocalizationManager.translate("DIFF_ALL"))
		diff_opt.add_item(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EASY))
		diff_opt.add_item(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_MEDIUM))
		diff_opt.add_item(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD))
		diff_opt.add_item(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EXPERT))
		diff_opt.selected = cur_d if cur_d >= 0 else 0

	if sort_opt != null:
		var cur_s := sort_opt.selected
		sort_opt.clear()
		sort_opt.add_item(LocalizationManager.translate("SORT_NEWEST"))
		sort_opt.add_item(LocalizationManager.translate("SORT_OLDEST"))
		sort_opt.add_item(LocalizationManager.translate("SORT_FASTEST"))
		sort_opt.add_item(LocalizationManager.translate("SORT_BEST_SCORE"))
		sort_opt.selected = cur_s if cur_s >= 0 else 0

	# Not from _ready: every screen is still visible then, before the app shows only the menu
	if is_visible_in_tree() and _started:
		refresh_history()
	else:
		_history_dirty = true

func refresh_history() -> void:
	_history_dirty = false
	if list_vbox == null or diff_opt == null or sort_opt == null:
		return

	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	var diff_idx := clampi(diff_opt.selected, 0, DIFF_KEYS.size() - 1)
	var sort_idx := clampi(sort_opt.selected, 0, SORT_KEYS.size() - 1)
	var status_idx := clampi(status_opt.selected, 0, STATUS_KEYS.size() - 1) if status_opt != null else 0

	var diff_filter: String = DIFF_KEYS[diff_idx]
	var sort_filter: String = SORT_KEYS[sort_idx]
	var status_filter: String = STATUS_KEYS[status_idx]

	var records := HistoryManager.get_filtered_history(diff_filter, status_filter, sort_filter)
	if records.is_empty():
		_pager.start(0, Callable())
		var empty_container := VBoxContainer.new()
		empty_container.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_container.custom_minimum_size = Vector2(0, 160)
		empty_container.size_flags_horizontal = SIZE_EXPAND_FILL

		var empty_lbl := Label.new()
		empty_lbl.text = LocalizationManager.translate("HISTORY_EMPTY")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.theme_type_variation = "Subtitle"
		empty_container.add_child(empty_lbl)

		list_vbox.add_child(empty_container)
		return

	_pending_records = records
	_pending_best_map = HistoryManager.get_best_records_map()
	_pager.start(records.size(), _add_record_row)

func _add_record_row(i: int) -> void:
	var r: Dictionary = _pending_records[i]
	var seed_val: int = int(r.get("seed", 0))
	var best_record: Dictionary = _pending_best_map.get(seed_val, {})
	var item := GameRecordItem.new()
	item.setup_history(r, best_record)
	item.replay_pressed.connect(func(s, d): replay_requested.emit(s, d))
	list_vbox.add_child(item)

