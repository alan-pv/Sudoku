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

#region Main Board Generation

static func generate_board(n: int = 9, dificultad: TypeDifficulty = TypeDifficulty.EASY, zones: bool = false) -> Dictionary:
	_USE_ZONES = zones
	_ZONE_MAP = [] # reset
	_zone_cells_cache = {}
	
	if n <= 0:
		push_error("SudokuBoard.generate_board: n debe ser > 0")
		return {}
	var box = int(sqrt(float(n)))
	if box * box != n:
		push_error("SudokuBoard.generate_board: n debe ser un cuadrado perfecto (4,9,16,...)")
		return {}

	# Generar zonas Jigsaw si está habilitado
	if _USE_ZONES:
		var zm = _generate_zones(n, n)
		if zm.is_empty():
			push_warning("No se pudo generar zonas válidas, continuando sin zonas")
			_USE_ZONES = false
		else:
			_ZONE_MAP = zm
			_update_zone_cache(n)
	
	# Generar solución completa
	var full = []
	while full.is_empty():
		full = _generate_full_with_retry(n)
	
	if full.is_empty():
		push_error("No se pudo generar tablero completo")
		return {}

	# Generar puzzle con la dificultad especificada
	var puzzle = _generate_puzzle(full, dificultad)
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
	var successful_swaps = 0
	for step in range(swap_steps):
		var success = _perform_simple_swap(zone_map, n, region_size)
		if success:
			successful_swaps += 1
	
	print("Realizados ", successful_swaps, " intercambios de ", swap_steps, " intentados")
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
	
	var box_size = int(sqrt(n))
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

#region Full Board Generation

## Genera un tablero completo con reintentos en caso de fallo
static func _generate_full_with_retry(n: int, max_attempts: int = 30) -> Array:
	var attempts = 0
	var zone_attempts = 0
	var max_zone_attempts = 20
	var success_stats = {
		"total_attempts": 0,
		"zone_regenerations": 0,
		"quick_rejects": 0,
		"timeout_failures": 0
	}
	
	print("=== INICIANDO GENERACIÓN DE TABLERO %dx%d ===" % [n, n])
	print("Usando zonas: %s" % str(_USE_ZONES))
	
	while attempts < max_attempts:
		success_stats["total_attempts"] = attempts + 1
		
		# REGENERAR ZONAS CADA INTENTO - Estrategia principal
		if _USE_ZONES:
			if zone_attempts >= max_zone_attempts:
				push_warning("Demasiados intentos de zonas (%d), desactivando zonas" % zone_attempts)
				_USE_ZONES = false
				_ZONE_MAP = []
				_zone_cells_cache = {}
			else:
				# Variar swaps para diversidad de zonas
				var swap_steps = n * 6 + randi() % (n * 10)
				_ZONE_MAP = _generate_zones(n, n, swap_steps)
				if _ZONE_MAP.is_empty():
					print("❌ Falló generación de zonas, desactivando...")
					_USE_ZONES = false
				else:
					# Precalcular cache
					_update_zone_cache(n)
					
					# VERIFICACIÓN RÁPIDA CRÍTICA
					if _quick_zone_viability_check(n) == false:
						success_stats["quick_rejects"] += 1
						# Continuar inmediatamente con nuevas zonas
						continue
					
				zone_attempts += 1
				success_stats["zone_regenerations"] = zone_attempts
		
		print("Intento %d/%d: Generando tablero..." % [attempts + 1, max_attempts])
		var start_time = Time.get_ticks_msec()
		
		# TIMEOUT AGRESIVO: 3 segundos máximo
		var full = _generate_full_with_timeout(n, 100)
		var end_time = Time.get_ticks_msec()
		var duration = end_time - start_time
		
		if not full.is_empty():
			print("✅ ¡TABLERO GENERADO EXITOSAMENTE!")
			print("   - Intentos totales: %d" % (attempts + 1))
			print("   - Regeneraciones de zona: %d" % zone_attempts)
			print("   - Rechazos rápidos: %d" % success_stats["quick_rejects"])
			print("   - Timeouts: %d" % success_stats["timeout_failures"])
			print("   - Tiempo del último intento: %d ms" % duration)
			print("   - Tamaño del tablero: %dx%d" % [n, n])
			print("=== GENERACIÓN COMPLETADA ===")
			return full
		else:
			if duration >= 3000:
				success_stats["timeout_failures"] += 1
				print("❌ Intento %d fallado - TIMEOUT (%d ms)" % [attempts + 1, duration])
				# Timeout: zonas probablemente imposibles
				if _USE_ZONES:
					_ZONE_MAP = []  # Forzar nuevas zonas
			else:
				print("❌ Intento %d fallado (%d ms)" % [attempts + 1, duration])
				# Fallo rápido: zonas definitivamente imposibles  
				if _USE_ZONES:
					_ZONE_MAP = []
		
		attempts += 1
	
	print("💥 ERROR: No se pudo generar tablero completo después de %d intentos" % max_attempts)
	print("   - Regeneraciones de zona: %d" % zone_attempts)
	print("   - Rechazos rápidos: %d" % success_stats["quick_rejects"])
	print("   - Fallos por timeout: %d" % success_stats["timeout_failures"])
	print("=== GENERACIÓN FALLIDA ===")
	return []

