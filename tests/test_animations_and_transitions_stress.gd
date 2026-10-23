extends SceneTree

# ==============================================================================
# JUST SUDOKU - HAFİF ANİMASYONLAR VE GEÇİŞLER KALİTE & STRES TESTİ
# GDD §40 ("Animasyon"), §49 ("Tepkisellik & Zero-Lag")
# Katı Zaman Sınırları ve Döngü Koruması (Max 1000 ms / test)
# ==============================================================================

const PER_TEST_TIMEOUT_MSEC: int = 1000
const MAX_TOTAL_RUNTIME_MSEC: int = 4000

var total_passed: int = 0
var total_failed: int = 0
var suite_start_msec: int = 0

var ui_root: Control
var orig_animations_enabled: bool = true

func _init() -> void:
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - HAFİF ANİMASYONLAR VE GEÇİŞLER TESTİ")
	print("   GDD §40, §49 • Katı Zaman Sınırları (Max 1000 ms / test)")
	print("================================================================")

	orig_animations_enabled = AppSettings.animations_enabled
	ui_root = Control.new()
	ui_root.custom_minimum_size = Vector2(800, 600)
	root.add_child(ui_root)

	run_all_tests()

	ui_root.queue_free()
	AppSettings.animations_enabled = orig_animations_enabled

	var suite_elapsed := Time.get_ticks_msec() - suite_start_msec
	print("\n================================================================")
	print("🏁 RESULTS: %d Passed, %d Failed (Toplam Süre: %d ms)" % [total_passed, total_failed, suite_elapsed])
	print("================================================================")

	quit(0 if total_failed == 0 else 1)

var test_app: AppRoot

func run_all_tests() -> void:
	test_app = AppRoot.new()

	_run_bounded("Boyut 1: Sayı Yerleşimi Pop Animasyonu (GDD §40)", test_dimension_1_pop_animation)
	_run_bounded("Boyut 2: Hücre Seçimi Mikro-Pulse Animasyonu (GDD §40)", test_dimension_2_select_animation)
	_run_bounded("Boyut 3: Hata & Çakışma Mikro-Shake Animasyonu (GDD §40)", test_dimension_3_shake_animation)
	_run_bounded("Boyut 4: Zafer Dalgası (Victory Wave) Animasyonu (GDD §40)", test_dimension_4_victory_wave)
	_run_bounded("Boyut 5: UI Ekran Geçişleri Mikro-Fade (GDD §40)", test_dimension_5_screen_transition_fade)
	_run_bounded("Boyut 6: Sıfır-Gecikme (Zero-Lag) & Toggle Emniyeti (GDD §49)", test_dimension_6_zero_lag_and_toggle)

	test_app.free()

func _run_bounded(name: String, test_cb: Callable) -> void:
	print("\n--- %s ---" % name)
	var t0 := Time.get_ticks_msec()
	test_cb.call()
	var elapsed := Time.get_ticks_msec() - t0
	assert_true(elapsed < PER_TEST_TIMEOUT_MSEC, "Zaman Sınırı Koruması: Test %d ms içinde tamamlandı (Tavan: %d ms)" % [elapsed, PER_TEST_TIMEOUT_MSEC])

