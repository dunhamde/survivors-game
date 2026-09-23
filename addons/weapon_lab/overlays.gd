extends Node2D

var arena: Node2D
var show_collisions := false
var show_targets := true


func _draw() -> void:
	if arena == null:
		return
	if show_collisions:
		_draw_shapes(arena)
	if show_targets:
		for target in get_tree().get_nodes_in_group("enemies"):
			var point := to_local(target.global_position)
			draw_arc(point, 15.0, 0.0, TAU, 32, Color(0.5, 0.9, 1.0, 0.8), 1.0)
			draw_line(point + Vector2(-4, 0), point + Vector2(4, 0), Color.WHITE)
			draw_line(point + Vector2(0, -4), point + Vector2(0, 4), Color.WHITE)
			var label := "%s hits" % target.hits
			draw_string(ThemeDB.fallback_font, point + Vector2(-18, 25), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _draw_shapes(node: Node) -> void:
	if node is CollisionShape2D and not node.disabled and node.shape != null:
		var transform: Transform2D = global_transform.affine_inverse() * node.global_transform
		draw_set_transform_matrix(transform)
		var color := Color(0.3, 1.0, 0.65, 0.85)
		if node.shape is CircleShape2D:
			draw_arc(Vector2.ZERO, node.shape.radius, 0.0, TAU, 48, color, 1.0)
		elif node.shape is RectangleShape2D:
			draw_rect(Rect2(-node.shape.size * 0.5, node.shape.size), color, false, 1.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for child in node.get_children():
		_draw_shapes(child)
