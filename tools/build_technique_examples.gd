extends SceneTree

## Builds assets/techniques/examples.json, what the Techniques screen teaches from:
##  - "examples": up to 3 positions per technique where the solver's next step is that technique.
##    Each puzzle is walked step by step from its clues (SudokuSolver.get_full_step_by_step_solution);
##    the first position in a puzzle whose step is the technique is a candidate, and the calmest
##    boards (fewest pencil marks on them, singles: the ones nearest a mid-game board) are kept,
##    one per puzzle.
##  - "practice": up to 30 puzzles per technique that the analyzer solves without guessing and
##    whose solution path uses it. Puzzles whose hardest technique is the technique itself come
##    first (the technique is what the puzzle is about), then puzzles with a harder hardest
##    technique, easiest first. Within a group the puzzles using the technique most often lead.
## Sources, in this order: a fixed set of live-generated Easy puzzles (the bank holds none, and
## the singles are only the hardest technique there), then the Medium, Hard and Expert banks.
## Everything is deterministic: the same Godot version, generator and banks rebuild the same file.
##   godot --headless --path . -s tools/build_technique_examples.gd

const SudokuBoard = preload("res://scripts/core/sudoku_board.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const SudokuSolver = preload("res://scripts/core/sudoku_solver.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const TechniqueLibrary = preload("res://scripts/data/technique_library.gd")

const OUT_PATH: String = "res://assets/techniques/examples.json"
## Easy puzzles generated as practice material for the singles
const EASY_COUNT: int = 40
const EASY_SEED_BASE: int = 7_300_000_000
const EASY_SEED_STEP: int = 104_729
## First-occurrence positions gathered per technique before the calmest are kept
const POOL_PER_TECHNIQUE: int = 40
## Pencil-mark total of a mid-game board, what the singles' examples aim for
const SINGLES_TARGET_MARKS: int = 170

func _init() -> void:
	var started := Time.get_ticks_msec()
	var sources: Array[Dictionary] = []
	for i in range(EASY_COUNT):
		var gen := SudokuGenerator.generate_live(EASY_SEED_BASE + i * EASY_SEED_STEP, DifficultyAnalyzer.LEVEL_EASY)
		if gen != null:
			sources.append({"puzzle": gen.puzzle.to_string_flat(), "level": DifficultyAnalyzer.LEVEL_EASY})
	for level in [DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD, DifficultyAnalyzer.LEVEL_EXPERT]:
		for flat in SudokuGenerator.bank(level):
			sources.append({"puzzle": flat, "level": level})

	var pools: Dictionary = {}
	var users: Dictionary = {}
	for tech in TechniqueLibrary.ORDER:
		pools[tech] = []
		users[tech] = []

	var skipped := 0
	print("%d puzzles to walk" % sources.size())
	for src in sources:
		var board := SudokuBoard.new()
		board.from_string_flat(src["puzzle"], true)
		var walk := SudokuSolver.get_full_step_by_step_solution(board)
		var steps: Array = walk["steps"]
		var counts: Dictionary = {}
		var hardest := 1
		var logical := true
		for step in steps:
			if not TechniqueLibrary.WEIGHTS.has(step.technique) and step.technique != "Full House":
				logical = false
				break
			counts[step.technique] = int(counts.get(step.technique, 0)) + 1
			hardest = maxi(hardest, step.difficulty_weight)
		if not logical:
			skipped += 1
			continue
		var seen: Dictionary = {}
		for i in range(steps.size()):
			var tech: String = steps[i].technique
			if not pools.has(tech) or seen.has(tech):
				continue
			seen[tech] = true
			if steps[i].difficulty_weight != TechniqueLibrary.WEIGHTS[tech]:
				printerr("Weight of %s is %d in the solver, %d in TechniqueLibrary" % [tech, steps[i].difficulty_weight, TechniqueLibrary.WEIGHTS[tech]])
			if pools[tech].size() < POOL_PER_TECHNIQUE:
				var snap: SudokuBoard = walk["snapshots"][i]
				var marks := 0
				var cands: Array = []
				for c in range(SudokuBoard.CELL_COUNT):
					marks += snap.get_candidate_count(c)
					cands.append(snap.candidates[c])
				pools[tech].append({
					"puzzle": src["puzzle"], "board": snap.to_string_flat(),
					"candidates": cands, "technique": tech, "marks": marks,
				})
		for tech in counts.keys():
			if users.has(tech):
				users[tech].append({
					"puzzle": src["puzzle"], "level": src["level"], "uses": counts[tech],
					"own": hardest == TechniqueLibrary.WEIGHTS[tech], "hardest": hardest,
				})

	var lines := PackedStringArray()
	for tech in TechniqueLibrary.ORDER:
		var pool: Array = pools[tech]
		var singles: bool = TechniqueLibrary.WEIGHTS[tech] <= 2
		pool.sort_custom(func(a, b):
			var ka: int = absi(a["marks"] - SINGLES_TARGET_MARKS) if singles else a["marks"]
			var kb: int = absi(b["marks"] - SINGLES_TARGET_MARKS) if singles else b["marks"]
			return ka < kb)
		var examples: Array = []
		for ex in pool:
			if examples.size() == TechniqueLibrary.EXAMPLES_PER_TECHNIQUE:
				break
			ex.erase("marks")
			examples.append(ex)

		var list: Array = users[tech]
		# sort_custom is not stable: the source order is the final tiebreak
		for i in range(list.size()):
			list[i]["order"] = i
		list.sort_custom(func(a, b):
			if a["own"] != b["own"]:
				return a["own"]
			if not a["own"] and a["hardest"] != b["hardest"]:
				return a["hardest"] < b["hardest"]
			if a["uses"] != b["uses"]:
				return a["uses"] > b["uses"]
			return a["order"] < b["order"])
		var practice: Array = []
		for p in list.slice(0, TechniqueLibrary.PRACTICE_PER_TECHNIQUE):
			practice.append({"puzzle": p["puzzle"], "level": p["level"]})

		var entry := {"examples": examples, "practice": practice}
		lines.append("%s:%s" % [JSON.stringify(tech), JSON.stringify(entry, "", true)])
		print("%-18s %d examples, %d practice (%d with it as the hardest technique)" % [
			tech, examples.size(), practice.size(), list.filter(func(p): return p["own"]).size()])

	var text := "{\"version\":1,\"techniques\":{\n" + ",\n".join(lines) + "\n}}\n"
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		printerr("Cannot write " + OUT_PATH)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("%d bytes written to %s from %d puzzles (%d skipped, not solvable without guessing) in %d s" % [
		text.length(), OUT_PATH, sources.size(), skipped, (Time.get_ticks_msec() - started) / 1000])
	quit()
