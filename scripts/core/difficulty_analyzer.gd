class_name DifficultyAnalyzer
extends RefCounted

## Analyzes puzzle difficulty based on human logical deductions, techniques, and step counts.

const LEVEL_EASY: String = "Easy"
const LEVEL_MEDIUM: String = "Medium"
const LEVEL_HARD: String = "Hard"
const LEVEL_EXPERT: String = "Expert"

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

	# GDD §11: Çok faktörlü zorluk modeli:
	# 1. Teknik Ağırlığı (max_weight)
	# 2. Çözüm Adımı Sayısı (total_steps)
	# 3. Çözüm Karmaşıklığı / İpucu Sayısı (clue_count)
	if not result.solved_logically or max_weight >= 8 or (clue_count <= 25 and max_weight >= 6):
		result.level = LEVEL_EXPERT
		result.difficulty_score = clampi(86 + (max_weight - 7) * 2 + int(empty_count * 0.15), 86, 100)
		result.estimated_seconds = 900 + result.total_steps * 10
	elif max_weight >= 6 or (clue_count <= 29 and (max_weight >= 4 or result.total_steps >= 35)):
		result.level = LEVEL_HARD
		result.difficulty_score = clampi(66 + (max_weight - 4) * 3 + int(result.total_steps * 0.25), 66, 85)
		result.estimated_seconds = 600 + result.total_steps * 8
	elif max_weight >= 3 or (clue_count <= 34 and result.total_steps >= 20):
		result.level = LEVEL_MEDIUM
		result.difficulty_score = clampi(36 + (max_weight - 2) * 5 + int(result.total_steps * 0.25), 36, 65)
		result.estimated_seconds = 360 + result.total_steps * 6
	else:
		result.level = LEVEL_EASY
		result.difficulty_score = clampi(12 + int(result.total_steps * 0.35), 10, 35)
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
