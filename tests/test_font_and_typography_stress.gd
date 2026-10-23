extends SceneTree

const FontManager = preload("res://scripts/services/font_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")
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
var orig_config: String = ""
var orig_font: String = ""

func _init() -> void:
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - FONT SEÇİMİ VE TİPOGRAFİ KALİTE TESTİ")
	print("   GDD §39, §43 • Katı Zaman Sınırları (Max %d ms / test)" % PER_TEST_TIMEOUT_MSEC)
	print("================================================================")

	_backup_state()

	ui_root = Control.new()
	var cr := get_root()
	if cr != null:
		cr.add_child(ui_root)

	run_bounded_test("Boyut 1: Font Aileleri & SystemFont Geçerliliği (GDD §39)", test_dimension_1_font_families_and_systemfont_validity)
	run_bounded_test("Boyut 2: Kalıcılık & Config Round-Trip (GDD §43)", test_dimension_2_config_persistence_roundtrip)
	run_bounded_test("Boyut 3: SettingsScreen Font Seçim Arayüzü (GDD §43)", test_dimension_3_settings_screen_font_dropdown)
	run_bounded_test("Boyut 4: ThemeManager & Dinamik Hot-Swap (GDD §39)", test_dimension_4_theme_manager_and_hotswap)
	run_bounded_test("Boyut 5: Çoklu Dil (Localization TR/EN) Senkronizasyonu (GDD §44)", test_dimension_5_localization_sync)
	run_bounded_test("Boyut 6: Hücre Tipografisi & Sıfır-Gecikme Stres Testi (GDD §49)", test_dimension_6_cell_typography_and_zero_lag)

	_restore_state()
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
# BOYUT 1: Font Aileleri & Yedek Zinciri (GDD §39)
# -----------------------------------------------------------------------------
func test_dimension_1_font_families_and_systemfont_validity() -> void:
	# 1. Family definitions
	assert_true(FontManager.FONT_FAMILIES.size() == 3, "Tam 3 adet GDD §39 font ailesi tanımlı")
	assert_true(FontManager.FONT_FAMILIES.has(FontManager.FONT_MODERN_SANS), "Modern Sans mevcut")
	assert_true(FontManager.FONT_FAMILIES.has(FontManager.FONT_ROUNDED_SANS), "Rounded Sans mevcut")
	assert_true(FontManager.FONT_FAMILIES.has(FontManager.FONT_CLASSIC_SERIF), "Classic Serif mevcut")

	# 2. Each family is a bundled font with a SystemFont chain behind it for rare symbols
	for family in FontManager.FONT_FAMILIES:
		var f := FontManager.get_font(family)
		assert_true(f != null, "Font nesnesi geçerli: %s" % family)
		assert_true(f is FontVariation and f.base_font is FontFile, "Oyunla gelen font (FontVariation + FontFile): %s" % family)
		var sf: SystemFont = f.fallbacks[0] as SystemFont if not f.fallbacks.is_empty() else null
		assert_true(sf != null and sf.font_names.size() > 0, "SystemFont yedek zinciri tanımlı (%d font): %s" % [sf.font_names.size() if sf != null else 0, family])

	# 3. Default font
	assert_true(FontManager.get_current_font() != null, "Aktif font nesnesi geçerli")

# -----------------------------------------------------------------------------
# BOYUT 2: Kalıcılık & Config Round-Trip (GDD §43)
# -----------------------------------------------------------------------------
func test_dimension_2_config_persistence_roundtrip() -> void:
	# 1. Set Classic Serif and save
	FontManager.set_font(FontManager.FONT_CLASSIC_SERIF)
	AppSettings.save_config()

	# 2. Reset in-memory to Modern Sans, then load_config
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	AppSettings.load_config()
	assert_true(FontManager.current_font_name == FontManager.FONT_CLASSIC_SERIF, "Kalıcılık: Classic Serif config.json'dan hatasız yüklendi")

	# 3. Set Rounded Sans and save
	FontManager.set_font(FontManager.FONT_ROUNDED_SANS)
	AppSettings.save_config()

	# 4. Reload
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	AppSettings.load_config()
	assert_true(FontManager.current_font_name == FontManager.FONT_ROUNDED_SANS, "Kalıcılık: Rounded Sans config.json'dan hatasız yüklendi")

# -----------------------------------------------------------------------------
# BOYUT 3: SettingsScreen Font Seçim Arayüzü (GDD §43)
# -----------------------------------------------------------------------------
func test_dimension_3_settings_screen_font_dropdown() -> void:
	var screen := SettingsScreen.new()
	ui_root.add_child(screen)

	assert_true(screen.font_label != null, "SettingsScreen font_label etiketine sahip")
	assert_true(screen.font_option != null, "SettingsScreen font_option seçim kutusuna sahip")
	assert_true(screen.font_option.item_count == 3, "font_option 3 seçeneğe sahip")

	# Simulate user selecting Modern Sans (idx 0)
	screen._on_font_selected(0)
	assert_true(FontManager.current_font_name == FontManager.FONT_MODERN_SANS, "Kullanıcı Seçimi 0: Modern Sans aktif")
	assert_true(screen.font_option.selected == 0, "OptionButton seçimi 0 olarak güncellendi")

	# Simulate user selecting Rounded Sans (idx 1)
	screen._on_font_selected(1)
	assert_true(FontManager.current_font_name == FontManager.FONT_ROUNDED_SANS, "Kullanıcı Seçimi 1: Rounded Sans aktif")
	assert_true(screen.font_option.selected == 1, "OptionButton seçimi 1 olarak güncellendi")

	# Simulate user selecting Classic Serif (idx 2)
	screen._on_font_selected(2)
	assert_true(FontManager.current_font_name == FontManager.FONT_CLASSIC_SERIF, "Kullanıcı Seçimi 2: Classic Serif aktif")
	assert_true(screen.font_option.selected == 2, "OptionButton seçimi 2 olarak güncellendi")

	screen.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 4: ThemeManager & Dinamik Hot-Swap (GDD §39)
