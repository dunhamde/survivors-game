extends Node2D

const DURATION := 0.38
const SAMPLE_DISTANCE_SQUARED := 16.0

var _points: Array[Vector2] = []
var _ages: Array[float] = []
var _finished := false
var _time := 0.0


func _ready() -> void:
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
	_time += delta
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
	if _points.size() < 2:
		return
	var tick := floori(_time * 20.0)
	for i in range(1, _points.size()):
		var life := 1.0 - (_ages[i - 1] + _ages[i]) * 0.5 / DURATION
		var start := _points[i - 1]
		var end := _points[i]
		var normal := (end - start).normalized().orthogonal()
		var mid := (start + end) * 0.5 + normal * float(((i * 7 + tick * 3) % 7) - 3)
		var path := PackedVector2Array([start, mid, end])
		draw_polyline(path, Color(0.12, 0.46, 1.0, 0.24 * life), 12.0 * life + 1.0, false)
		draw_polyline(path, Color(0.3, 0.79, 1.0, 0.7 * life), 4.0 * life + 1.0, false)
		draw_polyline(path, Color(0.91, 0.99, 1.0, 0.95 * life), 1.5, false)
		if (i + tick) % 3 == 0:
			var branch := mid + normal * (8.0 + 7.0 * life)
			draw_line(mid, branch, Color(0.4, 0.84, 1.0, 0.65 * life), 2.0, false)
			draw_line(mid, branch, Color(0.94, 1.0, 1.0, 0.85 * life), 1.0, false)
