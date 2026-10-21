class_name SudokuBoard
extends RefCounted

## 9x9 Sudoku Board Model
## Stores cell values, givens (initial clues), and candidate bitmasks.

const SIZE: int = 9
const CELL_COUNT: int = 81
const ALL_CANDIDATES_MASK: int = 0x3FE # Bits 1 to 9 set (1022 in decimal)

# Precomputed index tables
static var ROW_INDICES: Array = []
static var COL_INDICES: Array = []
static var BOX_INDICES: Array = []
static var PEERS: Array = []
static var CELL_ROW: PackedByteArray = PackedByteArray()
static var CELL_COL: PackedByteArray = PackedByteArray()
static var CELL_BOX: PackedByteArray = PackedByteArray()

var values: PackedByteArray
var givens: Array[bool]
var candidates: PackedInt32Array

static func _static_init() -> void:
	ROW_INDICES.resize(SIZE)
	COL_INDICES.resize(SIZE)
	BOX_INDICES.resize(SIZE)
	PEERS.resize(CELL_COUNT)
	CELL_ROW.resize(CELL_COUNT)
	CELL_COL.resize(CELL_COUNT)
	CELL_BOX.resize(CELL_COUNT)

	for r in range(SIZE):
		ROW_INDICES[r] = []
	for c in range(SIZE):
		COL_INDICES[c] = []
	for b in range(SIZE):
		BOX_INDICES[b] = []

	for idx in range(CELL_COUNT):
		var r: int = idx / SIZE
		var c: int = idx % SIZE
		var b: int = (r / 3) * 3 + (c / 3)
		CELL_ROW[idx] = r
		CELL_COL[idx] = c
		CELL_BOX[idx] = b
		ROW_INDICES[r].append(idx)
		COL_INDICES[c].append(idx)
		BOX_INDICES[b].append(idx)

	for idx in range(CELL_COUNT):
		var r: int = CELL_ROW[idx]
		var c: int = CELL_COL[idx]
		var b: int = CELL_BOX[idx]
		var peer_dict: Dictionary = {}

		for peer_idx in ROW_INDICES[r]:
			if peer_idx != idx:
				peer_dict[peer_idx] = true
		for peer_idx in COL_INDICES[c]:
			if peer_idx != idx:
				peer_dict[peer_idx] = true
		for peer_idx in BOX_INDICES[b]:
			if peer_idx != idx:
				peer_dict[peer_idx] = true

		PEERS[idx] = peer_dict.keys()

func _init() -> void:
	clear()

func clear() -> void:
	values = PackedByteArray()
	values.resize(CELL_COUNT)
	givens.clear()
	givens.resize(CELL_COUNT)
	givens.fill(false)
	candidates = PackedInt32Array()
	candidates.resize(CELL_COUNT)
	candidates.fill(0)

static func get_index(row: int, col: int) -> int:
	return row * SIZE + col

func get_cell(idx: int) -> int:
	return values[idx]

func set_cell(idx: int, val: int, is_given: bool = false) -> void:
	values[idx] = val
	givens[idx] = is_given
	if val != 0:
		candidates[idx] = 0

func is_given(idx: int) -> bool:
	return givens[idx]

func is_empty(idx: int) -> bool:
	return values[idx] == 0

func has_candidate(idx: int, digit: int) -> bool:
	return (candidates[idx] & (1 << digit)) != 0

func add_candidate(idx: int, digit: int) -> void:
	if digit >= 1 and digit <= 9:
		candidates[idx] |= (1 << digit)

func remove_candidate(idx: int, digit: int) -> bool:
	if digit < 1 or digit > 9:
		return false
	var bit: int = 1 << digit
	if (candidates[idx] & bit) != 0:
		candidates[idx] &= ~bit
		return true
	return false

func toggle_candidate(idx: int, digit: int) -> void:
	if digit >= 1 and digit <= 9:
		candidates[idx] ^= (1 << digit)

func clear_candidates(idx: int) -> void:
	candidates[idx] = 0

func clear_all_candidates() -> void:
	candidates.fill(0)

func get_candidates(idx: int) -> Array[int]:
	var result: Array[int] = []
	var mask: int = candidates[idx]
	for d in range(1, 10):
		if (mask & (1 << d)) != 0:
			result.append(d)
	return result

func get_candidate_count(idx: int) -> int:
	var mask: int = candidates[idx]
	var count: int = 0
	while mask > 0:
		count += mask & 1
		mask >>= 1
	return count

func get_empty_cell_count() -> int:
	var count: int = 0
	for idx in range(CELL_COUNT):
		if values[idx] == 0:
			count += 1
	return count

func get_digit_count(digit: int) -> int:
	var count: int = 0
	for idx in range(CELL_COUNT):
		if values[idx] == digit:
			count += 1
	return count

func reset_candidates_from_grid() -> void:
	for idx in range(CELL_COUNT):
		if values[idx] != 0:
			candidates[idx] = 0
		else:
			var mask: int = ALL_CANDIDATES_MASK
			for peer_idx in PEERS[idx]:
				var peer_val: int = values[peer_idx]
				if peer_val != 0:
					mask &= ~(1 << peer_val)
			candidates[idx] = mask

func clone() -> SudokuBoard:
	var copy := SudokuBoard.new()
	copy.values = values.duplicate()
	copy.givens = givens.duplicate()
	copy.candidates = candidates.duplicate()
	return copy

func to_string_flat() -> String:
	var result: String = ""
	for i in range(CELL_COUNT):
		var v: int = values[i]
		result += str(v) if v != 0 else "."
	return result

func from_string_flat(flat_str: String, as_givens: bool = true) -> void:
	clear()
	var clean: String = flat_str.replace(" ", "").replace("\n", "").replace("\r", "")
	var limit: int = mini(clean.length(), CELL_COUNT)
	for i in range(limit):
		var ch: String = clean[i]
		if ch >= "1" and ch <= "9":
			set_cell(i, ch.to_int(), as_givens)
		else:
			set_cell(i, 0, false)
	reset_candidates_from_grid()
