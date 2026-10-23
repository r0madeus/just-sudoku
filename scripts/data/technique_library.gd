class_name TechniqueLibrary
extends RefCounted

## The solving techniques the Techniques screen teaches, with the example positions and practice
## puzzles tools/build_technique_examples.gd precomputed for each (assets/techniques/examples.json).

const DATA_PATH: String = "res://assets/techniques/examples.json"

## The solver's names for the techniques, easiest first (the order of their difficulty weights)
const ORDER: Array[String] = [
	"Naked Single", "Hidden Single", "Locked Candidates", "Naked Pair", "Hidden Pair",
	"Naked Triple", "Hidden Triple", "X-Wing", "XY-Wing", "XYZ-Wing", "Swordfish",
	"Simple Coloring", "XY-Chain",
]

## Difficulty weight of each technique in the solver (the level it belongs to follows from it)
const WEIGHTS: Dictionary = {
	"Naked Single": 1, "Hidden Single": 2, "Locked Candidates": 3, "Naked Pair": 4,
	"Hidden Pair": 5, "Naked Triple": 6, "Hidden Triple": 7, "X-Wing": 8, "XY-Wing": 9,
	"XYZ-Wing": 10, "Swordfish": 10, "Simple Coloring": 11, "XY-Chain": 12,
}

## Examples shown per technique, practice puzzles kept per technique
const EXAMPLES_PER_TECHNIQUE: int = 3
const PRACTICE_PER_TECHNIQUE: int = 30

static var _data: Dictionary = {}
static var _loaded: bool = false

## Dictionary key of a technique's plain-language description, "TECH_DESC_X_WING" for "X-Wing"
static func description_key(tech: String) -> String:
	return "TECH_DESC_" + tech.to_upper().replace("-", "_").replace(" ", "_")

## The level whose puzzles first force the technique: the hardest-technique weight bands the
## analyzer rates levels by
static func first_level(tech: String) -> String:
	var weight: int = int(WEIGHTS.get(tech, 1))
	if weight >= DifficultyAnalyzer.EXPERT_MIN_WEIGHT:
		return DifficultyAnalyzer.LEVEL_EXPERT
	if weight >= DifficultyAnalyzer.HARD_MIN_WEIGHT:
		return DifficultyAnalyzer.LEVEL_HARD
	if weight >= DifficultyAnalyzer.MEDIUM_MIN_WEIGHT:
		return DifficultyAnalyzer.LEVEL_MEDIUM
	return DifficultyAnalyzer.LEVEL_EASY

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data = parsed.get("techniques", {})

## Example positions of a technique: {"puzzle", "board", "candidates", "technique"}
static func examples(tech: String) -> Array:
	_ensure_loaded()
	var entry: Dictionary = _data.get(tech, {})
	return entry.get("examples", [])

## Practice puzzles of a technique: {"puzzle", "level"}
static func practice(tech: String) -> Array:
	_ensure_loaded()
	var entry: Dictionary = _data.get(tech, {})
	return entry.get("practice", [])

## The position of an example as a board: its digits (the puzzle's clues as givens) and the
## candidates stored with it, which hold what earlier steps already ruled out
static func board_of(example: Dictionary) -> SudokuBoard:
	var puzzle := SudokuBoard.new()
	puzzle.from_string_flat(String(example.get("puzzle", "")), true)
	var board := SudokuBoard.new()
	board.from_string_flat(String(example.get("board", "")), false)
	for i in range(SudokuBoard.CELL_COUNT):
		board.givens[i] = puzzle.is_given(i)
	var cands: Array = example.get("candidates", [])
	for i in range(mini(cands.size(), SudokuBoard.CELL_COUNT)):
		board.candidates[i] = 0 if board.get_cell(i) != 0 else int(cands[i])
	return board

## Plays a step on a board: a placement fills the cell and strikes the digit from its peers,
## an elimination strikes the listed candidates. Notes the step did not touch stay as they are.
static func apply_step(board: SudokuBoard, step: SudokuSolver.SolveStep) -> void:
	if step.digit != 0 and step.cells.size() == 1:
		var idx: int = step.cells[0]
		board.set_cell(idx, step.digit, false)
		for peer in SudokuBoard.PEERS[idx]:
			board.remove_candidate(peer, step.digit)
		return
	for idx_key in step.eliminations.keys():
		for d in step.eliminations[idx_key]:
			board.remove_candidate(int(idx_key), d)
