extends Control
class_name UIPopup

## The pause, win and lose panels that sit on top of the board.

@onready var lose: Panel = %Lose
@onready var win: Panel = %Win
@onready var pause: Panel = %Pause

@onready var difficulty_label: Label = %Difficulty
@onready var time_label: Label = %TimeValue
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
	difficulty_label.text = get_difficulty_name()
	time_label.text = time

func get_difficulty_name() -> String:
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
