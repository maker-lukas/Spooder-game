extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Load preview images if they exist
	var proc_tex = _load_texture("res://images/preview_procedural.png")
	var test_tex = _load_texture("res://images/preview_testing.png")
	if proc_tex:
		$VBoxContainer/Cards/ProceduralCard/VBox/Preview.texture = proc_tex
	if test_tex:
		$VBoxContainer/Cards/TestingCard/VBox/Preview.texture = test_tex

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _on_procedural_pressed():
	get_tree().change_scene_to_file("res://procedual world.tscn")

func _on_testing_pressed():
	get_tree().change_scene_to_file("res://world.tscn")

func _on_quit_pressed():
	get_tree().quit()
