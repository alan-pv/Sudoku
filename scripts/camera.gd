extends Camera2D

# --- Ajustes (exportados para ajustar desde el editor) ---
@export var drag_button: int = MOUSE_BUTTON_LEFT
@export var zoom_speed: float = 0.12        # cambio porcentual objetivo por tick (0.12 = ~12%)
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0

# Suavizado (mayor = más rápido en alcanzar el objetivo; 0 = instantáneo)
@export var drag_smooth: float = 8.0        # suavizado del arrastre (posiciones por segundo)
@export var zoom_smooth: float = 12.0       # suavizado del zoom (valores por segundo)

# Opciones
@export var enable_drag: bool = true
@export var enable_zoom: bool = true

# --- Estado interno ---
var _dragging: bool = false
var _drag_origin_world: Vector2 = Vector2.ZERO
var _start_cam_pos: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO

var _target_zoom: float = 1.0

func _ready() -> void:
	# asegurar zoom uniforme
	_target_zoom = clamp(zoom.x, min_zoom, max_zoom)
	zoom = Vector2(_target_zoom, _target_zoom)
	_target_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Inicio / fin de arrastre
	if enable_drag and event.button_index == drag_button:
		if event.pressed:
			_dragging = true
			_drag_origin_world = get_global_mouse_position()
			_start_cam_pos = _target_position
		else:
			_dragging = false

	# Rueda de ratón: ajustar objetivo de zoom (no aplicamos el zoom instantáneamente)
	if enable_zoom and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_target_zoom(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_target_zoom(false)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not enable_drag or not _dragging:
		return
	# Calculamos la nueva posición objetivo manteniendo la diferencia entre
	# el punto del mundo donde se empezó a arrastrar y el punto actual del mouse.
	var current_mouse_world = get_global_mouse_position()
	var desired_pos = _start_cam_pos + (_drag_origin_world - current_mouse_world)
	_target_position = desired_pos

func _set_target_zoom(zoom_in: bool) -> void:
	var factor = 1.0 - zoom_speed if zoom_in else 1.0 + zoom_speed
	var new_target = _target_zoom * factor
	_target_zoom = clamp(new_target, min_zoom, max_zoom)
	# no cambiamos zoom instantáneamente: el _process lo animará y compensará la posición

func _process(delta: float) -> void:
	# ----------------------
	# Suavizar posición (drag)
	# ----------------------
	# factor de interpolación dependiente de delta y la velocidad deseada (drag_smooth)
	var pos_t = clamp(drag_smooth * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target_position, pos_t)

	# ----------------------
	# Suavizar zoom manteniendo el punto bajo el cursor
	# ----------------------
	if not is_equal_approx(zoom.x, _target_zoom):
		var zoom_t = clamp(zoom_smooth * delta, 0.0, 1.0)

		# punto del mundo bajo el cursor antes del paso de zoom
		var world_before = get_global_mouse_position()

		# interpolamos el valor de zoom (usamos componente x, mantenemos uniforme)
		var cur = zoom.x
		var new_zoom_val = lerp(cur, _target_zoom, zoom_t)
		new_zoom_val = clamp(new_zoom_val, min_zoom, max_zoom)
		zoom = Vector2(new_zoom_val, new_zoom_val)

		# punto del mundo bajo el cursor después del zoom y compensación
		var world_after = get_global_mouse_position()
		var shift = world_before - world_after

		# aplicamos compensación tanto a la posición actual como a la objetivo
		global_position += shift
		_target_position += shift

# utilidad pública para setear posición o zoom desde código (con suavizado)
func set_camera_target(pos: Vector2, zoom_value: float = -1.0) -> void:
	_target_position = pos
	if zoom_value > 0.0:
		_target_zoom = clamp(zoom_value, min_zoom, max_zoom)
