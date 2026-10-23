extends SceneTree

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameTimer = preload("res://scripts/gameplay/game_timer.gd")
const PerformanceScorer = preload("res://scripts/gameplay/performance_scorer.gd")
const SudokuGrid = preload("res://scenes/gameplay/sudoku_grid.gd")
const SmartNumpad = preload("res://scenes/gameplay/smart_numpad.gd")
const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var suite_start_msec: int = 0

const PER_TEST_TIMEOUT_MSEC: int = 1000

var test_gen: SudokuGenerator.GeneratedPuzzle
var ui_root: Control

func _init() -> void:
	suite_start_msec = Time.get_ticks_msec()
	print("================================================================")
	print("🧪 RUNNING JUST SUDOKU - OYNANIŞ MEKANİKLERİ KALİTE TESTİ")
	print("   GDD §14-§26, §42, §49 • Katı Zaman Sınırları (Max %d ms / test)" % PER_TEST_TIMEOUT_MSEC)
	print("================================================================")

	ui_root = Control.new()
	root_node_add(ui_root)

	# Generate single deterministic test puzzle for gameplay simulation
	var t0: int = Time.get_ticks_msec()
	test_gen = SudokuGenerator.generate(1001, DifficultyAnalyzer.LEVEL_EASY)
	print("[Ön Hazırlık: Deterministik Oynanış Bulmacası Hazırlandı (%d ms)]" % (Time.get_ticks_msec() - t0))

	run_bounded_test("Boyut 1: Hücre Seçimi, Highlight & Klavye Navigasyonu (GDD §15, §42)", test_dimension_1_selection_and_highlights)
	run_bounded_test("Boyut 2: Mobil Input, Numpad & Smart Numpad Filtreleme (GDD §16)", test_dimension_2_smart_numpad)
	run_bounded_test("Boyut 3: Not Sistemi, Smart Candidates & Auto-Remove (GDD §17)", test_dimension_3_notes_and_candidates)
	run_bounded_test("Boyut 4: Canlı Çakışma, Wrong Value & Check Sistemi (GDD §18, §19)", test_dimension_4_conflicts_and_check)
	run_bounded_test("Boyut 5: Sınırsız Undo / Redo & Not Kurtarma (GDD §20)", test_dimension_5_undo_redo)
	run_bounded_test("Boyut 6: Hint, Pause, Timer & Performance Score (GDD §21-§25)", test_dimension_6_hint_pause_timer_score)
	run_bounded_test("Boyut 7: Tamamlama ve Replay / Master it again (GDD §26)", test_dimension_7_completion_and_replay)

	var total_elapsed_msec: int = Time.get_ticks_msec() - suite_start_msec
	print("\n================================================================")
	print("🏁 RESULTS: %d Passed, %d Failed (Toplam Süre: %d ms)" % [tests_passed, tests_failed, total_elapsed_msec])
	print("================================================================")

	ui_root.queue_free()

	if tests_failed > 0 or total_elapsed_msec > 4000:
		if total_elapsed_msec > 4000:
			printerr("  ✗ SÜİT GENELİ ZAMAN AŞIMI: %d ms > 4000 ms tavanı aşıldı!" % total_elapsed_msec)
		quit(1)
	else:
		quit(0)

