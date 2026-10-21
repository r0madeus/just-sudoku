class_name PuzzleShareService
extends RefCounted

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuValidator = preload("res://scripts/core/sudoku_validator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameTimer = preload("res://scripts/gameplay/game_timer.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

## Service for exporting, importing, and clipboard sharing of seeds, puzzles, and saves (GDD §28, §29, §31)

static func export_puzzle_share_text(seed_val: int, difficulty: String, board: SudokuBoard) -> String:
	var code_str := board.to_string_flat() if board != null else ""
	var diff_label: String = LocalizationManager.translate("SHARE_DIFF_LABEL")
	var seed_label: String = LocalizationManager.translate("SHARE_SEED_LABEL")
	var code_label: String = LocalizationManager.translate("SHARE_CODE_LABEL")
	return "Just Sudoku\n%s: %s\n%s: %d\n%s: %s" % [diff_label, difficulty, seed_label, seed_val, code_label, code_str]

static func copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)

static func get_clipboard_text() -> String:
	return DisplayServer.clipboard_get()

## Parses and validates any raw input string (JSON Save, 81-char code, or Seed)
static func parse_import_string(raw_text: String, default_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM) -> Dictionary:
	var clean: String = raw_text.strip_edges()
	if clean.is_empty():
		return {
			"success": false,
			"type": "empty",
			"error": LocalizationManager.translate("ERROR_EMPTY_INPUT")
		}

	# 1. Try parsing as JSON Save Game
	if clean.begins_with("{") and clean.ends_with("}"):
		var state := SaveManager.import_game_from_string(clean)
		if state != null and state.initial_puzzle != null and state.current_board != null:
			var diff_name := LocalizationManager.get_difficulty_name(state.difficulty)
			var time_str := GameTimer.format_seconds(state.elapsed_time)
			var pct_int: int = int(roundf(float(81 - state.current_board.get_empty_cell_count()) / 81.0 * 100.0))
			var pct_str := LocalizationManager.format_percentage(pct_int)
			return {
				"success": true,
				"type": "save_json",
				"game_state": state,
				"difficulty": state.difficulty,
				"seed": state.seed_value,
				"info": LocalizationManager.translate("SHARE_INFO_SAVE") % [diff_name, time_str, pct_str]
			}
		else:
			return {
				"success": false,
				"type": "save_json",
				"error": LocalizationManager.translate("SHARE_ERR_SAVE")
			}

	# 2. Check if text contains structured lines (e.g., from export_puzzle_share_text)
	var lines := clean.split("\n")
	var extracted_code: String = ""
	var extracted_seed: int = 0
	var extracted_diff: String = default_difficulty

	for line in lines:
		var l: String = line.strip_edges()
		if l.to_lower().begins_with("kod:") or l.to_lower().begins_with("code:"):
			extracted_code = l.substr(l.find(":") + 1).strip_edges()
		elif l.to_lower().begins_with("seed:"):
			var seed_part := l.substr(l.find(":") + 1).strip_edges()
			if seed_part.is_valid_int():
				extracted_seed = int(seed_part)
		elif l.to_lower().begins_with("zorluk:") or l.to_lower().begins_with("difficulty:"):
			var diff_part := l.substr(l.find(":") + 1).strip_edges()
			for d in [DifficultyAnalyzer.LEVEL_EASY, DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD, DifficultyAnalyzer.LEVEL_EXPERT]:
				if diff_part.to_lower().contains(d.to_lower()):
					extracted_diff = d
					break

	# 3. Try parsing as 81-character puzzle string
	var candidate_code: String = extracted_code if not extracted_code.is_empty() else clean
	var clean_code: String = candidate_code.replace(" ", "").replace("\n", "").replace("\r", "")

	if clean_code.length() == 81 and _is_valid_puzzle_characters(clean_code):
		var board := SudokuBoard.new()
		board.from_string_flat(clean_code, true)

		# Validate conflicts
		var conflicts := SudokuValidator.get_conflicts(board)
		if not conflicts.is_empty():
			return {
				"success": false,
				"type": "puzzle_code",
				"error": LocalizationManager.translate("SHARE_ERR_CONFLICT") % conflicts.size()
			}

		# Validate unique solution
		if not SudokuValidator.has_unique_solution(board):
			return {
				"success": false,
				"type": "puzzle_code",
				"error": LocalizationManager.translate("SHARE_ERR_NO_UNIQUE")
			}

		# Analyze difficulty and solve
		var analysis: DifficultyAnalyzer.AnalysisResult = DifficultyAnalyzer.analyze(board)
		var solver_solution: SudokuBoard = SudokuSolver.solve_fast(board)
		if solver_solution == null:
			solver_solution = board.clone()

		var gen := SudokuGenerator.GeneratedPuzzle.new()
		gen.puzzle = board
		gen.solution = solver_solution
		gen.seed_value = extracted_seed if extracted_seed != 0 else SudokuGenerator.generate_new_seed()
		gen.difficulty = analysis.level
		gen.difficulty_score = analysis.difficulty_score
		gen.estimated_seconds = analysis.estimated_seconds
		gen.top_techniques = analysis.top_techniques

		var new_state := GameState.new()
		new_state.init_from_puzzle(gen)

		var diff_name := LocalizationManager.get_difficulty_name(analysis.level)
		return {
			"success": true,
			"type": "puzzle_code",
			"game_state": new_state,
			"difficulty": analysis.level,
			"seed": gen.seed_value,
			"info": LocalizationManager.translate("SHARE_INFO_CODE") % [
				diff_name, analysis.difficulty_score
			]
		}

	# 4. Try parsing as Seed Number
	if extracted_seed != 0 or clean.is_valid_int():
		var seed_num: int = extracted_seed if extracted_seed != 0 else clean.to_int()
		if seed_num > 0:
			var gen := SudokuGenerator.generate(seed_num, extracted_diff)
			var state := GameState.new()
			state.init_from_puzzle(gen)

			var diff_name := LocalizationManager.get_difficulty_name(extracted_diff)
			return {
				"success": true,
				"type": "seed",
				"game_state": state,
				"seed": seed_num,
				"difficulty": extracted_diff,
				"info": LocalizationManager.translate("SHARE_INFO_SEED") % [seed_num, diff_name]
			}

	return {
		"success": false,
		"type": "unknown",
		"error": LocalizationManager.translate("SHARE_ERR_UNKNOWN")
	}

static func _is_valid_puzzle_characters(s: String) -> bool:
	for i in range(s.length()):
		var c: String = s[i]
		if (c >= "1" and c <= "9") or c == "." or c == "0":
			continue
		return false
	return true
