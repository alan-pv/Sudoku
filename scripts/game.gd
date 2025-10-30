extends Control

@onready var lose_screen = %LoseScreen
@onready var win_screen = %WinScreen
@onready var game_ui = %GameUI
@onready var sudoku = %Sudoku

func _ready():
	Settings.connect("GameStart", _game_start)
	Settings.connect("GameOver", _game_over)
	Settings.connect("GetMenu", _get_menu)

func _get_menu() -> void:
	sudoku.hide()
	lose_screen.hide()
	win_screen.hide()
	game_ui.hide()

func _game_start() -> void:
	show()
	game_ui.show()
	sudoku.show()
	lose_screen.hide()
	win_screen.hide()

func _game_over(state: String) -> void:
	if state == "lose":
		lose_screen.show()
	elif state == "win":
		win_screen.show()
	elif state == "exit":
		Settings.saved_games[Settings.GRID_SIZE] = sudoku.grid.duplicate_deep()