## Verificación rápida de viabilidad de zonas - VERSIÓN MEJORADA
static func _quick_zone_viability_check(n: int) -> bool:
	var zone_stats = {}
	
	for zone_id in _zone_cells_cache:
		var cells = _zone_cells_cache[zone_id]
		zone_stats[zone_id] = {
			"size": cells.size(),
			"rows": {},
			"cols": {}
		}
		
		# Contar distribución por filas y columnas
		for cell in cells:
			zone_stats[zone_id]["rows"][cell.y] = true
			zone_stats[zone_id]["cols"][cell.x] = true
	
	# Análisis de viabilidad rápida - MÁS PERMISIVO PERO EFECTIVO
	for zone_id in zone_stats:
		var stats = zone_stats[zone_id]
		var row_count = stats["rows"].size()
		var col_count = stats["cols"].size()
		
		# CRITERIO PRINCIPAL: Evitar zonas en una sola fila o columna
		if row_count <= 1 or col_count <= 1:
			print("    Zona %d rechazada: muy concentrada (%d filas, %d columnas)" % [zone_id, row_count, col_count])
			return false
		
		# CRITERIO SECUNDARIO: Formas extremadamente desbalanceadas
		var row_ratio = float(stats["size"]) / row_count
		var col_ratio = float(stats["size"]) / col_count
		
		if row_ratio > 4.0 or col_ratio > 4.0:
			print("    Zona %d rechazada: forma extrema (size: %d, filas: %d, columnas: %d)" % [zone_id, stats["size"], row_count, col_count])
			return false
	
	return true

## Generación con timeout de 3 segundos
static func _generate_full_with_timeout(n: int, max_time_ms: int) -> Array:
	var board: Array = []
	for i in range(n):
		board.append([])
		for j in range(n):
			board[i].append(0)
	
	var start_time = Time.get_ticks_msec()
	var empty_cells = _compute_all_empty_cells(board)
	var success = _fill_board_mrv_timeout(board, empty_cells, 0, start_time, max_time_ms)
	
	if success and _validate_complete_board(board):
		return board
	return []

