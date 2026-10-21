extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const StatisticsManager = preload("res://scripts/data/statistics_manager.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var suite_start_msec: int = 0

const PER_TEST_TIMEOUT_MSEC: int = 1000

var test_gen: SudokuGenerator.GeneratedPuzzle

# Backup storage to restore existing player data after test suite finishes
var original_active_game: String = ""
var original_bak1: String = ""
var original_bak2: String = ""
var original_history: String = ""
var original_daily: String = ""
var original_index: String = ""

func _init() -> void:
	LocalizationManager.set_locale(LocalizationManager.LOCALE_TR)
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - VERİ KATMANI & PAYLAŞIM KALİTE TESTİ")
	print("   GDD §27-§35 • Katı Zaman Sınırları (Max %d ms / test)" % PER_TEST_TIMEOUT_MSEC)
	print("================================================================")

	_backup_user_data()

	# Prepare single deterministic test puzzle
	var t0: int = Time.get_ticks_msec()
	test_gen = SudokuGenerator.generate(1001, DifficultyAnalyzer.LEVEL_EASY)
	print("[Ön Hazırlık: Deterministik Test Bulmacası Hazırlandı (%d ms)]" % (Time.get_ticks_msec() - t0))

	run_bounded_test("Boyut 1: Atomik Kayıt, Çoklu Slot & Snapshot (GDD §27)", test_dimension_1_atomic_save_slots_snapshot)
	run_bounded_test("Boyut 2: Crash Recovery & 3 Aşamalı Yedek Kurtarma (GDD §32)", test_dimension_2_crash_recovery_3_state)
	run_bounded_test("Boyut 3: Günlük Sudoku Determinizmi & Streak Mantığı (GDD §34, §35)", test_dimension_3_daily_sudoku_determinism_and_streaks)
	run_bounded_test("Boyut 4: Geçmiş (History) Kaydı, Filtreleme & Best Record (GDD §31)", test_dimension_4_history_recording_filtering_sorting)
	run_bounded_test("Boyut 5: İstatistik Motoru (Statistics Aggregation) & Metrikler (GDD §33)", test_dimension_5_statistics_aggregation)
	run_bounded_test("Boyut 6: Paylaşım Export & Çoklu Format Import Doğrulaması (GDD §28, §29)", test_dimension_6_share_export_and_multi_format_import)
	run_bounded_test("Boyut 7: Hatalı / Bozuk Veri Emniyeti & Validasyon (GDD §29)", test_dimension_7_malformed_and_invalid_data_safety)

	_restore_user_data()

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
# BOYUT 1: Atomik Kayıt, Çoklu Slot ve Snapshot Bütünlüğü (GDD §27)
# -----------------------------------------------------------------------------
func test_dimension_1_atomic_save_slots_snapshot() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# Find editable empty cells
	var e1: int = -1
	var e2: int = -1
	for i in range(SudokuBoard.CELL_COUNT):
		if not state.initial_puzzle.is_given(i):
			if e1 == -1:
				e1 = i
			elif e2 == -1:
				e2 = i
				break

	# Modify state
	state.set_number(e1, 7)
	state.toggle_candidate(e2, 4)
	state.toggle_candidate(e2, 9)
	state.elapsed_time = 145.5

	# 1. Save active game (Atomic write verification)
	var saved := SaveManager.save_active_game(state)
	assert_true(saved == true, "SaveManager.save_active_game başarıyla kaydedildi")
	assert_true(FileAccess.file_exists(SaveManager.ACTIVE_GAME_FILE), "active_game.json dosyası mevcut")
	assert_true(not FileAccess.file_exists(SaveManager.ACTIVE_GAME_FILE + ".tmp"), "Atomik yazım tamamlandı (.tmp dosyası temizlendi)")

	# 2. Round-trip deserialization verification
	var loaded := SaveManager.load_active_game()
	assert_true(loaded != null, "Aktif oyun başarıyla yüklendi")
	assert_true(loaded.seed_value == state.seed_value, "Seed değeri kayıpsız korundu: %d" % loaded.seed_value)
	assert_true(loaded.current_board.get_cell(e1) == 7, "Hücre verisi (7) kayıpsız korundu")
	assert_true(loaded.current_board.has_candidate(e2, 4) and loaded.current_board.has_candidate(e2, 9), "Aday notları (4, 9) kayıpsız korundu")
	assert_true(is_equal_approx(loaded.elapsed_time, 145.5), "Geçen süre (145.5s) kayıpsız korundu")

	# 3. Multi-slot save and index verification
	var slot_saved := SaveManager.save_game_slot(state)
	assert_true(slot_saved == true, "Oyun yuvası başarıyla kaydedildi (slot_path)")
	var index_data := SaveManager.get_games_index()
	assert_true(index_data.has(state.game_id), "games_index.json içerisinde game_id girişi mevcut")
	var entry: Dictionary = index_data[state.game_id]
	assert_true(entry.get("seed", 0) == state.seed_value, "İndeks seed verisi doğru")
	assert_true(entry.has("progress_percentage"), "İlerletme yüzdesi indekste hesaplandı")

	var active_list := SaveManager.list_active_games()
	assert_true(active_list.size() >= 1, "list_active_games aktif yuvaları listeledi")

	# 4. Slot deletion
	var deleted := SaveManager.delete_game_slot(state.game_id)
	assert_true(deleted == true, "Oyun yuvası başarıyla silindi")
	var re_index := SaveManager.get_games_index()
	assert_true(not re_index.has(state.game_id), "Silinen oyun indeks tablosundan kaldırıldı")

# -----------------------------------------------------------------------------
# BOYUT 2: Crash Recovery & 3 Aşamalı Yedek Kurtarma (GDD §32)
# -----------------------------------------------------------------------------
func test_dimension_2_crash_recovery_3_state() -> void:
	# State 1 (Seed 1111)
	var s1 := GameState.new()
	s1.init_from_puzzle(test_gen)
	s1.seed_value = 1111
	s1.game_id = "test_s1_1111"
	SaveManager.save_active_game(s1)

	# State 2 (Seed 2222) -> Pushes s1 to bak1
	var s2 := GameState.new()
	s2.init_from_puzzle(test_gen)
	s2.seed_value = 2222
	s2.game_id = "test_s2_2222"
	SaveManager.save_active_game(s2)

	# State 3 (Seed 3333) -> Pushes s2 to bak1, s1 to bak2
	var s3 := GameState.new()
	s3.init_from_puzzle(test_gen)
	s3.seed_value = 3333
	s3.game_id = "test_s3_3333"
	SaveManager.save_active_game(s3)

	# Verify backup rotation exists
	assert_true(FileAccess.file_exists(SaveManager.BACKUP_1_FILE), "Yedek 1 (bak1) rotasyonla oluşturuldu")
	assert_true(FileAccess.file_exists(SaveManager.BACKUP_2_FILE), "Yedek 2 (bak2) rotasyonla oluşturuldu")

	# Scenario A: Normal load loads newest (3333)
	var normal_loaded := SaveManager.load_active_game()
	assert_true(normal_loaded != null and normal_loaded.seed_value == 3333, "Normal yükleme en son aktif kaydı getirdi (Seed 3333)")

	# Scenario B: Corrupt active_game.json -> should fallback to bak1 (2222)
	var f_act := FileAccess.open(SaveManager.ACTIVE_GAME_FILE, FileAccess.WRITE)
	f_act.store_string("INVALID_JSON_{{CRASH_CORRUPTED_SYNTAX")
	f_act.close()

	var rec1 := SaveManager.load_active_game()
	assert_true(rec1 != null, "Crash Recovery: Bozuk active_game.json durumunda çökmedi")
	assert_true(rec1 != null and rec1.seed_value == 2222, "Crash Recovery 1: Yedek 1'den (bak1) Seed 2222 başarıyla kurtarıldı")

	# Scenario C: Corrupt bak1 too -> should fallback to bak2 (1111)
	var f_bak1 := FileAccess.open(SaveManager.BACKUP_1_FILE, FileAccess.WRITE)
	f_bak1.store_string("CORRUPTED_BAK1_{{{SYNTAX_ERR")
	f_bak1.close()

	var rec2 := SaveManager.load_active_game()
	assert_true(rec2 != null, "Crash Recovery: İki dosya birden bozulduğunda çökmedi")
	assert_true(rec2 != null and rec2.seed_value == 1111, "Crash Recovery 2: Yedek 2'den (bak2) Seed 1111 başarıyla kurtarıldı")

	# Scenario D: Corrupt bak2 as well -> graceful null, no crash
	var f_bak2 := FileAccess.open(SaveManager.BACKUP_2_FILE, FileAccess.WRITE)
	f_bak2.store_string("ALL_CORRUPTED")
	f_bak2.close()

	var rec_fail := SaveManager.load_active_game()
	assert_true(rec_fail == null, "Crash Recovery 3: Tüm dosyalar bozulduğunda zarifçe null dönüldü (Crash önlendi)")

# -----------------------------------------------------------------------------
# BOYUT 3: Günlük Sudoku Determinizmi & Streak Mantığı (GDD §34, §35)
# -----------------------------------------------------------------------------
func test_dimension_3_daily_sudoku_determinism_and_streaks() -> void:
	# 1. Determinism
	var seed_oct3_a := DailyManager.get_seed_for_date(2026, 10, 3)
	var seed_oct3_b := DailyManager.get_seed_for_date(2026, 10, 3)
	var seed_oct4 := DailyManager.get_seed_for_date(2026, 10, 4)
	assert_true(seed_oct3_a == seed_oct3_b, "Günlük Sudoku Determinizmi: Aynı tarih daima aynı tohumu üretir (%d)" % seed_oct3_a)
	assert_true(seed_oct3_a != seed_oct4, "Günlük Sudoku Çeşitliliği: Farklı tarihler farklı tohumlar üretir")

	# Reset daily data for clean test
	DailyManager.save_daily_data({
		"completed_dates": [],
		"current_streak": 0,
		"longest_streak": 0,
		"last_completed_date": ""
	})

	# 2. Day 1 completion
	DailyManager.mark_date_completed(2026, 10, 1)
	assert_true(DailyManager.get_current_streak() == 1, "Gün 1 Tamamlama: current_streak = 1")
	assert_true(DailyManager.get_longest_streak() == 1, "Gün 1 Tamamlama: longest_streak = 1")

	# 3. Idempotency (same day played again)
	DailyManager.mark_date_completed(2026, 10, 1)
	assert_true(DailyManager.get_current_streak() == 1, "Idempotency: Aynı gün tekrar tamamlandığında mükerrer seri artışı engellendi")

	# 4. Day 2 completion (Consecutive)
	DailyManager.mark_date_completed(2026, 10, 2)
	assert_true(DailyManager.get_current_streak() == 2, "Ardışık Gün 2: current_streak = 2")
	assert_true(DailyManager.get_longest_streak() == 2, "Ardışık Gün 2: longest_streak = 2")

	# 5. Day 4 completion (Skip Day 3 -> Streak broken)
	DailyManager.mark_date_completed(2026, 10, 4)
	assert_true(DailyManager.get_current_streak() == 1, "Gün Atlandı: Seri kırılarak current_streak = 1'e sıfırlandı")
	assert_true(DailyManager.get_longest_streak() == 2, "En Uzun Seri Korundu: longest_streak = 2 olarak muhafaza edildi")

	assert_true(DailyManager.is_date_completed("2026-10-02") == true, "is_date_completed(2026-10-02) = true")
	assert_true(DailyManager.is_date_completed("2026-10-03") == false, "is_date_completed(2026-10-03) = false")

# -----------------------------------------------------------------------------
# BOYUT 4: Geçmiş (History) Kaydı, Filtreleme, Sıralama & Best Record (GDD §31)
# -----------------------------------------------------------------------------
func test_dimension_4_history_recording_filtering_sorting() -> void:
	HistoryManager.save_all_records([])

	# Add 4 diverse records
	HistoryManager.add_record({
		"game_id": "g_easy_1", "seed": 7001, "difficulty": DifficultyAnalyzer.LEVEL_EASY,
		"score": 100, "time": 120.0, "mistakes": 0, "hints": 0, "is_replay": false
	})
	HistoryManager.add_record({
		"game_id": "g_med_1", "seed": 7002, "difficulty": DifficultyAnalyzer.LEVEL_MEDIUM,
		"score": 80, "time": 300.0, "mistakes": 2, "hints": 1, "is_replay": false
	})
	HistoryManager.add_record({
		"game_id": "g_med_rep", "seed": 7002, "difficulty": DifficultyAnalyzer.LEVEL_MEDIUM,
		"score": 95, "time": 180.0, "mistakes": 0, "hints": 0, "is_replay": true
	})
	HistoryManager.add_record({
		"game_id": "g_hard_1", "seed": 7003, "difficulty": DifficultyAnalyzer.LEVEL_HARD,
		"score": 75, "time": 450.0, "mistakes": 1, "hints": 0, "is_replay": false
	})

	var all_recs := HistoryManager.load_all_records()
	assert_true(all_recs.size() == 4, "4 adet oyun geçmiş kaydı başarıyla eklendi")

	# 1. Filter by difficulty
	var hard_only := HistoryManager.get_filtered_history(DifficultyAnalyzer.LEVEL_HARD, "All", "Newest")
	assert_true(hard_only.size() == 1 and hard_only[0].get("game_id") == "g_hard_1", "Zorluk Filtresi: Sadece Hard oyun getirildi")

	# 2. Filter by Replay status
	var standard_only := HistoryManager.get_filtered_history("All", "Standard", "Newest")
	assert_true(standard_only.size() == 3, "Durum Filtresi: Standard filtresi 3 normal oyunu getirdi")
	var replay_only := HistoryManager.get_filtered_history("All", "Replay", "Newest")
	assert_true(replay_only.size() == 1 and replay_only[0].get("game_id") == "g_med_rep", "Durum Filtresi: Replay filtresi sadece replay oyununu getirdi")

	# 3. Sorting
	var fastest := HistoryManager.get_filtered_history("All", "All", "Fastest")
	assert_true(fastest[0].get("time") == 120.0, "Sıralama: Fastest filtresinde en hızlı oyun (120s) ilk sırada")

	var best_score_list := HistoryManager.get_filtered_history("All", "All", "Best Score")
	assert_true(best_score_list[0].get("score") == 100, "Sıralama: Best Score filtresinde 100 puanlı oyun ilk sırada")

	# 4. Best record for seed tie-break (GDD §26)
	var best_for_7002 := HistoryManager.get_best_record_for_seed(7002)
	assert_true(best_for_7002.get("score") == 95 and best_for_7002.get("is_replay") == true, "Seed 7002 için Replay'de yapılan 95 puanlık en iyi kayıt seçildi")

# -----------------------------------------------------------------------------
# BOYUT 5: İstatistik Motoru (Statistics Aggregation) & Metrikler (GDD §33)
# -----------------------------------------------------------------------------
func test_dimension_5_statistics_aggregation() -> void:
	var summary := StatisticsManager.get_summary_statistics()
	assert_true(summary.get("completed_games", 0) == 4, "İstatistik Özeti: completed_games = 4")
	assert_true(summary.get("best_score", 0) == 100, "İstatistik Özeti: best_score = 100")
	assert_true(summary.get("average_time", 0.0) > 0.0, "İstatistik Özeti: average_time hesaplandı (> 0)")
	assert_true(summary.get("completion_rate", 0.0) == 100.0, "İstatistik Özeti: completion_rate = 100%")

	var detailed := StatisticsManager.get_detailed_statistics()
	assert_true(detailed.has("difficulties"), "Detaylı istatistik zorluk dökümlerini içeriyor")
	var diffs: Dictionary = detailed["difficulties"]

	# Check played difficulties
	assert_true(diffs[DifficultyAnalyzer.LEVEL_EASY]["count"] == 1, "Easy tamamlanan oyun: 1")
	assert_true(diffs[DifficultyAnalyzer.LEVEL_MEDIUM]["count"] == 2, "Medium tamamlanan oyun: 2")
	assert_true(diffs[DifficultyAnalyzer.LEVEL_HARD]["count"] == 1, "Hard tamamlanan oyun: 1")

	# Check unplayed difficulty: Expert (Zero-division safety)
	assert_true(diffs[DifficultyAnalyzer.LEVEL_EXPERT]["count"] == 0, "Expert tamamlanan oyun: 0")
	assert_true(diffs[DifficultyAnalyzer.LEVEL_EXPERT]["avg_time"] == 0.0, "Sıfıra Bölme Koruması: Oynanmamış seviyede avg_time = 0.0")
	assert_true(diffs[DifficultyAnalyzer.LEVEL_EXPERT]["best_time"] == 0.0, "Sıfıra Bölme Koruması: Oynanmamış seviyede best_time = 0.0")

# -----------------------------------------------------------------------------
# BOYUT 6: Paylaşım Export & Çoklu Format Import Doğrulaması (GDD §28, §29)
# -----------------------------------------------------------------------------
func test_dimension_6_share_export_and_multi_format_import() -> void:
	var board: SudokuBoard = test_gen.puzzle
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# 1. Share text export
	var export_txt := PuzzleShareService.export_puzzle_share_text(1001, DifficultyAnalyzer.LEVEL_EASY, board)
	assert_true(export_txt.contains("Just Sudoku"), "Paylaşım Metni: 'Just Sudoku' başlığı içeriyor")
	assert_true(export_txt.contains("Seed: 1001"), "Paylaşım Metni: Seed bilgisini içeriyor")
	assert_true(export_txt.contains("Kod:"), "Paylaşım Metni: 81 karakterlik bulmaca kodunu içeriyor")

	# 2. Import format: Structured text
	var res1 := PuzzleShareService.parse_import_string(export_txt)
	assert_true(res1.get("success", false) == true, "İçe Aktarma (Yapılandırılmış Metin): Başarıyla parse edildi")
	assert_true(res1.get("type") == "puzzle_code", "İçe Aktarma Türü: 'puzzle_code' olarak algılandı")
	assert_true(res1.get("seed") == 1001, "İçe Aktarma: Seed 1001 doğrulandı")

	# 3. Import format: Raw 81-char string
	var raw_81 := board.to_string_flat()
	var res2 := PuzzleShareService.parse_import_string(raw_81)
	assert_true(res2.get("success", false) == true, "İçe Aktarma (Ham 81 Karakter): Başarıyla parse edildi")
	assert_true(res2.get("type") == "puzzle_code", "İçe Aktarma Türü: 'puzzle_code'")
	var imported_state: GameState = res2.get("game_state")
	assert_true(imported_state != null and imported_state.initial_puzzle.get_empty_cell_count() == board.get_empty_cell_count(), "İçe Aktarılan Tahta: Boş hücre sayısı orijinal ile tam eşleşiyor")

	# 4. Import format: Raw Seed number
	var res3 := PuzzleShareService.parse_import_string("889977")
	assert_true(res3.get("success", false) == true, "İçe Aktarma (Ham Seed): Başarıyla parse edildi")
	assert_true(res3.get("type") == "seed", "İçe Aktarma Türü: 'seed'")
	assert_true(res3.get("seed") == 889977, "İçe Aktarma: Seed 889977 olarak algılandı")

	# 5. Import format: Save Game JSON string
	var json_str := SaveManager.export_game_to_string(state)
	var res4 := PuzzleShareService.parse_import_string(json_str)
	assert_true(res4.get("success", false) == true, "İçe Aktarma (Kayıt JSON): Başarıyla parse edildi")
	assert_true(res4.get("type") == "save_json", "İçe Aktarma Türü: 'save_json'")
	assert_true(res4.get("seed") == 1001, "İçe Aktarma: JSON içindeki seed 1001")

# -----------------------------------------------------------------------------
# BOYUT 7: Hatalı / Bozuk Veri Emniyeti & Validasyon (GDD §29)
# -----------------------------------------------------------------------------
func test_dimension_7_malformed_and_invalid_data_safety() -> void:
	# 1. Empty input
	var res_empty := PuzzleShareService.parse_import_string("   ")
	assert_true(res_empty.get("success", true) == false, "Boş Metin Emniyeti: Boş girdi başarıyla reddedildi")
	assert_true(res_empty.get("type") == "empty", "Hata türü: 'empty'")

	# 2. Invalid string format
	var res_invalid := PuzzleShareService.parse_import_string("bu_bir_sudoku_degildir_tamamen_rastgele_yazi")
	assert_true(res_invalid.get("success", true) == false, "Geçersiz Metin: Tanınmayan format reddedildi")

	# 3. Corrupted JSON
	var res_bad_json := PuzzleShareService.parse_import_string("{\"game_id\": \"test\", broken_json: ...")
	assert_true(res_bad_json.get("success", true) == false, "Bozuk JSON: Hatalı JSON sözdizimi çökmeksizin reddedildi")

	# 4. 81-char puzzle with Row/Col Conflict (Invalid rules)
	# Take valid board and make two 5s in row 0
	var conflict_board := test_gen.puzzle.clone()
	conflict_board.set_cell(0, 5, false)
	conflict_board.set_cell(1, 5, false)
	var conflict_str := conflict_board.to_string_flat()
	var res_conflict := PuzzleShareService.parse_import_string(conflict_str)
	assert_true(res_conflict.get("success", true) == false, "Kural İhlali Emniyeti: Çakışmalı bulmaca reddedildi")
	assert_true(res_conflict.get("error", "").contains("çakışma"), "Hata mesajı çakışmayı bildirdi")

	# 5. Multiple solution puzzle rejection (Only 4 clues given)
	var multi_board := SudokuBoard.new()
	multi_board.set_cell(0, 1, false)
	multi_board.set_cell(1, 2, false)
	multi_board.set_cell(2, 3, false)
	multi_board.set_cell(3, 4, false)
	var multi_str := multi_board.to_string_flat()
	var res_multi := PuzzleShareService.parse_import_string(multi_str)
	assert_true(res_multi.get("success", true) == false, "Çoklu Çözüm Emniyeti: Birden fazla çözümü olan bulmaca reddedildi")
	assert_true(res_multi.get("error", "").contains("tek bir çözümü yok"), "Hata mesajı çoklu çözümü bildirdi")

# -----------------------------------------------------------------------------
# Test İzolasyonu ve Veri Yedekleme / Geri Yükleme Yardımcıları
# -----------------------------------------------------------------------------
func _backup_user_data() -> void:
	original_active_game = _read_file_safe(SaveManager.ACTIVE_GAME_FILE)
	original_bak1 = _read_file_safe(SaveManager.BACKUP_1_FILE)
	original_bak2 = _read_file_safe(SaveManager.BACKUP_2_FILE)
	original_history = _read_file_safe(HistoryManager.HISTORY_FILE)
	original_daily = _read_file_safe(DailyManager.DAILY_FILE)
	original_index = _read_file_safe(SaveManager.INDEX_FILE)

func _restore_user_data() -> void:
	_write_file_safe(SaveManager.ACTIVE_GAME_FILE, original_active_game)
	_write_file_safe(SaveManager.BACKUP_1_FILE, original_bak1)
	_write_file_safe(SaveManager.BACKUP_2_FILE, original_bak2)
	_write_file_safe(HistoryManager.HISTORY_FILE, original_history)
	_write_file_safe(DailyManager.DAILY_FILE, original_daily)
	_write_file_safe(SaveManager.INDEX_FILE, original_index)

func _read_file_safe(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	return content

func _write_file_safe(path: String, content: String) -> void:
	if content.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
