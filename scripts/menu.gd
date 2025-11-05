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

var index: int = 2:
	set(value):
		if value < 1 or value > 3:
			return
		index = value

func _ready():
	Settings.connect("GetMenu", show)
	Settings.connect("GameStart", hide)
	easy.pressed.connect(Settings.GameStart.emit)
	medium.pressed.connect(Settings.GameStart.emit)
	hard.pressed.connect(Settings.GameStart.emit)
	continue_button.pressed.connect(Settings.GameStart.emit)
	update_index(index)
	
	Settings.GetMenu.emit()

func _on_easy_pressed(): 
	Settings.GRID_SIZE = 4
	sudoku.init_game(true)
func _on_medium_pressed(): 
	Settings.GRID_SIZE = 9
	sudoku.init_game(true)
func _on_hard_pressed(): 
	Settings.GRID_SIZE = 16
	sudoku.init_game(true)
func _on_continue_pressed():
	if Settings.saved_game:
		sudoku.init_game(false)

func _on_prev_size_pressed(): update_index(index - 1)
func _on_next_size_pressed(): update_index(index + 1)
func _on_zones_pressed(): Settings.ZONES = !Settings.ZONES

func update_index(n: int) -> void:
	var dificultad: String = ""
	index = n
	prev_size.get_child(0).show()
	next_size.get_child(0).show()
	match index:
		1:
			prev_size.get_child(0).hide()
			dificultad = "Easy"
			Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.EASY
		2: 
			dificultad = "Medium"
			Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.MEDIUM
		3:
			next_size.get_child(0).hide()
			dificultad = "Hard"
			Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.HARD
	
	size_grid.text = str(dificultad)

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