# -----------------------------------------------------------------------------
func test_dimension_4_theme_manager_and_hotswap() -> void:
	var listener_fired := [false]
	var cb := func(): listener_fired[0] = true
	FontManager.add_listener(cb)

	# 1. Change font -> listener must fire
	FontManager.set_font(FontManager.FONT_MODERN_SANS)
	FontManager.set_font(FontManager.FONT_CLASSIC_SERIF)
	assert_true(listener_fired[0] == true, "FontManager.set_font listener'ı anında tetikledi (Hot-Swap)")

	# 2. ThemeManager.build_godot_theme() must reflect new font
	var theme := ThemeManager.build_godot_theme()
	assert_true(theme.default_font != null, "ThemeManager üretilen temada default_font atandı")
	assert_true(theme.default_font == FontManager.get_current_font(), "Temadaki default_font aktif FontManager fontu ile birebir eşleşiyor")

	FontManager.remove_listener(cb)

# -----------------------------------------------------------------------------
# BOYUT 5: Çoklu Dil (Localization TR/EN) Senkronizasyonu (GDD §44)
# -----------------------------------------------------------------------------
func test_dimension_5_localization_sync() -> void:
	# 1. TR translations
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	assert_true(LocalizationManager.translate("SETTING_FONT") == "Yazı tipi", "TR Çeviri: SETTING_FONT doğru")
	assert_true(LocalizationManager.translate("FONT_MODERN_SANS").contains("Modern"), "TR Çeviri: FONT_MODERN_SANS mevcut")
	assert_true(LocalizationManager.translate("FONT_ROUNDED_SANS") == "Yuvarlak", "TR Çeviri: FONT_ROUNDED_SANS mevcut")
	assert_true(LocalizationManager.translate("FONT_CLASSIC_SERIF") == "Klasik", "TR Çeviri: FONT_CLASSIC_SERIF mevcut")

	# 2. EN translations
	LocalizationManager.set_locale(LocalizationManager.LOCALE_EN)
	assert_true(LocalizationManager.translate("SETTING_FONT") == "Font", "EN Çeviri: SETTING_FONT doğru")
	assert_true(LocalizationManager.translate("FONT_MODERN_SANS").contains("Modern"), "EN Çeviri: FONT_MODERN_SANS mevcut")
	assert_true(LocalizationManager.translate("FONT_ROUNDED_SANS") == "Rounded", "EN Çeviri: FONT_ROUNDED_SANS mevcut")
	assert_true(LocalizationManager.translate("FONT_CLASSIC_SERIF") == "Classic", "EN Çeviri: FONT_CLASSIC_SERIF mevcut")

# -----------------------------------------------------------------------------
# BOYUT 6: Hücre Tipografisi & Sıfır-Gecikme Stres Testi (GDD §49)
# -----------------------------------------------------------------------------
func test_dimension_6_cell_typography_and_zero_lag() -> void:
	var cell := SudokuCell.new()
	ui_root.add_child(cell)
	cell._ready()

	# Verify cell renders without error under all 3 font families
	for family in FontManager.FONT_FAMILIES:
		FontManager.set_font(family)
		cell.set_cell_data(7, true, 0, false, false, false, false, false)
		assert_true(cell.num_label.text == "7", "Hücre verisi %s altında hatasız görüntülendi" % family)

	# Zero-Lag Stress: 50 consecutive font switches
	var t0 := Time.get_ticks_msec()
	for i in range(50):
		var target := FontManager.FONT_FAMILIES[i % 3]
		FontManager.set_font(target)
	var elapsed := Time.get_ticks_msec() - t0
	assert_true(elapsed < 50, "Sıfır-Gecikme (Zero-Lag): 50 font değişimi %d ms içinde tamamlandı (< 50 ms)" % elapsed)

	cell.queue_free()

# -----------------------------------------------------------------------------
# Durum Yedekleme ve Geri Yükleme Yardımcıları
# -----------------------------------------------------------------------------
func _backup_state() -> void:
	orig_font = FontManager.current_font_name
	if FileAccess.file_exists(AppSettings.CONFIG_PATH):
		var f := FileAccess.open(AppSettings.CONFIG_PATH, FileAccess.READ)
		if f != null:
			orig_config = f.get_as_text()
			f.close()

func _restore_state() -> void:
	FontManager.set_font(orig_font)
	if not orig_config.is_empty():
		var f := FileAccess.open(AppSettings.CONFIG_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(orig_config)
			f.close()
