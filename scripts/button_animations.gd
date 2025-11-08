# SudokuButtonAnimator.gd
extends Node
class_name SudokuButtonAnimator

@onready var sudoku = %Sudoku

signal animation_completed

# Tipos de animación disponibles
enum AnimationType {
	CENTER_OUT,          # Desde el centro hacia los extremos
	CORNERS_IN,          # Desde las esquinas hacia el centro
	LEFT_TO_RIGHT,       # De izquierda a derecha
	TOP_TO_BOTTOM,       # De arriba a abajo
	DIAGONAL,            # En diagonal desde esquinas
	SPIRAL,              # En espiral desde el centro
	RANDOM               # Aleatorio
}

# Configuración de animaciones
var animation_delay: float = 0.03
var group_delay: float = 0.05
var grid_size: int = 9

func _ready():
	pass

## Método principal para ejecutar animaciones
func animate_buttons(buttons: Array, animation_type: AnimationType, is_random: bool = false, show: bool = false) -> void:
	match animation_type:
		AnimationType.CENTER_OUT:
			_animate_center_out(buttons, is_random, show)
		AnimationType.CORNERS_IN:
			_animate_corners_in(buttons, is_random, show)
		AnimationType.LEFT_TO_RIGHT:
			_animate_left_to_right(buttons, is_random, show)
		AnimationType.TOP_TO_BOTTOM:
			_animate_top_to_bottom(buttons, is_random, show)
		AnimationType.DIAGONAL:
			_animate_diagonal(buttons, is_random, show)
		AnimationType.SPIRAL:
			_animate_spiral(buttons, is_random, show)
		AnimationType.RANDOM:
			_animate_random(buttons, show)
	
	# Esperar a que termine la animación y emitir señal
	await get_tree().create_timer(_calculate_total_animation_time(buttons.size())).timeout
	animation_completed.emit()

#region Animaciones Específicas

## Animación desde el centro hacia los extremos
func _animate_center_out(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var center = Vector2(grid_size / 2.0 - 0.5, grid_size / 2.0 - 0.5)
	var button_groups = {}
	
	# Agrupar por distancia al centro
	for button in buttons:
		var distance = snapped(button.pos.distance_to(center), 0.01)
		if not button_groups.has(distance):
			button_groups[distance] = []
		button_groups[distance].append(button)
	
	# Ordenar grupos por distancia
	var sorted_distances = button_groups.keys()
	sorted_distances.sort()
	
	# Animar grupos
	for distance in sorted_distances:
		var group = button_groups[distance]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación desde las esquinas hacia el centro
func _animate_corners_in(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var corners = [
		Vector2(0, 0),                    # Esquina superior izquierda
		Vector2(grid_size - 1, 0),        # Esquina superior derecha
		Vector2(0, grid_size - 1),        # Esquina inferior izquierda
		Vector2(grid_size - 1, grid_size - 1) # Esquina inferior derecha
	]
	
	var button_groups = {}
	
	# Agrupar por la distancia mínima a cualquier esquina
	for button in buttons:
		var min_distance = INF
		for corner in corners:
			var distance = button.pos.distance_to(corner)
			if distance < min_distance:
				min_distance = distance
		
		var rounded_distance = snapped(min_distance, 0.01)
		if not button_groups.has(rounded_distance):
			button_groups[rounded_distance] = []
		button_groups[rounded_distance].append(button)
	
	# Ordenar grupos por distancia (de mayor a menor para ir de afuera hacia adentro)
	var sorted_distances = button_groups.keys()
	sorted_distances.sort()
	sorted_distances.reverse()
	
	# Animar grupos
	for distance in sorted_distances:
		var group = button_groups[distance]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación de izquierda a derecha
func _animate_left_to_right(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Agrupar por columna
	for button in buttons:
		var col = button.pos.x
		if not button_groups.has(col):
			button_groups[col] = []
		button_groups[col].append(button)
	
	# Ordenar por columna
	var sorted_columns = button_groups.keys()
	sorted_columns.sort()
	
	# Animar grupos
	for col in sorted_columns:
		var group = button_groups[col]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación de arriba a abajo
func _animate_top_to_bottom(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Agrupar por fila
	for button in buttons:
		var row = button.pos.y
		if not button_groups.has(row):
			button_groups[row] = []
		button_groups[row].append(button)
	
	# Ordenar por fila
	var sorted_rows = button_groups.keys()
	sorted_rows.sort()
	
	# Animar grupos
	for row in sorted_rows:
		var group = button_groups[row]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación en diagonal desde las esquinas
func _animate_diagonal(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Agrupar por suma de coordenadas (diagonales)
	for button in buttons:
		var diagonal_index = button.pos.x + button.pos.y
		if not button_groups.has(diagonal_index):
			button_groups[diagonal_index] = []
		button_groups[diagonal_index].append(button)
	
	# Ordenar diagonales
	var sorted_diagonals = button_groups.keys()
	sorted_diagonals.sort()
	
	# Animar grupos
	for diagonal in sorted_diagonals:
		var group = button_groups[diagonal]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación en espiral desde el centro
func _animate_spiral(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var center = Vector2i(grid_size / 2, grid_size / 2)
	var button_groups = {}
	
	# Calcular "anillo" espiral para cada botón
	for button in buttons:
		var ring = max(abs(button.pos.x - center.x), abs(button.pos.y - center.y))
		if not button_groups.has(ring):
			button_groups[ring] = []
		button_groups[ring].append(button)
	
	# Ordenar anillos
	var sorted_rings = button_groups.keys()
	sorted_rings.sort()
	
	# Animar grupos
	for ring in sorted_rings:
		var group = button_groups[ring]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Animación completamente aleatoria
func _animate_random(buttons: Array, show: bool) -> void:
	var shuffled_buttons = buttons.duplicate()
	shuffled_buttons.shuffle()
	
	for button in shuffled_buttons:
		_animate_single_button(button, show)
		await get_tree().create_timer(animation_delay).timeout

#endregion

#region Métodos de Ayuda

## Animar un grupo de botones simultáneamente
func _animate_button_group(button_group: Array, show: bool) -> void:
	for button in button_group:
		_animate_single_button(button, show)

## Animar un solo botón
func _animate_single_button(button: GridButton, show: bool) -> void:
	if button and is_instance_valid(button):
		button.show()
		Settings.ui_sounds.connect_signals(button)
		Settings.ui_sounds.animate_hover(button)
		if show:
			button.set_data(sudoku.get_data(button.pos), button.pos)

## Calcular tiempo total aproximado de animación
func _calculate_total_animation_time(button_count: int) -> float:
	var estimated_groups = sqrt(button_count)
	return (estimated_groups * group_delay) + (button_count * animation_delay)

## Configurar parámetros de animación
func set_animation_speed(button_delay: float = 0.03, group_delay_param: float = 0.05) -> void:
	animation_delay = button_delay
	group_delay = group_delay_param

## Establecer tamaño del grid para cálculos de posición
func set_grid_size(size: int) -> void:
	grid_size = size

#endregion
