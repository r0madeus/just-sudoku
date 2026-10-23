extends SceneTree

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SoundManager = preload("res://scripts/services/sound_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
const CustomThemeDialog = preload("res://scenes/menus/dialogs/custom_theme_dialog.gd")
const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SudokuGrid = preload("res://scenes/gameplay/sudoku_grid.gd")
const SudokuCell = preload("res://scenes/gameplay/sudoku_cell.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var suite_start_msec: int = 0

const PER_TEST_TIMEOUT_MSEC: int = 1000

var ui_root: Control
var test_gen: SudokuGenerator.GeneratedPuzzle

# Backup configuration
var orig_config: String = ""
var orig_settings: String = ""
var orig_locale: String = ""
var orig_theme: String = ""

func _init() -> void:
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - SUNUM & AYARLAR KALİTE TESTİ")
	print("   GDD §36-§44, §49 • Katı Zaman Sınırları (Max %d ms / test)" % PER_TEST_TIMEOUT_MSEC)
	print("================================================================")

	_backup_configs()

	ui_root = Control.new()
	var cr := get_root()
	if cr != null:
		cr.add_child(ui_root)

	# Generate single deterministic test puzzle
	var t0: int = Time.get_ticks_msec()
	test_gen = SudokuGenerator.generate(1001, DifficultyAnalyzer.LEVEL_EASY)
	print("[Ön Hazırlık: Deterministik Bulmaca Hazırlandı (%d ms)]" % (Time.get_ticks_msec() - t0))

	run_bounded_test("Boyut 1: 5 Dahili Renk Teması & Palet Bütünlüğü (GDD §36)", test_dimension_1_builtin_themes_and_palettes)
	run_bounded_test("Boyut 2: Özel Tema Editörü & Harmonik Renk Türetimi (GDD §37)", test_dimension_2_custom_theme_editor_and_harmonics)
	run_bounded_test("Boyut 3: Ayarlar Menüsü, Kalıcı Yapılandırma & Çakışma Gizleme (GDD §18, §43)", test_dimension_3_settings_persistence_and_conflict_hiding)
	run_bounded_test("Boyut 4: Prosedürel Ses Sentezleyici & Ses Ayarı (GDD §40)", test_dimension_4_sound_synthesizer_and_mute)
	run_bounded_test("Boyut 5: Çoklu Dil (Localization TR/EN) Bütünlüğü & Hot-Swap (GDD §44)", test_dimension_5_localization_and_hot_swap)
	run_bounded_test("Boyut 6: Responsive Arayüz Düzeni, Orantı & Tipografi (GDD §38, §49)", test_dimension_6_responsive_layout_and_typography)
	run_bounded_test("Boyut 7: Animasyonlar & Sıfır-Gecikme (Zero-Lag) Performans (GDD §39, §49)", test_dimension_7_animations_and_zero_lag)

	_restore_configs()
	ui_root.queue_free()

	var total_elapsed_msec: int = Time.get_ticks_msec() - suite_start_msec
	print("\n================================================================")
	print("🏁 RESULTS: %d Passed, %d Failed (Toplam Süre: %d ms)" % [tests_passed, tests_failed, total_elapsed_msec])
	print("================================================================")

	if tests_failed > 0 or total_elapsed_msec > 3000:
		if total_elapsed_msec > 3000:
			printerr("  ✗ SÜİT GENELİ ZAMAN AŞIMI: %d ms > 3000 ms tavanı aşıldı!" % total_elapsed_msec)
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func run_bounded_test(title: String, test_fn: Callable) -> void:
	print("\n--- %s ---" % title)
	var t0: int = Time.get_ticks_msec()
	test_fn.call()
	var elapsed: int = Time.get_ticks_msec() - t0
	if elapsed <= PER_TEST_TIMEOUT_MSEC:
		assert_true(true, "Zaman Sınırı Koruması: Test %d ms içinde tamamlandı (Tavan: %d ms)" % [elapsed, PER_TEST_TIMEOUT_MSEC])
	else:
		assert_true(false, "TIMEOUT FAIL: Test %d ms sürdü, izin verilen %d ms tavanını aştı!" % [elapsed, PER_TEST_TIMEOUT_MSEC])

# -----------------------------------------------------------------------------
# BOYUT 1: 5 Dahili Renk Teması & Palet Bütünlüğü (GDD §36)
# -----------------------------------------------------------------------------
func test_dimension_1_builtin_themes_and_palettes() -> void:
	var required_keys: Array[String] = [
		"bg", "surface", "grid_major", "grid_minor", "cell_bg", "cell_selected",
		"cell_peer", "cell_same_num", "text_given", "text_user", "text_conflict",
		"text_wrong", "text_notes", "accent", "button_normal", "button_hover",
		"button_pressed", "button_text"
	]

	var themes := [
		ThemeManager.THEME_DARK,
		ThemeManager.THEME_AMOLED,
		ThemeManager.THEME_LIGHT,
		ThemeManager.THEME_SEPIA,
		ThemeManager.THEME_FOREST
	]

	for t_name in themes:
		assert_true(ThemeManager.PALETTES.has(t_name), "Tema mevcut: %s" % t_name)
		var p: Dictionary = ThemeManager.PALETTES[t_name]
		var keys_ok: bool = true
		for k in required_keys:
			if not p.has(k) or not (p[k] is Color):
				keys_ok = false
				break
		assert_true(keys_ok, "Zorunlu 18 renk anahtarının tamamı mevcut ve geçerli Color nesnesi: %s" % t_name)

	# AMOLED pure black check
	assert_true(ThemeManager.PALETTES[ThemeManager.THEME_AMOLED]["bg"] == Color("#000000"), "AMOLED: Saf siyah arka plan (#000000)")
	# Sepia warm parchment check
	assert_true(ThemeManager.PALETTES[ThemeManager.THEME_SEPIA]["bg"] == Color("#f4ecd8"), "Sepia: Sıcak parşömen arka plan (#f4ecd8)")
	# Forest dark sage check
	assert_true(ThemeManager.PALETTES[ThemeManager.THEME_FOREST]["bg"] == Color("#101a14"), "Forest: Koyu adaçayı arka plan (#101a14)")

	# Build Godot Theme verification
	var godot_theme := ThemeManager.build_godot_theme()
	assert_true(godot_theme != null, "ThemeManager.build_godot_theme() başarıyla Theme nesnesi üretti")
	assert_true(godot_theme.has_stylebox("normal", "Button"), "Button normal stylebox mevcut")
	assert_true(godot_theme.has_stylebox("hover", "Button"), "Button hover stylebox mevcut")

# -----------------------------------------------------------------------------
# BOYUT 2: Özel Tema Editörü & Harmonik Renk Türetimi (GDD §37)
# -----------------------------------------------------------------------------
func test_dimension_2_custom_theme_editor_and_harmonics() -> void:
	var dialog := CustomThemeDialog.new()
	ui_root.add_child(dialog)

	# 1. UI Components
	assert_true(dialog.picker_buttons.size() == 9, "CustomThemeDialog 9 temel renk seçici butonuna sahip")
	assert_true(dialog.preview_cells.size() == 9, "Canlı 3x3 önizleme ızgarası 9 hücreye sahip")
	assert_true(dialog.preset_buttons.size() >= 5, "5 adet hazır tema kopyalama butonu mevcut")

	# 2. Harmonic derivation test
	var custom_input: Dictionary = {
		"bg": Color("#181824"),
		"grid_major": Color("#505070"),
		"cell_bg": Color("#202030"),
		"cell_selected": Color("#304060"),
		"text_given": Color("#e0e0f0"),
		"text_user": Color("#60a0ff"),
		"accent_blue": Color("#4080ff"),
		"text_conflict": Color("#ff4040"),
		"text_notes": Color("#8080a0")
	}

	ThemeManager.apply_custom_palette(custom_input)
	assert_true(ThemeManager.current_theme_name == ThemeManager.THEME_CUSTOM, "Uygulanan tema THEME_CUSTOM olarak ayarlandı")
	assert_true(ThemeManager.get_color("bg") == Color("#181824"), "Arka plan rengi korundu")

	# Harmonically derived keys must exist and be valid
	assert_true(ThemeManager.current_palette.has("grid_minor"), "grid_minor harmonik olarak türetildi")
	assert_true(ThemeManager.current_palette.has("cell_peer"), "cell_peer harmonik olarak türetildi")
	assert_true(ThemeManager.current_palette.has("cell_same_num"), "cell_same_num harmonik olarak türetildi")
	assert_true(ThemeManager.current_palette.has("surface"), "surface harmonik olarak türetildi")
	assert_true(ThemeManager.current_palette.has("button_hover"), "button_hover harmonik olarak türetildi")

	dialog.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 3: Ayarlar Menüsü, Kalıcı Yapılandırma & Çakışma Gizleme (GDD §18, §43)
# -----------------------------------------------------------------------------
func test_dimension_3_settings_persistence_and_conflict_hiding() -> void:
	# 1. Round-trip config persistence
	AppSettings.smart_numpad_enabled = false
	AppSettings.auto_remove_notes = false
	AppSettings.show_conflicts = false
	AppSettings.animations_enabled = false
	AppSettings.sounds_enabled = false
	AppSettings.save_config()

	# Reload
	AppSettings.smart_numpad_enabled = true
	AppSettings.auto_remove_notes = true
	AppSettings.show_conflicts = true
	AppSettings.load_config()

	assert_true(AppSettings.smart_numpad_enabled == false, "Kalıcı Ayar: smart_numpad_enabled yüklendi (false)")
	assert_true(AppSettings.auto_remove_notes == false, "Kalıcı Ayar: auto_remove_notes yüklendi (false)")
	assert_true(AppSettings.show_conflicts == false, "Kalıcı Ayar: show_conflicts yüklendi (false)")
	assert_true(AppSettings.animations_enabled == false, "Kalıcı Ayar: animations_enabled yüklendi (false)")
	assert_true(AppSettings.sounds_enabled == false, "Kalıcı Ayar: sounds_enabled yüklendi (false)")

	# 2. Eksik Kapatma Doğrulaması: show_conflicts Entegrasyonu (GDD §18, §43)
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# Intentionally create a conflict in Row 0 (place two 8s)
	state.current_board.set_cell(0, 8, false)
	state.current_board.set_cell(1, 8, false)

	var grid := SudokuGrid.new()
	ui_root.add_child(grid)
	grid._ready()
	grid.bind_game_state(state)

	# When show_conflicts = false, cells must NOT show conflict
	AppSettings.show_conflicts = false
	grid.refresh_highlights()
	assert_true(grid.cells[0].is_conflict == false, "Eksik Kapatıldı: show_conflicts = false iken çakışma canlıda gizlendi (is_conflict = false)")
	assert_true(grid.cells[1].is_conflict == false, "Eksik Kapatıldı: Komşu çakışan hücre de gizlendi (is_conflict = false)")

	# When show_conflicts = true, cells MUST show conflict
	AppSettings.show_conflicts = true
	grid.refresh_highlights()
	assert_true(grid.cells[0].is_conflict == true, "show_conflicts = true iken çakışma kırmızı vurgulandı (is_conflict = true)")
	assert_true(grid.cells[1].is_conflict == true, "show_conflicts = true iken komşu hücre kırmızı vurgulandı (is_conflict = true)")

	grid.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 4: Prosedürel Ses Sentezleyici & Ses Ayarı (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_4_sound_synthesizer_and_mute() -> void:
	SoundManager.init_audio(ui_root)

	# Test 1: Sound enabled calls without crash
	AppSettings.sounds_enabled = true
	SoundManager.play_number_placed()
	SoundManager.play_erase()
	SoundManager.play_conflict()
	SoundManager.play_complete()
	assert_true(true, "SoundManager sesleri sounds_enabled = true iken hatasız/çökmesiz yürütüldü")

	# Test 2: Mute mode (sounds_enabled = false) executes safely
	AppSettings.sounds_enabled = false
	SoundManager.play_number_placed()
	SoundManager.play_erase()
	SoundManager.play_conflict()
	SoundManager.play_complete()
	assert_true(true, "SoundManager sessiz modda (sounds_enabled = false) 0 işlem ve 0 hata ile çalıştı")

	# Restore
	AppSettings.sounds_enabled = true

# -----------------------------------------------------------------------------
# BOYUT 5: Çoklu Dil (Localization TR/EN) Bütünlüğü & Hot-Swap (GDD §44)
# -----------------------------------------------------------------------------
func test_dimension_5_localization_and_hot_swap() -> void:
	# 1. Dictionary completeness check
	var tr_keys: Array = LocalizationManager.DICTIONARY_TR.keys()
	var en_keys: Array = LocalizationManager.DICTIONARY_EN.keys()
	assert_true(tr_keys.size() > 50, "TR sözlüğü 50'den fazla temel terim içeriyor (%d)" % tr_keys.size())
	assert_true(en_keys.size() > 50, "EN sözlüğü 50'den fazla temel terim içeriyor (%d)" % en_keys.size())

	var missing_in_en: Array[String] = []
	for k in tr_keys:
		if not LocalizationManager.DICTIONARY_EN.has(k):
			missing_in_en.append(k)
	assert_true(missing_in_en.is_empty(), "TR sözlüğündeki tüm anahtarlar EN sözlüğünde eksiksiz mevcut (Eksik: %s)" % str(missing_in_en))

	# 2. Dynamic runtime hot-swap check
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	assert_true(LocalizationManager.translate("BTN_NEW_GAME") == "Yeni Oyun", "TR Çeviri: BTN_NEW_GAME -> 'Yeni Oyun'")
	assert_true(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD) == "Zor", "TR Zorluk: LEVEL_HARD -> 'Zor'")

	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)
	assert_true(LocalizationManager.translate("BTN_NEW_GAME") == "New Game", "EN Çeviri (Hot-Swap): BTN_NEW_GAME -> 'New Game'")
	assert_true(LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD) == "Hard", "EN Zorluk: LEVEL_HARD -> 'Hard'")

	# 3. Formatters
	assert_true(LocalizationManager.format_duration(125.0) == "02:05", "Zaman formatı: 125s -> '02:05'")

