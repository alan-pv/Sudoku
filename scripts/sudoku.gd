extends Control
class_name Sudoku

## The board on screen: builds the grid of buttons, generates the puzzle on a
## background thread and keeps the cell data in sync with what is displayed.

signal ButtonSelected(btn: GridButton)
signal NumberSolved(value: int)
signal GenerationCompleted(board_dict: Dictionary)
signal NumbersChanged

@onready var game_ui = %GameUI
@onready var grid_container = %GridContainer
@onready var board_area = %BoardArea
@onready var button_animations = %ButtonAnimations
@onready var grid_button_scene = preload("res://scenes/button.tscn")

## The board lives in the right-hand panel of the HUD. Keep these in sync with
## BoardPanel in Game.tscn: they are only used as a fallback while the panel has
## not been laid out yet.
const BOARD_PANEL_RATIO := 2.0 / 3.0
const BOARD_MARGIN := 64.0
const BOX_SEPARATION := 4.0

# Grid data structure
var grid: Dictionary = {} 
var grid_containers: Array = []
var selected_button: GridButton = null
var box_size: int = -1
var cell_size: float = 0.0
var solved: Dictionary = {}
var total: int = 0

# Background generation
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
	
	# Join the worker thread if one is still running.
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
		generation_thread = null

func init_game(overwrite: bool = true):
	_reset()
	box_size = int(sqrt(Settings.GRID_SIZE))
	cell_size = _compute_cell_size()
	set_grid_container()
	
	_create_grid_containers()
	
	# Kick off generation before touching the UI...
	_start_parallel_generation(overwrite)
	
	# ...so the empty board can appear straight away instead of waiting.
	_create_grid_buttons_empty()

## Starts generation on its own thread, or inline where threads are unavailable.
##
## The web export ships without thread support on purpose: enabling it would force
## the page to be served with COOP/COEP headers, which breaks the site embedding the
## game. Without threads `Thread.start()` never runs, so the board stayed empty.
## Generating deferred instead costs one blocked frame and works everywhere.
func _start_parallel_generation(overwrite: bool) -> void:
	is_generating = true

	# Connect before starting, so a fast generation can't fire before we listen.
	if not GenerationCompleted.is_connected(_on_generation_completed):
		GenerationCompleted.connect(_on_generation_completed)

	if not OS.has_feature("threads"):
		# Deferred so the empty board still gets drawn first.
		call_deferred("_generate_board_in_thread", overwrite)
		return

	generation_thread = Thread.new()
	generation_thread.start(_generate_board_in_thread.bind(overwrite))

## Runs on the worker thread.
func _generate_board_in_thread(overwrite: bool) -> void:
	# Generating here keeps the UI responsive.
	var generated_board = SudokuBoard.generate_board(Settings.GRID_SIZE, Settings.DIFFICULTY, Settings.ZONES) if overwrite else Settings.saved_game
	
	# Hand the result back to the main thread.
	call_deferred("emit_signal", "GenerationCompleted", generated_board)

## Called on the main thread once generation finishes.
func _on_generation_completed(generated_board: Dictionary) -> void:
	board_dict = generated_board
	is_generating = false
	
	# Join the thread before dropping the reference.
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
		generation_thread = null
	
	# If the buttons already exist, fill them with the real board.
	if not grid.is_empty():
		_update_grid_with_real_data()

## Creates the buttons up front, before there is a puzzle to put in them.
func _create_grid_buttons_empty() -> void:
	# Placeholder data until the real board arrives.
	for row in range(Settings.GRID_SIZE):
		for col in range(Settings.GRID_SIZE):
			var box_row = int(row / box_size)
			var box_col = int(col / box_size)
			var box_index = (box_row * box_size + box_col)
			var container = grid_containers[box_index]
			var grid_button = _create_grid_button()
			var pos = Vector2i(col, row)
			
			# Start empty; _update_grid_with_real_data fills these in.
			grid[pos] = {"button": grid_button}
			grid_button.set_data({}, pos)
			
			container.add_child(grid_button.get_parent())
			grid_button.apply_cell_size(cell_size)
			grid_button.hide()
			all_buttons.append(grid_button)
	
	# Reveal the empty cells with a random entrance animation.
	animation_type = randi() % 7
	button_animations.set_grid_size(Settings.GRID_SIZE)
	button_animations.animate_buttons(all_buttons, animation_type, true, false)
	
	# Generation may already be done for a very small board.
	if not is_generating and not board_dict.is_empty():
		_update_grid_with_real_data()
		_reveal_numbers_animation()
	else:
		# Otherwise wait for it.
		_show_loading_indicator()

