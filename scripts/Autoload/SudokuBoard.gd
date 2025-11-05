# SudokuBoard.gd
# Autoload (singleton) para Godot 4.5
# generate_board(n: int, dificultad: String) -> Dictionary
# Keys: Vector2i(x=col,y=row) -> { "value": int, "solution": int }

extends Node
class_name SudokuBoard

enum TypeDifficulty { EASY, MEDIUM, HARD }

const LEVEL_NONE := 0
const LEVEL_SINGLES := 1
const LEVEL_PAIRS := 2
const LEVEL_XWING := 3
const LEVEL_SEARCH := 99

static var _USE_ZONES: bool = false
static var _ZONE_MAP: Array = []
static var _zone_cells_cache = {}
static var box_size: int = -1

## Bitmask
static var _ROW_MASK: Array = []
static var _COL_MASK: Array = []
static var _ZONE_MASK: Array = []
static var _ALL_MASK: int = 0

#region Main Board Generation

static func generate_board(n: int = 9, dificultad: TypeDifficulty = TypeDifficulty.EASY, zones: bool = false) -> Dictionary:
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
	
	# Generar solución completa
	var full = _generate_full_with_retry(n)
	print("Tablero completado. ")
	
	# Generar puzzle con la dificultad especificada
	var puzzle = _generate_puzzle(full, dificultad)
	print("Puzzle completado. ")
	return _to_output_dict(puzzle, full)
#endregion

#region Zone Generation - Jigsaw Algorithm

## Genera zonas Jigsaw mediante intercambios controlados entre regiones vecinas
static func _generate_zones(n: int, regions: int = 9, swap_steps: int = 25) -> Array:
	if (n * n) % regions != 0:
		return []
	
	var region_size = (n * n) / regions
	
	# 1. Inicializar con regiones estándar (cajas tradicionales)
	var zone_map = _initialize_standard_regions(n)
	
	# 2. Realizar múltiples intercambios para crear patrones irregulares
	for step in range(swap_steps):
		_perform_simple_swap(zone_map, n, region_size)
	
	return zone_map

## Realiza intercambios simples entre regiones vecinas
static func _perform_simple_swap(zone_map: Array, n: int, region_size: int) -> bool:
	# Encontrar todos los pares de regiones vecinas
	var neighbor_pairs = _find_neighbor_region_pairs(zone_map, n)
	
	if neighbor_pairs.is_empty():
		return false
	
	# Mezclar para aleatoriedad
	neighbor_pairs.shuffle()
	
	# Intentar cada par hasta encontrar un intercambio válido
	for pair in neighbor_pairs:
		var region_a = pair[0]
		var region_b = pair[1]
		
		# Encontrar todas las celdas en la frontera entre estas regiones
		var border_cells_a = _find_border_cells_for_region(zone_map, n, region_a, region_b)
		var border_cells_b = _find_border_cells_for_region(zone_map, n, region_b, region_a)
		
		if border_cells_a.is_empty() or border_cells_b.is_empty():
			continue
		
		# Mezclar las celdas fronterizas
		border_cells_a.shuffle()
		border_cells_b.shuffle()
		
		# Intentar intercambiar diferentes combinaciones de celdas
		for cell_a in border_cells_a:
			for cell_b in border_cells_b:
				# Verificar si el intercambio mantiene la conectividad
				if _is_swap_valid(zone_map, n, region_size, region_a, region_b, cell_a, cell_b):
					# Realizar el intercambio
					zone_map[cell_a.y][cell_a.x] = region_b
					zone_map[cell_b.y][cell_b.x] = region_a
					return true
	
	return false

## Encuentra todas las celdas de una región que son adyacentes a otra región específica
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

