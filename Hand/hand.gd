extends Node3D

@export var move_speed: float = 5.0
@export var turn_speed: float = 2.0
@export var ground_offset: float = 3.0
@export var jump_force: float = 12.0
@export var gravity: float = 25.0

@onready var thumb = $ThumbIKTarget
@onready var index = $IndexIKTarget
@onready var middle = $MiddleIKTarget
@onready var ring = $RingIKTarget
@onready var pinky = $PinkyIKTarget

@onready var camera_pivot = $CameraPivot

var is_grounded: bool = true
var _velocity_y: float = 0.0
var _ground_y: float = 0.0

var _finger_ik_config = [
	{"root": "Bone.012", "tip": "Bone.022", "target": "IndexIKTarget", "ray": "IndexRay"},
	{"root": "Bone.013", "tip": "Bone.023", "target": "MiddleIKTarget", "ray": "MiddleRay"},
	{"root": "Bone.014", "tip": "Bone.024", "target": "RingIKTarget", "ray": "RingRay"},
	{"root": "Bone.015", "tip": "Bone.025", "target": "PinkyIKTarget", "ray": "PinkyRay"},
	{"root": "Bone.021", "tip": "Bone.026", "target": "ThumbIKTarget", "ray": "ThumbRay"},
]

func _ready():
	var skeleton = _find_skeleton(self)
	if !skeleton:
		push_error("Could not find Skeleton3D in hand model!")
		return
	
	var step_container = $StepTargetContainer
	
	for config in _finger_ik_config:
		var ik = SkeletonIK3D.new()
		ik.root_bone = config["root"]
		ik.tip_bone = config["tip"]
		ik.process_priority = 1
		skeleton.add_child(ik)
		var target_node = get_node(config["target"])
		ik.target_node = ik.get_path_to(target_node)
		ik.start()
		
		# Position IK target at the fingertip's rest position
		var tip_idx = skeleton.find_bone(config["tip"])
		if tip_idx >= 0:
			var tip_world = skeleton.global_transform * skeleton.get_bone_global_rest(tip_idx)
			target_node.global_position = tip_world.origin
			
			var ray = step_container.get_node_or_null(config["ray"])
			if ray:
				var offset = tip_world.origin - global_position
				ray.position = Vector3(offset.x, 5.0, offset.z)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _process(delta):
	if is_grounded:
		_process_grounded(delta)
	else:
		_process_airborne(delta)
	
	_handle_movement(delta)

func _process_grounded(delta):
	var plane1 = Plane(index.global_position, ring.global_position, pinky.global_position)
	var plane2 = Plane(index.global_position, middle.global_position, pinky.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	var target_basis = _basis_from_normal(avg_normal)
	var from_q = transform.basis.orthonormalized().get_rotation_quaternion()
	var to_q = target_basis.orthonormalized().get_rotation_quaternion()
	transform.basis = Basis(from_q.slerp(to_q, clampf(move_speed * delta, 0.0, 1.0)))
	
	var avg = (thumb.position + index.position + middle.position + ring.position + pinky.position) / 5
	var target_pos = avg + transform.basis.y * ground_offset
	var distance = transform.basis.y.dot(target_pos - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)
	
	if Input.is_action_just_pressed("jump"):
		_ground_y = global_position.y
		_velocity_y = jump_force
		is_grounded = false

func _process_airborne(delta):
	_velocity_y -= gravity * delta
	global_position.y += _velocity_y * delta
	
	var level_basis = _basis_from_normal(Vector3.UP)
	var from_q = transform.basis.orthonormalized().get_rotation_quaternion()
	var to_q = level_basis.orthonormalized().get_rotation_quaternion()
	transform.basis = Basis(from_q.slerp(to_q, clampf(5.0 * delta, 0.0, 1.0)))
	
	if _velocity_y < 0 and global_position.y <= _ground_y:
		global_position.y = _ground_y
		_velocity_y = 0.0
		is_grounded = true

func _handle_movement(delta):
	var input_dir = Vector2(
		Input.get_axis('move_left', 'move_right'),
		Input.get_axis('move_forward', 'move_backward')
	)
	
	if input_dir.length() < 0.1:
		return
	
	var cam_yaw = camera_pivot.yaw
	var cam_fwd = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var cam_right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var desired = (cam_fwd * -input_dir.y + cam_right * input_dir.x).normalized()
	
	var my_fwd = -transform.basis.z
	my_fwd.y = 0
	my_fwd = my_fwd.normalized()
	var turn = clampf(my_fwd.cross(desired).y, -1.0, 1.0)
	rotate_object_local(Vector3.UP, turn * turn_speed * delta)
	
	translate(Vector3(0, 0, -1) * move_speed * delta)

func _basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x = normal.cross(transform.basis.z)
	result.y = normal
	result.z = transform.basis.x.cross(normal)
	return result.orthonormalized()
