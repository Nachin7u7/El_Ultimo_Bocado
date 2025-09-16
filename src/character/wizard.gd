extends CharacterBody2D

@export var _speed: Vector2 = Vector2(400, 600)
@export var gravity: Vector2 = Vector2(0, 1200)

var _velocity : Vector2 = Vector2.ZERO

@export var _reticule_anchor_node_path : NodePath
@onready var reticule_anchor : Node2D = get_node(_reticule_anchor_node_path)

@export var weapon_projectile : PackedScene
@export var weapon_speed : float = 3

var _attack_power : float = 0
var _attack_scale : float = 3
var _attack_clicked : bool = false

var is_active_turn: bool = false

# --- SISTEMA DE VIDA Y DAÑO ---
@export var max_hp: int = 10
var current_hp: int = max_hp
@onready var hp_label: Label = $HP
@onready var damage_label: Label = $Damage

# Muestra el HP actual en el label
func update_hp_label():
	if hp_label:
		hp_label.text = str(current_hp) + " HP"

# Muestra el daño recibido en el label y lo oculta después de un tiempo
var _damage_tween: Tween = null

func show_damage(amount: int):
	if damage_label:
		damage_label.text = "-" + str(amount)
		damage_label.visible = true
		damage_label.modulate = Color(1,0,0,1)
		if _damage_tween and _damage_tween.is_running():
			_damage_tween.kill()
		_damage_tween = create_tween()
		_damage_tween.tween_property(damage_label, "modulate:a", 0, 1.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		_damage_tween.connect("finished", Callable(self, "_on_damage_tween_finished"))

func _on_damage_tween_finished():
	if damage_label:
		damage_label.visible = false
		damage_label.modulate = Color(1,0,0,1)

# Lógica para recibir daño
func apply_damage(amount: int):
	var result_game = null
	for child in get_tree().get_root().get_children():
		if child is CanvasLayer and child.has_method("show_result"):
			result_game = child
			break
	if result_game and result_game.game_over:
		return # El juego ya terminó, no aplicar daño
	if current_hp <= 0:
		return # Ya está muerto, no aplicar más daño
	current_hp = max(current_hp - amount, 0)
	update_hp_label()
	show_damage(amount)
	if current_hp <= 0:
		die()

func die():
	# Desactivar controles
	enable_player_input(false)
	# Reproducir animación de muerte si existe
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("Death"):
		anim.play("Death")
	# Mostrar pantalla de resultado usando la escena
	var result_scene = preload("res://src/levels/result_game.tscn")
	var result_layer = null
	# Buscar si ya existe una instancia de result_game
	for child in get_tree().get_root().get_children():
		if child is CanvasLayer and child.has_method("show_result"):
			result_layer = child
			break
	if not result_layer:
		result_layer = result_scene.instantiate()
		get_tree().get_root().add_child(result_layer)
	# Determinar si este es el jugador 1 o 2 (puedes ajustar esto según tu lógica)
	var loser = 1 if is_in_group("player1") else 2
	result_layer.show_result(loser)
	# Opcional: puedes hacer queue_free() después de la animación si lo deseas

# When _attack_power reaches this we'll force the shot. (ie, this is the max cap of power for any 1 shot)
@onready var _auto_attack_power : float = (reticule_anchor.get_child_count() / _attack_scale)

signal attack_launched
signal projectile_fired(projectile)

@onready var anim = $Frames

func _ready():
	add_to_group("wizards")
	update_hp_label()
	if damage_label:
		damage_label.visible = false
	if anim == null:
		push_error("ERROR: AnimatedSprite2D node not found. Por favor verifica que el nodo se llame exactamente 'AnimatedSprite2D' y sea hijo directo de este nodo.")
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return

func _process(_delta : float):
	_rotate_reticule()
	_redraw_power()


func _unhandled_input(event):
	if not is_active_turn:
		return
	# Click and drag - begin / end clicking
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_attack_clicked = true
		else:
			# We're checking _attack_clicked because it gets set to false if
			# we auto-fire because the player held the button for too long.
			if _attack_clicked:
				shoot()
			_attack_clicked = false


func shoot():
	# Spawn projectile
	var new_projectile := weapon_projectile.instantiate() as RigidBody2D
	var reticule := reticule_anchor.find_child("Reticule")
	new_projectile.global_position = reticule.global_position
	new_projectile.linear_velocity = (reticule.global_position - global_position) * weapon_speed * (_attack_power * _attack_scale)
	get_parent().call_deferred("add_child", new_projectile) # <-- Cambiado aquí
	# Notificar que un proyectil fue disparado (para que el controlador espere impacto o timeout)
	emit_signal("projectile_fired", new_projectile)
	_attack_power = 0
	_attack_clicked = false
	emit_signal("attack_launched")


func _rotate_reticule():
	reticule_anchor.rotate(reticule_anchor.get_angle_to(get_global_mouse_position()))


func _physics_process(_delta : float):
	if current_hp <= 0:
		return # No procesar si está muerto
	if _attack_clicked:
		_attack_power += _delta

	if _attack_power >= _auto_attack_power:
		shoot()

	var input_direction = _get_input_direction()
	_velocity = _calculate_move_velocity(_velocity, input_direction, _speed)
	set_velocity(_velocity)
	set_up_direction(Vector2(0, -1))
	move_and_slide()
	_velocity = velocity

	# --- ANIMACIÓN Y ORIENTACIÓN ---
	if anim:
		# Flip horizontal según dirección X
		if _velocity.x > 0:
			anim.flip_h = false
		elif _velocity.x < 0:
			anim.flip_h = true

		anim.flip_v = false

		var is_moving = abs(_velocity.x) > 1 or abs(_velocity.y) > 1
		if is_moving and is_on_floor():
			if anim.animation != "Walk":
				anim.play("Walk")
		elif is_on_floor():
			if anim.animation != "Idle":
				anim.play("Idle")
		else:
			anim.stop()
	else:
		print("AnimatedSprite node not found!")


func _get_input_direction() -> Vector2:
	return Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			-1 if Input.is_action_just_pressed("jump") and is_on_floor() else 0
		)


func _calculate_move_velocity(
		linear_velocity: Vector2,
		direction: Vector2,
		speed: Vector2
	):
		var new_velocity := linear_velocity
		new_velocity.x = speed.x * direction.x

		# Apply gravity
		new_velocity += gravity * get_physics_process_delta_time()

		# If player is jumping
		if direction.y == -1:
			new_velocity.y = speed.y * direction.y

		return new_velocity


func _redraw_power():
	var sprites_to_show : int = int(_attack_power * _attack_scale)

	# Note - we ignore the last child, as we don't want to hide the reticule!
	for i in range(reticule_anchor.get_child_count() - 1):
		if i < sprites_to_show:
			reticule_anchor.get_child(i).visible = true
		else:
			reticule_anchor.get_child(i).visible = false


func enable_player_input(enabled: bool):
	is_active_turn = enabled
	set_process_input(enabled)
	set_physics_process(enabled)
	set_process(enabled)
	set_process(enabled)
	set_physics_process(enabled)
	set_process(enabled)
	set_process(enabled)
