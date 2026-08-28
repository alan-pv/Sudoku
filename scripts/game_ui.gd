extends Control
class_name GameUI

## The in-game HUD: mistake counter, clock and the number pad.

@onready var sudoku: Sudoku = %Sudoku
@onready var mistakes_label = %Mistakes
@onready var timer_label = %TimerLabel
@onready var select_grid = %SelectGrid
@onready var timer: Timer = %Timer

## Number pad buttons are square. The size is picked so that a full row still
## fits comfortably on screen at any board size, rather than being tied to a
## particular window width.
const PAD_ROW_WIDTH := 560.0
const PAD_MIN_SIZE := 40.0
const PAD_MAX_SIZE := 72.0

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

func _start_game() -> void:
	for button in select_grid.get_children():
		button.queue_free()
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
	var button_size: float = clampf(
		PAD_ROW_WIDTH / Settings.GRID_SIZE, PAD_MIN_SIZE, PAD_MAX_SIZE
	)
	for i in range(Settings.GRID_SIZE):
		var n_button = Button.new()
		select_grid.add_child(n_button)
		n_button.theme = preload("res://Resource/Button.tres")
		n_button.custom_minimum_size = Vector2.ONE * button_size
		n_button.text = str(i + 1)
		n_button.name = str(i + 1)
		n_button.connect("pressed", sudoku._on_select_grid_button_pressed.bind(int(n_button.text)))

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
