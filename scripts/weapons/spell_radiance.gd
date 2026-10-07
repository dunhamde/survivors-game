class_name SpellRadiance
extends Node2D

## Bounded world-space trails and brief contact sparks shared by the new spells.
const TRAIL_LIFE := 0.24
const IMPACT_LIFE := 0.24
var follow: Node2D
var is_trail := false
var _age := 0.0
var _points: Array[Vector2] = []
var _ages: Array[float] = []


static func trail(owner_node: Node2D) -> SpellRadiance:
	var fx := SpellRadiance.new()
	fx.follow = owner_node
	fx.is_trail = true
	owner_node.get_parent().add_child(fx)
	fx.z_index = 5
	return fx


static func impact(host: Node, at: Vector2) -> void:
	var fx := SpellRadiance.new()
	host.add_child(fx)
	fx.global_position = at
	fx.z_index = 9


func _process(delta: float) -> void:
	_age += delta
	if is_trail:
		for i in range(_ages.size() - 1, -1, -1):
			_ages[i] += delta
			if _ages[i] >= TRAIL_LIFE:
				_ages.remove_at(i)
				_points.remove_at(i)
		if is_instance_valid(follow) and follow.is_visible_in_tree():
			var point := to_local(follow.global_position)
			if _points.is_empty() or _points[-1].distance_squared_to(point) >= 4.0:
				_points.append(point)
				_ages.append(0.0)
				if _points.size() > 24:
					_points.pop_front()
					_ages.pop_front()
		elif _points.is_empty():
			queue_free()
	elif _age >= IMPACT_LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if is_trail:
		for i in range(1, _points.size()):
			var life := 1.0 - _ages[i - 1] / TRAIL_LIFE
			draw_line(_points[i - 1], _points[i], Color(1.0, 0.72, 0.22, life * 0.16), 9.0 * life, true)
			draw_line(_points[i - 1], _points[i], Color(1.0, 0.94, 0.65, life * 0.6), maxf(1.0, 2.5 * life), false)
		return
	var u := clampf(_age / IMPACT_LIFE, 0.0, 1.0)
	var life := 1.0 - u
	var radius := 3.0 + u * 13.0
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.78, 0.3, life * 0.15))
	for i in 6:
		var ray := Vector2.from_angle(TAU * i / 6.0)
		draw_line(ray * radius * 0.6, ray * (radius + 5.0 * life), Color(1.0, 0.94, 0.7, life), 1.5, false)
	draw_circle(Vector2.ZERO, 3.0 * life, Color(1.0, 0.99, 0.9, life))
