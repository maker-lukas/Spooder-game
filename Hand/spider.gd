extends Node3D

@export var move_speed: float = 5.0
@export var turn_speed: float = 2.0
@export var ground_offset: float = 5.0
@export var jump_force: float = 12.0
@export var gravity: float = 25.0
@export var max_health: float = 5.0
@export var damage_cooldown: float = 0.8

var health: float
var _damage_timer: float = 0.0
var is_dead: bool = false

signal health_changed(new_health: float, max_hp: float)
signal died()

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget

@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

@onready var camera_pivot = $CameraPivot

func _ready():
	add_to_group("player")
	health = max_health

var is_grounded: bool = true
var _velocity_y: float = 0.0
var _ground_y: float = 0.0
@export var kick_range: float = 5.0
@export var kick_height: float = 4.0
@export var kick_damage: float = 1.0
@export var kick_duration: float = 0.35

var _kick_left := { "active": false, "timer": 0.0, "rest": Vector3.ZERO }
var _kick_right := { "active": false, "timer": 0.0, "rest": Vector3.ZERO }

signal kick_hit(body: Node3D)

func _process(delta):
	if is_dead:
		return
	
	_damage_timer -= delta
	
	if is_grounded:
		_process_grounded(delta)
	else:
		_process_airborne(delta)
	
	_handle_movement(delta)
	_check_blob_contact()
	
	if _kick_left["active"]:
		_process_kick(delta, fl_leg, _kick_left)
	elif Input.is_action_just_pressed("attack_left") and is_grounded:
		_start_kick(fl_leg, _kick_left)
	
	if _kick_right["active"]:
		_process_kick(delta, fr_leg, _kick_right)
	elif Input.is_action_just_pressed("attack_right") and is_grounded:
		_start_kick(fr_leg, _kick_right)

func _start_kick(leg: Node3D, state: Dictionary):
	state["active"] = true
	state["timer"] = 0.0
	state["rest"] = leg.global_position - global_position
	leg.is_kicking = true

func _process_grounded(delta):
	# Body tilt from leg positions
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	var target_basis = _basis_from_normal(avg_normal)
	var from_q = transform.basis.orthonormalized().get_rotation_quaternion()
	var to_q = target_basis.orthonormalized().get_rotation_quaternion()
	transform.basis = Basis(from_q.slerp(to_q, clampf(move_speed * delta, 0.0, 1.0)))
	
	# Height adjustment
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var target_pos = avg + transform.basis.y * ground_offset
	var distance = transform.basis.y.dot(target_pos - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)
	
	# Jump
	if Input.is_action_just_pressed("jump"):
		_ground_y = global_position.y
		_velocity_y = jump_force
		is_grounded = false

func _process_airborne(delta):
	# Gravity
	_velocity_y -= gravity * delta
	global_position.y += _velocity_y * delta
	
	# Keep body level while airborne
	var level_basis = _basis_from_normal(Vector3.UP)
	var from_q = transform.basis.orthonormalized().get_rotation_quaternion()
	var to_q = level_basis.orthonormalized().get_rotation_quaternion()
	transform.basis = Basis(from_q.slerp(to_q, clampf(5.0 * delta, 0.0, 1.0)))
	
	# Land when falling back to ground level
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
	
	# Desired direction from camera + input
	var cam_yaw = camera_pivot.yaw
	var cam_fwd = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var cam_right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var desired = (cam_fwd * -input_dir.y + cam_right * input_dir.x).normalized()
	
	# Turn toward desired direction using cross product
	var my_fwd = -transform.basis.z
	my_fwd.y = 0
	my_fwd = my_fwd.normalized()
	var turn = clampf(my_fwd.cross(desired).y, -1.0, 1.0)
	rotate_object_local(Vector3.UP, turn * turn_speed * delta)
	
	# Always walk forward
	translate(Vector3(0, 0, -1) * move_speed * delta)

func _process_kick(delta: float, leg: Node3D, state: Dictionary):
	state["timer"] += delta
	var t: float = state["timer"] / kick_duration
	
	if t >= 1.0:
		leg.is_kicking = false
		state["active"] = false
		leg.global_position = leg.step_target.global_position
		return
	
	var rest_pos = global_position + state["rest"]
	var forward = -transform.basis.z
	var up = transform.basis.y
	
	var kick_pos: Vector3
	if t < 0.25:
		var wind = t / 0.25
		kick_pos = rest_pos + forward * (-2.0 * wind) + up * (1.5 * wind)
	elif t < 0.6:
		var strike = (t - 0.25) / 0.35
		var arc = sin(strike * PI)
		kick_pos = rest_pos + forward * (-2.0 + (2.0 + kick_range) * strike) + up * (1.5 + kick_height * arc)
	else:
		var recover = (t - 0.6) / 0.4
		var end_pos = rest_pos + forward * kick_range
		var ground_pos = leg.step_target.global_position
		kick_pos = end_pos.lerp(ground_pos, recover)
	
	leg.global_position = kick_pos
	
	if t >= 0.35 and t < 0.5:
		_kick_check_hit(leg.global_position)

func _kick_check_hit(kick_pos: Vector3):
	var space = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 4.0
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, kick_pos)
	params.collision_mask = 2  # Enemy layer
	var results = space.intersect_shape(params, 10)
	for result in results:
		var body = result["collider"]
		kick_hit.emit(body)
		if body.has_method("take_damage"):
			body.take_damage(kick_damage)

func _check_blob_contact():
	if _damage_timer > 0:
		return
	var space = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 4.0
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = 2
	var results = space.intersect_shape(params, 1)
	if results.size() > 0:
		take_damage(1.0)

func take_damage(amount: float):
	if is_dead:
		return
	_damage_timer = damage_cooldown
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		health = 0
		_die()

func _die():
	is_dead = true
	died.emit()

func _basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x = normal.cross(transform.basis.z)
	result.y = normal
	result.z = transform.basis.x.cross(normal)
	return result.orthonormalized()
