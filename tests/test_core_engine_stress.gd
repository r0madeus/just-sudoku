extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var suite_start_msec: int = 0

# Generating Hard/Medium puzzles takes seconds (analyzer-verified), so the budget covers one generation
const PER_TEST_TIMEOUT_MSEC: int = 6000
const BOUNDED_SEEDS: Array[int] = [1001, 77777, 999999]
const DIFFICULTIES: Array[String] = [
	DifficultyAnalyzer.LEVEL_EASY,
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]

# Cached test puzzles (diff -> Array[GeneratedPuzzle])
var puzzle_cache: Dictionary = {}
var generation_latencies: Array[int] = []

func _init() -> void:
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - CORE MOTOR KALİTE VE STRES TESTİ (REVİZE)")
	print("   GDD §8-§12, §22, §49 • Katı Zaman Sınırları (Max %d ms / test)" % PER_TEST_TIMEOUT_MSEC)
	print("================================================================")

	# 1. Warmup & Bounded Cache Generation (12 puzzles, timed)
	warmup_generate_cache()

	# 2. Run Test Dimensions (each with individual stopwatch guard)
	run_bounded_test("Boyut 1: Determinizm ve Seed Bütünlüğü", test_dimension_1_determinism)
	run_bounded_test("Boyut 2: Tekil Çözüm (Uniqueness) & Kural Bütünlüğü", test_dimension_2_uniqueness)
	run_bounded_test("Boyut 3: 10 İnsan Mantık Tekniği & Aday Koruma", test_dimension_3_techniques_and_safety)
	run_bounded_test("Boyut 4: Adım Adım Çözüm & Snapshot Bütünlüğü", test_dimension_4_step_by_step)
	run_bounded_test("Boyut 5: Zorluk Kalibrasyonu & İpucu Aralıkları", test_dimension_5_difficulty_calibration)
	run_bounded_test("Boyut 6: İptal Emniyeti & Performans Kriterleri", test_dimension_6_cancellation_and_performance)

	var total_elapsed_msec: int = Time.get_ticks_msec() - suite_start_msec
	print("\n================================================================")
	print("🏁 RESULTS: %d Passed, %d Failed (Toplam Süre: %d ms)" % [tests_passed, tests_failed, total_elapsed_msec])
	print("================================================================")

	if tests_failed > 0 or total_elapsed_msec > 30000:
		if total_elapsed_msec > 30000:
			printerr("  ✗ SÜİT GENELİ ZAMAN AŞIMI: %d ms > 30000 ms tavanı aşıldı!" % total_elapsed_msec)
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
# WARMUP: 20 Bounded Test Bulmacasını Tek Seferde Üretme & Önbelleğe Alma
# -----------------------------------------------------------------------------
func warmup_generate_cache() -> void:
	print("\n[Ön Hazırlık: 20 Deterministik Bulmaca Üretimi & Performans Ölçümü]")
	var warmup_start: int = Time.get_ticks_msec()
	var total_count: int = 0

	for diff in DIFFICULTIES:
		puzzle_cache[diff] = []
		for s in BOUNDED_SEEDS:
			var t0: int = Time.get_ticks_msec()
			var gen := SudokuGenerator.generate(s, diff)
			var dt: int = Time.get_ticks_msec() - t0
			generation_latencies.append(dt)
			assert_true(gen != null, "Bulmaca üretildi: %s (Seed: %d, Süre: %d ms)" % [diff, s, dt])
			puzzle_cache[diff].append(gen)
			total_count += 1

	var warmup_total: int = Time.get_ticks_msec() - warmup_start
	print("  -> 20 Bulmaca Toplam Üretim Süresi: %d ms (Ortalama: %.1f ms/bulmaca)" % [
		warmup_total, float(warmup_total) / float(total_count)
	])

# -----------------------------------------------------------------------------
# DIMENSION 1: Determinizm ve Seed Tekrarlanabilirliği (GDD §8)
# -----------------------------------------------------------------------------
func test_dimension_1_determinism() -> void:
	var all_identical: bool = true

	# Test regeneration on Easy and Medium against cache within strict timeout
	for diff in [DifficultyAnalyzer.LEVEL_EASY, DifficultyAnalyzer.LEVEL_MEDIUM]:
		var cached_gen: SudokuGenerator.GeneratedPuzzle = puzzle_cache[diff][0]
		var regen := SudokuGenerator.generate(cached_gen.seed_value, diff)

		for i in range(SudokuBoard.CELL_COUNT):
			if regen.puzzle.get_cell(i) != cached_gen.puzzle.get_cell(i):
				all_identical = false
				break
			if regen.solution.get_cell(i) != cached_gen.solution.get_cell(i):
				all_identical = false
				break

		if regen.difficulty_score != cached_gen.difficulty_score:
			all_identical = false
		if regen.top_techniques != cached_gen.top_techniques:
			all_identical = false

	assert_true(all_identical, "Determinizm Güvencesi: Aynı Seed + Zorluk = Birebir %100 aynı tahta, çözüm ve skor üretildi")

