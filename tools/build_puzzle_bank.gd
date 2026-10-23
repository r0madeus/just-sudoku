extends SceneTree

## Builds the puzzle bank (assets/puzzles/<level>.txt) the game draws Medium, Hard and Expert
## puzzles from. Each line is one puzzle, 81 characters, "." for an empty cell. Only puzzles the
## analyzer rates at the level and that it solves without guessing go in. The seeds are fixed,
## so the same Godot version and generator rebuild the same bank.
##   LEVEL=Expert FROM=0 COUNT=100 OUT=/tmp/expert_0.txt godot --headless --path . -s tools/build_puzzle_bank.gd
## Runs of separate FROM ranges can go side by side; join their files with tools/build_puzzle_bank.sh.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

## Bank seeds start here, well away from the seeds players and tests use
const SEED_BASE: int = 7_100_000_000
const SEED_STEP: int = 104_729

func _init() -> void:
	var level := OS.get_environment("LEVEL")
	var from := int(OS.get_environment("FROM"))
	var count := int(OS.get_environment("COUNT"))
	var out_path := OS.get_environment("OUT")
	if not SudokuGenerator.LEVEL_ORDER.has(level) or count <= 0 or out_path.is_empty():
		printerr("Set LEVEL (Easy, Medium, Hard, Expert), FROM, COUNT and OUT")
		quit(1)
		return
	var lines := PackedStringArray()
	var skipped := 0
	for i in range(from, from + count):
		var gen := SudokuGenerator.generate_live(SEED_BASE + i * SEED_STEP, level)
		if gen == null:
			skipped += 1
			continue
		var analysis := DifficultyAnalyzer.analyze(gen.puzzle)
		if analysis.level != level or not analysis.solved_logically:
			skipped += 1
			continue
		lines.append(gen.puzzle.to_string_flat())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("%s: %d puzzles written, %d skipped (not at the level or not solvable without guessing)" % [level, lines.size(), skipped])
	quit()