## Backtracking con timeout estricto de 3 segundos
static func _fill_board_mrv_timeout(board: Array, empty_cells: Array, depth: int, start_time: int, max_time: int) -> bool:
	# Verificar timeout MUY frecuentemente
	if Time.get_ticks_msec() - start_time > max_time:
		return false
	
	if empty_cells.is_empty():
		return true
	
	# Límite de profundidad conservador
	if depth > board.size() * board.size() * 1.5:
		return false
	
	var best_cell = null
	var best_candidates = []
	var min_candidates = board.size() + 1
	
	# MRV RÁPIDO - verificar máximo 10 celdas
	var cells_to_check = empty_cells
	if empty_cells.size() > 10:
		cells_to_check = []
		for i in range(min(10, empty_cells.size())):
			cells_to_check.append(empty_cells[i])
	
	for cell in cells_to_check:
		# Verificar timeout en cada celda
		if Time.get_ticks_msec() - start_time > max_time:
			return false
			
		var candidates = _candidates_for_cell_fast(board, cell.y, cell.x)
		if candidates.size() == 0:
			return false
		
		if candidates.size() < min_candidates:
			min_candidates = candidates.size()
			best_cell = cell
			best_candidates = candidates
			if min_candidates == 1:
				break
	
	if best_cell == null:
		return false
	
	# Probar candidatos en orden aleatorio CON LÍMITE
	best_candidates.shuffle()
	var new_empty_cells = empty_cells.duplicate()
	new_empty_cells.erase(best_cell)
	
	# Límite AGRESIVO de candidatos a probar
	var max_candidates_to_try = min(2, best_candidates.size()) if depth > 5 else min(4, best_candidates.size())
	
	for i in range(max_candidates_to_try):
		if Time.get_ticks_msec() - start_time > max_time:
			return false
			
		var num = best_candidates[i]
		board[best_cell.y][best_cell.x] = num
		if _fill_board_mrv_timeout(board, new_empty_cells, depth + 1, start_time, max_time):
			return true
		board[best_cell.y][best_cell.x] = 0
	
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
	
	# Verificar zonas o cajas
	if not _USE_ZONES:
		var box_size = int(sqrt(n))
		for brow in range(0, n, box_size):
			for bcol in range(0, n, box_size):
				var box_set = []
				for r in range(brow, brow + box_size):
					for c in range(bcol, bcol + box_size):
						if board[r][c] in box_set:
							return false
						box_set.append(board[r][c])
	else:
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
	
	# Verificar zona
	if _USE_ZONES and _ZONE_MAP.size() == n:
		var zid = _ZONE_MAP[row][col]
		if _zone_cells_cache.has(zid):
			for cell in _zone_cells_cache[zid]:
				if board[cell.y][cell.x] != 0:
					used[board[cell.y][cell.x]] = true
	else:
		# Cajas regulares
		var box_size = int(sqrt(n))
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
## Genera un puzzle removiendo celdas del tablero completo según la dificultad
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

	# Intentar remover celdas manteniendo unicidad y nivel de dificultad humano
	while puzzle_filled_count(puzzle) > target_filled and cells.size() > 0:
		var cell: Vector2i = cells.pop_back()
		var saved = puzzle[cell.y][cell.x]
		puzzle[cell.y][cell.x] = 0

		# Verificar que solo tenga una solución
		var count = _count_solutions(puzzle, 2)
		if count != 1:
			puzzle[cell.y][cell.x] = saved
			continue

		# Verificar que sea resoluble con técnicas humanas del nivel permitido
		var puzzle_copy = puzzle.duplicate(true)
		var solved_bool = _human_solve(puzzle_copy)[0]
		var max_level_used = _human_solve(puzzle_copy)[1]
		if not solved_bool or max_level_used > allowed_level:
			puzzle[cell.y][cell.x] = saved
	
	return puzzle

## Calcula cuántas celdas deben permanecer según la dificultad
static func _difficulty_to_filled_count(n: int, dificultad: TypeDifficulty) -> int:
	var total = n * n
	var fill_percent: float = 0.40
	match dificultad:
		TypeDifficulty.EASY:
			fill_percent = 0.50
		TypeDifficulty.MEDIUM:
			fill_percent = 0.40
		TypeDifficulty.HARD:
			fill_percent = 0.30
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
## Cuenta el número de soluciones hasta un límite usando MRV
static func _count_solutions(board: Array, limit: int) -> int:
	return _count_solutions_rec(board, limit)

static func _count_solutions_rec(board: Array, limit: int) -> int:
	var n = board.size()
	
	# Encontrar la celda con menos candidatos (MRV)
	var best_r = -1
	var best_c = -1
	var best_candidates: Array = []
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0:
				var cand = _candidates_for_cell(board, r, c)
				if best_r == -1 or cand.size() < best_candidates.size():
					best_r = r
					best_c = c
					best_candidates = cand
	
	# Si no hay celdas vacías, encontramos una solución
	if best_r == -1:
		return 1
	
	# Probar cada candidato y contar soluciones
	var solutions = 0
	for val in best_candidates:
		board[best_r][best_c] = val
		var found = _count_solutions_rec(board, limit - solutions)
		solutions += found
		board[best_r][best_c] = 0
		if solutions >= limit:
			break
	
	return solutions

