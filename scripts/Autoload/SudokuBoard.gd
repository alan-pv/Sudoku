# SudokuBoard.gd
#
# Board generation and solving. Pure logic: it never touches a node.
#
# generate_board(n, difficulty, zones) returns a Dictionary keyed by
# Vector2i(x = column, y = row), each entry holding:
#   { "value": int, "solution": int, "zone": int }
# where "value" is 0 for a cell the player has to fill in.

extends Node
class_name SudokuBoard

enum TypeDifficulty { EASY, MEDIUM, HARD }

const LEVEL_NONE := 0
const LEVEL_SINGLES := 1
const LEVEL_PAIRS := 2
const LEVEL_SEARCH := 99

static var _USE_ZONES: bool = false
static var _ZONE_MAP: Array = []
static var _zone_cells_cache = {}
static var box_size: int = -1

## Candidate bitmasks: bit i of a mask stands for the value i + 1.
static var _ROW_MASK: Array = []
static var _COL_MASK: Array = []
static var _ZONE_MASK: Array = []
static var _ALL_MASK: int = 0

#region Main Board Generation

static func generate_board(n: int = 9, difficulty: TypeDifficulty = TypeDifficulty.EASY, zones: bool = false) -> Dictionary:
	_USE_ZONES = zones
	_ZONE_MAP = [] 
	_zone_cells_cache = {}
	box_size = int(sqrt(float(n)))
	if box_size * box_size != n:
		push_error("SudokuBoard.generate_board: n debe ser un cuadrado perfecto (4,9,16,...)")
		return {}
	
	_ALL_MASK = (1 << n) - 1
	_ROW_MASK = [] ; _COL_MASK = [] ; _ZONE_MASK = []
	for i in range(n): _ROW_MASK.append(0); _COL_MASK.append(0); _ZONE_MASK.append(0)
	
	_ZONE_MAP = _initialize_standard_regions(n)
	_update_zone_cache(n)
	
	# Build a complete, valid grid first...
	var full = _generate_full_with_retry(n)
	
	# ...then take cells away from it.
	var puzzle = _generate_puzzle(full, difficulty, n)
	return _to_output_dict(puzzle, full, n)
#endregion

#region Zone Generation - Jigsaw Algorithm

## Grows jigsaw regions from the standard boxes by controlled swapping.
static func _generate_zones(n: int, regions: int = 9, swap_steps: int = 25) -> Array:
	if (n * n) % regions != 0:
		return []
	
	var region_size = (n * n) / regions
	
	# 1. Start from the traditional boxes.
	var zone_map = _initialize_standard_regions(n)
	
	# 2. Swap repeatedly to bend them into irregular shapes.
	for step in range(swap_steps):
		_perform_simple_swap(zone_map, n, region_size)
	
	return zone_map

## Swaps one cell between two neighbouring regions, if it stays legal.
static func _perform_simple_swap(zone_map: Array, n: int, region_size: int) -> bool:
	# Every pair of regions that share a border.
	var neighbor_pairs = _find_neighbor_region_pairs(zone_map, n)
	
	if neighbor_pairs.is_empty():
		return false
	
	# Shuffle so the layout does not settle into a pattern.
	neighbor_pairs.shuffle()
	
	# Try pairs until one admits a legal swap.
	for pair in neighbor_pairs:
		var region_a = pair[0]
		var region_b = pair[1]
		
		# Only cells on the shared border can move.
		var border_cells_a = _find_border_cells_for_region(zone_map, n, region_a, region_b)
		var border_cells_b = _find_border_cells_for_region(zone_map, n, region_b, region_a)
		
		if border_cells_a.is_empty() or border_cells_b.is_empty():
			continue
		
		# Shuffle the border cells too.
		border_cells_a.shuffle()
		border_cells_b.shuffle()
		
		# Try combinations until one keeps both regions connected.
		for cell_a in border_cells_a:
			for cell_b in border_cells_b:
				# A swap that splits a region in two is not allowed.
				if _is_swap_valid(zone_map, n, region_size, region_a, region_b, cell_a, cell_b):
					# Commit it.
					zone_map[cell_a.y][cell_a.x] = region_b
					zone_map[cell_b.y][cell_b.x] = region_a
					return true
	
	return false

