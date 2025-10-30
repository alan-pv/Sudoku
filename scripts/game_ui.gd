extends Control
class_name GameUI

@onready var sudoku: Sudoku = %Sudoku
@onready var errores_label = %Errores
@onready var timer_label = %TimerLabel
@onready var select_grid = %SelectGrid
@onready var panel_central = %PanelCentral
@onready var lose_screen = %LoseScreen
@onready var win_screen = %WinScreen

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
var buttons: Array[Button] = []

func _ready():
	Settings.connect("GameStart", bind_select_grid_button_actions)
	Settings.connect("GameStart", _reset_game_stats)

func bind_select_grid_button_actions():
	for button in buttons:
		button.queue_free()
	
	buttons = []
	for i in range(Settings.GRID_SIZE):
		var n_button = Button.new()
		select_grid.add_child(n_button)
		n_button.custom_minimum_size = Vector2i(64,64)
		n_button.text = str(i + 1)
		n_button.connect("pressed", sudoku._on_select_grid_button_pressed.bind(int(n_button.text)))
		buttons.append(n_button)

func _update_ui() -> void:
	var seconds = time % 60
	var minutes = (time / 60)
	
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	errores_label.text = "Errores %d / 3" % errores

func _on_segunda_oportunidad_pressed(): 
	errores -= 1
	panel_central.hide()
	
func _reset_game_stats() -> void:
	time = 0
	errores = 0
	panel_central.hide()
	_update_ui()
	
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