## Encuentra todos los valores posibles para una celda
static func _candidates_for_cell(board: Array, row: int, col: int) -> Array:
	var n = board.size()
	var out: Array = []
	for v in range(1, n + 1):
		if _is_safe_fast(board, row, col, v):
			out.append(v)
	return out
	
## Verificación de seguridad ultra optimizada
static func _is_safe_fast(board: Array, row: int, col: int, val: int) -> bool:
	var n = board.size()
	
	# Verificar fila y columna rápidamente
	for i in range(n):
		if board[row][i] == val or board[i][col] == val:
			return false
	
	# Verificar zona o caja
	if not _USE_ZONES:
		# Cajas regulares - más rápido
		var box_size = int(sqrt(n))
		var box_row = row - (row % box_size)
		var box_col = col - (col % box_size)
		
		for r in range(box_row, box_row + box_size):
			for c in range(box_col, box_col + box_size):
				if board[r][c] == val:
					return false
	else:
		# Zonas Jigsaw - usar cache precalculado
		if _ZONE_MAP.size() == n:
			var zid = _ZONE_MAP[row][col]
			if _zone_cells_cache.has(zid):
				for cell in _zone_cells_cache[zid]:
					if board[cell.y][cell.x] == val:
						return false
			else:
				# Fallback: calcular en el momento (más lento)
				for r in range(n):
					for c in range(n):
						if _ZONE_MAP[r][c] == zid and board[r][c] == val:
							return false
	
	return true
#endregion

#region Output Format
## Convierte el puzzle y solución al formato de diccionario de salida
static func _to_output_dict(puzzle: Array, full: Array) -> Dictionary:
	var n = full.size()
	var out: Dictionary = {}
	for y in range(n):
		for x in range(n):
			var key = Vector2i(x, y)
			var entry = {"value": puzzle[y][x], "solution": full[y][x], "zone": -1}
			# Agregar información de zona si está habilitado
			print(_USE_ZONES, " ", _ZONE_MAP.size() == n, " because: ", _ZONE_MAP.size(), " != ", n)
			if _USE_ZONES and _ZONE_MAP.size() == n:
				entry["zone"] = int(_ZONE_MAP[y][x])
				
			out[key] = entry
			
	return out
#endregion

#region Human Solver
## Intenta resolver el puzzle usando técnicas humanas y devuelve el nivel máximo usado
static func _human_solve(board: Array) -> Array:
	var max_level = LEVEL_NONE
	var changed = true
	
	while changed:
		changed = false
		
		# Aplicar técnicas en orden de dificultad
		var applied_singles = _apply_singles(board)
		if applied_singles:
			changed = true
			max_level = max(max_level, LEVEL_SINGLES)
			continue
		
		var applied_pairs = _apply_naked_subsets_and_pointing(board)
		if applied_pairs:
			changed = true
			max_level = max(max_level, LEVEL_PAIRS)
			continue
		
		var applied_xwing = _apply_xwing(board)
		if applied_xwing:
			changed = true
			max_level = max(max_level, LEVEL_XWING)
			continue
	
	# Devolver si se resolvió y el nivel máximo usado
	if _is_filled(board):
		return [true, max_level]
	return [false, LEVEL_SEARCH]

## Verifica si el tablero está completamente lleno
static func _is_filled(board: Array) -> bool:
	for r in board:
		for v in r:
			if v == 0:
				return false
	return true
#endregion

