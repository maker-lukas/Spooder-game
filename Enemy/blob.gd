extends CharacterBody3D

@export var move_speed: float = 1.5
@export var chase_speed: float = 3.0
@export var detection_range: float = 25.0
@export var health: float = 3.0
@export var wander_radius: float = 10.0
@export var keep_distance: float = 6.0

var _target: Node3D
var _wander_target: Vector3
var _wander_timer: float = 0.0
var _time: float = 0.0

func _ready():
	add_to_group("blob")
	_target = get_tree().get_first_node_in_group("player")
	_pick_wander_target()
	# Unique material so damage flash is per-blob
	var mesh: MeshInstance3D = $MeshInstance3D
	var mat: ShaderMaterial = mesh.mesh.material.duplicate()
	# Randomize wobble phase so they don't all pulse in sync
	mat.set_shader_parameter("wobble_speed", randf_range(1.5, 2.5))
	mesh.set_surface_override_material(0, mat)

func _physics_process(delta):
	_time += delta

	if not is_on_floor():
		velocity.y -= 25.0 * delta

	var flat_velocity := Vector3.ZERO
	var dist_to_player := INF
	if _target:
		dist_to_player = global_position.distance_to(_target.global_position)

	if _target and dist_to_player < detection_range:
		var dir = (_target.global_position - global_position)
		dir.y = 0
		if dir.length() > keep_distance:
			# Chase player but stop at keep_distance
			flat_velocity = dir.normalized() * chase_speed
		elif dir.length() < keep_distance * 0.6:
			# Too close — back away
			flat_velocity = -dir.normalized() * move_speed
	else:
		# Wander
		_wander_timer -= delta
		if _wander_timer <= 0:
			_pick_wander_target()
		var dir = (_wander_target - global_position)
		dir.y = 0
		if dir.length() > 1.0:
			flat_velocity = dir.normalized() * move_speed
		else:
			_pick_wander_target()

	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	move_and_slide()

	# Idle jiggle + squash when moving
	var speed = Vector2(velocity.x, velocity.z).length()
	var jiggle_y = 1.0 + sin(_time * 4.0) * 0.05
	var jiggle_xz = 1.0 + cos(_time * 4.0) * 0.03
	var squash = remap(speed, 0, chase_speed, 1.0, 0.8)
	var stretch = remap(speed, 0, chase_speed, 1.0, 1.15)
	$MeshInstance3D.scale = Vector3(jiggle_xz * stretch, jiggle_y * squash, jiggle_xz * stretch)

func _pick_wander_target():
	_wander_target = global_position + Vector3(
		randf_range(-wander_radius, wander_radius),
		0,
		randf_range(-wander_radius, wander_radius)
	)
	_wander_timer = randf_range(2.0, 5.0)

func take_damage(amount: float):
	health -= amount
	# Flash white
	var mesh: MeshInstance3D = $MeshInstance3D
	var mat: ShaderMaterial = mesh.get_surface_override_material(0)
	if mat:
		var original_color = mat.get_shader_parameter("base_color")
		mat.set_shader_parameter("base_color", Vector3(1.0, 1.0, 1.0))
		mat.set_shader_parameter("wobble_strength", 0.2)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(mesh):
				mat.set_shader_parameter("base_color", original_color)
				mat.set_shader_parameter("wobble_strength", 0.08)
		)
	if health <= 0:
		_die()

func _die():
	set_physics_process(false)
	$CollisionShape3D.disabled = true
	var t = get_tree().create_tween()
	t.tween_property($MeshInstance3D, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
