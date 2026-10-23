## XY-Wing, XYZ-Wing, Simple Coloring and XY-Chain. Static finders for SudokuSolver, which keeps
## the public API and the search order.
extends RefCounted

static func _find_xy_wing(board: SudokuBoard) -> SudokuSolver.SolveStep:
	# XY-Wing: Pivot with (X, Y), Pincer1 with (X, Z), Pincer2 with (Y, Z)
	var bi_value_cells: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0 and board.get_candidate_count(idx) == 2:
			bi_value_cells.append(idx)

	for pivot in bi_value_cells:
		var p_cands: Array[int] = board.get_candidates(pivot)
		var x: int = p_cands[0]
		var y: int = p_cands[1]

		var pincer_x: Array[int] = [] # has x and z
		var pincer_y: Array[int] = [] # has y and z

		for other in bi_value_cells:
			if other != pivot and SudokuBoard.PEERS[pivot].has(other):
				var o_cands: Array[int] = board.get_candidates(other)
				if o_cands.has(x) and not o_cands.has(y):
					pincer_x.append(other)
				elif o_cands.has(y) and not o_cands.has(x):
					pincer_y.append(other)

		for px in pincer_x:
			var px_cands: Array[int] = board.get_candidates(px)
			var z_cand: int = px_cands[0] if px_cands[1] == x else px_cands[1]

			for py in pincer_y:
				var py_cands: Array[int] = board.get_candidates(py)
				if py_cands.has(z_cand):
					# Found XY-Wing! Eliminate z_cand from common peers of px and py
					var elims: Dictionary = {}
					for peer in SudokuBoard.PEERS[px]:
						if peer != pivot and peer != px and peer != py:
							if SudokuBoard.PEERS[py].has(peer) and board.get_cell(peer) == 0:
								if board.has_candidate(peer, z_cand):
									elims[peer] = [z_cand]

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "XY-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 9
						step.cells = [pivot, px, py]
						step.eliminations = elims
						step.set_text("EXPL_XY_WING", [{"cell": pivot}, {"cell": px}, {"cell": py}, z_cand])
						return step
	return null

static func _find_xyz_wing(board: SudokuBoard) -> SudokuSolver.SolveStep:
	# Pivot with (X, Y, Z), Pincer1 with (X, Z), Pincer2 with (Y, Z)
	# Pivot and Pincer1 must share a box, and Pincer2 sees pivot.
	var tri_value_cells: Array[int] = []
	var bi_value_cells: Array[int] = []

	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0:
			var cnt: int = board.get_candidate_count(idx)
			if cnt == 3:
				tri_value_cells.append(idx)
			elif cnt == 2:
				bi_value_cells.append(idx)

	for pivot in tri_value_cells:
		var p_cands: Array[int] = board.get_candidates(pivot)
		var p_peers: Array = SudokuBoard.PEERS[pivot]

		# Check all pairs of bi-value peers
		var bi_peers: Array[int] = []
		for bvc in bi_value_cells:
			if p_peers.has(bvc):
				bi_peers.append(bvc)

		for i in range(bi_peers.size()):
			var p1: int = bi_peers[i]
			var p1_cands: Array[int] = board.get_candidates(p1)
			# P1 must share 2 candidates with pivot
			if not (p_cands.has(p1_cands[0]) and p_cands.has(p1_cands[1])):
				continue

			for j in range(i + 1, bi_peers.size()):
				var p2: int = bi_peers[j]
				var p2_cands: Array[int] = board.get_candidates(p2)
				if not (p_cands.has(p2_cands[0]) and p_cands.has(p2_cands[1])):
					continue
				# The wings must be XZ and YZ: two wings with the same pair prove nothing (the
				# pivot could be the third digit while both wings are the shared one's partner)
				if p1_cands[0] == p2_cands[0] and p1_cands[1] == p2_cands[1]:
					continue

				# Find common candidate Z between p1 and p2
				var z_cand: int = 0
				for c in p1_cands:
					if p2_cands.has(c):
						z_cand = c
						break

				if z_cand != 0:
					# Both p1 and p2 share candidate z_cand with pivot
					var elims: Dictionary = {}
					for peer in SudokuBoard.PEERS[pivot]:
						if peer != p1 and peer != p2 and board.get_cell(peer) == 0:
							if SudokuBoard.PEERS[p1].has(peer) and SudokuBoard.PEERS[p2].has(peer):
								if board.has_candidate(peer, z_cand):
									elims[peer] = [z_cand]

					if not elims.is_empty():
						var step := SudokuSolver.SolveStep.new()
						step.technique = "XYZ-Wing"
						step.category = "Advanced"
						step.difficulty_weight = 10
						step.cells = [pivot, p1, p2]
						step.eliminations = elims
						step.set_text("EXPL_XYZ_WING", [{"cell": pivot}, z_cand])
						return step

	return null