## Verifica si dos celdas son adyacentes (comparten borde)
static func _are_cells_adjacent(cell_a: Vector2i, cell_b: Vector2i) -> bool:
	var dx = abs(cell_a.x - cell_b.x)
	var dy = abs(cell_a.y - cell_b.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

## Encuentra todos los pares únicos de regiones que son vecinas
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
					# Crear clave única para el par de regiones
					var pair_key = ""
					if current_region < neighbor_region:
						pair_key = str(current_region) + "_" + str(neighbor_region)
					else:
						pair_key = str(neighbor_region) + "_" + str(current_region)
					
					if not processed_pairs.has(pair_key):
						processed_pairs[pair_key] = true
						pairs.append([current_region, neighbor_region])
	
	return pairs

## Verifica si intercambiar dos celdas mantiene ambas regiones conectadas
static func _is_swap_valid(zone_map: Array, n: int, region_size: int, region_a: int, region_b: int, cell_a: Vector2i, cell_b: Vector2i) -> bool:
	# Crear copia temporal para prueba
	var test_map = []
	for i in range(n):
		test_map.append(zone_map[i].duplicate())
	
	# Aplicar intercambio temporal
	test_map[cell_a.y][cell_a.x] = region_b
	test_map[cell_b.y][cell_b.x] = region_a
	
	# Verificar conectividad de ambas regiones
	return _is_region_connected(test_map, region_a, n, region_size) and _is_region_connected(test_map, region_b, n, region_size)

## Verifica si una región está completamente conectada usando BFS
static func _is_region_connected(zone_map: Array, region_id: int, n: int, expected_size: int) -> bool:
	# Encontrar cualquier celda de la región como punto de inicio
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
	
	# BFS para contar celdas conectadas
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
		
		# Revisar los 4 vecinos
		var neighbors = _get_neighbor_cells(cell.x, cell.y, n)
		for neighbor in neighbors:
			if not visited[neighbor.y][neighbor.x] and zone_map[neighbor.y][neighbor.x] == region_id:
				visited[neighbor.y][neighbor.x] = true
				queue.append(neighbor)
	
	# La región está conectada si encontramos todas sus celdas
	return count == expected_size

## Devuelve las celdas vecinas en las 4 direcciones cardinales
static func _get_neighbor_cells(x: int, y: int, n: int) -> Array:
	var neighbors = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx >= 0 and nx < n and ny >= 0 and ny < n:
			neighbors.append(Vector2i(nx, ny))
	
	return neighbors

## Inicializa el mapa de zonas con las cajas tradicionales del sudoku
static func _initialize_standard_regions(n: int) -> Array:
	var zone_map = []
	for i in range(n):
		zone_map.append([])
		for j in range(n):
			zone_map[i].append(-1)
	
	var zone_id = 0
	
	# Crear cajas estándar 3x3 para 9x9, 2x2 para 4x4, etc.
	for box_row in range(0, n, box_size):
		for box_col in range(0, n, box_size):
			for r in range(box_row, box_row + box_size):
				for c in range(box_col, box_col + box_size):
					zone_map[r][c] = zone_id
			zone_id += 1
	
	return zone_map
#endregion

#region Full Board Generation

## Genera un tablero completo con reintentos en caso de fallo
static func _generate_full_with_retry(n: int) -> Array:
	var attempts = 0
	
	while true:
		if _USE_ZONES:
			var swap_steps = n * 6 + randi() % (n * 10)
			_ZONE_MAP = _generate_zones(n, n, swap_steps)
			_update_zone_cache(n)
		
		print("Intento %d: Generando tablero..." % [attempts + 1])
		
		# TIMEOUT 
		var end_time = 25 * n * n
		var full = _generate_full(n, end_time)
		
		if not full.is_empty():
			return full
		
		attempts += 1
	return []

## Generación de solución
static func _generate_full(n: int, end_time: int) -> Array:
	var board: Array = []
	for i in range(n):
		board.append([])
		for j in range(n):
			board[i].append(0)
	
	var start_time = Time.get_ticks_msec()
	var empty_cells = _compute_all_empty_cells(board)
	var success = _fill_board_masks(board, empty_cells, 0, start_time, end_time)
	
	if success and _validate_complete_board(board):
		return board
	return []

## Backtracking con timeout estricto de 3 segundos
static func _fill_board_masks(board: Array, empty_cells: Array, depth: int, start_time: int, end_time: int) -> bool:
	if empty_cells.is_empty():
		return true

	if Time.get_ticks_msec() - start_time > end_time:
		return false

	# MRV: buscar celda con menor popcount de candidatos
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

	# sacar cell
	var chosen_cell = empty_cells[best_idx]
	var new_empty = empty_cells.duplicate()
	new_empty.remove_at(best_idx)

	# ordenar por least-constraining (heurística simple): probar valores en orden de mayor flexibilidad
	var candidates_list = _bits_to_list(best_mask)
	candidates_list.shuffle()

	for val in candidates_list:
		_assign_value(board, chosen_cell.y, chosen_cell.x, val)
		if _fill_board_masks(board, new_empty, depth + 1, start_time, end_time):
			return true
		_unassign_value(board, chosen_cell.y, chosen_cell.x, val)

	return false

## Actualiza la cache de celdas por zona para mejor rendimiento
static func _update_zone_cache(n: int):
	_zone_cells_cache = {}
	for y in range(n):
		for x in range(n):
			var zid = _ZONE_MAP[y][x]
			if not _zone_cells_cache.has(zid):
				_zone_cells_cache[zid] = []
			_zone_cells_cache[zid].append(Vector2i(x, y))

## Obtiene todas las celdas vacías del tablero
static func _compute_all_empty_cells(board: Array) -> Array:
	var empty_cells = []
	var n = board.size()
	for y in range(n):
		for x in range(n):
			if board[y][x] == 0:
				empty_cells.append(Vector2i(x, y))
	return empty_cells

## Valida que un tablero completo sea válido
static func _validate_complete_board(board: Array) -> bool:
	var n = board.size()
	
	# Verificar que no haya ceros
	for y in range(n):
		for x in range(n):
			if board[y][x] == 0:
				return false
	
	# Verificar filas y columnas
	for i in range(n):
		var row_set = []
		var col_set = []
		for j in range(n):
			# Fila
			if board[i][j] in row_set:
				return false
			row_set.append(board[i][j])
			
			# Columna  
			if board[j][i] in col_set:
				return false
			col_set.append(board[j][i])
	
	# Verificar zonas Jigsaw
	for zone_id in _zone_cells_cache:
		var zone_set = []
		for cell in _zone_cells_cache[zone_id]:
			if board[cell.y][cell.x] in zone_set:
				return false
			zone_set.append(board[cell.y][cell.x])
	
	return true

## Versión ultra rápida de candidatos (sin verificaciones redundantes)
static func _candidates_for_cell_fast(board: Array, row: int, col: int) -> Array:
	var n = board.size()
	var used = []
	used.resize(n + 1)
	used.fill(false)
	
	# Verificar fila y columna
	for i in range(n):
		if board[row][i] != 0:
			used[board[row][i]] = true
		if board[i][col] != 0:
			used[board[i][col]] = true
	
	# Cajas regulares
	var box_row = row - (row % box_size)
	var box_col = col - (col % box_size)
	for r in range(box_row, box_row + box_size):
		for c in range(box_col, box_col + box_size):
			if board[r][c] != 0:
				used[board[r][c]] = true
	
	var candidates = []
	for val in range(1, n + 1):
		if not used[val]:
			candidates.append(val)
	return candidates

#endregion

#region Puzzle Generation
## Genera un puzzle removiendo celdas del tablero completo según la dificultad - OPTIMIZADO
static func _generate_puzzle(full: Array, dificultad: TypeDifficulty) -> Array:
	var n = full.size()
	var puzzle = full.duplicate(true)

	# Determinar cuántas celdas mantener según la dificultad
	var target_filled = _difficulty_to_filled_count(n, dificultad)
	var allowed_level = _dificulty_to_allowed_level(dificultad)
	
	# Lista de todas las celdas en orden aleatorio
	var cells: Array = []
	for r in range(n):
		for c in range(n):
			cells.append(Vector2i(c, r))
	cells.shuffle()
	
	# Fase 1: Remoción rápida sin verificación humana (solo unicidad)
	var fast_removal_count = int(target_filled * 0.8)  # Remover el 80% rápidamente
	var removed_count = 0
	
	while removed_count < fast_removal_count and cells.size() > 0:
		var cell: Vector2i = cells.pop_back()
		var saved = puzzle[cell.y][cell.x]
		puzzle[cell.y][cell.x] = 0
		
		# Verificación rápida de unicidad
		var count = _count_solutions(puzzle, 2)
		if count != 1:
			puzzle[cell.y][cell.x] = saved
		else:
			removed_count += 1
	
	# Fase 2: Remoción con verificación completa
	while puzzle_filled_count(puzzle) > target_filled and cells.size() > 0:
		var cell: Vector2i = cells.pop_back()
		var saved = puzzle[cell.y][cell.x]
		puzzle[cell.y][cell.x] = 0
		
		# Verificar que solo tenga una solución
		var count = _count_solutions(puzzle, 2)
		if count != 1:
			puzzle[cell.y][cell.x] = saved
			continue
		
		# Verificar que sea resoluble con técnicas humanas
		var human_solvable = _human_solve(puzzle, allowed_level)
		if not human_solvable:
			puzzle[cell.y][cell.x] = saved
	
	return puzzle

## Ajustar porcentajes para mejor equilibrio dificultad/velocidad
static func _difficulty_to_filled_count(n: int, dificultad: TypeDifficulty) -> int:
	var total = n * n
	var fill_percent: float = 0.45  
	
	match dificultad:
		TypeDifficulty.EASY:
			fill_percent = 0.5 
		TypeDifficulty.MEDIUM:
			fill_percent = 0.35 
		TypeDifficulty.HARD:
			fill_percent = 0.15  
	return int(round(total * fill_percent))

## Define el nivel máximo de técnica humana permitida para cada dificultad
static func _dificulty_to_allowed_level(dificultad: TypeDifficulty) -> int:
	match dificultad:
		TypeDifficulty.EASY:
			return LEVEL_SINGLES
		TypeDifficulty.MEDIUM:
			return LEVEL_PAIRS
		TypeDifficulty.HARD:
			return LEVEL_XWING
	return LEVEL_PAIRS

## Cuenta cuántas celdas tienen valores en el puzzle
static func puzzle_filled_count(puzzle: Array) -> int:
	var c = 0
	for r in puzzle:
		for v in r:
			if v != 0:
				c += 1
	return c
#endregion

#region Solution Counting

## Versión optimizada de count_solutions que usa el sistema de máscaras
static func _count_solutions(board: Array, limit: int) -> int:
	var n = board.size()
	
	# Usar el sistema de máscaras para mayor velocidad
	_reset_masks(board)
	
	return _count_solutions_masks(board, limit, 0)

static func _count_solutions_masks(board: Array, limit: int, depth: int) -> int:
	if depth > 1000:  # Límite de profundidad para evitar stack overflow
		return 0
		
	var n = board.size()
	
	# Buscar celda con menos candidatos usando máscaras (MRV)
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
					return 0  # Sin solución
				if count < best_count:
					best_count = count
					best_mask = mask
					best_r = r
					best_c = c
					if count == 1:  # Optimización: naked single
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
		solutions += _count_solutions_masks(board, limit - solutions, depth + 1)
		
		# Deshacer
		_unassign_value(board, best_r, best_c, val)
		board[best_r][best_c] = 0
		
		if solutions >= limit:
			break
	
	return solutions

## Versión optimizada de candidatos para counting
static func _candidates_for_cell_during_counting(board: Array, row: int, col: int) -> Array:
	var n = board.size()
	var used_mask = 0
	
	# Verificar fila
	for c in range(n):
		if board[row][c] != 0:
			used_mask |= (1 << (board[row][c] - 1))
	
	# Verificar columna
	for r in range(n):
		if board[r][col] != 0:
			used_mask |= (1 << (board[r][col] - 1))
	
	# Verificar zona
	var zone_id = _ZONE_MAP[row][col]
	for cell in _zone_cells_cache[zone_id]:
		if board[cell.y][cell.x] != 0:
			used_mask |= (1 << (board[cell.y][cell.x] - 1))
	
	# Convertir máscara a lista
	var candidates = []
	var all_mask = (1 << n) - 1
	var available_mask = all_mask & ~used_mask
	
	while available_mask != 0:
		var lb = available_mask & -available_mask
		var idx = _lowest_bit_index(lb)
		candidates.append(idx + 1)
		available_mask &= available_mask - 1
	
	return candidates
#endregion

#region Bitmask

static func _bit_count(x: int) -> int:
	# popcount — sigue siendo válido y rápido
	var c = 0
	while x != 0:
		x &= x - 1
		c += 1
	return c

static func _lowest_bit_index(x: int) -> int:
	# retorna índice 0..n-1 del bit menos significativo; -1 si x == 0
	if x == 0:
		return -1
	var idx = 0
	var t = x
	# desplazar hasta que el LSB sea 1
	while (t & 1) == 0:
		t = t >> 1
		idx += 1
	return idx

static func _bits_to_list(x: int) -> Array:
	# convierte máscara de bits a lista de valores [1..n]
	var out: Array = []
	while x != 0:
		# obtener bit menos significativo
		var lb = x & -x
		var idx = _lowest_bit_index(lb)
		# idx es 0-based, los valores de sudoku son idx+1
		out.append(idx + 1)
		# remover ese bit
		x &= x - 1
	return out

# --- función que devuelve máscara de candidatos para (r,c) ---
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
## Convierte el puzzle y solución al formato de diccionario de salida
static func _to_output_dict(puzzle: Array, full: Array) -> Dictionary:
	var n = full.size()
	var out: Dictionary = {}
	for y in range(n):
		for x in range(n):
			out[Vector2i(x, y)] = {"value": puzzle[y][x], "solution": full[y][x], "zone": _ZONE_MAP[y][x]}
			
	return out
#endregion

#region Human Solver
## Verificación rápida de resolubilidad humana
static func _human_solve(board: Array, allowed_level: int) -> bool:
	var n = board.size()
	var board_copy = board.duplicate(true)
	
	# Aplicar singles hasta 3 veces antes de verificar técnicas más avanzadas
	for i in range(n):
		if not _apply_singles(board_copy):
			break
		if _is_filled(board_copy):
			return true
	
	# Si el nivel permitido es solo singles, verificar si está resuelto
	if allowed_level == LEVEL_SINGLES:
		return _is_filled(board_copy)
	
	# Para niveles superiores, aplicar técnicas permitidas
	var changed = true
	var iterations = 0
	
	while changed and iterations < 50:  # Límite de iteraciones
		changed = false
		iterations += 1
		
		if _apply_singles(board_copy):
			changed = true
			if _is_filled(board_copy):
				return true
			continue
		
		if allowed_level >= LEVEL_PAIRS:
			print("level_pairs")
			if _apply_naked_subsets_and_pointing(board_copy):
				changed = true
				if _is_filled(board_copy):
					return true
				continue
		
		if allowed_level >= LEVEL_XWING:
			print("level_xwing")
			if _apply_xwing(board_copy):
				changed = true
				if _is_filled(board_copy):
					return true
				continue
	
	return _is_filled(board_copy)

## Verifica si el tablero está completamente lleno
static func _is_filled(board: Array) -> bool:
	for r in board:
		for v in r:
			if v == 0:
				return false
	return true
#endregion

#region Solving Techniques
static func _apply_singles(board: Array) -> bool:
	var n = board.size()
	
	# Reiniciar máscaras
	_reset_masks(board)
	
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
				
				# Verificar fila
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
				
				# Verificar columna
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
				
				# Verificar zona
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

static func _reset_masks(board: Array):
	var n = board.size()
	for i in range(n):
		_ROW_MASK[i] = 0
		_COL_MASK[i] = 0
		_ZONE_MASK[i] = 0
	
	for r in range(n):
		for c in range(n):
			if board[r][c] != 0:
				_assign_value(board, r, c, board[r][c])

## Versión optimizada para calcular todos los candidatos
static func _compute_all_candidates_fast(board: Array) -> Array:
	var n = board.size()
	var candidates = []
	for r in range(n):
		candidates.append([])
		for c in range(n):
			if board[r][c] == 0:
				candidates[r].append(_candidates_for_cell_fast(board, r, c))
			else:
				candidates[r].append([])
	return candidates

static func _apply_naked_subsets_and_pointing(board: Array) -> bool:
	# Versión conservadora - solo buscar naked pairs muy obvios
	var n = board.size()
	var changed = false
	
	# Reiniciar máscaras para tener estado consistente
	_reset_masks(board)
	
	# Solo buscar naked pairs que lleven directamente a naked singles
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0:
				var mask = _candidates_mask_for_cell(r, c)
				if _bit_count(mask) == 2:
					# Buscar en fila
					for other_c in range(n):
						if other_c != c and board[r][other_c] == 0:
							var other_mask = _candidates_mask_for_cell(r, other_c)
							if mask == other_mask:
								# Este es un naked pair válido
								# Intentar aplicar cambios limitados
								var applied_change = _apply_naked_pair_elimination(board, r, c, other_c, true)
								changed = changed or applied_change
					
					# Buscar en columna
					for other_r in range(n):
						if other_r != r and board[other_r][c] == 0:
							var other_mask = _candidates_mask_for_cell(other_r, c)
							if mask == other_mask:
								var applied_change = _apply_naked_pair_elimination(board, r, c, other_r, false)
								changed = changed or applied_change
	
	return changed

static func _apply_naked_pair_elimination(board: Array, idx1: int, idx2: int, idx3: int, is_row: bool) -> bool:
	var changed = false
	var n = board.size()
	
	if is_row:
		var r = idx1
		var c1 = idx2
		var c2 = idx3
		var mask = _candidates_mask_for_cell(r, c1)
		
		for remove_c in range(n):
			if remove_c != c1 and remove_c != c2 and board[r][remove_c] == 0:
				var remove_mask = _candidates_mask_for_cell(r, remove_c)
				var new_mask = remove_mask & (~mask)
				if new_mask != remove_mask and _bit_count(new_mask) == 1:
					# Solo aplicar si resulta en un naked single
					var val = _lowest_bit_index(new_mask) + 1
					board[r][remove_c] = val
					_assign_value(board, r, remove_c, val)
					changed = true
	else:
		# Lógica similar para columnas
		var c = idx1
		var r1 = idx2
		var r2 = idx3
		var mask = _candidates_mask_for_cell(r1, c)
		
		for remove_r in range(n):
			if remove_r != r1 and remove_r != r2 and board[remove_r][c] == 0:
				var remove_mask = _candidates_mask_for_cell(remove_r, c)
				var new_mask = remove_mask & (~mask)
				if new_mask != remove_mask and _bit_count(new_mask) == 1:
					var val = _lowest_bit_index(new_mask) + 1
					board[remove_r][c] = val
					_assign_value(board, remove_r, c, val)
					changed = true
	
	return changed

## Aplica técnica X-Wing optimizada usando el sistema de máscaras
static func _apply_xwing(board: Array) -> bool:
	var n = board.size()
	var changed = false
	
	# Reiniciar máscaras para tener estado consistente
	_reset_masks(board)
	
	for val in range(1, n + 1):
		var val_mask = 1 << (val - 1)
		
		# X-Wing en filas
		var row_patterns = {}
		for r in range(n):
			var cols = []
			for c in range(n):
				if board[r][c] == 0:
					var cell_mask = _candidates_mask_for_cell(r, c)
					if cell_mask & val_mask:
						cols.append(c)
			if cols.size() == 2:
				var key = str(cols[0]) + "," + str(cols[1])
				if not row_patterns.has(key):
					row_patterns[key] = []
				row_patterns[key].append(r)
		
		# Aplicar X-Wing en filas
		for pattern in row_patterns:
			var rows = row_patterns[pattern]
			if rows.size() == 2:
				var cols = pattern.split(",")
				var col1 = int(cols[0])
				var col2 = int(cols[1])
				
				# Eliminar candidatos de otras filas en estas columnas
				for r in range(n):
					if not rows.has(r) and board[r][col1] == 0:
						var cell_mask = _candidates_mask_for_cell(r, col1)
						if cell_mask & val_mask:
							_ROW_MASK[r] |= val_mask
							changed = true
					
					if not rows.has(r) and board[r][col2] == 0:
						var cell_mask = _candidates_mask_for_cell(r, col2)
						if cell_mask & val_mask:
							_ROW_MASK[r] |= val_mask
							changed = true
		
		# X-Wing en columnas (completando la técnica)
		var col_patterns = {}
		for c in range(n):
			var rows = []
			for r in range(n):
				if board[r][c] == 0:
					var cell_mask = _candidates_mask_for_cell(r, c)
					if cell_mask & val_mask:
						rows.append(r)
			if rows.size() == 2:
				var key = str(rows[0]) + "," + str(rows[1])
				if not col_patterns.has(key):
					col_patterns[key] = []
				col_patterns[key].append(c)
		
		# Aplicar X-Wing en columnas
		for pattern in col_patterns:
			var cols = col_patterns[pattern]
			if cols.size() == 2:
				var rows = pattern.split(",")
				var row1 = int(rows[0])
				var row2 = int(rows[1])
				
				# Eliminar candidatos de otras columnas en estas filas
				for c in range(n):
					if not cols.has(c) and board[row1][c] == 0:
						var cell_mask = _candidates_mask_for_cell(row1, c)
						if cell_mask & val_mask:
							_COL_MASK[c] |= val_mask
							changed = true
					
					if not cols.has(c) and board[row2][c] == 0:
						var cell_mask = _candidates_mask_for_cell(row2, c)
						if cell_mask & val_mask:
							_COL_MASK[c] |= val_mask
							changed = true
	
	# Si hubo cambios, aplicar naked singles inmediatamente
	if changed:
		return _apply_singles(board)
	
	return false

## Obtiene las columnas donde el valor es candidato en una fila dada
static func _get_candidate_columns_for_value(candidates: Array, row: int, val: int) -> Array:
	var cols = []
	for c in range(candidates[row].size()):
		if candidates[row][c].has(val):
			cols.append(c)
	return cols

## Obtiene las filas donde el valor es candidato en una columna dada
static func _get_candidate_rows_for_value(candidates: Array, col: int, val: int) -> Array:
	var rows = []
	for r in range(candidates.size()):
		if candidates[r][col].has(val):
			rows.append(r)
	return rows
#endregion

#region Utility Functions
## Convierte una lista ordenada a string para usar como clave
static func _sorted_list_to_key(arr: Array) -> String:
	var a = arr.duplicate()
	a.sort()
	return String(",").join(a)

## Convierte una clave string de vuelta a lista ordenada
static func _key_to_sorted_list(key: String) -> Array:
	if key == "":
		return []
	var parts = key.split(",")
	var out = []
	for p in parts:
		if p == "": continue
		out.append(int(p))
	return out
#endregion