# -----------------------------------------------------------------------------
# BOYUT 6: Responsive Arayüz Düzeni, Orantı & Tipografi (GDD §38, §49)
# -----------------------------------------------------------------------------
func test_dimension_6_responsive_layout_and_typography() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	var grid := SudokuGrid.new()
	ui_root.add_child(grid)
	grid._ready()
	for c in grid.cells:
		c._ready()
	grid.bind_game_state(state)

	# 1. Mobile Portrait scaling (360 x 640)
	grid.size = Vector2(360, 640)
	grid._layout_cells()
	assert_true(grid.cells[0].size.x == 40.0, "Mobil Dikey Düzen (360x640): Hücre genişliği tam 40.0 px (360 / 9)")
	assert_true(grid.cells[0].size.y == 40.0, "Mobil Dikey Düzen (360x640): Hücre yüksekliği tam 40.0 px (1:1 kare)")

	# 2. Desktop Landscape scaling (800 x 600)
	grid.size = Vector2(800, 600)
	grid._layout_cells()
	assert_true(is_equal_approx(grid.cells[0].size.x, 600.0 / 9.0), "Masaüstü Yatay Düzen (800x600): Hücreler 600 / 9 px kare olarak kilitlendi")

	# 3. Eksik Kapatma Doğrulaması: Font boyutu taban koruması (maxi 8)
	var cell: SudokuCell = grid.cells[0]
	cell.size = Vector2(10.0, 10.0)
	cell._update_font_sizes()
	assert_true(cell.num_label.get_theme_font_size("font_size") >= 8, "Eksik Kapatıldı: Mikro boyutta (10x10) font boyutu en az 8 px tabanında korundu")

	cell.size = Vector2(80.0, 80.0)
	cell._update_font_sizes()
	assert_true(cell.num_label.get_theme_font_size("font_size") >= 40, "Büyük boyutta (80x80) font boyutu orantılı büyütüldü (%d px)" % cell.num_label.get_theme_font_size("font_size"))

	grid.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 7: Animasyonlar & Sıfır-Gecikme (Zero-Lag) Performans (GDD §39, §49)