## Simple Coloring: where a digit has exactly two places in a unit, one of them holds it (a
## strong link). Linked cells are coloured alternately; in each chain one colour is all true.
## Two cells of one colour in the same unit: that colour is false, so its cells lose the digit.
## A cell outside the chain that sees both colours cannot hold the digit.
static func _find_simple_coloring(board: SudokuBoard) -> SudokuSolver.SolveStep:
	for d in range(1, 10):
		# Strong links for d
		var links: Dictionary = {} # cell -> Array of linked cells
		for unit in SudokuSolver.ALL_UNITS:
			var at: Array[int] = []
			for idx in unit:
				if board.get_cell(idx) == 0 and board.has_candidate(idx, d):
					at.append(idx)
			if at.size() == 2:
				if not links.has(at[0]): links[at[0]] = []
				if not links.has(at[1]): links[at[1]] = []
				if not links[at[0]].has(at[1]): links[at[0]].append(at[1])
				if not links[at[1]].has(at[0]): links[at[1]].append(at[0])

		var colored: Dictionary = {} # cell -> 0 or 1
		var starts: Array = links.keys()
		starts.sort()
		for start in starts:
			if colored.has(start):
				continue
			# Colour one chain
			var chain: Array[int] = [start]
			var color: Dictionary = {start: 0}
			var queue: Array[int] = [start]
			while not queue.is_empty():
				var cur: int = queue.pop_front()
				for nb in links[cur]:
					if not color.has(nb):
						color[nb] = 1 - int(color[cur])
						chain.append(nb)
						queue.append(nb)
			for c in chain:
				colored[c] = color[c]
			if chain.size() < 3:
				continue
			chain.sort()

			# Colour wrap: two cells of one colour see each other
			for bad in [0, 1]:
				var clash := false
				for i in range(chain.size()):
					for j in range(i + 1, chain.size()):
						if color[chain[i]] == bad and color[chain[j]] == bad and SudokuBoard.PEERS[chain[i]].has(chain[j]):
							clash = true
							break
					if clash:
						break
				if clash:
					var elims: Dictionary = {}
					for c in chain:
						if color[c] == bad:
							elims[c] = [d]
					return _coloring_step(d, chain, elims, "EXPL_SIMPLE_COLORING_WRAP")

			# Colour trap: an outside cell seeing both colours
			var elims: Dictionary = {}
			for idx in range(SudokuBoard.CELL_COUNT):
				if color.has(idx) or board.get_cell(idx) != 0 or not board.has_candidate(idx, d):
					continue
				var sees := [false, false]
				for c in chain:
					if SudokuBoard.PEERS[idx].has(c):
						sees[int(color[c])] = true
				if sees[0] and sees[1]:
					elims[idx] = [d]
			if not elims.is_empty():
				return _coloring_step(d, chain, elims, "EXPL_SIMPLE_COLORING_TRAP")
	return null

static func _coloring_step(d: int, chain: Array[int], elims: Dictionary, key: String) -> SudokuSolver.SolveStep:
	var step := SudokuSolver.SolveStep.new()
	step.technique = "Simple Coloring"
	step.category = "Advanced"
	step.difficulty_weight = 11
	step.cells = chain
	step.eliminations = elims
	step.set_text(key, [d, d])
	return step

## Longest XY-Chain followed, in cells; longer chains are rare and slow to search
const XY_CHAIN_MAX_CELLS: int = 12

## XY-Chain: two-candidate cells, each seeing the next and sharing a digit with it. If the first
## cell is not z it is its other digit, which forces the next cell, and so on, until a cell is
## forced to z. So the first or the last cell is z, and any cell seeing both cannot be.
static func _find_xy_chain(board: SudokuBoard) -> SudokuSolver.SolveStep:
	var bivalue: Array[int] = []
	for idx in range(SudokuBoard.CELL_COUNT):
		if board.get_cell(idx) == 0 and board.get_candidate_count(idx) == 2:
			bivalue.append(idx)
	if bivalue.size() < 3:
		return null

	for start in bivalue:
		var sc: Array[int] = board.get_candidates(start)
		for zi in range(2):
			var z: int = sc[zi]
			var first_value: int = sc[1 - zi]
			# Breadth first over (cell, value the chain forces on it); shortest chains first
			var parent: Dictionary = {}
			var depth: Dictionary = {}
			var start_key: int = start * 10 + first_value
			parent[start_key] = -1
			depth[start_key] = 1
			var queue: Array[int] = [start_key]
			while not queue.is_empty():
				var key: int = queue.pop_front()
				var cell: int = key / 10
				var value: int = key % 10
				if depth[key] >= XY_CHAIN_MAX_CELLS:
					continue
				for nb in bivalue:
					if nb == cell or nb == start or not SudokuBoard.PEERS[cell].has(nb) or not board.has_candidate(nb, value):
						continue
					var nc: Array[int] = board.get_candidates(nb)
					var forced: int = nc[0] if nc[1] == value else nc[1]
					var nkey: int = nb * 10 + forced
					if parent.has(nkey):
						continue
					parent[nkey] = key
					depth[nkey] = int(depth[key]) + 1
					if forced == z and int(depth[nkey]) >= 3:
						var elims: Dictionary = {}
						for peer in SudokuBoard.PEERS[start]:
							if peer != nb and SudokuBoard.PEERS[nb].has(peer) and board.get_cell(peer) == 0 and board.has_candidate(peer, z):
								elims[peer] = [z]
						if not elims.is_empty():
							var chain: Array[int] = []
							var k: int = nkey
							while k != -1:
								chain.push_front(k / 10)
								k = parent[k]
							var step := SudokuSolver.SolveStep.new()
							step.technique = "XY-Chain"
							step.category = "Advanced"
							step.difficulty_weight = 12
							step.cells = chain
							step.eliminations = elims
							step.set_text("EXPL_XY_CHAIN", [{"cell": start}, {"cell": nb}, z, z])
							return step
					queue.append(nkey)
	return null
