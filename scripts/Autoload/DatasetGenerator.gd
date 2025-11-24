# DatasetGenerator.gd
# Godot 4.5 - Autoload
extends Node

const SUDOKU_BOARD_PATH := "res://scripts/Autoload/SudokuBoard.gd"

# Configuración por defecto
var sizes_to_generate := [4, 9, 16]
var difficulties := ["easy", "medium", "hard"]
var count_per_diff := 10
var run_on_ready := true

# Internals
var _sudoku_board = null

func _ready() -> void:
	_load_sudoku_board()
	if run_on_ready:
		generate_all()

func _load_sudoku_board() -> void:
	if ResourceLoader.exists(SUDOKU_BOARD_PATH):
		_sudoku_board = load(SUDOKU_BOARD_PATH)
		print("DatasetGenerator: loaded SudokuBoard from: ", SUDOKU_BOARD_PATH)
	else:
		push_error("DatasetGenerator: No se pudo cargar SudokuBoard. Asegúrate de que el archivo exista en: " + SUDOKU_BOARD_PATH)

func generate_all() -> void:
	if _sudoku_board == null:
		push_error("DatasetGenerator: SudokuBoard no cargado. Abortando.")
		return
	
	var idx_total := 0
	for side in sizes_to_generate:
		var side_actual := _normalize_side(side)
		for diff in difficulties:
			for i in range(count_per_diff):
				idx_total += 1
				var id_str := "puzzle_%d_%s_%03d" % [side_actual, diff, i + 1]
				var out := _generate_single(side, diff, id_str)
				if not out.is_empty():
					var saved := _save_puzzle_json(side_actual, diff, id_str, out)
					if saved:
						print("Saved: ", id_str)
					else:
						push_error("Failed to save " + id_str)
	print("DatasetGenerator: terminado. Generados: %d archivos." % idx_total)

func _generate_single(size_input, difficulty: String, id_str: String) -> Dictionary:
	var side := _normalize_side(size_input)
	
	# Convertir string difficulty a enum del SudokuBoard
	var difficulty_enum
	match difficulty:
		"easy":
			difficulty_enum = _sudoku_board.TypeDifficulty.EASY
		"medium":
			difficulty_enum = _sudoku_board.TypeDifficulty.MEDIUM
		"hard":
			difficulty_enum = _sudoku_board.TypeDifficulty.HARD
		_:
			difficulty_enum = _sudoku_board.TypeDifficulty.EASY
	
	# Llamar al método estático generate_board
	var board = _sudoku_board.generate_board(side, difficulty_enum, false)
	if typeof(board) != TYPE_DICTIONARY:
		push_error("DatasetGenerator: generate_board no devolvió un Dictionary.")
		return {}
	
	# Convertir al formato JSON especificado
	return _convert_board_to_json_schema(board, side, id_str, difficulty)

func _convert_board_to_json_schema(board: Dictionary, side: int, id_str: String, difficulty: String) -> Dictionary:
	# Inicializar arrays
	var regions := []
	var initial_grid := []
	var givens := []
	
	# Crear arrays 2D vacíos del tamaño correcto
	for y in range(side):
		var region_row := []
		var grid_row := []
		for x in range(side):
			region_row.append(0)
			grid_row.append(0)
		regions.append(region_row)
		initial_grid.append(grid_row)
	
	# Llenar con datos del board
	for key in board:
		var entry = board[key]
		
		# Extraer coordenadas de la clave Vector2i
		var x: int
		var y: int
		
		if key is Vector2i:
			x = key.x
			y = key.y
		else:
			push_error("Tipo de clave no soportado en board: " + str(typeof(key)))
			continue
		
		# Verificar que las coordenadas estén en rango
		if x < 0 or x >= side or y < 0 or y >= side:
			push_error("Coordenadas fuera de rango: (%d, %d) para side %d" % [x, y, side])
			continue
		
		# Obtener valores
		var value := int(entry.get("value", 0))
		var zone_id := int(entry.get("zone", 0))
		
		# Asignar valores (nota: en regions usamos 1-based)
		regions[y][x] = zone_id + 1
		initial_grid[y][x] = value
		
		if value != 0:
			givens.append({"x": x, "y": y, "value": value})
	
	# Construir el JSON final
	var json_out := {
		"n": side,
		"grid_size": [side, side],
		"regions": regions,
		"givens": givens,
		"initial_grid": initial_grid,
		"id": id_str,
		"difficulty": difficulty
	}
	return json_out

func _save_puzzle_json(side: int, difficulty: String, id_str: String, data: Dictionary) -> bool:
	var dir_path := "sudoku_dataset/%d/%s" % [side, difficulty]
	
	# Crear directorios si no existen
	if not DirAccess.dir_exists_absolute(dir_path):
		var error = DirAccess.make_dir_recursive_absolute(dir_path)
		if error != OK:
			push_error("DatasetGenerator: No se pudo crear directorio: " + dir_path + " Error: " + str(error))
			return false
	
	var file_path := dir_path.path_join(id_str + ".json")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("DatasetGenerator: No se pudo abrir archivo para escritura: " + file_path + " Error: " + str(error))
		return false
	
	# Serializar JSON
	var json_text := JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()
	return true

func _normalize_side(v) -> int:
	var iv := int(v)
	if iv in [2, 3, 4]:
		return iv * iv
	return iv
