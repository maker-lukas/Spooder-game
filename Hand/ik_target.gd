extends Marker3D

@export var step_target: Node3D
@export var step_distance: float = 2.0

@export var adjacent_target: Node3D
@export var opposite_target: Node3D

var is_stepping := false
var is_kicking := false
var _rest_offset: Vector3
var _step_sound: AudioStreamPlayer3D

func _ready():
	_rest_offset = global_position - owner.global_position
	_step_sound = AudioStreamPlayer3D.new()
	_step_sound.stream = preload("res://Hand/footstep.mp3")
	_step_sound.volume_db = 0.0
	_step_sound.unit_size = 20.0
	_step_sound.max_distance = 100.0
	add_child(_step_sound)

func _process(delta):
	if is_kicking:
		return
	
	if !owner.is_grounded:
		if owner._velocity_y >= 0:
			# Going up — pull legs in tight under the body
			var tucked = owner.global_position + owner.transform.basis * (_rest_offset * 0.65)
			global_position = global_position.lerp(tucked, 15.0 * delta)
		else:
			# Falling — reach toward ground positions
			global_position = global_position.lerp(step_target.global_position, 8.0 * delta)
		return
	
	if !is_stepping && !adjacent_target.is_stepping && abs(global_position.distance_to(step_target.global_position)) > step_distance:
		step()
		opposite_target.step()

func step():
	var target_pos = step_target.global_position
	var half_way = (global_position + step_target.global_position) / 2
	is_stepping = true
	
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", half_way + owner.basis.y, 0.1)
	t.tween_property(self, "global_position", target_pos, 0.1)
	t.tween_callback(func():
		is_stepping = false
		_step_sound.pitch_scale = randf_range(0.85, 1.15)
		_step_sound.play()
	)

func snap_to_ground():
	is_stepping = false
	global_position = step_target.global_position