func root_node_add(node: Node) -> void:
	var cr := get_root()
	if cr != null:
		cr.add_child(node)

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
# BOYUT 1: Hücre Seçimi, Highlight & Klavye Navigasyonu (GDD §15, §42)
# -----------------------------------------------------------------------------
func test_dimension_1_selection_and_highlights() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	var grid := SudokuGrid.new()
	ui_root.add_child(grid)
	grid._ready()
	grid.bind_game_state(state)

	# 1. Select cell 0
	grid.select_cell(0)
	assert_true(grid.selected_idx == 0, "Hücre seçimi aktif (selected_idx = 0)")
	assert_true(grid.cells[0].is_selected == true, "Hücre 0 görsel olarak is_selected = true")

	# 2. Peer highlight: All 20 peers of cell 0 must have is_peer = true
	var peers_count: int = 0
	for peer_idx in SudokuBoard.PEERS[0]:
		if grid.cells[peer_idx].is_peer:
			peers_count += 1
	assert_true(peers_count == 20, "Hücre 0'ın 20 komşusunun tamamı is_peer = true olarak vurgulandı")

	# 3. Non-peer cells must NOT be peer
	assert_true(grid.cells[80].is_peer == false, "Hücre 0 ile ilişkisiz hücre 80 is_peer = false")

	# 4. Same number highlight: select a given digit (cell 0 may be empty, which would test nothing)
	var given_idx: int = -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.initial_puzzle.is_given(i):
			given_idx = i
			break
	var digit: int = state.current_board.get_cell(given_idx)
	grid.select_cell(given_idx)
	var same_total: int = 0
	var same_marked: int = 0
	var others_marked: int = 0
	for i in range(SudokuBoard.CELL_COUNT):
		if i == given_idx:
			continue
		if state.current_board.get_cell(i) == digit:
			same_total += 1
			if grid.cells[i].is_same_number:
				same_marked += 1
		elif grid.cells[i].is_same_number:
			others_marked += 1
	assert_true(same_total > 0 and same_marked == same_total, "Aynı rakam (%d) olan %d hücrenin %d'i vurgulandı" % [digit, same_total, same_marked])
	assert_true(others_marked == 0, "Başka rakamlar vurgulanmadı (%d)" % others_marked)
	grid.select_cell(0)

	# 5. Keyboard Navigation (GDD §42 Arrow keys)
	grid.move_selection(0, 1) # Move right
	assert_true(grid.selected_idx == 1, "Klavye Sağa Hareket: selected_idx = 1")
	grid.move_selection(1, 0) # Move down
	assert_true(grid.selected_idx == 10, "Klavye Aşağı Hareket: selected_idx = 10 (R1C1)")
	grid.move_selection(-10, -10) # Clamped upper-left
	assert_true(grid.selected_idx == 0, "Klavye Sınır Koruması: (0,0) sınırına kilitlendi (selected_idx = 0)")
	grid.move_selection(20, 20) # Clamped bottom-right
	assert_true(grid.selected_idx == 80, "Klavye Sınır Koruması: (8,8) sınırına kilitlendi (selected_idx = 80)")

	grid.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 2: Mobil Input, Numpad & Smart Numpad Filtreleme (GDD §16)
# -----------------------------------------------------------------------------
func test_dimension_2_smart_numpad() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	var numpad := SmartNumpad.new()
	ui_root.add_child(numpad)

	# Find empty cell
	var empty_idx: int = -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			empty_idx = i
			break
	assert_true(empty_idx != -1, "Test için boş hücre bulundu: %d" % empty_idx)

	# 1. Update Smart Numpad states
	AppSettings.smart_numpad_enabled = true
	numpad.set_notes_mode(false)
	numpad.update_smart_states(state.current_board, empty_idx)

	var smart_filter_verified: bool = true
	for d in range(1, 10):
		var btn: Button = numpad.num_buttons[d - 1]
		var can_place: bool = SudokuValidator.is_valid_placement(state.current_board, empty_idx, d)
		if not can_place and not btn.disabled:
			smart_filter_verified = false

	assert_true(smart_filter_verified, "Smart Numpad: Kural ihlali yaratacak geçersiz rakam butonları kilitlendi (disabled)")

	# 2. Notes mode overrides smart filter (all valid notes are enabled)
	numpad.set_notes_mode(true)
	numpad.update_smart_states(state.current_board, empty_idx)
	var all_enabled_in_notes: bool = true
	for d in range(1, 10):
		if numpad.num_buttons[d - 1].disabled:
			all_enabled_in_notes = false
	assert_true(all_enabled_in_notes, "Not Modu: Tüm 1-9 butonları aday girişi için aktif")

	# 3. Toggle Cell Clear (tapping same number clears it)
	numpad.set_notes_mode(false)
	state.set_number(empty_idx, 7)
	assert_true(state.current_board.get_cell(empty_idx) == 7, "Hücreye 7 yazıldı")
	state.set_number(empty_idx, 7)
	assert_true(state.current_board.get_cell(empty_idx) == 0, "Aynı sayıya 2. kez dokunulduğunda hücre silindi (Toggle davranışı)")

	numpad.queue_free()

# -----------------------------------------------------------------------------
# BOYUT 3: Not Sistemi, Smart Candidates & Auto-Remove (GDD §17)
# -----------------------------------------------------------------------------
func test_dimension_3_notes_and_candidates() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	var empty_idx: int = -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			empty_idx = i
			break

	# 1. Candidate toggle
	state.toggle_candidate(empty_idx, 4)
	assert_true(state.current_board.has_candidate(empty_idx, 4) == true, "Hücreye aday 4 eklendi")
	state.toggle_candidate(empty_idx, 4)
	assert_true(state.current_board.has_candidate(empty_idx, 4) == false, "Aday 4 tekrar dokunulunca kaldırıldı")

	# 2. Auto-remove notes on digit placement
	state.toggle_candidate(empty_idx, 2)
	var peer_idx: int = SudokuBoard.PEERS[empty_idx][0]
	if state.can_edit_cell(peer_idx):
		state.toggle_candidate(peer_idx, 2)
		assert_true(state.current_board.has_candidate(peer_idx, 2) == true, "Komşu hücreye aday 2 eklendi")

		# Place 2 in empty_idx with auto_remove_notes
		state.set_number(empty_idx, 2, true)
		assert_true(state.current_board.has_candidate(peer_idx, 2) == false, "Auto-Remove Notes: Sayı yerleştirilince komşu hücredeki aday 2 otomatik silindi")

	# 3. Smart Candidates setting
	AppSettings.smart_candidates_enabled = true
	var sc_state := GameState.new()
	sc_state.init_from_puzzle(test_gen)
	assert_true(sc_state.current_board.candidates[empty_idx] != 0, "Smart Candidates = Açık iken boş hücrelerde adaylar otomatik hesaplandı")

	AppSettings.smart_candidates_enabled = false
	var clean_state := GameState.new()
	clean_state.init_from_puzzle(test_gen)
	assert_true(clean_state.current_board.candidates[empty_idx] == 0, "Smart Candidates = Kapalı iken başlangıç tahtası 0 kalabalıkla temiz başladı")

