extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -1.2
@export var max_pitch: float = 0.2

var yaw: float = 0.0
var pitch: float = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	yaw = rotation.y
	pitch = rotation.x

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

func _process(delta):
	global_position = get_parent().global_position
	rotation = Vector3(pitch, yaw, 0)
