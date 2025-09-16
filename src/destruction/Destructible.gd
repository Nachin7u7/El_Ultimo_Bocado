extends Node2D

@export var viewport_destruction_nodepath : NodePath
@export var collision_holder_node_path : NodePath

var world_size : Vector2

var collision_holder : Node2D
var _to_cull : Array

var _image_republish_texture := ImageTexture.new()

var _parent_material : Material
var _destruction_threads := Array()
var _viewport_destruction_node : Node


func _ready():
	add_to_group("destructibles")

	collision_holder = get_node(collision_holder_node_path)
	world_size = (get_parent() as Sprite2D).get_rect().size
	_parent_material = get_parent().material
	_viewport_destruction_node = get_node(viewport_destruction_nodepath)

	# Set our viewport size. We don't know this until run time, since its from our parent.
	$SubViewport.set_size(world_size)

	# Passing 0 to duplicate, as we don't want to duplicate scripts/signals etc
	# We don't use 8 since we're going to delete our duplicate nodes after first render anyway
	var dup = get_parent().duplicate(0) as Node2D
	_to_cull.append(dup)

	# Then reposition, so we're in the right spot
	dup.position = _world_to_viewport(dup.position)

	# Add to the viewport, so that our destructible viewport has our starting point
	$SubViewport.add_child(dup)

	# Start the timer, so it can delete our duplicated parent info
	$CullTimer.start()

	# Esperar a que el sprite esté listo y la textura cargada
	await RenderingServer.frame_post_draw
	# Eliminar colliders antiguos y reconstruir con la textura actual
	for child in collision_holder.get_children():
		if child is CollisionPolygon2D:
			child.queue_free()
	await get_tree().process_frame
	build_collisions_from_image()


func _exit_tree():
	for thread in _destruction_threads:
		thread.wait_to_finish()


func _unhandled_input(event):
	pass # Screenshot saving disabled


@warning_ignore("shadowed_variable_base_class")
func destroy(position : Vector2, radius : float):
	# Collision rebuild thread!
	var thread := Thread.new()
	var error = thread.start(Callable(self, "rebuild_collisions_from_geometry").bind([position, radius]))
	if error != OK:
		print("Error creating destruction thread: ", error)
	_destruction_threads.push_back(thread)

	# Move our subtractive-circle so que nuestro Viewport elimina los píxeles de la explosión
	_viewport_destruction_node.reposition(_world_to_viewport(position), radius)
	# Re-render the viewport into our texture
	rebuild_texture()

	# Esperar a que el viewport termine de renderizar
	await RenderingServer.frame_post_draw
	republish_sprite()

	# Sincronizar el collider con la nueva imagen del terreno
	_sync_collision_with_image()

func _sync_collision_with_image():
   # Elimina todos los CollisionPolygon2D existentes
	for child in collision_holder.get_children():
		if child is CollisionPolygon2D:
			child.queue_free()
	await get_tree().process_frame # Espera a que se liberen los nodos
   # Reconstruye los colliders a partir de la imagen actual
	build_collisions_from_image()


func _cull_foreground_duplicates():
	for dup in _to_cull:
		dup.queue_free()
	_to_cull = Array()


func rebuild_texture():
	# Force re-render to update our target viewport
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# Improved collision rebuilding!
func rebuild_collisions_from_geometry(arguments : Array):
	@warning_ignore("shadowed_variable_base_class")
	var position : Vector2 = arguments[0]
	var radius : float = arguments[1]

	# Defer the main logic to ensure thread safety
	call_deferred("_rebuild_collisions_main", position, radius)


func _rebuild_collisions_main(position: Vector2, radius: float):
	# Convert world coordinates of the collision point to local coordinates
	position = position - global_position

	var nb_points = 8
	var points_arc = PackedVector2Array()
	points_arc.push_back(position)

	for i in range(nb_points + 1):
		@warning_ignore("integer_division")
		var angle_point = deg_to_rad(i * 360 / nb_points)
		points_arc.push_back(position + Vector2(cos(angle_point), sin(angle_point)) * radius)

	for collision_polygon in collision_holder.get_children():
		var clipped_polygons = Geometry2D.clip_polygons(collision_polygon.polygon, points_arc)

		# If the clip failed, we're almost certainly trying to delete the last few
		# remnants of an 'island'
		if clipped_polygons.size() == 0:
			collision_polygon.queue_free()

		for i in range(clipped_polygons.size()):
			var clipped_collision = clipped_polygons[i]

			# Ignore clipped polygons that are too small to actually create
			if clipped_collision.size() < 3:
				continue

			var points = PackedVector2Array()
			for point in clipped_collision:
				points.push_back(point)

			# Update the existing polygon if possible
			if i == 0:
				collision_polygon.call_deferred("set", "polygon", points)
			else:
				var collider := CollisionPolygon2D.new()
				collider.polygon = points
				collision_holder.call_deferred("add_child", collider)


func build_collisions_from_image():
	# Create bitmap from the Viewport (which projects into our sprite)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha($Sprite2D.texture.get_image())

	# DEBUG:
	#$Sprite.get_texture().get_data().save_png("res://screenshots/debug" + get_parent().name + ".png")
	#print("Saved")

	# This will generate polygons for the given coordinate rectangle within the bitmap
	# In our case, our given coordinates are the entire image.
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2(0,0), bitmap.get_size()))

	# Now create a collision polygon for each polygon returned
	# For the most part there will probably only be one.... unless you have islands
	for polygon in polygons:
		var collider := CollisionPolygon2D.new()

		# Remap our points from the viewport coordinates back to world coordinates.
		var newpoints := Array()
		for point in polygon:
			newpoints.push_back(_viewport_to_world(point))
		collider.polygon = newpoints
		collision_holder.add_child(collider)


func republish_sprite() -> void:
	# Assume the image has changed, so we'll need to update our ImageTexture
	_image_republish_texture = ImageTexture.create_from_image($Sprite2D.texture.get_image())

	# If our parent has the proper src/destruction/parent_material shader
	# We can set our destruction_mask parameter against it,
	# which will carve out our destruction map!
	if _parent_material != null:
		_parent_material.set_shader_parameter("destruction_mask", _image_republish_texture)


func _viewport_to_world(point : Vector2) -> Vector2:
	var dynamic_texture_size = $SubViewport.get_size()
	return Vector2(
		((point.x + get_viewport_rect().position.x) / dynamic_texture_size.x) * world_size.x,
		((point.y + get_viewport_rect().position.y) / dynamic_texture_size.y) * world_size.y
	)


func _world_to_viewport(point : Vector2) -> Vector2:
	var dynamic_texture_size = $SubViewport.get_size()
	var parent_offset = get_parent().position
	return Vector2(
		((point.x - parent_offset.x ) / world_size.x) * dynamic_texture_size.x + get_viewport_rect().position.x,
		((point.y - parent_offset.y ) / world_size.y) * dynamic_texture_size.y + get_viewport_rect().position.y
	)
