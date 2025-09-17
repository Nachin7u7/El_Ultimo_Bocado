extends CanvasLayer

# Pantalla de resultado para mostrar el ganador y reiniciar la partida


var label_result : Label = null
var button_restart : Button = null
var result_shown : bool = false
static var game_over : bool = false

func _ready():
	game_over = false

# Llama a esta función para mostrar el resultado

func show_result(loser: String):
	#print("GAMEOVER: Perdió %s | result_shown=%s | game_over=%s" % [loser, str(result_shown), str(game_over)])
	if result_shown or game_over:
		return
	result_shown = true
	game_over = true
	# Determinar el ganador (puedes adaptar esta lógica si tienes los nombres de ambos jugadores)
	var winner = "Tucumana" if loser == "Saltenia" else "Saltenia"
	if not label_result:
		label_result = Label.new()
		label_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_result.anchor_left = 0.25
		label_result.anchor_right = 0.75
		label_result.anchor_top = 0.3
		label_result.anchor_bottom = 0.5
		label_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
		label_result.grow_vertical = Control.GROW_DIRECTION_BOTH
		label_result.add_theme_font_size_override("font_size", 48)
		add_child(label_result)
	label_result.text = "¡%s gana!" % winner

	if not button_restart:
		button_restart = Button.new()
		button_restart.text = "Jugar otra vez"
		button_restart.anchor_left = 0.4
		button_restart.anchor_right = 0.6
		button_restart.anchor_top = 0.6
		button_restart.anchor_bottom = 0.7
		button_restart.grow_horizontal = Control.GROW_DIRECTION_BOTH
		button_restart.grow_vertical = Control.GROW_DIRECTION_BOTH
		if not button_restart.pressed.is_connected(_on_restart_pressed):
			button_restart.pressed.connect(_on_restart_pressed)
		add_child(button_restart)

func _on_restart_pressed():
	result_shown = false
	game_over = false
	if label_result:
		label_result.queue_free()
		label_result = null
	if button_restart:
		button_restart.queue_free()
		button_restart = null
	get_tree().reload_current_scene()
