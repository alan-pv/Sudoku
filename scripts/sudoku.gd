extends Control
class_name Sudoku

signal ButtonSelected(btn: GridButton)
signal NumberSolved(value: int)
signal GenerationCompleted(board_dict: Dictionary)  # Nueva señal

@onready var game_ui = %GameUI
@onready var grid_container = %GridContainer
@onready var button_animations = %ButtonAnimations
@onready var grid_button_scene = preload("res://scenes/button.tscn")

# Grid data structure
var grid: Dictionary = {} 
var grid_containers: Array = []
var selected_button: GridButton = null
var box_size: int = -1
var solved: Dictionary = {}
var total: int = 0

# Variables para generación en paralelo
var generation_thread: Thread
var is_generating: bool = false
var board_dict: Dictionary = {}
var animation_type: int = 0
var all_buttons = []

func _reset() -> void:
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()
	selected_button = null
	grid_containers.clear()
	solved.clear()
	grid.clear()
	total = 0
	all_buttons = []
	
	# Limpiar hilo si existe
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
		generation_thread = null

func init_game(overwrite: bool = true):
	_reset()
	box_size = int(sqrt(Settings.GRID_SIZE))
	set_grid_container()
	
	_create_grid_containers()
	
	# INICIAR GENERACIÓN EN PARALELO
	_start_parallel_generation(overwrite)
	
	# CREAR BOTONES INMEDIATAMENTE (no esperar a la generación)
	_create_grid_buttons_empty()

## Iniciar generación en un hilo separado
func _start_parallel_generation(overwrite: bool) -> void:
	is_generating = true
	generation_thread = Thread.new()
	generation_thread.start(_generate_board_in_thread.bind(overwrite))
	if not GenerationCompleted.is_connected(_on_generation_completed):
		GenerationCompleted.connect(_on_generation_completed)

## Función que se ejecuta en el hilo
func _generate_board_in_thread(overwrite: bool) -> void:
	# Generar el tablero en el hilo (esto ya no bloquea la UI)
	var generated_board = SudokuBoard.generate_board(Settings.GRID_SIZE, Settings.DIFFICULTY, Settings.ZONES) if overwrite else Settings.saved_game
	print(generated_board)
	Dlv._solve_sudoku(generated_board)
	
	# Notificar al hilo principal que la generación terminó
	call_deferred("emit_signal", "GenerationCompleted", generated_board)

## Cuando la generación termina
func _on_generation_completed(generated_board: Dictionary) -> void:
	board_dict = generated_board
	is_generating = false
	
	# Esperar a que el hilo termine
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
		generation_thread = null
	
	# Si los botones ya están creados, actualizar con la información real
	if not grid.is_empty():
		_update_grid_with_real_data()

## Crear botones vacíos inmediatamente (sin esperar la generación)
func _create_grid_buttons_empty() -> void:
	# Crear botones con datos temporales/vacíos
	for row in range(Settings.GRID_SIZE):
		for col in range(Settings.GRID_SIZE):
			var box_row = int(row / box_size)
			var box_col = int(col / box_size)
			var box_index = (box_row * box_size + box_col)
			var container = grid_containers[box_index]
			var grid_button = _create_grid_button()
			var pos = Vector2i(col, row)
			
			# Inicializar con diccionario vacío
			grid[pos] = {"button": grid_button}
			grid_button.set_data({}, pos)  # Pasar diccionario vacío
			
			container.add_child(grid_button.get_parent())
			grid_button.hide()
			all_buttons.append(grid_button)
	
	# Animación de aparición de botones vacíos
	animation_type = randi() % 7
	button_animations.set_grid_size(Settings.GRID_SIZE)
	button_animations.animate_buttons(all_buttons, animation_type, true, false)
	
	# Si la generación ya terminó, proceder inmediatamente
	if not is_generating and not board_dict.is_empty():
		_update_grid_with_real_data()
		_reveal_numbers_animation()
	else:
		# Mostrar indicador de carga y esperar
		_show_loading_indicator()

## Mostrar indicador de carga mientras se genera
func _show_loading_indicator() -> void:
	
	# Esperar hasta que la generación termine
	while is_generating:
		await get_tree().create_timer(0.01).timeout
	
	# Cuando termine, actualizar y revelar números
	_update_grid_with_real_data()
	_reveal_numbers_animation()

## Crear botón (sin datos reales aún)
func _create_grid_button() -> GridButton:
	var grid_button: GridButton = grid_button_scene.instantiate().get_node("GridButton")
	
	# connections
	grid_button.pressed.connect(_on_grid_button_pressed.bind(grid_button))
	grid_button.Solved.connect(_number_solved)
	connect("ButtonSelected", grid_button.update_state)
	
	# Actualizar selected_button
	if not selected_button:
		selected_button = grid_button
	
	return grid_button

