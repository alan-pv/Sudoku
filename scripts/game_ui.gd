extends Control
class_name GameUI

## The in-game HUD: mistake counter, clock and the number pad.

@onready var sudoku: Sudoku = %Sudoku
@onready var mistakes_label = %Mistakes
@onready var timer_label = %TimerLabel
@onready var select_grid = %SelectGrid
@onready var timer: Timer = %Timer

## The number pad is laid out as a grid, one box wide (3 columns for a 9x9), and
## lives in the left third of the screen. Buttons are square and sized so a full
## row fits in that third, whatever the board size is.
const PAD_THEME := preload("res://Resource/Button.tres")
const PAD_PANEL_RATIO := 1.0 / 3.0
const PAD_PADDING := 48.0
const PAD_SEPARATION := 8
const PAD_MIN_SIZE := 40.0
const PAD_MAX_SIZE := 96.0

## Pad buttons by the number they stand for, so finished numbers can be hidden.
var number_buttons: Dictionary = {}

var time: int = 0:
	set(value):
		time = value
		_update_ui()
var mistakes: int = 0:
	set(value):
		if value < 0:
			return
		mistakes = value
		_update_ui()
		if value >= 3:
			Settings.emit_signal("GameOver", "lose")

func _ready():
	Settings.connect("GameStart", _start_game)
	Settings.connect("GameOver", _end_game)
	sudoku.NumbersChanged.connect(_refresh_select_grid)

func _start_game() -> void:
	number_buttons.clear()
	for slot in select_grid.get_children():
		select_grid.remove_child(slot)
		slot.queue_free()
	bind_select_grid_button_actions()
	_reset_game_stats()
	timer.start()
	_update_ui()

func _end_game(state: String) -> void:
	if state == "win":
		Settings.save_stats({
			"global_time": Time.get_datetime_dict_from_system(),
			"time": time,
			"difficulty": Settings.DIFFICULTY,
		})
	_reset_game_stats()
	timer.stop()
	_update_ui()

func bind_select_grid_button_actions():
	var columns: int = int(sqrt(float(Settings.GRID_SIZE)))
	select_grid.columns = columns
	select_grid.add_theme_constant_override("h_separation", PAD_SEPARATION)
	select_grid.add_theme_constant_override("v_separation", PAD_SEPARATION)
	
	var panel_width: float = get_viewport_rect().size.x * PAD_PANEL_RATIO - PAD_PADDING
	var button_size: float = clampf(
		(panel_width - PAD_SEPARATION * (columns - 1)) / columns, PAD_MIN_SIZE, PAD_MAX_SIZE
	)
	
	for i in range(Settings.GRID_SIZE):
		var number: int = i + 1
		
		# Each button gets its own slot: hiding a finished number then leaves an
		# empty gap instead of shuffling the rest of the pad around.
		var slot = Control.new()
		slot.custom_minimum_size = Vector2.ONE * button_size
		select_grid.add_child(slot)
		
		var n_button = Button.new()
		n_button.theme = PAD_THEME
		n_button.text = str(number)
		n_button.name = str(number)
		n_button.add_theme_font_size_override("font_size", int(button_size / 2))
		slot.add_child(n_button)
		n_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n_button.connect("pressed", sudoku._on_select_grid_button_pressed.bind(number))
		number_buttons[number] = n_button
	
	_refresh_select_grid()

## Drops the buttons for numbers that are already fully placed on the board:
## there is nothing left to put down with them.
func _refresh_select_grid() -> void:
	if number_buttons.is_empty():
		return
	var remaining: Dictionary = sudoku.get_remaining_counts()
	for number in number_buttons:
		number_buttons[number].visible = remaining.get(number, 0) > 0

func _update_ui() -> void:
	var seconds = time % 60
	var minutes = (time / 60)

	timer_label.text = "%02d:%02d" % [minutes, seconds]
	mistakes_label.text = "Mistakes %d / 3" % mistakes

func _on_second_chance_pressed(): mistakes -= 1
func _reset_game_stats() -> void: time = 0; mistakes = 0
func _on_new_game_pressed(): Settings.GameStart.emit()
func _on_back_pressed():
	Settings.GameOver.emit("exit")
	Settings.GetMenu.emit()

func _on_hint_pressed(): sudoku._show_hint()
func _on_solve_pressed(): sudoku._solve()
func _on_timer_timeout(): time += 1


func _on_options_pressed():
	pass # Replace with function body.

func _on_share_pressed():
	pass # Replace with function body.
