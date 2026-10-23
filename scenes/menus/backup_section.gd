class_name BackupSection
extends VBoxContainer

## Settings section "Data": back up everything to a file or the clipboard, and restore it.
## Files go through the system's file picker where there is one (Android, desktop); the
## clipboard works everywhere.

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SettingRow = preload("res://scenes/ui/setting_row.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const BackupManager = preload("res://scripts/data/backup_manager.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")

## Saved data was replaced by a backup; whatever was open must not save over it
signal data_restored()

const FILE_FILTERS: PackedStringArray = ["*.json;JSON;application/json"]
## Some file managers do not call a .json file JSON, so opening also offers plain files
const OPEN_FILTERS: PackedStringArray = ["*.json;JSON;application/json,text/plain,application/octet-stream"]

var section_lbl: Label
var backup_row: SettingRow
var restore_row: SettingRow
var backup_btn: Button
var restore_btn: Button
## Result of the last backup or restore, under the rows
var status_lbl: Label
## Native file picker available: files are offered first, the clipboard as well
var has_file_dialog: bool = false

var _choice: AppModal = null

func _init() -> void:
	add_theme_constant_override("separation", 8)
	has_file_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	_build_ui()
	_update_locale_texts()

func _enter_tree() -> void:
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_apply_theme)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_apply_theme)

func _build_ui() -> void:
	section_lbl = Label.new()
	section_lbl.theme_type_variation = "Caption"
	ThemeManager.set_font_size(section_lbl, 11)
	add_child(section_lbl)
	add_child(HSeparator.new())

	var card := GlassPanel.card()
	add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	backup_btn = _make_button("upload", _on_backup_pressed)
	backup_row = SettingRow.new("", "", backup_btn)
	vbox.add_child(backup_row)

	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 2)
	vbox.add_child(div)

	restore_btn = _make_button("download", _on_restore_pressed)
	restore_row = SettingRow.new("", "", restore_btn)
	vbox.add_child(restore_row)

	status_lbl = Label.new()
	status_lbl.theme_type_variation = "Caption"
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeManager.set_font_size(status_lbl, 12)
	status_lbl.visible = false
	vbox.add_child(status_lbl)
	_apply_theme()

func _make_button(icon: String, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "SecondaryButton"
	btn.icon = ThemeManager.get_icon(icon)
	btn.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(btn, 13)
	btn.custom_minimum_size = Vector2(0, ResponsiveManager.TOUCH_TARGET_MIN)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(on_pressed)
	return btn

func _apply_theme() -> void:
	if section_lbl != null:
		section_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func _update_locale_texts() -> void:
	section_lbl.text = LocalizationManager.upper(LocalizationManager.translate("SETTINGS_SEC_DATA"))
	backup_row.set_title(LocalizationManager.translate("SETTING_BACKUP"))
	backup_row.set_description(LocalizationManager.translate("SETTING_DESC_BACKUP"))
	backup_btn.text = LocalizationManager.translate("BTN_BACKUP")
	restore_row.set_title(LocalizationManager.translate("SETTING_RESTORE"))
	restore_row.set_description(LocalizationManager.translate("SETTING_DESC_RESTORE"))
	restore_btn.text = LocalizationManager.translate("BTN_RESTORE")

func _show_status(key: String, is_error: bool = false) -> void:
	status_lbl.text = LocalizationManager.translate(key)
	status_lbl.add_theme_color_override("font_color",
		ThemeManager.get_color("text_conflict") if is_error else ThemeManager.get_color("accent"))
	status_lbl.visible = true
	_scroll_to_status.call_deferred()

## The section is the last in Settings: bring the result into view once it has its size
func _scroll_to_status() -> void:
	var node: Node = get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null and is_instance_valid(status_lbl):
		await get_tree().process_frame
		(node as ScrollContainer).ensure_control_visible(status_lbl)

## Two ways out: a file (when there is a picker) or the clipboard
func _ask_where(title_key: String, file_key: String, clip_key: String, on_file: Callable, on_clip: Callable) -> void:
	if _choice != null and is_instance_valid(_choice):
		_choice.queue_free()
	_choice = AppModal.new()
	_choice.title = LocalizationManager.translate(title_key)
	_choice.dialog_text = LocalizationManager.translate("BACKUP_WHAT")
	_choice.cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	var modal := _choice
	if has_file_dialog:
		_choice.ok_button_text = LocalizationManager.translate(file_key)
		_choice.confirmed.connect(on_file)
		_choice.add_button(LocalizationManager.translate(clip_key), true, "clipboard")
		_choice.custom_action.connect(func(_id):
			modal.close_modal()
			on_clip.call()
		)
	else:
		_choice.ok_button_text = LocalizationManager.translate(clip_key)
		_choice.confirmed.connect(on_clip)
	get_tree().root.add_child(_choice)
	_choice.visibility_changed.connect(func():
		if not modal.visible:
			modal.queue_free()
	)
	_choice.open_modal()

func _on_backup_pressed() -> void:
	_ask_where("SETTING_BACKUP", "BTN_SAVE_FILE", "BTN_COPY_CLIPBOARD", _backup_to_file, backup_to_clipboard)

func _on_restore_pressed() -> void:
	_ask_where("SETTING_RESTORE", "BTN_OPEN_FILE", "BTN_PASTE_CLIPBOARD", _restore_from_file, restore_from_clipboard)

func backup_to_clipboard() -> void:
	PuzzleShareService.copy_to_clipboard(BackupManager.to_clipboard_text())
	_show_status("BACKUP_COPIED")

func _backup_to_file() -> void:
	DisplayServer.file_dialog_show(LocalizationManager.translate("SETTING_BACKUP"), "", BackupManager.file_name(),
		false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, FILE_FILTERS,
		func(ok: bool, paths: PackedStringArray, _filter: int):
			if ok and not paths.is_empty():
				if BackupManager.save_to_path(paths[0]):
					_show_status("BACKUP_SAVED")
				else:
					_show_status("BACKUP_ERR_WRITE", true)
	)

func _restore_from_file() -> void:
	DisplayServer.file_dialog_show(LocalizationManager.translate("SETTING_RESTORE"), "", "",
		false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, OPEN_FILTERS,
		func(ok: bool, paths: PackedStringArray, _filter: int):
			if ok and not paths.is_empty():
				restore_from_text(BackupManager.read_path(paths[0]))
	)

func restore_from_clipboard() -> void:
	restore_from_text(PuzzleShareService.get_clipboard_text())

## Checks the backup, says what it holds, and replaces the data once the player agrees.
## Returns the confirmation dialog, or null when the text is not a usable backup.
func restore_from_text(text: String) -> AppModal:
	var parsed := BackupManager.parse(text)
	if not parsed.ok:
		_show_status(parsed.error, true)
		return null
	var backup: Dictionary = parsed.backup
	var s := BackupManager.summarize(backup)
	var body := LocalizationManager.translate("BACKUP_CONFIRM") % [
		AchievementManager.date_text(s.created) if s.created > 0 else "?",
		s.games, s.saved, s.daily]
	var on_restore := func():
		if BackupManager.restore(backup):
			_show_status("BACKUP_RESTORED")
			data_restored.emit()
		else:
			_show_status("BACKUP_ERR_WRITE", true)
	return AppModal.ask(get_tree().root, LocalizationManager.translate("SETTING_RESTORE"), body,
		LocalizationManager.translate("BTN_RESTORE"), on_restore, true)