## Cells of source_region that touch target_region.
static func _find_border_cells_for_region(zone_map: Array, n: int, source_region: int, target_region: int) -> Array:
	var border_cells = []
	
	for y in range(n):
		for x in range(n):
			if zone_map[y][x] == source_region:
				var neighbors = _get_neighbor_cells(x, y, n)
				for neighbor in neighbors:
					if zone_map[neighbor.y][neighbor.x] == target_region:
						border_cells.append(Vector2i(x, y))
						break
	
	return border_cells

## Every unordered pair of regions that share a border.
static func _find_neighbor_region_pairs(zone_map: Array, n: int) -> Array:
	var pairs = []
	var processed_pairs = {}
	
	for y in range(n):
		for x in range(n):
			var current_region = zone_map[y][x]
			var neighbors = _get_neighbor_cells(x, y, n)
			
			for neighbor in neighbors:
				var neighbor_region = zone_map[neighbor.y][neighbor.x]
				
				if neighbor_region != current_region:
					# Order the ids so each pair is only recorded once.
					var pair_key = ""
					if current_region < neighbor_region:
						pair_key = str(current_region) + "_" + str(neighbor_region)
					else:
						pair_key = str(neighbor_region) + "_" + str(current_region)
					
					if not processed_pairs.has(pair_key):
						processed_pairs[pair_key] = true
						pairs.append([current_region, neighbor_region])
	
	return pairs

## Whether swapping two cells leaves both regions connected.
static func _is_swap_valid(zone_map: Array, n: int, region_size: int, region_a: int, region_b: int, cell_a: Vector2i, cell_b: Vector2i) -> bool:
	# Test on a copy; the real map must not change if the swap fails.
	var test_map = []
	for i in range(n):
		test_map.append(zone_map[i].duplicate())
	
	# Apply the swap to the copy.
	test_map[cell_a.y][cell_a.x] = region_b
	test_map[cell_b.y][cell_b.x] = region_a
	
	# Both regions have to survive it.
	return _is_region_connected(test_map, region_a, n, region_size) and _is_region_connected(test_map, region_b, n, region_size)

## Breadth-first flood fill: connected iff it reaches every cell.
static func _is_region_connected(zone_map: Array, region_id: int, n: int, expected_size: int) -> bool:
	# Any cell of the region will do as a starting point.
	var start_cell = null
	for y in range(n):
		for x in range(n):
			if zone_map[y][x] == region_id:
				start_cell = Vector2i(x, y)
				break
		if start_cell != null:
			break
	
	if start_cell == null:
		return false
	
	# Walk outwards, counting what we can reach.
	var visited = []
	for i in range(n):
		visited.append([])
		for j in range(n):
			visited[i].append(false)
	
	var queue = [start_cell]
	visited[start_cell.y][start_cell.x] = true
	var count = 0
	
	while not queue.is_empty():
		var cell = queue.pop_front()
		count += 1
		
		# Cardinal neighbours only; diagonals do not connect a region.
		var neighbors = _get_neighbor_cells(cell.x, cell.y, n)
		for neighbor in neighbors:
			if not visited[neighbor.y][neighbor.x] and zone_map[neighbor.y][neighbor.x] == region_id:
				visited[neighbor.y][neighbor.x] = true
				queue.append(neighbor)
	
	# Reached every cell means the region is in one piece.
	return count == expected_size

## The in-bounds neighbours of a cell, in the four cardinal directions.
static func _get_neighbor_cells(x: int, y: int, n: int) -> Array:
	var neighbors = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx >= 0 and nx < n and ny >= 0 and ny < n:
			neighbors.append(Vector2i(nx, ny))
	
	return neighbors

## The traditional boxes: 3x3 for a 9x9 board, 2x2 for a 4x4.
static func _initialize_standard_regions(n: int) -> Array:
	var zone_map = _create_empty_board(n)
	var zone_id = 0
	
	# Walk the boxes in reading order, numbering them as we go.
	for box_row in range(0, n, box_size):
		for box_col in range(0, n, box_size):
			for r in range(box_row, box_row + box_size):
				for c in range(box_col, box_col + box_size):
					zone_map[r][c] = zone_id
			zone_id += 1
	
	return zone_map
#endregion

#region Full Board Generation