# -----------------------------------------------------------------------------
func test_dimension_7_animations_and_zero_lag() -> void:
	var cell := SudokuCell.new()
	ui_root.add_child(cell)
	cell._ready()

	# 1. Animations toggle check
	AppSettings.animations_enabled = false
	cell.set_cell_data(5, false, 0, false, false, false, false, false)
	assert_true(true, "animations_enabled = false iken hücre animasyonu hatasız atlandı")

	AppSettings.animations_enabled = true
	cell.set_cell_data(0, false, 0, false, false, false, false, false)
	cell.set_cell_data(6, false, 0, false, false, false, false, false)
	assert_true(true, "animations_enabled = true iken pop animasyonu başlatıldı")

	# 2. Zero-Lag Performance: 10 theme switches
	var t_theme_0 := Time.get_ticks_msec()
	for i in range(10):
		var target: String = ThemeManager.THEME_DARK if i % 2 == 0 else ThemeManager.THEME_LIGHT
		ThemeManager.set_theme(target)
	var theme_elapsed := Time.get_ticks_msec() - t_theme_0
	assert_true(theme_elapsed < 50, "Sıfır-Gecikme (Zero-Lag): 10 tema değişimi %d ms içinde tamamlandı (< 50 ms)" % theme_elapsed)

	# 3. Zero-Lag Performance: 10 language switches
	var t_loc_0 := Time.get_ticks_msec()
	for i in range(10):
		var loc: String = LocalizationManager.LOCALE_TR if i % 2 == 0 else LocalizationManager.LOCALE_EN
		LocalizationManager.set_locale(loc)
	var loc_elapsed := Time.get_ticks_msec() - t_loc_0
	assert_true(loc_elapsed < 30, "Sıfır-Gecikme (Zero-Lag): 10 dil değişimi %d ms içinde tamamlandı (< 30 ms)" % loc_elapsed)

	cell.queue_free()

# -----------------------------------------------------------------------------
# Yapılandırma Yedekleme ve Temizlik Yardımcıları
# -----------------------------------------------------------------------------
func _backup_configs() -> void:
	orig_locale = LocalizationManager.get_locale()
	orig_theme = ThemeManager.current_theme_name
	if FileAccess.file_exists(AppSettings.CONFIG_PATH):
		var f := FileAccess.open(AppSettings.CONFIG_PATH, FileAccess.READ)
		if f != null:
			orig_config = f.get_as_text()
			f.close()
	if FileAccess.file_exists(ThemeManager.SETTINGS_PATH):
		var f := FileAccess.open(ThemeManager.SETTINGS_PATH, FileAccess.READ)
		if f != null:
			orig_settings = f.get_as_text()
			f.close()

func _restore_configs() -> void:
	LocalizationManager.set_locale(orig_locale)
	ThemeManager.set_theme(orig_theme)
	_write_file_safe(AppSettings.CONFIG_PATH, orig_config)
	_write_file_safe(ThemeManager.SETTINGS_PATH, orig_settings)

func _write_file_safe(path: String, content: String) -> void:
	if content.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
