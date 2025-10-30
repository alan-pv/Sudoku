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
		if value < 2 or value > 5:
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
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.EASY
	Settings.saved_games[Settings.GRID_SIZE] = SudokuBoard.generate_board(Settings.GRID_SIZE, Settings.DIFFICULTY, Settings.ZONES)
	sudoku.init_game(Settings.saved_games[Settings.GRID_SIZE])
func _on_medium_pressed(): 
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.MEDIUM
	Settings.saved_games[Settings.GRID_SIZE] = SudokuBoard.generate_board(Settings.GRID_SIZE, Settings.DIFFICULTY, Settings.ZONES)
	sudoku.init_game(Settings.saved_games[Settings.GRID_SIZE])
func _on_hard_pressed(): 
	Settings.DIFFICULTY = SudokuBoard.TypeDifficulty.HARD
	Settings.saved_games[Settings.GRID_SIZE] = SudokuBoard.generate_board(Settings.GRID_SIZE, Settings.DIFFICULTY, Settings.ZONES)
	sudoku.init_game(Settings.saved_games[Settings.GRID_SIZE])
func _on_continue_pressed():
	sudoku.init_game(Settings.saved_games[Settings.GRID_SIZE])

func _on_prev_size_pressed(): update_index(index - 1)
func _on_next_size_pressed(): update_index(index + 1)
func _on_zones_pressed(): Settings.ZONES = !Settings.ZONES

func update_index(n: int) -> void:
	index = n
	Settings.GRID_SIZE = index * index
	size_grid.text = "%d x %d" % [index, index]

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
