extends Button
class_name GridButton

signal Solved()

@onready var control: Control = $".."
@onready var label = %Label

enum CellStates { NORMAL, OPTION, SELECTED, CORRECT, WRONG, ZONE }

var cell_states: Dictionary = {
	CellStates.NORMAL: Color("#1E1E1E"),
	CellStates.OPTION: Color("3A3A3A"), 
	CellStates.SELECTED: Color("007F5F"),
	CellStates.ZONE: Color("b2b2b278")
}

var solved: bool = false
var c_answer: int = 0
var answer: int = 0
var pos: Vector2i = Vector2i.ZERO
var zone: int = -1
var current_state: CellStates = CellStates.NORMAL

func _ready():
	var custom_size = Vector2.ONE * ((720-48) / Settings.GRID_SIZE)
	control.custom_minimum_size = custom_size
	label.label_settings.font_size = custom_size.x / 2
	
	
func set_data(data: Dictionary, new_pos: Vector2i) -> void:
	pos = new_pos
	
	if data.size() <= 1: 
		zone = -1
		answer = 0
		c_answer = 0
		solved = false
		update_state(null)
		return
	
	zone = data["zone"]
	answer = data["solution"]
	
	if data["value"] == data["solution"]:
		
		_set_text(answer)
		set_answer(data["value"])
		c_answer = -1
		#emit_signal("Solved", answer)
	
	
func update_state(btn: GridButton) -> void:
	current_state = CellStates.NORMAL
	
	if not btn: 
		set_state(current_state)
		return
	
	if btn.pos.x == pos.x or btn.pos.y == pos.y or btn.zone == zone and zone != -1:
		current_state = CellStates.OPTION
	if btn == self or btn.answer == answer and solved and btn.solved:
		current_state = CellStates.SELECTED
		emit_signal("mouse_entered")
	
	set_state(current_state)

func set_state(state: CellStates):
	current_state = state
	if not label: label = $Label
	label.self_modulate = Color.WHITE
	if solved and c_answer != -1:
		label.self_modulate = Color.GREEN_YELLOW
	elif not solved and c_answer != -1:
		label.self_modulate = Color.INDIAN_RED
	if zone != -1:
		get_theme_stylebox("normal").border_color = Settings.colores_acentos[zone] if Settings.ZONES else Color("000000")
		get_theme_stylebox("normal").bg_color = cell_states[state]
	else:
		get_theme_stylebox("normal").border_color = Color("000000")
		get_theme_stylebox("normal").bg_color = cell_states[state]

func set_answer(value: int) -> bool:
	if value == answer:
		solved = true
		emit_signal("Solved", answer)
	c_answer = value
	_set_text(value)
	return solved

func _set_text(value: int):
	if label == null: label = get_node("Label")
	
	if value > 0:
		label.show()
		label.text = str(value)
	else:
		label.hide()
