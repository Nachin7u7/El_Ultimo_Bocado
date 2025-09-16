extends CharacterBody2D

# ====== MOVIMIENTO / FÍSICA ======
@export var _speed: Vector2 = Vector2(400, 600)   # x = vel horizontal, y = impulso salto
@export var gravity: Vector2 = Vector2(0, 1200)

var _velocity: Vector2 = Vector2.ZERO

# ====== RETÍCULA / DISPARO ======
@export var _reticule_anchor_node_path: NodePath
@onready var reticule_anchor: Node2D = get_node(_reticule_anchor_node_path)

@export var weapon_projectile: PackedScene
@export var weapon_speed: float = 350.0   # << subí el base speed para notar mejor la carga
@export var min_shot_power: float = 0.25  # << mínimo al disparar (25% del máximo)
@export var max_shot_power: float = 1.00  # << máximo (100%)

var _attack_power: float = 0.0
var _attack_scale: float = 3.0
var _attack_clicked: bool = false

# Se calcula en _ready() para asegurar que cuente SOLO los segmentos (hijos-1)
var _auto_attack_power: float = 1.0

# ====== ANIMACIÓN ======
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
var _current_anim: StringName = &""

func _ready() -> void:
	# Asegura que "Reticule" exista y quede como ÚLTIMO hijo del anchor
	var reticule := reticule_anchor.get_node_or_null("Reticule")
	if reticule:
		reticule_anchor.move_child(reticule, reticule_anchor.get_child_count() - 1)

	# Recalcula el tope de carga usando SOLO segmentos (hijos - 1)
	var segments: int = max(0, reticule_anchor.get_child_count() - 1)
	_auto_attack_power = max(0.6, float(segments) / _attack_scale) # mínimo ~0.6s para que se note

	# Inicialmente apaga todos los segmentos (el Reticule se deja como está)
	for i in range(segments):
		reticule_anchor.get_child(i).visible = false

	_play_anim(&"idle")

func _process(_delta: float) -> void:
	_rotate_reticule()
	_redraw_power()

func _unhandled_input(event: InputEvent) -> void:
	# Click and drag - begin / end clicking (como tu original)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_attack_clicked = true
			_attack_power = 0.0  # reinicia la carga al empezar
		else:
			# Si no auto-disparó, dispara al soltar
			if _attack_clicked:
				shoot()
			_attack_clicked = false

func shoot() -> void:
	# Spawn projectile (tu original, con dirección normalizada y ratio de carga)
	var new_projectile := weapon_projectile.instantiate() as RigidBody2D
	var reticule := reticule_anchor.find_child("Reticule") as Node2D
	if reticule == null:
		return

	new_projectile.global_position = reticule.global_position

	# === CAMBIO CLAVE: usar dirección NORMALIZADA + potencia por RATIO ===
	var dir: Vector2 = (reticule.global_position - global_position).normalized()

	# Cuánto cargaste (0..1) según el tope real
	var charge_ratio: float = 0.0
	if _auto_attack_power > 0.0:
		charge_ratio = clamp(_attack_power / _auto_attack_power, 0.0, 1.0)

	# Interpola entre mínimo y máximo perceptibles
	var shot_power: float = lerp(min_shot_power, max_shot_power, charge_ratio)

	# Velocidad final
	new_projectile.linear_velocity = dir * weapon_speed * (shot_power * _attack_scale)

	get_parent().add_child(new_projectile)

	# Reset de la carga
	_attack_power = 0.0
	_attack_clicked = false

func _rotate_reticule() -> void:
	# Igual que tu original: gira hacia el mouse
	reticule_anchor.rotate(reticule_anchor.get_angle_to(get_global_mouse_position()))

func _physics_process(delta: float) -> void:
	# Carga mientras mantienes
	if _attack_clicked:
		_attack_power += delta

	# Auto-disparo cuando supera el tope (tope basado en # de segmentos)
	if _attack_power >= _auto_attack_power:
		shoot()

	# Movimiento
	var input_direction := _get_input_direction()
	_velocity = _calculate_move_velocity(_velocity, input_direction, _speed)
	set_velocity(_velocity)
	set_up_direction(Vector2(0, -1))
	move_and_slide()
	_velocity = velocity

	# Flip del sprite (usa tu Sprite2D)
	if _velocity.x > 1.0:
		sprite.flip_h = false
	elif _velocity.x < -1.0:
		sprite.flip_h = true

	_update_animation()

func _get_input_direction() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		-1.0 if Input.is_action_just_pressed("jump") and is_on_floor() else 0.0
	)

func _calculate_move_velocity(
		linear_velocity: Vector2,
		direction: Vector2,
		speed: Vector2
	) -> Vector2:
	var new_velocity := linear_velocity
	new_velocity.x = speed.x * direction.x

	# Gravedad
	new_velocity += gravity * get_physics_process_delta_time()

	# Salto
	if direction.y == -1.0:
		new_velocity.y = speed.y * direction.y

	return new_velocity

# ====== BARRA DE POTENCIA (segmentos hijos del ReticuleAnchor, último = Reticule) ======
func _redraw_power() -> void:
	var segments: int = max(0, reticule_anchor.get_child_count() - 1) # último = Reticule
	if segments == 0:
		return

	# Ratio de carga coherente con el tope real de auto-disparo
	var ratio: float = 0.0
	if _auto_attack_power > 0.0:
		ratio = clamp(_attack_power / _auto_attack_power, 0.0, 1.0)

	var to_show: int = int(ceil(ratio * float(segments)))
	for i in range(segments):
		reticule_anchor.get_child(i).visible = i < to_show

# ====== ANIMACIONES ======
func _update_animation() -> void:
	if not is_on_floor():
		_play_anim(&"fall")
		return
	if absf(_velocity.x) > 5.0:
		_play_anim(&"walk")
		return
	_play_anim(&"idle")

func _play_anim(name: StringName) -> void:
	if _current_anim == name:
		return
	_current_anim = name
	if anim.has_animation(name):
		anim.play(name)

func play_hurt() -> void:
	if anim.has_animation(&"hurt"):
		anim.play(&"hurt")