# -----------------------------------------------------------------------------
# BOYUT 4: Canlı Çakışma, Wrong Value & Check Sistemi (GDD §18, §19)
# -----------------------------------------------------------------------------
func test_dimension_4_conflicts_and_check() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# Find empty cell with given peer
	var target_empty: int = -1
	var conflict_val: int = 0
	for idx in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(idx) == 0:
			for p in SudokuBoard.PEERS[idx]:
				if state.initial_puzzle.is_given(p):
					target_empty = idx
					conflict_val = state.initial_puzzle.get_cell(p)
					break
		if target_empty != -1: break

	# 1. Instant Conflict
	var init_mistakes: int = state.mistakes_count
	state.set_number(target_empty, conflict_val)
	assert_true(state.mistakes_count == init_mistakes + 1, "Canlı Çakışma: Satır/sütun/kutuda aynı sayı olunca mistakes_count anında arttı")
	assert_true(SudokuValidator.get_conflicts(state.current_board).has(target_empty), "Çakışan hücre get_conflicts tarafından kırmızı olarak tespit edildi")

	# Revert
	state.set_number(target_empty, 0)

	# 2. Wrong Value (locally valid but wrong vs final solution)
	var true_val: int = state.solution.get_cell(target_empty)
	var wrong_valid_val: int = 0
	for d in range(1, 10):
		if d != true_val and SudokuValidator.is_valid_placement(state.current_board, target_empty, d):
			wrong_valid_val = d
			break

	if wrong_valid_val != 0:
		state.set_number(target_empty, wrong_valid_val)
		assert_true(not SudokuValidator.get_conflicts(state.current_board).has(target_empty), "Wrong Value: Kuralı bozmayan yanlış sayı canlıda kırmızı yanmadı (GDD §18)")

	# 3. Check Board action
	var wrong_cells := state.check_board()
	if wrong_valid_val != 0:
		assert_true(wrong_cells.has(target_empty), "Check Butonu: Yanlış hücre Check ile tespit edildi")
		assert_true(state.checked_wrong_indices.has(target_empty), "Yanlış hücre checked_wrong_indices listesine eklendi")

	# 4. Duplicate Check penalty prevention
	var mistakes_before := state.mistakes_count
	state.check_board()
	assert_true(state.mistakes_count == mistakes_before, "Tekrarlanan Check basımında aynı hataya mükerrer ceza yazılmadı")

# -----------------------------------------------------------------------------
# BOYUT 5: Sınırsız Undo / Redo & Not Kurtarma (GDD §20)
# -----------------------------------------------------------------------------
func test_dimension_5_undo_redo() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# Find empty cell
	var e_idx: int = -1
	for i in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(i) == 0:
			e_idx = i
			break

	# Perform 3 moves:
	# Move 1: Add note 8
	state.toggle_candidate(e_idx, 8)
	# Move 2: Add note 9
	state.toggle_candidate(e_idx, 9)
	# Move 3: Place number 5
	state.set_number(e_idx, 5)

	assert_true(state.current_board.get_cell(e_idx) == 5, "Hamle 3: Hücre 5 oldu")
	assert_true(state.can_undo() == true, "can_undo() = true")

	# Undo Move 3 -> Back to notes (8, 9)
	state.undo()
	assert_true(state.current_board.get_cell(e_idx) == 0, "Undo 1: Sayı 0'a döndü")
	assert_true(state.current_board.has_candidate(e_idx, 8) and state.current_board.has_candidate(e_idx, 9), "Undo 1: Aday notları (8, 9) eksiksiz geri yüklendi")

	# Undo Move 2 -> Note 9 removed
	state.undo()
	assert_true(state.current_board.has_candidate(e_idx, 9) == false, "Undo 2: Aday 9 geri alındı")

	# Undo Move 1 -> Note 8 removed
	state.undo()
	assert_true(state.current_board.has_candidate(e_idx, 8) == false, "Undo 3: Aday 8 geri alındı")
	assert_true(state.can_undo() == false, "Tüm hamleler geri alındığında can_undo() = false")

	# Redo
	assert_true(state.can_redo() == true, "can_redo() = true")
	state.redo() # Redo note 8
	state.redo() # Redo note 9
	state.redo() # Redo number 5
	assert_true(state.current_board.get_cell(e_idx) == 5, "Redo: Hamleler ileri alınarak hücre tekrar 5 oldu")
	assert_true(state.can_redo() == false, "Redo stack tükendiğinde can_redo() = false")