## Retries until a complete grid comes out.
static func _generate_full_with_retry(n: int) -> Array:
	var attempts = 0
	
	while true:
		if _USE_ZONES:
			var swap_steps = n * 6 + randi() % (n * 10)
			_ZONE_MAP = _generate_zones(n, n, swap_steps)
			_update_zone_cache(n)
		
		# A hostile jigsaw layout can stall the search, so each attempt is
		# given a budget and the regions are redrawn if it runs out.
		var end_time = 25 * n * n
		var full = _generate_full(n, end_time)
		
		if not full.is_empty():
			return full
		
		attempts += 1
	return []

static func _create_empty_board(n: int) -> Array:
	var board = []
	board.resize(n)
	for i in range(n):
		board[i] = []
		board[i].resize(n)
		board[i].fill(0)
	return board

## One attempt at a complete grid, within the given time budget.
static func _generate_full(n: int, end_time: int) -> Array:
	var board: Array = _create_empty_board(n)
	var start_time = Time.get_ticks_msec()
	var empty_cells = _compute_all_empty_cells(board, n)
	var success = _fill_board_masks(board, empty_cells, 0, start_time, end_time)
	
	if success and _validate_complete_board(board, n):
		return board
	return []

## Backtracking search, always expanding the most constrained cell.
static func _fill_board_masks(board: Array, empty_cells: Array, depth: int, start_time: int, end_time: int) -> bool:
	if empty_cells.is_empty():
		return true

	if Time.get_ticks_msec() - start_time > end_time:
		return false

	# Minimum remaining values: fewest candidates first.
	var best_idx = -1
	var best_mask = 0
	var best_count = 999
	for i in range(empty_cells.size()):
		var cell = empty_cells[i]
		var mask = _candidates_mask_for_cell(cell.y, cell.x)
		var cnt = _bit_count(mask)
		if cnt == 0:
			return false
		if cnt < best_count:
			best_count = cnt
			best_mask = mask
			best_idx = i
			if cnt == 1:
				break

	if best_idx == -1:
		return false

	# Take the chosen cell out of the pending list.
	var chosen_cell = empty_cells[best_idx]
	var new_empty = empty_cells.duplicate()
	new_empty.remove_at(best_idx)

	# Shuffle the candidates so repeated runs produce different boards.
	var candidates_list = _bits_to_list(best_mask)
	candidates_list.shuffle()

	for val in candidates_list:
		_assign_value(board, chosen_cell.y, chosen_cell.x, val)
		if _fill_board_masks(board, new_empty, depth + 1, start_time, end_time):
			return true
		_unassign_value(board, chosen_cell.y, chosen_cell.x, val)

	return false

## Caches the cells of each region; the hidden-single check leans on it.
static func _update_zone_cache(n: int):
	_zone_cells_cache = {}
	for y in range(n):
		for x in range(n):
			var zid = _ZONE_MAP[y][x]
			if not _zone_cells_cache.has(zid):
				_zone_cells_cache[zid] = []
			_zone_cells_cache[zid].append(Vector2i(x, y))

## Every empty cell on the board.
static func _compute_all_empty_cells(board: Array, n: int) -> Array:
	var empty_cells = []
	for y in range(n):
		for x in range(n):
			if board[y][x] == 0:
				empty_cells.append(Vector2i(x, y))
	return empty_cells

## Whether every row, column and region holds all n values.
static func _validate_complete_board(board: Array, n: int) -> bool:
	_reset_masks(board, n)
	
	for i in range(n):
		if _ROW_MASK[i] != _ALL_MASK or _COL_MASK[i] != _ALL_MASK or _ZONE_MASK[i] != _ALL_MASK:
			return false
	
	return true

#endregion

