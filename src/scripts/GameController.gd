extends Node

# Controlador de partida para multijugador por turnos y modo bot

enum GameMode { PLAYER_VS_PLAYER, PLAYER_VS_BOT }

var game_mode : GameMode = GameMode.PLAYER_VS_PLAYER
var current_turn : int = 0 # 0 = jugador 1, 1 = jugador 2/bot
var players : Array = [] # Referencias a los magos
var bot_enabled : bool = false
var turn_label: Label
var turn_banner_layer: CanvasLayer
var turn_banner_label: Label
var waiting_for_resolution: bool = false
var resolution_done: bool = false
var active_projectile: Node = null
var active_resolution_timer: SceneTreeTimer = null
const BOT_SHOT_DELAY := 2.0

func _ready():
	# Buscar magos en la escena
	players = get_tree().get_nodes_in_group("wizards")
	# Conectar menú
	var menu = get_node_or_null("../Menu")
	if menu:
		menu.connect("mode_selected", Callable(self, "set_game_mode"))
	# Conectar señales de disparo e inicio de ataque
	for player in players:
		player.connect("attack_launched", Callable(self, "_on_attack_launched"))
		player.connect("projectile_fired", Callable(self, "_on_projectile_fired"))
	if game_mode == GameMode.PLAYER_VS_BOT:
		bot_enabled = true
		# Si el segundo mago es bot, desactivar input manual
		if players.size() > 1:
			players[1].enable_player_input(false)
	# Crear capa UI y banners de turno
	var main_node = get_tree().current_scene
	turn_banner_layer = CanvasLayer.new()
	main_node.add_child.call_deferred(turn_banner_layer)

	# Label pequeño persistente de turno (arriba-izquierda)
	turn_label = Label.new()
	turn_label.text = "Turno: "
	turn_label.position = Vector2(30, 30)
	turn_label.custom_minimum_size = Vector2(400, 40)
	turn_label.add_theme_color_override("font_color", Color(1,1,0))
	turn_banner_layer.add_child(turn_label)

	# Banner central de turno (grande y temporal)
	turn_banner_label = Label.new()
	turn_banner_label.visible = false
	turn_banner_label.text = ""
	turn_banner_label.add_theme_color_override("font_color", Color(1, 1, 1))
	turn_banner_label.add_theme_font_size_override("font_size", 48)
	# Anclado al centro-superior
	turn_banner_label.anchor_left = 0.5
	turn_banner_label.anchor_top = 0.1
	turn_banner_label.anchor_right = 0.5
	turn_banner_label.anchor_bottom = 0.1
	turn_banner_label.offset_left = -250
	turn_banner_label.offset_top = 20
	turn_banner_label.custom_minimum_size = Vector2(500, 60)
	turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_layer.add_child(turn_banner_label)

	update_turn_label()
	ensure_min_player_spacing()
	start_turn()

func start_turn():
	if players.size() > 0:
		var camera_nodes = get_tree().get_nodes_in_group("cameras")
		if camera_nodes.size() > 0:
			var camera = camera_nodes[0]
			# Seguir al jugador activo
			if camera.has_method("follow_target"):
				camera.follow_target(players[current_turn], true)
			else:
				camera.global_position = players[current_turn].global_position
			if camera.has_method("set_follow_smoothing"):
				camera.set_follow_smoothing(0.0)
			if camera.has_method("make_current"):
				camera.make_current()
	update_turn_label()
	show_turn_banner(get_current_turn_text())
	# Activar input solo para el jugador actual
	if bot_enabled and current_turn == 1:
		for i in range(players.size()):
			players[i].enable_player_input(false)
		await get_tree().create_timer(BOT_SHOT_DELAY).timeout
		bot_take_turn()
	else:
		for i in range(players.size()):
			players[i].enable_player_input(i == current_turn)

func end_turn():
	# Detener seguimiento de cámara antes de cambiar de turno
	var camera_nodes = get_tree().get_nodes_in_group("cameras")
	if camera_nodes.size() > 0:
		var camera = camera_nodes[0]
		if camera.has_method("follow_target"):
			camera.follow_target(null, false)
	current_turn = (current_turn + 1) % players.size()
	start_turn()

func ensure_min_player_spacing(min_distance: float = 1000.0):
	if players.size() < 2:
		return
	var p0 = players[0]
	var p1 = players[1]
	var dx = p1.global_position.x - p0.global_position.x
	if abs(dx) >= min_distance:
		return
	var mid_x = (p0.global_position.x + p1.global_position.x) / 2.0
	var half = min_distance / 2.0
	# Mantener Y original, solo ajustar X
	p0.global_position.x = mid_x - half
	p1.global_position.x = mid_x + half

