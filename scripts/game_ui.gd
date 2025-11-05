extends Control
class_name GameUI

@onready var sudoku: Sudoku = %Sudoku
@onready var errores_label = %Errores
@onready var timer_label = %TimerLabel
@onready var select_grid = %SelectGrid
@onready var timer: Timer = %Timer

var time: int = 0:
	set(value):
		time = value
		_update_ui()
var errores: int = 0:
	set(value):
		if value < 0:
			return
		errores = value
		_update_ui()
		if value >= 3: 
			Settings.emit_signal("GameOver", "lose")

func _ready():
	Settings.connect("GameStart", _start_game)
	Settings.connect("GameOver", _end_game)

func _start_game() -> void:
	_reset_game_stats()
	timer.start()
	_update_ui()
	
func _end_game(state: String) -> void:
	if state == "win":
		Settings.save_stats({ "global_time": Time.get_datetime_dict_from_system(), "time": time, "dificultad": Settings.DIFFICULTY } )
	for button in select_grid.get_children():
		button.queue_free()
	_reset_game_stats()
	timer.stop()
	_update_ui()

func bind_select_grid_button_actions():
	for i in range(Settings.GRID_SIZE):
		var n_button = Button.new()
		select_grid.add_child(n_button)
		n_button.theme = preload("res://Resource/Button.tres")
		n_button.custom_minimum_size = (Vector2.ONE * (720 - 48)) / Settings.GRID_SIZE
		n_button.text = str(i + 1)
		n_button.name = str(i + 1)
		n_button.connect("pressed", sudoku._on_select_grid_button_pressed.bind(int(n_button.text)))

func _update_ui() -> void:
	var seconds = time % 60
	var minutes = (time / 60)
	
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	errores_label.text = "Errores %d / 3" % errores

func _on_segunda_oportunidad_pressed():  errores -= 1
func _reset_game_stats() -> void: time = 0; errores = 0
func _on_nuevo_juego_pressed(): Settings.GameStart.emit()
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