#region Puzzle Generation
## Carves a puzzle out of a full grid by removing cells.
static func _generate_puzzle(full: Array, difficulty: TypeDifficulty, n: int) -> Array:
	var puzzle = full.duplicate(true)
	var target_filled = _difficulty_to_filled_count(n, difficulty)
	var allowed_level = _difficulty_to_allowed_level(difficulty)
	var cells = _get_shuffled_cells(n)
	var total_cells = n * n
	var cells_to_remove = total_cells - target_filled
	var fast_removal_count = int(cells_to_remove * 0.8)
	var removed_count = 0
	
	# Pass 1: uniqueness only, which is the cheap check.
	while removed_count < fast_removal_count and cells.size() > 0:
		var cell: Vector2i = cells.pop_back()
		var saved = puzzle[cell.y][cell.x]
		puzzle[cell.y][cell.x] = 0
		
		if _count_solutions_masks(puzzle, 2, n) == 1:
			removed_count += 1
		else:
			puzzle[cell.y][cell.x] = saved
	
	# Pass 2: also require that a person could solve it.
	while cells.size() > 0:
		# Count what is still filled in.
		var current_filled = 0
		for r in puzzle:
			for v in r:
				if v != 0: current_filled += 1
		
		# Stop once the target number of givens is reached.
		if current_filled <= target_filled:
			break
			
		var cell: Vector2i = cells.pop_back()
		var saved = puzzle[cell.y][cell.x]
		puzzle[cell.y][cell.x] = 0
		
		# Removing this cell must not open up a second solution.
		var count = _count_solutions_masks(puzzle, 2, n)
		if count != 1:
			puzzle[cell.y][cell.x] = saved
			continue
		
		# And the result must still be solvable without guessing.
		var human_solvable = _human_solve(puzzle, allowed_level, n)
		if not human_solvable:
			puzzle[cell.y][cell.x] = saved
	
	return puzzle

## How many cells stay filled, per difficulty.
static func _difficulty_to_filled_count(n: int, difficulty: TypeDifficulty) -> int:
	var total_cells = n * n
	match difficulty:
		TypeDifficulty.EASY: return int(total_cells * 0.7)   # 70% pistas
		TypeDifficulty.MEDIUM: return int(total_cells * 0.5) # 50% pistas  
		TypeDifficulty.HARD: return int(total_cells * 0.3)   # 30% pistas
	return int(total_cells * 0.5)

## The hardest technique a solver is allowed to need, per difficulty.
static func _difficulty_to_allowed_level(difficulty: TypeDifficulty) -> int:
	match difficulty:
		TypeDifficulty.EASY: return LEVEL_SINGLES
		TypeDifficulty.MEDIUM: return LEVEL_SINGLES
		TypeDifficulty.HARD: return LEVEL_PAIRS
	return LEVEL_PAIRS

#endregion

#region Solution Counting

## Counts solutions, stopping as soon as limit is reached.
## Carving only needs "exactly one or more than one", so limit is 2.
static func _count_solutions_masks(board: Array, limit: int, n: int) -> int:
	_reset_masks(board, n)
	
	# Minimum remaining values again.
	var best_r = -1
	var best_c = -1
	var best_mask = 0
	var best_count = n + 1
	
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0:
				var mask = _candidates_mask_for_cell(r, c)
				var count = _bit_count(mask)
				if count == 0:
					return 0  # No solution
				if count < best_count:
					best_count = count
					best_mask = mask
					best_r = r
					best_c = c
					if count == 1:  # Naked single; nothing will beat it.
						break
		if best_count == 1:
			break
	
	if best_r == -1:
		return 1  # Tablero completo
	
	# Probar candidatos
	var solutions = 0
	var candidates = _bits_to_list(best_mask)
	
	for val in candidates:
		# Asignar valor
		board[best_r][best_c] = val
		_assign_value(board, best_r, best_c, val)
		
		# Llamada recursiva
		solutions += _count_solutions_masks(board, limit - solutions, n)
		
		# Deshacer
		_unassign_value(board, best_r, best_c, val)
		board[best_r][best_c] = 0
		
		if solutions >= limit:
			break
	
	return solutions

#endregion

#region Bitmask

static func _bit_count(x: int) -> int:
	# popcount
	var c = 0
	while x != 0:
		x &= x - 1
		c += 1
	return c

static func _lowest_bit_index(x: int) -> int:
	# Index 0..n-1 of the lowest set bit; -1 when x is 0.
	if x == 0:
		return -1
	var idx = 0
	var t = x
	# Shift until the lowest bit is set.
	while (t & 1) == 0:
		t = t >> 1
		idx += 1
	return idx

