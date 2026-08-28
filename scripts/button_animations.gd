# SudokuButtonAnimator.gd
#
# Staggered entrance and reveal animations for the grid of cells.
extends Node
class_name SudokuButtonAnimator

@onready var sudoku = %Sudoku

signal animation_completed

# The available patterns
enum AnimationType {
	CENTER_OUT,          # Outwards from the middle
	CORNERS_IN,          # Inwards from the corners
	LEFT_TO_RIGHT,       # Left to right
	TOP_TO_BOTTOM,       # Top to bottom
	DIAGONAL,            # Diagonally from the corners
	SPIRAL,              # Spiralling out from the centre
	RANDOM               # No order at all
}

# Timing
var animation_delay: float = 0.03
var group_delay: float = 0.05
var grid_size: int = 9

func _ready():
	pass

## Entry point: plays one of the patterns over the given buttons.
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
	
	# Wait out the whole sequence before reporting it finished.
	await get_tree().create_timer(_calculate_total_animation_time(buttons.size())).timeout
	animation_completed.emit()

#region Patterns

## Outwards from the middle of the board.
func _animate_center_out(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var center = Vector2(grid_size / 2.0 - 0.5, grid_size / 2.0 - 0.5)
	var button_groups = {}
	
	# Group by distance from the centre.
	for button in buttons:
		var distance = snapped(button.pos.distance_to(center), 0.01)
		if not button_groups.has(distance):
			button_groups[distance] = []
		button_groups[distance].append(button)
	
	# Nearest first, so the wave travels outwards.
	var sorted_distances = button_groups.keys()
	sorted_distances.sort()
	
	# Play the groups one after another.
	for distance in sorted_distances:
		var group = button_groups[distance]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Inwards from the four corners.
func _animate_corners_in(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var corners = [
		Vector2(0, 0),                    # Esquina superior izquierda
		Vector2(grid_size - 1, 0),        # Esquina superior derecha
		Vector2(0, grid_size - 1),        # Esquina inferior izquierda
		Vector2(grid_size - 1, grid_size - 1) # Esquina inferior derecha
	]
	
	var button_groups = {}
	
	# Group by distance to the nearest corner.
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
	
	# Farthest first, so the wave travels inwards.
	var sorted_distances = button_groups.keys()
	sorted_distances.sort()
	sorted_distances.reverse()
	
	# Play the groups one after another.
	for distance in sorted_distances:
		var group = button_groups[distance]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Column by column, left to right.
func _animate_left_to_right(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Group by column.
	for button in buttons:
		var col = button.pos.x
		if not button_groups.has(col):
			button_groups[col] = []
		button_groups[col].append(button)
	
	# Left to right.
	var sorted_columns = button_groups.keys()
	sorted_columns.sort()
	
	# Play the groups one after another.
	for col in sorted_columns:
		var group = button_groups[col]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Row by row, top to bottom.
func _animate_top_to_bottom(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Group by row.
	for button in buttons:
		var row = button.pos.y
		if not button_groups.has(row):
			button_groups[row] = []
		button_groups[row].append(button)
	
	# Top to bottom.
	var sorted_rows = button_groups.keys()
	sorted_rows.sort()
	
	# Play the groups one after another.
	for row in sorted_rows:
		var group = button_groups[row]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Along the diagonals, starting at the corners.
func _animate_diagonal(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var button_groups = {}
	
	# Cells on a diagonal share the same x + y.
	for button in buttons:
		var diagonal_index = button.pos.x + button.pos.y
		if not button_groups.has(diagonal_index):
			button_groups[diagonal_index] = []
		button_groups[diagonal_index].append(button)
	
	# Corner outwards.
	var sorted_diagonals = button_groups.keys()
	sorted_diagonals.sort()
	
	# Play the groups one after another.
	for diagonal in sorted_diagonals:
		var group = button_groups[diagonal]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## Spiralling out from the centre.
func _animate_spiral(buttons: Array, random_within_group: bool = false, show: bool = false) -> void:
	var center = Vector2i(grid_size / 2, grid_size / 2)
	var button_groups = {}
	
	# Which concentric ring each button sits on.
	for button in buttons:
		var ring = max(abs(button.pos.x - center.x), abs(button.pos.y - center.y))
		if not button_groups.has(ring):
			button_groups[ring] = []
		button_groups[ring].append(button)
	
	# Innermost ring first.
	var sorted_rings = button_groups.keys()
	sorted_rings.sort()
	
	# Play the groups one after another.
	for ring in sorted_rings:
		var group = button_groups[ring]
		if random_within_group:
			group.shuffle()
		
		_animate_button_group(group, show)
		await get_tree().create_timer(group_delay).timeout

## No order at all.
func _animate_random(buttons: Array, show: bool) -> void:
	var shuffled_buttons = buttons.duplicate()
	shuffled_buttons.shuffle()
	
	for button in shuffled_buttons:
		_animate_single_button(button, show)
		await get_tree().create_timer(animation_delay).timeout

#endregion

#region Helpers

## Animates a group of buttons at once.
func _animate_button_group(button_group: Array, show: bool) -> void:
	for button in button_group:
		_animate_single_button(button, show)

## Animates a single button.
func _animate_single_button(button: GridButton, show: bool) -> void:
	if button and is_instance_valid(button):
		button.show()
		Settings.ui_sounds.connect_signals(button)
		Settings.ui_sounds.animate_hover(button)
		if show:
			button.set_data(sudoku.get_data(button.pos), button.pos)

## Roughly how long the whole sequence will take.
func _calculate_total_animation_time(button_count: int) -> float:
	var estimated_groups = sqrt(button_count)
	return (estimated_groups * group_delay) + (button_count * animation_delay)

## Adjusts the stagger timing.
func set_animation_speed(button_delay: float = 0.03, group_delay_param: float = 0.05) -> void:
	animation_delay = button_delay
	group_delay = group_delay_param

## The board size the position maths is based on.
func set_grid_size(size: int) -> void:
	grid_size = size

#endregion
