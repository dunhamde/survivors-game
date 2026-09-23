extends Node2D

const DURATION := 0.22

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var life := 1.0 - _age / DURATION
	var radius := 5.0 + 15.0 * (1.0 - life)
	draw_circle(Vector2.ZERO, radius * 0.75, Color(0.2, 0.68, 1.0, 0.18 * life))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.46, 0.88, 1.0, 0.9 * life), 2.0, false)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var ray := Vector2.from_angle(angle)
		var side := ray.orthogonal()
		var start := ray * (radius * 0.5)
		var kink := ray * (radius * 0.8) + side * (3.0 if i % 2 == 0 else -3.0)
		var end := ray * (radius + 8.0 * life)
		var path := PackedVector2Array([start, kink, end])
		draw_polyline(path, Color(0.27, 0.7, 1.0, 0.7 * life), 3.0, false)
		draw_polyline(path, Color(0.96, 1.0, 1.0, life), 1.0, false)
