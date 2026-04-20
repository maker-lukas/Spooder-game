extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var death_label: Label = $DeathLabel

var _player: Node3D

func _ready():
	death_label.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		health_bar.max_value = _player.max_health
		health_bar.value = _player.health
		_player.health_changed.connect(_on_health_changed)
		_player.died.connect(_on_died)

func _on_health_changed(new_health: float, max_hp: float):
	health_bar.value = new_health

func _on_died():
	death_label.visible = true

func _unhandled_input(event):
	if death_label.visible and event.is_action_pressed("jump"):
		get_tree().change_scene_to_file("res://menu.tscn")