#region Solving Techniques
## Aplica técnicas de singles (naked y hidden)
static func _apply_singles(board: Array) -> bool:
	var n = board.size()
	var candidates = _compute_all_candidates(board)
	var applied := false

	# Naked singles
	for r in range(n):
		for c in range(n):
			if board[r][c] == 0 and candidates[r][c].size() == 1:
				board[r][c] = candidates[r][c][0]
				applied = true
	
	if applied:
		return true

	# Hidden singles en filas, columnas y cajas
	var box_size = int(sqrt(float(n)))
	
	# Filas
	for r in range(n):
		var counts = {}
		for c in range(n):
			if board[r][c] == 0:
				for val in candidates[r][c]:
					if not counts.has(val):
						counts[val] = []
					counts[val].append(Vector2i(r, c))
		for val in counts.keys():
			if counts[val].size() == 1:
				var pos = counts[val][0]
				board[pos.x][pos.y] = val
				return true
	
	# Columnas
	for c in range(n):
		var counts_c = {}
		for r in range(n):
			if board[r][c] == 0:
				for val in candidates[r][c]:
					if not counts_c.has(val):
						counts_c[val] = []
					counts_c[val].append(Vector2i(r, c))
		for val in counts_c.keys():
			if counts_c[val].size() == 1:
				var pos = counts_c[val][0]
				board[pos.x][pos.y] = val
				return true
	
	# Cajas
	for brow in range(0, n, box_size):
		for bcol in range(0, n, box_size):
			var counts_b = {}
			for r in range(brow, brow + box_size):
				for c in range(bcol, bcol + box_size):
					if board[r][c] == 0:
						for val in candidates[r][c]:
							if not counts_b.has(val):
								counts_b[val] = []
							counts_b[val].append(Vector2i(r, c))
			for val in counts_b.keys():
				if counts_b[val].size() == 1:
					var pos = counts_b[val][0]
					board[pos.x][pos.y] = val
					return true
	
	return false

## Calcula todos los candidatos posibles para cada celda vacía
static func _compute_all_candidates(board: Array) -> Array:
	var n = board.size()
	var candidates = []
	for r in range(n):
		candidates.append([])
		for c in range(n):
			if board[r][c] == 0:
				candidates[r].append(_candidates_for_cell(board, r, c))
			else:
				candidates[r].append([])
	return candidates

## Aplica técnicas de naked subsets y pointing pairs/triples
static func _apply_naked_subsets_and_pointing(board: Array) -> bool:
	var n = board.size()
	var candidates = _compute_all_candidates(board)
	var changed = false

	# Naked subsets para pares y triples
	for size_subset in [2, 3]:
		changed = changed or _apply_naked_subsets_to_unit(candidates, n, size_subset)
	
	# Pointing pairs
	changed = changed or _apply_pointing_pairs(candidates, n)
	
	# Aplicar naked singles resultantes
	if changed:
		for r in range(n):
			for c in range(n):
				if board[r][c] == 0 and candidates[r][c].size() == 1:
					board[r][c] = candidates[r][c][0]
		return true
	
	return false

## Aplica naked subsets a una unidad (fila, columna o caja)
static func _apply_naked_subsets_to_unit(candidates: Array, n: int, subset_size: int) -> bool:
	var changed = false
	var box_size = int(sqrt(float(n)))
	
	# Filas
	for r in range(n):
		changed = changed or _apply_naked_subsets_to_group(candidates, n, subset_size, "row", r)
	
	# Columnas
	for c in range(n):
		changed = changed or _apply_naked_subsets_to_group(candidates, n, subset_size, "col", c)
	
	# Cajas
	for brow in range(0, n, box_size):
		for bcol in range(0, n, box_size):
			changed = changed or _apply_naked_subsets_to_group(candidates, n, subset_size, "box", brow, bcol)
	
	return changed

