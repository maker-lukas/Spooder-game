extends CanvasLayer

@onready var panel = $Panel

func _ready():
	panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if panel.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause():
	panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume():
	panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed():
	_resume()

func _on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
