extends Camera2D


var _previous_position : Vector2 = Vector2.ZERO
var _move_camera := false
var _target: Node2D = null
var _follow_enabled: bool = false

func _ready():
	# Add camera to group so GameController can find it and set a more zoomed-out default
	add_to_group("cameras")
	zoom = Vector2(0.7, 0.7)

func _unhandled_input(event):
	# Click and drag - begin / end clicking
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		if event.is_pressed():
			_previous_position = event.position
			_move_camera = true
		else:
			_move_camera = false

	# Click and drag - dragging
	elif event is InputEventMouseMotion && _move_camera:
		get_viewport().set_input_as_handled()
		position += (_previous_position - event.position)
		_previous_position = event.position

	# Zoom
	elif event is InputEventMouseButton:
		var new_zoom := Vector2.ZERO
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			new_zoom = zoom.lerp(Vector2(0.5, 0.5), 0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			new_zoom = zoom.lerp(Vector2(4,4), 0.2)

		if (new_zoom != Vector2.ZERO):
			get_viewport().set_input_as_handled()
			zoom = new_zoom

func follow_target(target: Node2D, enabled: bool = true):
	_target = target
	_follow_enabled = enabled
	if enabled:
		make_current()

func _process(_delta):
	if _follow_enabled and _target:
		global_position = lerp(global_position, _target.global_position, 0.15)
