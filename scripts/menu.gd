extends Control

@onready var prev_size = %PrevSize
@onready var size_grid = %Size
@onready var next_size = %NextSize
@onready var icon = %Icon
@onready var sudoku = %Sudoku

@onready var easy: Button = %Easy
@onready var medium: Button = %Medium
@onready var hard: Button = %Hard
@onready var continue_button = %Continue

@onready var two = %two
@onready var three = %three
@onready var four = %four

@onready var normal_sprite = preload("res://Sprites/sudoku-svgrepo-com.svg")
@onready var jigsaw_sprite = preload("res://Sprites/maze-svgrepo-com.svg")

var index: int = 1:
	set(value):
		if value < 1 or value > 2:
			return
		index = value
var size_buttons = []

func _ready():
	Settings.connect("GetMenu", _show)
	Settings.connect("GameStart", hide)
	easy.pressed.connect(Settings.GameStart.emit)
	medium.pressed.connect(Settings.GameStart.emit)
	hard.pressed.connect(Settings.GameStart.emit)
	continue_button.pressed.connect(Settings.GameStart.emit)
	update_index(index)
	
	Settings.GetMenu.emit()
	size_buttons = [two, three, four]
	
	for button in size_buttons:
		button.toggle_mode = true
		button.pressed.connect(_on_size_button_pressed.bind(button))
	
	three.set_pressed(true)
	Settings.emit_signal("GetMenu")

func _show() -> void:
	show()
	continue_button.visible = not Settings.saved_game.is_empty()

func _on_easy_pressed(): 
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.EASY
	sudoku.init_game(true)
func _on_medium_pressed(): 
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.MEDIUM
	sudoku.init_game(true)
func _on_hard_pressed(): 
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.HARD
	sudoku.init_game(true)
func _on_continue_pressed():
	if Settings.saved_game:
		sudoku.init_game(false)

func update_index(n: int) -> void:
	var dificultad: String = ""
	var sprite: Texture = null
	index = n
	prev_size.get_child(0).show()
	next_size.get_child(0).show()
	match index:
		1: 
			sprite = normal_sprite
			dificultad = "Normal"
			prev_size.get_child(0).hide()
			Settings.ZONES = false
		2: 
			sprite = jigsaw_sprite
			dificultad = "Jigsaw"
			next_size.get_child(0).hide()
			Settings.ZONES = true
	
	size_grid.text = str(dificultad)
	icon.texture = sprite


func _on_size_button_pressed(selected_button):
	# Deseleccionar todos los demás
	for button in size_buttons:
		if button != selected_button:
			button.set_pressed(false)
	
	# Actualizar configuración según el botón presionado
	if selected_button == two:
		Settings.GRID_SIZE = 4
	elif selected_button == three:
		Settings.GRID_SIZE = 9
	elif selected_button == four:
		Settings.GRID_SIZE = 16

func _on_prev_size_pressed(): update_index(index - 1)
func _on_next_size_pressed(): update_index(index + 1)
func _on_zones_pressed(): Settings.ZONES = !Settings.ZONES

func _on_options_pressed():
	pass # Replace with function body.

func _on_eliminar_anuncios_pressed():
	pass # Replace with function body.

func _on_configuration_pressed():
	pass # Replace with function body.

func _on_store_pressed():
	pass # Replace with function body.

func _on_leaderboard_pressed():
	pass # Replace with function body.

func _on_information_pressed():
	pass # Replace with function body.
