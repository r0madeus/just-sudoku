class_name DifficultyAnalyzer
extends RefCounted

## Analyzes puzzle difficulty based on human logical deductions, techniques, and step counts.

const LEVEL_EASY: String = "Easy"
const LEVEL_MEDIUM: String = "Medium"
const LEVEL_HARD: String = "Hard"
const LEVEL_EXPERT: String = "Expert"

const MEDIUM_MIN_WEIGHT: int = 3
const HARD_MIN_WEIGHT: int = 5
const EXPERT_MIN_WEIGHT: int = 10

const SCORE_BANDS: Dictionary = {
	LEVEL_EASY: Vector2i(10, 35),
	LEVEL_MEDIUM: Vector2i(36, 65),
	LEVEL_HARD: Vector2i(66, 85),
	LEVEL_EXPERT: Vector2i(86, 100)
}

## Hardest-technique weight range mapped onto each level's score band
const WEIGHT_RANGES: Dictionary = {
	LEVEL_EASY: Vector2i(1, 2),
	LEVEL_MEDIUM: Vector2i(3, 4),
	LEVEL_HARD: Vector2i(5, 9),
	LEVEL_EXPERT: Vector2i(10, 11)
}

class AnalysisResult extends RefCounted:
	var level: String = LEVEL_EASY
	var difficulty_score: int = 0 # 0 to 100
	var total_steps: int = 0
	var top_techniques: Array[String] = []
	var estimated_seconds: int = 300
	var solved_logically: bool = false
	var technique_counts: Dictionary = {}
	var steps: Array[SudokuSolver.SolveStep] = []

	func _to_string() -> String:
		return "[%s (Score: %d) Est: %dm %ds | Top: %s]" % [
			level, difficulty_score, estimated_seconds / 60, estimated_seconds % 60, ", ".join(top_techniques)
		]

static func analyze(board: SudokuBoard) -> AnalysisResult:
	var result := AnalysisResult.new()
	var solve_res: Dictionary = SudokuSolver.solve_logical(board)

	result.solved_logically = solve_res.solved
	result.technique_counts = solve_res.technique_counts
	result.steps = solve_res.steps
	result.total_steps = solve_res.steps.size()

	var tech_counts: Dictionary = solve_res.technique_counts
	var max_weight: int = 1
	var total_weight: int = solve_res.total_weight

	for step in solve_res.steps:
		if step.difficulty_weight > max_weight:
			max_weight = step.difficulty_weight

	var empty_count: int = board.get_empty_cell_count()
	var clue_count: int = SudokuBoard.CELL_COUNT - empty_count

	# GDD §11: the level follows the hardest technique the puzzle forces (the solver always
	# takes the easiest available step, so max_weight is what a human cannot avoid).
	# Weights: 1 Naked Single, 2 Hidden Single, 3 Locked Candidates, 4 Naked Pair, 5 Hidden Pair,
	# 6-7 Naked/Hidden Triple, 8 X-Wing, 9 XY-Wing, 10+ XYZ-Wing, Swordfish. Stuck logically -> Expert.
	var logical: bool = result.solved_logically
	if not logical or max_weight >= EXPERT_MIN_WEIGHT:
		result.level = LEVEL_EXPERT
	elif max_weight >= HARD_MIN_WEIGHT:
		result.level = LEVEL_HARD
	elif max_weight >= MEDIUM_MIN_WEIGHT:
		result.level = LEVEL_MEDIUM
	else:
		result.level = LEVEL_EASY

	var band: Vector2i = SCORE_BANDS[result.level]
	var weight_range: Vector2i = WEIGHT_RANGES[result.level]
	# Within a level, hardest technique (50%), solution length (25%) and fewer clues (25%) decide the score
	var w_norm: float = 1.0 if not logical else clampf(
		float(max_weight - weight_range.x) / float(maxi(1, weight_range.y - weight_range.x)), 0.0, 1.0)
	var s_norm: float = clampf(float(result.total_steps) / 60.0, 0.0, 1.0)
	var c_norm: float = clampf(float(40 - clue_count) / 20.0, 0.0, 1.0)
	var blend: float = 0.5 * w_norm + 0.25 * s_norm + 0.25 * c_norm
	result.difficulty_score = band.x + int(round(float(band.y - band.x) * blend))

	match result.level:
		LEVEL_EXPERT:
			result.estimated_seconds = 900 + result.total_steps * 10
		LEVEL_HARD:
			result.estimated_seconds = 600 + result.total_steps * 8
		LEVEL_MEDIUM:
			result.estimated_seconds = 360 + result.total_steps * 6
		_:
			result.estimated_seconds = 180 + result.total_steps * 4

	# Extract top 3 techniques (sorted by technique importance/weight, then frequency)
	var sorted_techniques: Array = []
	for tech_name in tech_counts.keys():
		var sample_step: SudokuSolver.SolveStep = null
		for s in solve_res.steps:
			if s.technique == tech_name:
				sample_step = s
				break
		var weight: int = sample_step.difficulty_weight if sample_step != null else 1
		sorted_techniques.append({
			"name": tech_name,
			"weight": weight,
			"count": tech_counts[tech_name]
		})

	sorted_techniques.sort_custom(func(a, b):
		if a.weight != b.weight:
			return a.weight > b.weight
		return a.count > b.count
	)

	result.top_techniques = []
	for i in range(mini(3, sorted_techniques.size())):
		result.top_techniques.append(sorted_techniques[i].name)

	if result.top_techniques.is_empty():
		result.top_techniques.append("Naked Single")

	return result