static func _bits_to_list(x: int) -> Array:
	# Turns a candidate mask into the list of values it stands for.
	var out: Array = []
	while x != 0:
		# Isolate the lowest set bit.
		var lb = x & -x
		var idx = _lowest_bit_index(lb)
		# Bit i means value i + 1.
		out.append(idx + 1)
		# Clear it and carry on.
		x &= x - 1
	return out

## Values still legal at (r, c), as a bitmask.
static func _candidates_mask_for_cell(r: int, c: int) -> int:
	return _ALL_MASK & ~(_ROW_MASK[r] | _COL_MASK[c] | _ZONE_MASK[_ZONE_MAP[r][c]])

static func _assign_value(board: Array, r: int, c: int, val: int) -> void:
	board[r][c] = val
	var mask = 1 << (val - 1)
	_ROW_MASK[r] |= mask
	_COL_MASK[c] |= mask
	_ZONE_MASK[_ZONE_MAP[r][c]] |= mask


static func _unassign_value(board: Array, r: int, c: int, val: int) -> void:
	board[r][c] = 0
	var mask = ~(1 << (val - 1))
	_ROW_MASK[r] &= mask
	_COL_MASK[c] &= mask
	_ZONE_MASK[_ZONE_MAP[r][c]] &= mask

#endregion

#region Output Format
## Packs the puzzle, its solution and the regions into the output format.
static func _to_output_dict(puzzle: Array, full: Array, n: int) -> Dictionary:
	var out: Dictionary = {}
	for y in range(n):
		for x in range(n):
			out[Vector2i(x, y)] = {"value": puzzle[y][x], "solution": full[y][x], "zone": _ZONE_MAP[y][x]}
			
	return out
#endregion

#region Human Solver
## Whether the puzzle falls to the techniques allowed at this level.
static func _human_solve(board: Array, allowed_level: int, n: int) -> bool:
	var board_copy = board.duplicate(true)
	
	# Singles alone carry most boards; try them before anything harder.
	for i in range(n):
		if not _apply_singles(board_copy, n):
			break
		if _is_filled(board_copy):
			return true
	
	# At the easier levels, singles are all that is on offer.
	if allowed_level == LEVEL_SINGLES:
		return _is_filled(board_copy)
	
	# Otherwise alternate between the techniques until nothing changes.
	var changed = true
	var iterations = 0
	
	while changed and iterations < 50:  # Guard against a technique that never settles.
		changed = false
		iterations += 1
		
		if _apply_singles(board_copy, n):
			changed = true
			if _is_filled(board_copy):
				return true
			continue
		
		if allowed_level >= LEVEL_PAIRS:
			if _apply_naked_subsets_and_pointing(board_copy, n):
				changed = true
				if _is_filled(board_copy):
					return true
				continue
	
	return _is_filled(board_copy)

## Whether every cell holds a value.
static func _is_filled(board: Array) -> bool:
	for r in board:
		for v in r:
			if v == 0:
				return false
	return true
#endregion

#region Solving Techniques
static func _apply_singles(board: Array, n: int) -> bool:
	# Rebuild the masks from the board.
	_reset_masks(board, n)
	
	# Naked singles
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0:
				var mask = _candidates_mask_for_cell(r, c)
				var count = _bit_count(mask)
				if count == 1:
					var val = _lowest_bit_index(mask) + 1
					board[r][c] = val
					_assign_value(board, r, c, val)
					return true
	
	# Hidden singles
	for r in range(n):
		for c in range(n):
			if board[r][c] != 0:
				continue
				
			var original_mask = _candidates_mask_for_cell(r, c)
			var temp_mask = original_mask
			
			while temp_mask != 0:
				var val_mask = temp_mask & -temp_mask
				var val = _lowest_bit_index(val_mask) + 1
				temp_mask &= temp_mask - 1
				
				# Nowhere else in the row?
				var unique_in_row = true
				for other_c in range(n):
					if other_c != c and board[r][other_c] == 0:
						var other_mask = _candidates_mask_for_cell(r, other_c)
						if other_mask & val_mask:
							unique_in_row = false
							break
				if unique_in_row:
					board[r][c] = val
					_assign_value(board, r, c, val)
					return true
				
				# Nowhere else in the column?
				var unique_in_col = true
				for other_r in range(n):
					if other_r != r and board[other_r][c] == 0:
						var other_mask = _candidates_mask_for_cell(other_r, c)
						if other_mask & val_mask:
							unique_in_col = false
							break
				if unique_in_col:
					board[r][c] = val
					_assign_value(board, r, c, val)
					return true
				
				# Nowhere else in the region?
				var unique_in_zone = true
				var zone_id = _ZONE_MAP[r][c]
				for zone_cell in _zone_cells_cache[zone_id]:
					if zone_cell.x == c and zone_cell.y == r:
						continue
					if board[zone_cell.y][zone_cell.x] == 0:
						var other_mask = _candidates_mask_for_cell(zone_cell.y, zone_cell.x)
						if other_mask & val_mask:
							unique_in_zone = false
							break
				if unique_in_zone:
					board[r][c] = val
					_assign_value(board, r, c, val)
					return true
	
	return false

