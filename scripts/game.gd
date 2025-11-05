extends Control

@onready var game_ui = %GameUI
@onready var sudoku = %Sudoku
@onready var popup: UIPopup = %Popup

func _ready():
	Settings.connect("GameStart", _game_start)
	Settings.connect("GameOver", _game_over)
	Settings.connect("GetMenu", _get_menu)

func _get_menu() -> void:
	sudoku.hide()
	game_ui.hide()

func _game_start() -> void:
	show()
	game_ui.show()
	sudoku.show()

func _game_over(state: String) -> void:
	if state == "lose":
		popup.get_lose_screen()
	elif state == "win":
		popup.get_win_screen(game_ui.timer_label.text)
	elif state == "exit":
		Settings.saved_game = sudoku.grid.duplicate_deep()
		popup.get_menu()