func update_turn_label():
	if turn_label:
		turn_label.text = get_current_turn_text()

func get_current_turn_text() -> String:
	if bot_enabled and current_turn == 1:
		return "Turno: Bot"
	else:
		return "Turno: %s" % players[current_turn].name

func show_turn_banner(text: String):
	if not turn_banner_label:
		return
	turn_banner_label.text = text
	turn_banner_label.visible = true
	turn_banner_label.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(turn_banner_label, "modulate:a", 1.0, 0.25)
	t.tween_interval(0.6)
	t.tween_property(turn_banner_label, "modulate:a", 0.35, 0.35)
	t.tween_property(turn_banner_label, "modulate:a", 0.0, 0.35)
	t.tween_callback(Callable(turn_banner_label, "hide"))

func bot_take_turn():
	var bot = players[1]
	var target = players[0]
	var reticule = bot.reticule_anchor.find_child("Reticule")
	var move_distance = 350 # Distancia mínima para acercarse
	var max_move_time = 2.0 # Tiempo máximo de movimiento antes de disparar
	var move_speed = bot._speed.x
	var stuck_timer = 0.0
	var last_x = bot.global_position.x
	var move_dir = 0
	var delta = 0.1 # Simulación de delta para cada paso

	# Moverse hacia el jugador si está lejos
	while bot.global_position.distance_to(target.global_position) > move_distance and stuck_timer < max_move_time:
		var direction = (target.global_position - bot.global_position).normalized()
		move_dir = sign(direction.x)
		var input_direction = Vector2(move_dir, 0)
		var prev_x = bot.global_position.x
		# Simular movimiento llamando a la función de movimiento del player
		bot._velocity = bot._calculate_move_velocity(bot._velocity, input_direction, bot._speed)
		bot.set_velocity(bot._velocity)
		bot.set_up_direction(Vector2(0, -1))
		bot.move_and_slide()
		bot._velocity = bot.velocity
		# Animación y orientación igual que en _physics_process
		if bot.anim:
			if bot._velocity.x > 0:
				bot.anim.flip_h = false
			elif bot._velocity.x < 0:
				bot.anim.flip_h = true
			bot.anim.flip_v = false
			var is_moving = abs(bot._velocity.x) > 1 or abs(bot._velocity.y) > 1
			if is_moving and bot.is_on_floor():
				if bot.anim.animation != "Walk":
					bot.anim.play("Walk")
			elif bot.is_on_floor():
				if bot.anim.animation != "Idle":
					bot.anim.play("Idle")
			else:
				bot.anim.stop()
		# Si no avanzó, intentar saltar
		if abs(bot.global_position.x - prev_x) < 2 and bot.is_on_floor():
			var jump_dir = Vector2(move_dir, -1)
			bot._velocity = bot._calculate_move_velocity(bot._velocity, jump_dir, bot._speed)
			bot.set_velocity(bot._velocity)
			bot.set_up_direction(Vector2(0, -1))
			bot.move_and_slide()
			bot._velocity = bot.velocity
		await get_tree().create_timer(delta).timeout
		stuck_timer += delta

	# Apuntar y disparar
	if reticule and target:
		var direction = (target.global_position - bot.global_position).normalized()
		reticule.global_position = bot.global_position + direction * 100
	bot._attack_power = 1.0
	bot.shoot() # Ahora se espera a impacto o timeout para cambiar turno

func set_game_mode(mode):
	game_mode = mode
	bot_enabled = (mode == GameMode.PLAYER_VS_BOT)
	if players.size() > 1:
		players[1].enable_player_input(false)
	update_turn_label()
	if bot_enabled and current_turn == 1:
		start_turn()

# Señales de turno y resolución de proyectil
func _on_attack_launched():
	# Desactivar input durante el vuelo del proyectil
	for i in range(players.size()):
		players[i].enable_player_input(false)

func _on_projectile_fired(projectile: Node):
	waiting_for_resolution = true
	resolution_done = false
	active_projectile = projectile
	# Esperar a que el proyectil se destruya (impacto) o a un timeout de 10s
	if not projectile.is_connected("tree_exited", Callable(self, "_on_projectile_exited")):
		projectile.connect("tree_exited", Callable(self, "_on_projectile_exited"))
	active_resolution_timer = get_tree().create_timer(10.0)
	active_resolution_timer.connect("timeout", Callable(self, "_on_resolution_timeout"))

func _on_projectile_exited():
	if resolution_done:
		return
	resolution_done = true
	proceed_to_next_turn()

func _on_resolution_timeout():
	if resolution_done:
		return
	resolution_done = true
	proceed_to_next_turn()

func proceed_to_next_turn():
	waiting_for_resolution = false
	active_projectile = null
	active_resolution_timer = null
	end_turn()
