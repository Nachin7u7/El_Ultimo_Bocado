extends RigidBody2D

@export var explosion_radius : float = 20
@export var explosion_scene : PackedScene

func _on_SlimeGreen_body_entered(_body):
	# Destruir objetos destructibles
	get_tree().call_group("destructibles", "destroy", global_position, explosion_radius)

	# Daño a jugadores dentro del radio
	var wizards = get_tree().get_nodes_in_group("wizards")
	for wizard in wizards:
		if not wizard.has_method("apply_damage"):
			continue
		var dist = global_position.distance_to(wizard.global_position)
		if dist <= explosion_radius:
			# Daño máximo en el centro, mínimo en el borde
			var damage = int(20 * (1.0 - clamp(dist / explosion_radius, 0, 1)))
			if damage > 0:
				wizard.apply_damage(damage)

	# Mostrar animación de explosión
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	queue_free()
