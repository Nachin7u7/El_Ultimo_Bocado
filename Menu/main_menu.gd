extends Control


var float_time := 0.0
var float_amplitude := 10.0 # píxeles de movimiento
var float_speed := 1.0 # velocidad de la animación
var base_y := 0.0

func _ready():
	# Guardar la posición base en Y
	base_y = $MarginContainer/BoxContainer/TextureRect.position.y
	# Conecta los botones (puedes hacerlo también desde el editor)
	$MarginContainer/BoxContainer/Play.pressed.connect(_on_play_pressed)
	$MarginContainer/BoxContainer/Exit.pressed.connect(_on_quit_pressed)

func _process(delta):
	float_time += delta * float_speed
	var offset = sin(float_time) * float_amplitude
	var tex_rect = $MarginContainer/BoxContainer/TextureRect
	tex_rect.position.y = base_y + offset

func _on_play_pressed():
	get_tree().change_scene_to_file("res://src/levels/FirstLevel.tscn")

func _on_quit_pressed():
	get_tree().quit()