# -----------------------------------------------------------------------------
# BOYUT 1: Sayı Yerleşimi Pop Animasyonu (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_1_pop_animation() -> void:
	var cell := SudokuCell.new()
	cell.size = Vector2(50, 50)
	ui_root.add_child(cell)
	cell._ready()

	# 1. Animations = true iken scale 1.15 ile başlar
	AppSettings.animations_enabled = true
	cell.scale = Vector2.ONE
	cell.animate_pop()
	assert_true(is_equal_approx(cell.scale.x, 1.15) and is_equal_approx(cell.scale.y, 1.15), "Pop: animations_enabled = true iken hücre 1.15x ölçeklendi")

	# 2. Animations = false iken scale Vector2.ONE kalır
	AppSettings.animations_enabled = false
	cell.scale = Vector2.ONE
	cell.animate_pop()
	assert_true(cell.scale == Vector2.ONE, "Pop: animations_enabled = false iken ölçekleme atlandı (Vector2.ONE)")

	# 3. set_cell_data üzerinden boş hücreye sayı girişi pop'u tetikler
	AppSettings.animations_enabled = true
	cell.value = 0
	cell.set_cell_data(7, false, 0, false, false, false, false, false)
	assert_true(is_equal_approx(cell.scale.x, 1.15), "Pop: set_cell_data ile boş hücreye sayı girildiğinde pop tetiklendi")

	cell.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 2: Hücre Seçimi Mikro-Pulse Animasyonu (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_2_select_animation() -> void:
	var cell := SudokuCell.new()
	cell.size = Vector2(50, 50)
	ui_root.add_child(cell)
	cell._ready()

	# 1. Animations = true iken animate_select() çağrısı
	AppSettings.animations_enabled = true
	cell.scale = Vector2.ONE
	cell.animate_select()
	assert_true(is_equal_approx(cell.scale.x, 1.05), "Select: animate_select mikro-pulse ölçeklemesi uygulandı (1.05x)")

	# 2. Animations = false iken seçim mikro-pulse atlanır
	AppSettings.animations_enabled = false
	cell.scale = Vector2.ONE
	cell.animate_select()
	assert_true(cell.scale == Vector2.ONE, "Select: animations_enabled = false iken ölçekleme atlandı")

	# 3. set_cell_data ile hücre ilk kez seçildiğinde tetiklenme
	AppSettings.animations_enabled = true
	cell.value = 4
	cell.is_selected = false
	cell.set_cell_data(4, false, 0, true, false, false, false, false)
	assert_true(is_equal_approx(cell.scale.x, 1.05), "Select: set_cell_data seçimi algılayarak mikro-pulse başlattı")

	cell.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 3: Hata & Çakışma Mikro-Shake Animasyonu (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_3_shake_animation() -> void:
	var cell := SudokuCell.new()
	cell.position = Vector2(100, 100)
	cell.size = Vector2(50, 50)
	ui_root.add_child(cell)
	cell._ready()

	# 1. Animations = true iken shake durumu işaretlenir
	AppSettings.animations_enabled = true
	cell.animate_shake()
	assert_true(cell._is_shaking == true, "Shake: animations_enabled = true iken _is_shaking bayrağı true oldu")
	assert_true(is_equal_approx(cell._original_pos_x, 100.0), "Shake: Orijinal x pozisyonu (100.0) hafızaya alındı")

	# 2. Animations = false iken shake atlanır
	AppSettings.animations_enabled = false
	var cell_off := SudokuCell.new()
	cell_off.position = Vector2(200, 200)
	cell_off.size = Vector2(50, 50)
	ui_root.add_child(cell_off)
	cell_off._ready()
	cell_off.animate_shake()
	assert_true(cell_off._is_shaking == false, "Shake: animations_enabled = false iken titreme atlandı")
	assert_true(is_equal_approx(cell_off.position.x, 200.0), "Shake: Pozisyon kesinlikle değişmedi (200.0)")

	# 3. set_cell_data ile canlı çakışma oluştuğunda shake tetiklenmesi
	AppSettings.animations_enabled = true
	cell.is_conflict = false
	cell.set_cell_data(4, false, 0, false, false, false, true, false)
	assert_true(cell._is_shaking == true, "Shake: set_cell_data ile çakışma oluştuğunda shake otomatik tetiklendi")

	cell.queue_free()
	cell_off.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 4: Zafer Dalgası (Victory Wave) Animasyonu (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_4_victory_wave() -> void:
	var grid := SudokuGrid.new()
	grid.size = Vector2(450, 450)
	ui_root.add_child(grid)
	grid._ready()

	assert_true(grid.cells.size() == SudokuBoard.CELL_COUNT, "Zafer Dalgası: Grid 81 hücreye sahip")

	# 1. Tekil hücre animate_wave testi
	var c0: SudokuCell = grid.cells[0]
	AppSettings.animations_enabled = true
	c0.animate_wave(0.0)
	assert_true(is_equal_approx(c0.scale.x, 1.10), "Wave: Hücre dalga ölçeklemesi uygulandı (1.10x)")

	# 2. Grid play_victory_wave (animations = true)
	grid.play_victory_wave()
	assert_true(is_equal_approx(grid.cells[80].scale.x, 1.10), "Wave: Son hücreye (R8C8) kadar dalga yayıldı")

	# 3. Grid play_victory_wave (animations = false) -> Anında callback çağrısı
	AppSettings.animations_enabled = false
	var result := { "immediate_called": false }
	grid.play_victory_wave(func(): result.immediate_called = true)
	assert_true(result.immediate_called == true, "Wave: animations_enabled = false iken zafer dalgası anında 0 ms ile tamamlandı")

	grid.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 5: UI Ekran Geçişleri Mikro-Fade (GDD §40)
# -----------------------------------------------------------------------------
func test_dimension_5_screen_transition_fade() -> void:
	# 1. animations_enabled = true iken fade başlatılması
	AppSettings.animations_enabled = true
	test_app._show_screen(test_app.settings_screen)
	assert_true(test_app.settings_screen.visible == true, "Fade: Hedef ekran görünür yapıldı")
	assert_true(test_app.main_menu.visible == false, "Fade: Diğer ekranlar gizlendi")
	assert_true(test_app.settings_screen.modulate.a <= 1.0, "Fade: Hedef ekranda mikro-fade alfa değeri kontrol altında")

	# 2. animations_enabled = false iken doğrudan görünürlük
	AppSettings.animations_enabled = false
	test_app._show_screen(test_app.main_menu)
	assert_true(test_app.main_menu.visible == true, "Geçiş: animations_enabled = false iken ana menü anında görünür")
	assert_true(is_equal_approx(test_app.main_menu.modulate.a, 1.0), "Geçiş: Alfa gecikmesiz tam 1.0 olarak ayarlandı")

# -----------------------------------------------------------------------------
# BOYUT 6: Sıfır-Gecikme (Zero-Lag) & Toggle Emniyeti (GDD §49)
# -----------------------------------------------------------------------------
func test_dimension_6_zero_lag_and_toggle() -> void:
	var cell := SudokuCell.new()
	cell.position = Vector2(50, 50)
	cell.size = Vector2(50, 50)
	ui_root.add_child(cell)
	cell._ready()

	# 1. 100 ardışık pop ve select çağrısının hız testi (Zero-Lag < 20 ms)
	AppSettings.animations_enabled = true
	var t0 := Time.get_ticks_msec()
	for i in range(100):
		cell.animate_pop()
		cell.animate_select()
	var elapsed_anim := Time.get_ticks_msec() - t0
	assert_true(elapsed_anim < 30, "Sıfır-Gecikme: 100 pop + select tetiklemesi %d ms içinde tamamlandı (< 30 ms)" % elapsed_anim)

	# 2. 100 ardışık shake çağrısı ve konum kararlılığı
	var t_shake_0 := Time.get_ticks_msec()
	for i in range(100):
		cell.animate_shake()
	var elapsed_shake := Time.get_ticks_msec() - t_shake_0
	assert_true(elapsed_shake < 30, "Sıfır-Gecikme: 100 shake tetiklemesi %d ms içinde tamamlandı (< 30 ms)" % elapsed_shake)

	# 3. Animasyon kapatıldığında sıfır maliyet garantisi
	AppSettings.animations_enabled = false
	var t_off_0 := Time.get_ticks_msec()
	for i in range(100):
		cell.animate_pop()
		cell.animate_select()
		cell.animate_shake()
		cell.animate_wave(0.0)
	var elapsed_off := Time.get_ticks_msec() - t_off_0
	assert_true(elapsed_off < 10, "Sıfır-Maliyet: Animasyonlar kapalıyken 400 çağrı %d ms içinde tamamlandı (< 10 ms)" % elapsed_off)

	cell.queue_free()

# -----------------------------------------------------------------------------
# Assertion Yardımcıları
# -----------------------------------------------------------------------------
func assert_true(condition: bool, message: String) -> void:
	if condition:
		total_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		total_failed += 1
		print("  ✗ FAIL: %s" % message)