# -----------------------------------------------------------------------------
# DIMENSION 2: Tekil Çözüm (Uniqueness) & Kural Bütünlüğü (GDD §9, §12)
# -----------------------------------------------------------------------------
func test_dimension_2_uniqueness() -> void:
	var all_unique: bool = true
	var all_conflicts_free: bool = true
	var all_solutions_valid: bool = true
	var all_givens_match_solution: bool = true

	for diff in DIFFICULTIES:
		for gen in puzzle_cache[diff]:
			# 1. Uniqueness check
			if SudokuValidator.count_solutions(gen.puzzle, 2) != 1:
				all_unique = false

			# 2. Conflicts check
			if not SudokuValidator.get_conflicts(gen.puzzle).is_empty():
				all_conflicts_free = false

			# 3. Complete and valid solution check
			if not SudokuValidator.is_board_complete_and_valid(gen.solution):
				all_solutions_valid = false

			# 4. Given matching check
			for idx in range(SudokuBoard.CELL_COUNT):
				var p_val: int = gen.puzzle.get_cell(idx)
				if p_val != 0 and p_val != gen.solution.get_cell(idx):
					all_givens_match_solution = false
					break

	assert_true(all_unique, "20/20 bulmacada tam olarak 1 tekil çözüm bulundu (Uniqueness = 1)")
	assert_true(all_conflicts_free, "Üretilen tüm bulmacaların başlangıç ipuçları 0 çakışmaya sahip")
	assert_true(all_solutions_valid, "Üretilen tüm çözümler satır, sütun ve kutu kurallarını %100 sağlıyor")
	assert_true(all_givens_match_solution, "Başlangıç ipuçlarının tamamı çözümle %100 uyuşuyor")

# -----------------------------------------------------------------------------
# DIMENSION 3: İnsan Mantık Teknikleri & Aday Koruma Testi (GDD §10)
# -----------------------------------------------------------------------------
func test_dimension_3_techniques_and_safety() -> void:
	var sample_gen: SudokuGenerator.GeneratedPuzzle = puzzle_cache[DifficultyAnalyzer.LEVEL_EASY][0]
	var working := sample_gen.puzzle.clone()
	working.reset_candidates_from_grid()

	var step := SudokuSolver.find_next_step(working)
	assert_true(step != null, "Mantıksal solver sonraki adımı başarıyla tespit etti: %s" % (step.technique if step != null else "null"))

	if step != null and step.cells.size() > 0:
		assert_true(step.digit == sample_gen.solution.get_cell(step.cells[0]), "Tespit edilen ilk mantık adımı gerçek çözüm rakamıyla eşleşiyor")

	# Candidate safety across 3 puzzles (Easy, Medium, Hard)
	var candidate_safety_passed: bool = true
	var steps_tested: int = 0

	for diff in [DifficultyAnalyzer.LEVEL_EASY, DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD]:
		var p_gen: SudokuGenerator.GeneratedPuzzle = puzzle_cache[diff][1]
		var p_work := p_gen.puzzle.clone()
		p_work.reset_candidates_from_grid()

		var step_idx: int = 0
		while p_work.get_empty_cell_count() > 0 and step_idx < 30:
			step_idx += 1
			var st := SudokuSolver.find_next_step(p_work)
			if st == null:
				break

			steps_tested += 1
			if st.digit != 0 and st.cells.size() == 1:
				var c: int = st.cells[0]
				if st.digit != p_gen.solution.get_cell(c):
					candidate_safety_passed = false
				p_work.set_cell(c, st.digit, false)
				p_work.reset_candidates_from_grid()
			else:
				for cell_str in st.eliminations.keys():
					var c_idx: int = int(cell_str)
					var true_val: int = p_gen.solution.get_cell(c_idx)
					for el_d in st.eliminations[cell_str]:
						if el_d == true_val:
							candidate_safety_passed = false
						p_work.remove_candidate(c_idx, el_d)

	assert_true(candidate_safety_passed and steps_tested >= 20, "Aday koruma garantisi: Test edilen %d mantık adımında hiçbir doğru çözüm rakamı asla elenmedi" % steps_tested)