## Actualizar la grid con los datos reales del sudoku generado
func _update_grid_with_real_data() -> void:
	# Establecer los datos reales del tablero generado SIN revelar números
	for row in range(Settings.GRID_SIZE):
		for col in range(Settings.GRID_SIZE):
			var key = Vector2i(col, row)
			var entry = board_dict.get(key, {"value": 0, "solution": 0, "zone": 0})
			
			grid[key] = {
				"value": int(entry["value"]),
				"solution": int(entry["solution"]),
				"zone": entry["zone"],
				"button": grid[key]["button"]
			}
			
			# IMPORTANTE: Solo configurar datos, NO revelar números todavía
			var grid_button = grid[key]["button"]
			grid_button.pos = key
			grid_button.zone = entry["zone"]
			grid_button.answer = int(entry["solution"])
			
			# Configurar estado de resuelto pero NO mostrar el número
			if entry["value"] == entry["solution"]:
				grid_button.c_answer = -1
				grid_button.solved = true
			else:
				grid_button.c_answer = 0
				grid_button.solved = false
				grid_button._set_text(0)

## Revelar números después de que todo esté listo
func _reveal_numbers_animation() -> void:
	button_animations.set_animation_speed(0.075, 0.125)
	button_animations.animate_buttons(all_buttons, animation_type, false, true)
	ButtonSelected.emit(selected_button)

func get_data(pos: Vector2i) -> Dictionary:
	return grid[pos] if grid.has(pos) else {}

func set_grid_container() -> void:
	grid_container.columns = box_size
	var separation = 8 if not Settings.ZONES else 4
	grid_container.add_theme_constant_override("h_separation", separation)
	grid_container.add_theme_constant_override("v_separation", separation)

func _create_grid_containers():
	grid_containers.clear()
	for r in range(box_size):
		for c in range(box_size):
			var n_grid = GridContainer.new()
			n_grid.columns = box_size
			grid_container.add_child(n_grid)
			grid_containers.append(n_grid)

func _on_grid_button_pressed(grid_button: GridButton):
	selected_button = grid_button
	ButtonSelected.emit(grid_button)

func _on_select_grid_button_pressed(number_pressed):
	if not selected_button:
		return
	var pos = selected_button.pos
	var cell_data = grid[pos]
	
	if cell_data["value"] == cell_data["solution"]:
		print("No se puede colocar en una celda ya solucionada.")
		return
		
	_update_data(pos, number_pressed)
	if cell_data["solution"] != number_pressed:
		game_ui.errores += 1

func _number_solved(n: int) -> void:
	if not solved.has(n): solved[n] = 0 
	solved[n] += 1; total += 1
	
	if total >= (Settings.GRID_SIZE * Settings.GRID_SIZE):
		Settings.emit_signal("GameOver", "win")

func _update_data(pos: Vector2i, number: int) -> void:
	var grid_selected_button: GridButton = grid[pos]["button"]
	if grid_selected_button.set_answer(number):
		_number_solved(number)
	grid[pos]["value"] = number
	ButtonSelected.emit(grid_selected_button)

# Mostrar una pista rellenando una celda vacía con su valor correcto
func _show_hint() -> void:
	var options := []
	for key in grid:
		if grid[key]["value"] == 0:
			options.append(key)
	if options.is_empty():
		return
	var hint = options.pick_random()
	_update_data(hint, grid[hint]["solution"])

# Resuelve el tablero poniendo todas las respuestas
func _solve() -> void:
	for key in grid:
		if grid[key]["value"] == 0:
			_update_data(key, grid[key]["solution"])

# Funciones utilitarias
func get_column(col: int) -> Array:
	var col_list = []
	for row in range(Settings.GRID_SIZE):
		col_list.append(grid[Vector2i(col, row)]["value"])
	return col_list

func get_subgrid(row: int, col: int) -> Array:
	var subgrid = []
	var start_row = int((row / box_size) * box_size)
	var start_col = int((col / box_size) * box_size)
	for r in range(start_row, start_row + box_size):
		for c in range(start_col, start_col + box_size):
			subgrid.append(grid[Vector2i(c, r)]["value"])
	return subgrid

func is_valid(row: int, col: int, num: int) -> bool:
	return (
		num not in _get_row_values(row) and
		num not in get_column(col) and
		num not in get_subgrid(row, col)
	)

func _get_row_values(row: int) -> Array:
	var row_list = []
	for col in range(Settings.GRID_SIZE):
		row_list.append(grid[Vector2i(col, row)]["value"])
	return row_list

func _exit_tree() -> void:
	# Asegurarse de limpiar el hilo al salir
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
