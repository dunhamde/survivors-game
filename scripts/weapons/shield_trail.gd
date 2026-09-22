extends Node2D

const DURATION := 0.52
const SAMPLE_DISTANCE_SQUARED := 4.0

var _points: Array[Vector2] = []
var _ages: Array[float] = []
var _finished := false


func _ready() -> void:
	# Draw behind the spinning shield, but above the ground layer.
	z_index = -1


func record(world_position: Vector2) -> void:
	var point := to_local(world_position)
	if not _points.is_empty() and _points[-1].distance_squared_to(point) < SAMPLE_DISTANCE_SQUARED:
		return
	_points.append(point)
	_ages.append(0.0)
	queue_redraw()


func finish() -> void:
	_finished = true
	if _points.is_empty():
		queue_free()


func _process(delta: float) -> void:
	for i in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta
		if _ages[i] >= DURATION:
			_ages.remove_at(i)
			_points.remove_at(i)
	if _finished and _points.is_empty():
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	_draw_layer(Color(1.0, 0.65, 0.2), 19.5, 0.2)
	_draw_layer(Color(1.0, 0.9, 0.55), 10.5, 0.55)
	_draw_layer(Color(1.0, 0.99, 0.9), 4.5, 0.95)


func _draw_layer(tint: Color, width: float, opacity: float) -> void:
	for i in range(1, _points.size()):
		var life := 1.0 - (_ages[i - 1] + _ages[i]) * 0.5 / DURATION
		var color := Color(tint.r, tint.g, tint.b, opacity * life * life)
		draw_line(_points[i - 1], _points[i], color, maxf(1.0, width * life), false)