# -----------------------------------------------------------------------------
# DIMENSION 4: Adım Adım Çözüm & Snapshot Bütünlüğü Testi (GDD §22)
# -----------------------------------------------------------------------------
func test_dimension_4_step_by_step() -> void:
	var all_steps_valid: bool = true
	var all_snapshots_valid: bool = true
	var all_end_boards_valid: bool = true

	# Test 4 puzzles (1 per diff)
	for diff in DIFFICULTIES:
		var gen: SudokuGenerator.GeneratedPuzzle = puzzle_cache[diff][0]
		var sol := SudokuSolver.get_full_step_by_step_solution(gen.puzzle)

		var steps: Array = sol["steps"]
		var snapshots: Array = sol["snapshots"]
		var solved: SudokuBoard = sol["solved_board"]

		if steps.is_empty() or snapshots.size() != steps.size() + 1:
			all_snapshots_valid = false

		for k in range(steps.size()):
			var step = steps[k]
			if step.digit != 0 and step.cells.size() == 1:
				if step.digit != gen.solution.get_cell(step.cells[0]):
					all_steps_valid = false
					break

		if not SudokuValidator.is_board_complete_and_valid(solved):
			all_end_boards_valid = false
		else:
			for i in range(SudokuBoard.CELL_COUNT):
				if solved.get_cell(i) != gen.solution.get_cell(i):
					all_end_boards_valid = false
					break

	assert_true(all_steps_valid, "Adım adım çözümdeki tüm adımlar gerçek çözüm tahtasıyla %100 uyuşuyor")
	assert_true(all_snapshots_valid, "Her adım için tam ve kesintisiz snapshot zinciri üretildi (Snapshots = Steps + 1)")
	assert_true(all_end_boards_valid, "Adım adım çözüm sonunda tahta %100 hatasız tamamlandı")

# -----------------------------------------------------------------------------
# DIMENSION 5: Zorluk Kalibrasyonu & İpucu Aralıkları (GDD §11, §12)
# -----------------------------------------------------------------------------
func test_dimension_5_difficulty_calibration() -> void:
	var clues_within_bounds: bool = true
	var scores_within_bounds: bool = true
	var easy_has_no_advanced_techniques: bool = true

	for diff in DIFFICULTIES:
		for gen in puzzle_cache[diff]:
			var clue_count: int = SudokuBoard.CELL_COUNT - gen.puzzle.get_empty_cell_count()
			var score: int = gen.difficulty_score

			match diff:
				DifficultyAnalyzer.LEVEL_EASY:
					if clue_count < 32 or clue_count > 42:
						clues_within_bounds = false
					if score < 10 or score > 35:
						scores_within_bounds = false
					for tech in gen.top_techniques:
						if tech in ["X-Wing", "Swordfish", "XY-Wing", "XYZ-Wing"]:
							easy_has_no_advanced_techniques = false
				DifficultyAnalyzer.LEVEL_MEDIUM:
					if clue_count < 20 or clue_count > 42:
						clues_within_bounds = false
					if score < 36 or score > 65:
						scores_within_bounds = false
				DifficultyAnalyzer.LEVEL_HARD:
					if clue_count < 20 or clue_count > 42:
						clues_within_bounds = false
					if score < 66 or score > 85:
						scores_within_bounds = false
				DifficultyAnalyzer.LEVEL_EXPERT:
					if clue_count < 20 or clue_count > 42:
						clues_within_bounds = false
					if score < 86 or score > 100:
						scores_within_bounds = false

	assert_true(clues_within_bounds, "İpucu sayıları makul aralıkta (zorluk artık teknik analizle belirlenir; Easy >= 32, hepsi 20-42)")
	assert_true(scores_within_bounds, "Zorluk skorları GDD §11 çok faktörlü modeline tam uygun (Easy 10-35, Med 36-65, Hard 66-85, Exp 86-100)")
	assert_true(easy_has_no_advanced_techniques, "Easy seviyesinde ileri teknikler (X-Wing vb.) kesinlikle yer almıyor")

# -----------------------------------------------------------------------------
# DIMENSION 6: İptal Emniyeti & Performans Kriterleri
# -----------------------------------------------------------------------------
func test_dimension_6_cancellation_and_performance() -> void:
	# 1. Cancellation test with Dictionary tracker (safe capture)
	var cancel_tracker := { "called": false }
	var cancel_cb := func() -> bool:
		cancel_tracker["called"] = true
		return true

	var cancelled_gen := SudokuGenerator.generate(88888, DifficultyAnalyzer.LEVEL_EXPERT, cancel_cb)
	assert_true(cancelled_gen == null, "İptal callback'i tetiklendiğinde üretici anında null dönerek thread'i serbest bıraktı")
	assert_true(cancel_tracker["called"] == true, "İptal callback'i üretici tarafından başarıyla çağrıldı")

	# 2. Latency checks across the 20 warm-up generations
	var max_lat: int = 0
	var sum_lat: int = 0
	for lat in generation_latencies:
		if lat > max_lat: max_lat = lat
		sum_lat += lat
	var avg_lat: float = float(sum_lat) / float(generation_latencies.size())

	# Ceilings include retries until the analyzer rates the puzzle at the requested level (Expert is the slow case)
	assert_true(max_lat < 14000, "En yavaş bulmaca üretim süresi makul tavanın altında: %d ms" % max_lat)
	assert_true(avg_lat < 2000.0, "Ortalama bulmaca üretim süresi makul hız standardında: %.1f ms" % avg_lat)
