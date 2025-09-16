extends Control

func _ready():
	# Conecta los botones (puedes hacerlo también desde el editor)
	$MarginContainer/BoxContainer/Play.pressed.connect(_on_play_pressed)
	$MarginContainer/BoxContainer/Exit.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://src/levels/FirstLevel.tscn")

func _on_quit_pressed():
	get_tree().quit()
