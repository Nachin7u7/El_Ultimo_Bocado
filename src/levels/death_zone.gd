extends Area2D

# Cuando un cuerpo entra en el área, si es un jugador, pierde toda su vida
func _on_body_entered(body):
	if body.is_in_group("wizards"):
		if body.has_method("apply_damage"):
			body.apply_damage(body.current_hp)
