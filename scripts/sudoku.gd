extends Control
class_name Sudoku

signal ButtonSelected(btn: GridButton)
signal NumberSolved(value: int)

@onready var game_ui = %GameUI
@onready var grid_container = %GridContainer
@onready var grid_button_scene = preload("res://scenes/button.tscn")

# Grid data structure
var grid: Dictionary = {} # Vector2i(x,y): { "value": int, "solution": int, "button": GridButton }
var grid_containers: Array = [] # Holds the GridContainer nodes for subgrids
var selected_button: GridButton = null
var box_size: int = -1

func _reset() -> void:
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()
	grid.clear()
	grid_containers.clear()
	selected_button = null

func init_game(board_dict: Dictionary):
	_reset()
	box_size = int(sqrt(Settings.GRID_SIZE))
	set_grid_container()
	
	_create_grid_containers()
	set_grid(board_dict)
	
	_create_grid_buttons()
	ButtonSelected.emit(selected_button)

func set_grid_container() -> void:
	grid_container.columns = box_size
	var separation = 8 if not Settings.ZONES else 4
	grid_container.add_theme_constant_override("h_separation", separation)
	grid_container.add_theme_constant_override("v_separation", separation)

func set_grid(dict: Dictionary) -> void:
	# Populate grid dictionary with board data
	for row in range(Settings.GRID_SIZE):
		for col in range(Settings.GRID_SIZE):
			var key = Vector2i(col, row)
			var entry = dict.get(key, {"value": 0, "solution": 0, "zone": 0}) 
			
			grid[key] = {
				"value": int(entry["value"]),
				"solution": int(entry["solution"]),
				"button": null,
				"zone": entry["zone"]
			}
			

func _create_grid_containers():
	grid_containers.clear()
	for r in range(box_size):
		for c in range(box_size):
			var n_grid = GridContainer.new()
			n_grid.columns = box_size
			grid_container.add_child(n_grid)
			grid_containers.append(n_grid)

func _create_grid_buttons() -> void:
	for row in range(Settings.GRID_SIZE):
		for col in range(Settings.GRID_SIZE):
			var key = Vector2i(col, row)
			var box_row = int(row / box_size)
			var box_col = int(col / box_size)
			var box_index = (box_row * box_size + box_col)
			var container = grid_containers[box_index]
			var grid_button = _create_grid_button(key, box_index)
			grid[key]["button"] = grid_button
			container.add_child(grid_button)

func _create_grid_button(pos: Vector2i, box_index: int) -> GridButton:
	var grid_button: GridButton = grid_button_scene.instantiate()
	grid_button.pos = pos
	var cell_data = grid[pos]
	
	# If cell has initial value, show it and mark as fixed
	if cell_data["value"] != 0:
		grid_button.c_answer = -1
		grid_button.solved = true
	
	grid_button.zone = cell_data["zone"]
	grid_button.answer = cell_data["solution"]
	grid_button.box_index = box_index
	# connections
	grid_button.pressed.connect(_on_grid_button_pressed.bind(grid_button))
	connect("ButtonSelected", grid_button.update_state)
	
	if selected_button == null:
		selected_button = grid_button
		
	return grid_button

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
	var solved: int = 0
	for key in grid:
		var button: GridButton = grid[key]["button"]
		if button.answer == n and button.solved:
			solved += 1
	if solved == Settings.GRID_SIZE:
		for i in range(game_ui.buttons.size() - 1, -1, -1):
			if game_ui.buttons[i].text == str(n):
				game_ui.buttons[i].queue_free()
				game_ui.buttons.remove_at(i)
				break
	if game_ui.buttons.is_empty():
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
