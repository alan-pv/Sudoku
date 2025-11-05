# Main.gd
extends Node

const PATH = "DLV/sudoku.txt"

# sudoku = { "value": int, "solution": int, "zone": int } 

func _solve_sudoku(sudoku: Dictionary):
	var contenido := build_dlv_text(sudoku)
	if contenido == "":
		push_error("No se generó el contenido DLV (revisa la matriz).")
		return

	# Ruta relativa dentro del proyecto (puedes cambiarla)
	var abs_path := save_text_file(PATH, contenido)
	if abs_path == "":
		push_error("No se guardó el archivo.")
		return
	print("Archivo guardado en (ruta absoluta): ", abs_path)
	print("Ahora puedes ejecutar desde CMD: dlv \"", abs_path, "\"")


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
			# intentar con str(key) ya hecho en la función; si falla, advertir y saltar
			push_warning("No se pudo parsear la key: %s — será ignorada.".format(str(key)))
			continue
		var x = pos[0]
		var y = pos[1]
		if x > max_x:
			max_x = x
		if y > max_y:
			max_y = y
		parsed_pairs.append([y, x, key]) # guardamos key original para reusar

	# Determinar N (asumimos 0-based)
	if max_x < 0 or max_y < 0:
		push_error("No se encontraron keys válidas en el diccionario.")
		return ""
	var N_x := max_x + 1
	var N_y := max_y + 1
	var N := N_x

	# Verificar N sea cuadrado perfecto (N = b*b)
	var b_f := sqrt(float(N))
	var b := int(b_f)
	if b * b != N:
		push_error("N debe ser un cuadrado perfecto (N = b*b). N = %d no cumple.".format(N))
		return ""

	# Crear matriz NxN inicializada en 0
	var cells := []
	for i in range(N):
		var row := []
		for j in range(N):
			row.append(0)
		cells.append(row)

	# Rellenar cells con los valores encontrados en el diccionario
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
		else:
			# si el valor asociado no es diccionario, intentar convertir directo
			cells[x][y] = int(cell)

	# Construir texto DLV igual que antes
	var s := ""
	s += "%SUDOKU\n"
	for x in range(N):
		for y in range(N):
			var v = cells[x][y]
			if v != 0:
				s += "tab(%d,%d,%d). " % [x, y, v]
		s += "\n"

	s += "\n% Una solucion para el problema del SUDOKU\n"
	s += "#maxint=%d.\n\n" % N

	# Generar la lista de opciones "tab(X,Y,1) v tab(X,Y,2) ... v tab(X,Y,N)"
	var choices := []
	for num in range(1, N + 1):
		choices.append("tab(X,Y,%d)" % num)

	var choices_line := ""
	for i in range(choices.size()):
		choices_line += choices[i]
		if i < choices.size() - 1:
			choices_line += " v "

	s += choices_line + " :- #int(X), X<%d, Y<%d,#int(Y).\n\n" % [N, N]

	# Reglas de filas y columnas
	s += "% Checa renglones y columnas\n"
	s += ":- tab(X,Y1,Z), tab(X,Y2,Z), Y1<>Y2.\n"
	s += ":- tab(X1,Y,Z), tab(X2,Y,Z), X1<>X2.\n\n"

	# Reglas de subtabla (usando división entera /(.,b,W) para indexar subcuadros)
	s += "% Checa subtabla\n"
	s += ":- tab(X1,Y1,Z), tab(X2,Y2,Z), Y1 <> Y2,\n"
	s += "   /(X1,%d,W1), /(X2,%d,W1),\n" % [b, b]
	s += "   /(Y1,%d,W2), /(Y2,%d,W2).\n\n" % [b, b]

	s += ":- tab(X1,Y1,Z), tab(X2,Y2,Z), X1 <> X2,\n"
	s += "   /(X1,%d,W1), /(X2,%d,W1),\n" % [b, b]
	s += "   /(Y1,%d,W2), /(Y2,%d,W2).\n" % [b, b]

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

	# String tipo "(0, 0)" o "0,0" o "0, 0"
	var s := str(key).strip_edges()
	# remover paréntesis y espacios redundantes
	s = s.replace("(", "").replace(")", "").strip_edges()
	s = s.replace(" ", "")
	var parts := s.split(",")
	if parts.size() >= 2:
		# intentar convertir a int (protegido)
		var ok_x := true
		var ok_y := true
		var xi := 0
		var yi := 0
		# conversión segura
		match parts[0]:
			_:
				xi = int(parts[0])
		match parts[1]:
			_:
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