## Waits for generation to finish, then reveals the numbers.
func _show_loading_indicator() -> void:
	
	# Poll rather than await the signal: it may already have fired.
	while is_generating:
		await get_tree().create_timer(0.01).timeout
	
	# Now the real values can go in.
	_update_grid_with_real_data()
	_reveal_numbers_animation()

## Builds one cell button and wires its signals.
func _create_grid_button() -> GridButton:
	var grid_button: GridButton = grid_button_scene.instantiate().get_node("GridButton")
	
	# connections
	grid_button.pressed.connect(_on_grid_button_pressed.bind(grid_button))
	grid_button.Solved.connect(_number_solved)
	connect("ButtonSelected", grid_button.update_state)
	
	# The first button created becomes the initial selection.
	if not selected_button:
		selected_button = grid_button
	
	return grid_button

## Copies the generated board into the cells, without revealing anything yet.
func _update_grid_with_real_data() -> void:
	# Values are stored now and shown later, so the reveal animation can play.
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
			
			# Data only. Showing the number here would spoil the animation.
			var grid_button = grid[key]["button"]
			grid_button.pos = key
			grid_button.zone = entry["zone"]
			grid_button.answer = int(entry["solution"])
			
			# Mark givens as solved, still without displaying them.
			if entry["value"] == entry["solution"]:
				grid_button.c_answer = -1
				grid_button.solved = true
			else:
				grid_button.c_answer = 0
				grid_button.solved = false
				grid_button._set_text(0)
	
	NumbersChanged.emit()

## Plays the reveal once every cell is ready.
func _reveal_numbers_animation() -> void:
	button_animations.set_animation_speed(0.075, 0.125)
	button_animations.animate_buttons(all_buttons, animation_type, false, true)
	ButtonSelected.emit(selected_button)

func get_data(pos: Vector2i) -> Dictionary:
	return grid[pos] if grid.has(pos) else {}

func set_grid_container() -> void:
	grid_container.columns = box_size
	var separation = _box_gap()
	grid_container.add_theme_constant_override("h_separation", separation)
	grid_container.add_theme_constant_override("v_separation", separation)

## Gap between the boxes of the board. Jigsaw boards use a tighter one, since
## the borders already tell the regions apart.
func _box_gap() -> int:
	return 8 if not Settings.ZONES else 4

## The cell size that makes the whole board fit inside the board panel, whatever
## the board size is, so it never runs from edge to edge of the screen.
func _compute_cell_size() -> float:
	var area: Vector2 = board_area.size if board_area else Vector2.ZERO
	if area.x <= 1.0 or area.y <= 1.0:
		# The HUD is still hidden, so the panel has no size yet.
		var viewport := get_viewport_rect().size
		area = Vector2(viewport.x * BOARD_PANEL_RATIO, viewport.y) - Vector2.ONE * (BOARD_MARGIN * 2.0)
	
	var gaps: float = _box_gap() * (box_size - 1) + BOX_SEPARATION * box_size * (box_size - 1)
	return maxf(floorf((minf(area.x, area.y) - gaps) / Settings.GRID_SIZE), 12.0)

## How many cells of each value the board is still missing. Only a cell holding
## its correct value counts as placed, so a wrong guess never makes a number
## disappear from the pad.
func get_remaining_counts() -> Dictionary:
	var counts: Dictionary = {}
	for n in range(1, Settings.GRID_SIZE + 1):
		counts[n] = Settings.GRID_SIZE
	for key in grid:
		var cell: Dictionary = grid[key]
		var solution: int = cell.get("solution", 0)
		if solution > 0 and cell.get("value", 0) == solution:
			counts[solution] -= 1
	return counts

func _create_grid_containers():
	grid_containers.clear()
	for r in range(box_size):
		for c in range(box_size):
			var n_grid = GridContainer.new()
			n_grid.columns = box_size
			n_grid.add_theme_constant_override("h_separation", int(BOX_SEPARATION))
			n_grid.add_theme_constant_override("v_separation", int(BOX_SEPARATION))
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
	
	# A cell that already holds its correct value cannot be overwritten.
	if cell_data["value"] == cell_data["solution"]:
		return
		
	_update_data(pos, number_pressed)
	if cell_data["solution"] != number_pressed:
		game_ui.mistakes += 1

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
	NumbersChanged.emit()

## Fills one random empty cell with its correct value.
func _show_hint() -> void:
	var options := []
	for key in grid:
		if grid[key]["value"] == 0:
			options.append(key)
	if options.is_empty():
		return
	var hint = options.pick_random()
	_update_data(hint, grid[hint]["solution"])

## Fills in every remaining cell.
func _solve() -> void:
	for key in grid:
		if grid[key]["value"] == 0:
			_update_data(key, grid[key]["solution"])

# Helpers used to validate a placement
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
	# Never leave the worker thread running past this node.
	if generation_thread and generation_thread.is_alive():
		generation_thread.wait_to_finish()