static func _reset_masks(board: Array, n: int):
	for i in range(n):
		_ROW_MASK[i] = 0
		_COL_MASK[i] = 0
		_ZONE_MASK[i] = 0
	
	for r in range(n):
		for c in range(n):
			if board[r][c] != 0:
				_assign_value(board, r, c, board[r][c])

static func _apply_naked_subsets_and_pointing(board: Array, n: int) -> bool:
	# Deliberately conservative: this decides whether a *person* could
	# solve the puzzle, not how fast a machine can.
	var changed = false
	
	# Rebuild the masks from the board. para tener estado consistente
	_reset_masks(board, n)
	
	# Only pairs that immediately force a placement count.
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0:
				var mask = _candidates_mask_for_cell(r, c)
				if _bit_count(mask) == 2:
					# Look along the row.
					for other_c in range(n):
						if other_c != c and board[r][other_c] == 0:
							var other_mask = _candidates_mask_for_cell(r, other_c)
							if mask == other_mask:
								# A genuine naked pair.
								var applied_change = _apply_naked_pair_elimination(board, r, c, other_c, true, n)
								changed = changed or applied_change
					
					# Look down the column.
					for other_r in range(n):
						if other_r != r and board[other_r][c] == 0:
							var other_mask = _candidates_mask_for_cell(other_r, c)
							if mask == other_mask:
								var applied_change = _apply_naked_pair_elimination(board, r, c, other_r, false, n)
								changed = changed or applied_change
	
	return changed

static func _apply_naked_pair_elimination(board: Array, main_coord: int, pair_coord1: int, pair_coord2: int, is_row: bool, n: int) -> bool:
	var changed = false
	var pair_mask: int
	
	if is_row:
		pair_mask = _candidates_mask_for_cell(main_coord, pair_coord1)
		
		# Confirm the pair before eliminating anything.
		if _candidates_mask_for_cell(main_coord, pair_coord2) != pair_mask:
			return false
		
		# The pair claims both values, so no other cell in the row can use them.
		for col in range(n):
			if col != pair_coord1 and col != pair_coord2 and board[main_coord][col] == 0:
				if _eliminate_candidates_from_cell(board, main_coord, col, pair_mask):
					changed = true
	else:
		pair_mask = _candidates_mask_for_cell(pair_coord1, main_coord)
		
		# Confirm the pair before eliminating anything.
		if _candidates_mask_for_cell(pair_coord2, main_coord) != pair_mask:
			return false
		
		# Same down the column.
		for row in range(n):
			if row != pair_coord1 and row != pair_coord2 and board[row][main_coord] == 0:
				if _eliminate_candidates_from_cell(board, row, main_coord, pair_mask):
					changed = true
	
	return changed

## Places a value if removing the pair's candidates leaves exactly one.
static func _eliminate_candidates_from_cell(board: Array, row: int, col: int, candidates_to_remove: int) -> bool:
	var current_mask = _candidates_mask_for_cell(row, col)
	var new_mask = current_mask & (~candidates_to_remove)
	
	if new_mask != current_mask and _bit_count(new_mask) == 1:
		var val = _lowest_bit_index(new_mask) + 1
		board[row][col] = val
		_assign_value(board, row, col, val)
		return true
	
	return false

#endregion

#region Utility
static func _get_shuffled_cells(n: int) -> Array:
	var cells = []
	for y in range(n):
		for x in range(n):
			cells.append(Vector2i(x, y))
	cells.shuffle()
	return cells
#endregion
