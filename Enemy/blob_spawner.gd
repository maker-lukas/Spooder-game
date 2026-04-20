extends Node3D

@export var blob_scene: PackedScene
@export var map_size: float = 256.0
@export var max_blobs: int = 8
@export var spawn_interval: float = 8.0

var _timer: float = 0.0

func _ready():
	for i in range(4):
		_spawn_blob()

func _process(delta):
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		var blob_count = get_tree().get_nodes_in_group("blob").size()
		if blob_count < max_blobs:
			_spawn_blob()

func _spawn_blob():
	if !blob_scene:
		return
	var blob = blob_scene.instantiate()
	var half = map_size / 2.0
	var pos = Vector3(
		randf_range(-half, half),
		10.0,
		randf_range(-half, half)
	)
	add_child(blob)
	blob.global_position = pos
