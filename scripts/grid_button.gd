extends Button
class_name GridButton

@onready var label = %Label
@onready var color = %Color

enum CellStates { NORMAL, OPTION, SELECTED, CORRECT, WRONG, ZONE }

var cell_states: Dictionary = {
	CellStates.NORMAL: Color("#1E1E1E"),
	CellStates.OPTION: Color("2B2B2B"), 
	CellStates.SELECTED: Color("007F5F"),
	CellStates.ZONE: Color("b2b2b278")
}

var solved: bool = false
var c_answer: int = 0
var answer: int = 0
var pos: Vector2i = Vector2i.ZERO
var zone: int = -1
var box_index: int = -1
var current_state: CellStates = CellStates.NORMAL

func _ready():
	custom_minimum_size = Vector2(48, 48)
	add_theme_font_size_override("font_size", 24)
	if solved:
		_set_text(answer)

func update_state(btn: GridButton) -> void:
	current_state = CellStates.NORMAL
	
	if not btn: 
		set_state(current_state)
		return
	
	if btn.pos.x == pos.x or btn.pos.y == pos.y or (btn.box_index == box_index and zone == -1):
		current_state = CellStates.OPTION
	if btn.zone == zone and zone != -1:
		current_state = CellStates.ZONE
	if btn == self or btn.answer == answer and solved and btn.solved:
		current_state = CellStates.SELECTED
	color.visible = false
	color.self_modulate = Settings.colores_acentos[zone]
	
	set_state(current_state)

func set_state(state: CellStates):
	current_state = state
	self_modulate = cell_states[state]
	label.self_modulate = Color.WHITE
	if solved and c_answer != -1:
		label.self_modulate = Color("#359734")
	elif not solved and c_answer != -1:
		label.self_modulate = Color.DARK_RED
	if Settings.ZONES:
		self_modulate = Settings.colores_acentos[zone]

func set_answer(value: int) -> bool:
	if value == answer:
		solved = true
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
	
