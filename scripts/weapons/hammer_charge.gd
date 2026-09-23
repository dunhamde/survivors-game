extends Node2D

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Three broken arcs crawl around the leading head. Their joints jump in
	# discrete steps so the effect reads as electricity at pixel-art scale.
	var tick := floori(_time * 18.0)
	var pulse := 0.75 + 0.25 * sin(_time * 16.0)
	var arcs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(2, -13), Vector2(5, -16 + tick % 3), Vector2(8, -13), Vector2(11, -16), Vector2(15, -10)]),
		PackedVector2Array([Vector2(13, -7), Vector2(17, -5 + tick % 3), Vector2(14, -2), Vector2(18, 1), Vector2(14, 5)]),
		PackedVector2Array([Vector2(3, 13), Vector2(6, 16 - tick % 3), Vector2(9, 13), Vector2(12, 16), Vector2(15, 10)]),
	]
	for arc in arcs:
		draw_polyline(arc, Color(0.16, 0.56, 1.0, 0.55 * pulse), 5.0, false)
		draw_polyline(arc, Color(0.42, 0.87, 1.0, 0.9 * pulse), 2.0, false)
		draw_polyline(arc, Color(0.94, 1.0, 1.0, pulse), 1.0, false)
	var spark := Vector2(16 + tick % 3, -10 + tick % 5)
	draw_line(spark + Vector2(-2, 0), spark + Vector2(2, 0), Color(0.8, 0.98, 1.0, pulse), 1.0, false)
	draw_line(spark + Vector2(0, -2), spark + Vector2(0, 2), Color(0.8, 0.98, 1.0, pulse), 1.0, false)
