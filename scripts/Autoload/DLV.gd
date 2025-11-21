# Main.gd
extends Node

const PATH = "DLV/ClingoSudoku.txt"

# sudoku = { "value": int, "solution": int, "zone": int } 
# El input debe contener una entrada por cada casilla (x,y) con su zona.
# value = 0 significa casilla vacía (marcador nulo)

func _solve_sudoku(sudoku: Dictionary):
	var contenido := build_dlv_text(sudoku)
	print(sudoku)
	if contenido == "":
		push_error("No se generó el contenido DLV (revisa la matriz).")
		return

	# Ruta relativa dentro del proyecto (puedes cambiarla)
	var abs_path := save_text_file(PATH, contenido)
	if abs_path == "":
		push_error("No se guardó el archivo.")
		return
	print("Archivo guardado en: ", abs_path)


# build_dlv_text adaptada para Dictionary con keys (x,y)
func build_dlv_text(grid: Dictionary) -> String:
	# Validaciones básicas
	if grid.is_empty():
		push_error("La matriz está vacía.")
		return ""

	# Primero recorremos todas las keys para obtener el tamaño (max x,y)
	var max_x := -1
	var max_y := -1
	var parsed_pairs := []
	for key in grid.keys():
		var pos := _parse_key_to_xy(key)
		if pos.is_empty():
			push_warning("No se pudo parsear la key: %s — será ignorada.".format(str(key)))
			continue
		var x = pos[0]
		var y = pos[1]
		if x > max_x:
			max_x = x
		if y > max_y:
			max_y = y
		parsed_pairs.append([x, y, key]) # guardamos key original para reusar

	# Determinar N (asumimos 0-based)
	if max_x < 0 or max_y < 0:
		push_error("No se encontraron keys válidas en el diccionario.")
		return ""
	var N_x := max_x + 1
	var N_y := max_y + 1
	if N_x != N_y:
		push_error("La matriz debe ser cuadrada. Encontrado %d x %d." % [N_x, N_y])
		return ""
	var N := N_x

	# Crear matrices NxN para valores y zonas (inicializadas en 0)
	var cells := []
	var zones := []
	for i in range(N):
		var row := []
		var zrow := []
		for j in range(N):
			row.append(0)
			zrow.append(0)
		cells.append(row)
		zones.append(zrow)

	# Rellenar cells y zones con los valores encontrados en el diccionario
	for pair in parsed_pairs:
		var x = pair[0]
		var y = pair[1]
		var original_key = pair[2]
		var cell = grid.get(original_key, null)
		if typeof(cell) == TYPE_DICTIONARY:
			# Tomar "value" si existe, si no 0
			var v := 0
			if cell.has("value"):
				v = int(cell["value"])
			elif cell.has("solution"):
				# fallback si usas "solution" en vez de "value"
				v = int(cell["solution"])
			cells[x][y] = v

			# Tomar "zone" si existe, si no 0 (pero advertir)
			var z := 0
			if cell.has("zone"):
				z = int(cell["zone"])
			else:
				push_warning("Falta 'zone' para la celda %s. Se usará 0." % str(original_key))
				z = 0
			zones[x][y] = z
		else:
			# si el valor asociado no es diccionario, intentar convertir directo (asumimos value)
			var v2 := 0
			match typeof(cell):
				TYPE_INT:
					v2 = int(cell)
				_:
					v2 = 0
			cells[x][y] = v2
			zones[x][y] = 0
			push_warning("Entrada no-diccionario para %s. Se usará value=%d, zone=0." % [str(original_key), v2])

	# Construir texto DLV con todas las facts tab(X,Y,Z,V) y el programa
	var s := ""
	s += "% SUDOKU (entradas: tab(X,Y,Z,V); V=0 => vacía)\n"
	s += "% Hechos generados desde el diccionario de Godot\n\n"

	# Facts: una por cada casilla (incluso si V==0)
	for x in range(N):
		for y in range(N):
			var v = cells[x][y]
			var z = zones[x][y]
			# Aseguramos valores no-negativos
			if v < 0:
				v = 0
			if z < 0:
				z = 0
			s += "tab(%d,%d,%d,%d).\n" % [x, y, z, v]
	s += "\n"

	# Programa DLV que resuelve jigsaw (usa zonas)
	s += "% Parametro: tamanio del Sudoku\n"
	s += "#const n = %d.\n\n" % N

	s += "% Extrae zonas y fijos\n"
	s += "zone(X,Y,Z) :- tab(X,Y,Z,_).\n"
	s += "val(X,Y,V) :- tab(X,Y,_,V), V > 0.\n\n"

	s += "% Eleccion para casillas vacias (V == 0)\n"
	s += "1 { val(X,Y,1..n) } 1 :- tab(X,Y,_,0).\n\n"

	s += "% Unicidad en fila y columna\n"
	s += ":- val(X,Y1,V), val(X,Y2,V), Y1 <> Y2.\n"
	s += ":- val(X1,Y,V), val(X2,Y,V), X1 <> X2.\n\n"

	s += "% Unicidad por zona (jigsaw): dos celdas distintas de la misma zona no pueden tener el mismo valor\n"
	s += ":- V = 1..n,\n"
	s += "   X1 = 0..%d-1, Y1 = 0..%d-1, X2 = 0..%d-1, Y2 = 0..%d-1,\n" % [N, N, N, N]
	s += "   ID1 = X1*%d + Y1, ID2 = X2*%d + Y2, ID1 < ID2,\n" % [N, N]
	s += "   val(X1,Y1,V), val(X2,Y2,V),\n"
	s += "   zone(X1,Y1,Z), zone(X2,Y2,Z).\n\n"

	s += "% Salida: solved(X,Y,Z,V) con la solucion encontrada\n"
	s += "solved(X,Y,Z,V) :- val(X,Y,V), zone(X,Y,Z).\n\n"
	s += "#show solved/4.\n"

	return s


# Auxiliar: devuelve [x,y] si puede parsear la key, o [] si falla
func _parse_key_to_xy(key) -> Array:
	# Vector2 / Vector2i directos
	if key is Vector2:
		return [int(key.x), int(key.y)]
	if key is Vector2i:
		return [int(key.x), int(key.y)]

	# Array tipo [x,y]
	if typeof(key) == TYPE_ARRAY and key.size() >= 2:
		return [int(key[0]), int(key[1])]

	# String tipo "(0,0)" o "0,0" o "(0, 0)"
	var s := str(key).strip_edges()
	# remover paréntesis y espacios redundantes
	s = s.replace("(", "").replace(")", "").strip_edges()
	s = s.replace(" ", "")
	var parts := s.split(",")
	if parts.size() >= 2:
		var xi := 0
		var yi := 0
		# conversión segura
		xi = int(parts[0])
		yi = int(parts[1])
		return [xi, yi]

	# si no se pudo, devolver vacío
	return []


# --- Guarda archivo y devuelve ruta absoluta (usa ruta relativa del proyecto) ---
func save_text_file(local_path: String, content: String) -> String:
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir el archivo para escritura: %s" % local_path)
		return ""
	file.store_string(content)
	file.close()

	# Obtiene la ruta absoluta para que puedas copiar/pegar en CMD
	var abs := ProjectSettings.globalize_path(local_path)
	return abs