# -----------------------------------------------------------------------------
# BOYUT 6: Hint, Pause, Timer & Performance Score (GDD §21-§25)
# -----------------------------------------------------------------------------
func test_dimension_6_hint_pause_timer_score() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	# 1. Hint System (GDD §21: Applies next logical deduction step)
	var init_hints: int = state.hints_used
	var hint_step := state.apply_hint()
	assert_true(hint_step != null, "Hint: Solver bir sonraki mantık adımını üretti: %s" % (hint_step.technique if hint_step != null else "null"))
	assert_true(state.hints_used == init_hints + 1, "Hint: hints_used sayacı 1 arttı")

	# 2. Timer System (GDD §24)
	var timer := GameTimer.new()
	ui_root.add_child(timer)
	timer.start(0.0)
	assert_true(timer.is_running == true, "Timer başlatıldı (is_running = true)")
	timer.pause()
	assert_true(timer.is_running == false, "Timer durduruldu (pause)")
	assert_true(GameTimer.format_seconds(125) == "02:05", "Zaman biçimlendirme 125s -> 02:05")
	assert_true(GameTimer.format_seconds(3665) == "01:01:05", "Zaman biçimlendirme 3665s -> 01:01:05")
	timer.queue_free()

	# 3. Performance Score (GDD §25: 0-100 normalized score)
	# Fast clean solve
	var perfect_score: int = PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 180.0, 360, 0, 0, 0)
	assert_true(perfect_score >= 90 and perfect_score <= 100, "Performans Skoru: Hatasız ve hızlı çözüm 90-100 aralığında (%d)" % perfect_score)

	# Heavy mistakes and hints
	var penalised_score: int = PerformanceScorer.calculate_score(DifficultyAnalyzer.LEVEL_MEDIUM, 900.0, 360, 5, 3, 20)
	assert_true(penalised_score < 50, "Performans Skoru: 5 hata ve 3 ipucu ile skor düşürüldü (%d)" % penalised_score)

# -----------------------------------------------------------------------------
# BOYUT 7: Tamamlama ve Replay / Master it again (GDD §26)
# -----------------------------------------------------------------------------
func test_dimension_7_completion_and_replay() -> void:
	var state := GameState.new()
	state.init_from_puzzle(test_gen)

	var completion_signal_received: Array[bool] = [false]
	var received_summary: Array[Dictionary] = [{}]
	state.game_completed.connect(func(summary: Dictionary):
		completion_signal_received[0] = true
		received_summary[0] = summary
	)

	# Fill entire board with solution except 1 cell
	var last_idx: int = -1
	for idx in range(SudokuBoard.CELL_COUNT):
		if state.current_board.get_cell(idx) == 0:
			if last_idx == -1:
				last_idx = idx
			else:
				state.current_board.set_cell(idx, state.solution.get_cell(idx), false)

	assert_true(last_idx != -1, "Son çözülecek hücre: %d" % last_idx)

	# Enter final correct number
	state.set_number(last_idx, state.solution.get_cell(last_idx))
	assert_true(state.is_completed == true, "Son sayı girildiğinde is_completed = true oldu")
	assert_true(completion_signal_received[0] == true, "game_completed sinyali otomatik tetiklendi")
	assert_true(received_summary[0].has("score") and received_summary[0].has("time"), "Tamamlama özeti skor ve süre verilerini içeriyor")

	# Replay / Master it again (GDD §26)
	var orig_game_id: String = state.game_id
	state.reset_for_replay()
	assert_true(state.is_replay == true, "Replay sıfırlaması: is_replay = true")
	assert_true(state.is_completed == false, "Replay sıfırlaması: is_completed = false")
	assert_true(state.elapsed_time == 0.0, "Replay sıfırlaması: elapsed_time = 0.0")
	assert_true(state.mistakes_count == 0, "Replay sıfırlaması: mistakes_count = 0")
	assert_true(state.hints_used == 0, "Replay sıfırlaması: hints_used = 0")
	assert_true(state.game_id != orig_game_id, "Replay sıfırlaması: Yeni benzersiz game_id üretildi")
	assert_true(state.game_id.begins_with("replay_"), "Replay game_id 'replay_' önekiyle başlıyor")
	assert_true(state.current_board.get_empty_cell_count() == state.initial_puzzle.get_empty_cell_count(), "Replay tahtası ilk boş hücre durumuna geri döndürüldü")