## Aplica naked subsets a un grupo específico (fila, columna o caja)
static func _apply_naked_subsets_to_group(candidates: Array, n: int, subset_size: int, type: String, param1: int, param2: int = 0) -> bool:
	var changed = false
	var positions = []
	
	# Obtener posiciones del grupo
	match type:
		"row":
			for c in range(n):
				if candidates[param1][c].size() > 0:
					positions.append(Vector2i(param1, c))
		"col":
			for r in range(n):
				if candidates[r][param1].size() > 0:
					positions.append(Vector2i(r, param1))
		"box":
			var box_size = int(sqrt(float(n)))
			for r in range(param1, param1 + box_size):
				for c in range(param2, param2 + box_size):
					if candidates[r][c].size() > 0:
						positions.append(Vector2i(r, c))
	
	# Buscar subsets
	if positions.size() >= subset_size:
		# Implementación simplificada - buscar celdas con exactamente subset_size candidatos que sean iguales
		var combos = {}
		for pos in positions:
			var key = _sorted_list_to_key(candidates[pos.x][pos.y])
			if not combos.has(key):
				combos[key] = []
			combos[key].append(pos)
		
		for key in combos.keys():
			var set_vals = _key_to_sorted_list(key)
			if set_vals.size() == subset_size and combos[key].size() == subset_size:
				# Eliminar estos valores de otras celdas en el grupo
				for pos in positions:
					if not combos[key].has(pos):
						for val in set_vals:
							if candidates[pos.x][pos.y].has(val):
								candidates[pos.x][pos.y].erase(val)
								changed = true
	
	return changed

## Aplica técnica de pointing pairs (cuando un candidato aparece solo en una fila/columna dentro de una caja)
static func _apply_pointing_pairs(candidates: Array, n: int) -> bool:
	var changed = false
	var box_size = int(sqrt(float(n)))
	
	for brow in range(0, n, box_size):
		for bcol in range(0, n, box_size):
			for val in range(1, n + 1):
				var positions = []
				# Encontrar todas las apariciones del valor en la caja
				for r in range(brow, brow + box_size):
					for c in range(bcol, bcol + box_size):
						if candidates[r][c].has(val):
							positions.append(Vector2i(r, c))
				
				if positions.size() == 0:
					continue
				
				# Verificar si todas están en la misma fila o columna
				var same_row = true
				var same_col = true
				var first_pos = positions[0]
				
				for pos in positions:
					if pos.x != first_pos.x:
						same_row = false
					if pos.y != first_pos.y:
						same_col = false
				
				# Eliminar de la fila/columna fuera de la caja
				if same_row:
					for c in range(n):
						if c < bcol or c >= bcol + box_size:
							if candidates[first_pos.x][c].has(val):
								candidates[first_pos.x][c].erase(val)
								changed = true
				
				if same_col:
					for r in range(n):
						if r < brow or r >= brow + box_size:
							if candidates[r][first_pos.y].has(val):
								candidates[r][first_pos.y].erase(val)
								changed = true
	
	return changed

## Aplica técnica X-Wing para eliminar candidatos
static func _apply_xwing(board: Array) -> bool:
	var n = board.size()
	var candidates = _compute_all_candidates(board)
	var changed = false

	# Buscar X-Wing en filas
	for val in range(1, n + 1):
		for i in range(n - 1):
			var cols_i = _get_candidate_columns_for_value(candidates, i, val)
			if cols_i.size() != 2:
				continue
			
			for j in range(i + 1, n):
				var cols_j = _get_candidate_columns_for_value(candidates, j, val)
				if cols_j.size() != 2 or cols_i != cols_j:
					continue
				
				# Encontrado X-Wing - eliminar de otras filas en estas columnas
				for col in cols_i:
					for r in range(n):
						if r != i and r != j and candidates[r][col].has(val):
							candidates[r][col].erase(val)
							changed = true
	
	# Buscar X-Wing en columnas
	for val in range(1, n + 1):
		for i in range(n - 1):
			var rows_i = _get_candidate_rows_for_value(candidates, i, val)
			if rows_i.size() != 2:
				continue
			
			for j in range(i + 1, n):
				var rows_j = _get_candidate_rows_for_value(candidates, j, val)
				if rows_j.size() != 2 or rows_i != rows_j:
					continue
				
				# Encontrado X-Wing - eliminar de otras columnas en estas filas
				for row in rows_i:
					for c in range(n):
						if c != i and c != j and candidates[row][c].has(val):
							candidates[row][c].erase(val)
							changed = true
	
	# Aplicar naked singles resultantes
	if changed:
		for r in range(n):
			for c in range(n):
				if board[r][c] == 0 and candidates[r][c].size() == 1:
					board[r][c] = candidates[r][c][0]
		return true
	
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
