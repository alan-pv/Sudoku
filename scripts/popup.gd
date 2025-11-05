extends Control
class_name UIPopup

@onready var lose: Panel = %Lose
@onready var win: Panel = %Win
@onready var pause: Panel = %Pause

@onready var dificultad: Label = %Dificultad
@onready var tiempo: Label = %Tiempo
@onready var sudoku: Sudoku = %Sudoku


func _ready() -> void:
	Settings.connect("GameStart", get_menu)

func get_menu() -> void:
	lose.hide()
	win.hide()
	pause.hide()

func get_pause_panel() -> void:
	pause.show()

func get_lose_screen() -> void:
	get_pause_panel()
	lose.show()
	
func get_win_screen(time: String) -> void:
	get_pause_panel()
	win.show()
	dificultad.text = get_dificultad()
	tiempo.text = time

func get_dificultad() -> String:
	match Settings.DIFFICULTY:
		SudokuBoard.TypeDifficulty.EASY:
			return "Easy"
		SudokuBoard.TypeDifficulty.MEDIUM:
			return "Medium"
		SudokuBoard.TypeDifficulty.HARD:
			return "Hard"
		_:
			return ""


func _on_new_game_pressed() -> void:
	Settings.emit_signal("GameStart")
	sudoku.init_game()


func _on_back_pressed() -> void:
	Settings.emit_signal("GetMenu")
	get_menu()


func _on_share_pressed() -> void:
	pass # Replace with function body.
