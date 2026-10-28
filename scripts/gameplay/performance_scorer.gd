class_name PerformanceScorer
extends RefCounted

## Calculates normalized 0-100 Performance Score according to GDD §25
## Evaluates: Difficulty, Time, Mistakes, Hints, and Move efficiency.

static func calculate_score(
	difficulty: String,
	elapsed_seconds: float,
	estimated_seconds: int,
	mistakes: int,
	hints: int,
	undo_count: int = 0,
	hint_cost: int = 0
) -> int:
	# Base score according to difficulty tier
	var base_score: float = 75.0
	match difficulty:
		DifficultyAnalyzer.LEVEL_EASY:
			base_score = 75.0
		DifficultyAnalyzer.LEVEL_MEDIUM:
			base_score = 82.0
		DifficultyAnalyzer.LEVEL_HARD:
			base_score = 88.0
		DifficultyAnalyzer.LEVEL_EXPERT:
			base_score = 94.0

	# Time factor: ratio of estimated vs actual time
	var safe_est: float = maxf(float(estimated_seconds), 60.0)
	var time_ratio: float = safe_est / maxf(elapsed_seconds, 30.0)
	# time_bonus: between -20 and +15
	var time_bonus: float = 0.0
	if time_ratio >= 1.0:
		# Faster than estimated: bonus up to +15
		time_bonus = minf((time_ratio - 1.0) * 15.0, 15.0)
	else:
		# Slower than estimated: mild deduction down to -20
		time_bonus = maxf((time_ratio - 1.0) * 20.0, -20.0)

	# Deductions
	var mistake_penalty: float = mistakes * 6.0
	# hint_cost also counts hints only looked at; older saves only know the applied count
	var hint_penalty: float = maxf(float(hint_cost), hints * 12.0)
	var undo_penalty: float = minf(undo_count * 0.5, 8.0) # Gentle cap on undo penalty

	var raw_score: float = base_score + time_bonus - mistake_penalty - hint_penalty - undo_penalty

	# Perfect clean solve bonus (no mistakes, no hints)
	if mistakes == 0 and hints == 0 and hint_cost == 0:
		raw_score += 5.0

	return clampi(int(round(raw_score)), 0, 100)
