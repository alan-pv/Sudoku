extends Node
class_name UISounds

@export var root_path : NodePath
#@export var ui_click: AudioFile
#@export var ui_hover: AudioFile

#@export var audio_hit: AudioFile = preload("res://Audio/AudioFiles/hit.tres")

# create audio player instances
@onready var sounds = {
	&"UI_Hover": AudioStreamPlayer.new(),
	&"UI_Click": AudioStreamPlayer.new()
}

#@export var songs: Array[AudioFile]  # Cambiado a array para múltiples canciones
#var current_music_player: SAudioStreamPlayer = null
var current_song_index: int = 0

func _ready() -> void:
	assert(root_path != null, "Empty root path for Interface Sounds!")
	
	# Configurar audios
	#for sound in sounds:
		#sounds[sound].stream = load("res://Audio/" + str(sound) + ".wav")
		#sounds[sound].bus = &"Sfx"
		#add_child(sounds[sound])
	if root_path:
		install_sounds(get_node(root_path))
	#play_next_song()
	Settings.ui_sounds = self

func install_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is Button or child is TextureButton:
			connect_signals(child)
		
		install_sounds(child)

func connect_signals(node: GridButton) -> void:
	if not node.mouse_entered.is_connected(_on_hover):
		node.mouse_entered.connect(_on_hover)
		node.pressed.connect(_on_click)
		node.mouse_entered.connect(animate_hover.bind(node))
		node.pressed.connect(animate_hover.bind(node))
		node.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_hover() -> void:
	#Audio.play_audio(ui_hover)
	pass
	
func _on_click() -> void:
	#Audio.play_audio(ui_click)
	pass

func ui_sfx_play(sound: String) -> void:
	sounds[sound].play()

func animate_hover(node: Control) -> void:
	if node.get_parent().name == "Anim":
		node = node.get_parent()
	var tween = node.create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	node.pivot_offset = node.size / 2
	
	var _sign = randf_range(1, -1)
	
	# Animación de rotación elástica
	tween.tween_property(node, "rotation_degrees", 7.5 * _sign , 0.1)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.7)
	
	# Opcional: Agregar escala para mayor efecto
	var scale_tween = node.create_tween()
	scale_tween.tween_property(node, "scale", Vector2(0.8, 0.8), 0.1)
	scale_tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)

#func play_next_song() -> void:
	#if current_song_index < songs.size():
		#var next_song = songs[current_song_index]
		#current_music_player = Audio.play_audio(next_song)
		#
		#if current_music_player:
			## Conectar la señal de finalización
			#if current_music_player.is_connected("finished", _on_song_finished):
				#current_music_player.disconnect("finished", _on_song_finished)
			#current_music_player.connect("finished", _on_song_finished)
		#current_song_index += 1
	#else:
		## Reiniciar o manejar fin de lista
		#current_song_index = 0
		#play_next_song()

#func _on_song_finished() -> void:
	#play_next_song()
