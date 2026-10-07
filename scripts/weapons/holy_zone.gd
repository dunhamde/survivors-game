extends Area2D

var damage: int = 10
var radius: float = 36.0
var pulses_left: int = 3
var pulse_interval: float = 0.5
var source: WeaponBase
var show_hammer: bool = false

var _wait := 0.0
var _started := false
var _finishing := false
var _fade := 1.0
var _visual_time := 0.0
var _pulse_age := 0.0
var _ring: Sprite2D
var _hammer: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	z_index = -4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	_ring = Sprite2D.new()
	_ring.texture = WeaponArt.texture(&"ring")
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ring.scale = Vector2.ONE * (radius / 28.0)
	_ring.visible = false
	add_child(_ring)
	if show_hammer:
		_hammer = Sprite2D.new()
		_hammer.texture = WeaponArt.texture(&"ground_hammer")
		_hammer.position = Vector2(0.0, -17.0)
		_hammer.z_as_relative = false
		_hammer.z_index = 3
		_hammer.visible = false
		add_child(_hammer)
	# Let the physics server register bodies before the first damage tick.
	await get_tree().physics_frame
	_first_pulse.call_deferred()


func _first_pulse() -> void:
	_started = true
	_ring.visible = true
	if _hammer != null:
		_hammer.visible = true
		# No victim: the zone owns all damage, without an extra bolt hit.
		var bolt = load("res://scenes/weapons/holy_shock_bolt.tscn").instantiate()
		bolt.position = get_parent().to_local(global_position + Vector2(-18.0, -190.0))
		bolt.end_global = global_position
		get_parent().add_child(bolt)
	_pulse()
	pulses_left -= 1
	_wait = pulse_interval
	if pulses_left <= 0:
		_finishing = true


func _physics_process(delta: float) -> void:
	if not _started:
		return
	_visual_time += delta
	_pulse_age += delta
	if _finishing:
		_fade = maxf(0.0, _fade - delta / 0.22)
		modulate.a = _fade
		if _fade <= 0.0:
			queue_free()
	else:
		_wait -= delta
		if _wait <= 0.0:
			_pulse()
			pulses_left -= 1
			_wait += pulse_interval
			if pulses_left <= 0:
				_finishing = true
	_ring.modulate.a = 0.3 + 0.2 * exp(-_pulse_age * 8.0)
	queue_redraw()


func _pulse() -> void:
	_pulse_age = 0.0
	for body in get_overlapping_bodies():
		if not Hittable.is_target(body):
			continue
		if is_instance_valid(source):
			source.deal_to(body, damage)
		else:
			body.take_damage(damage)


func _draw() -> void:
	if not _started:
		return
	var energy := exp(-_pulse_age * 9.0)
	# The bright outer line follows the actual circular damage boundary.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.81, 0.38, 0.45 + energy * 0.3), 1.0, false)
	draw_arc(Vector2.ZERO, radius * 0.88, 0.0, TAU, 64, Color(1.0, 0.95, 0.7, 0.2), 1.0, false)
	for i in 8:
		var ray := Vector2.from_angle(TAU * i / 8.0)
		var side := ray.orthogonal()
		var at := ray * radius * 0.94
		var rune := Color(1.0, 0.93, 0.61, 0.5 + energy * 0.3)
		draw_line(at - ray * 2.5, at + ray * 2.5, rune, 1.0)
		draw_line(at - side * 2.0, at + side * 2.0, rune, 1.0)
		var phase := fmod(_visual_time * 0.8 + float(i) / 8.0, 1.0)
		var mote := ray * radius * (0.3 + phase * 0.45) + Vector2(0, -phase * 7.0)
		draw_rect(Rect2(mote, Vector2.ONE * 1.5), Color(1.0, 0.9, 0.5, sin(phase * PI) * 0.65))
	if _pulse_age < 0.35:
		var wave := clampf(_pulse_age / 0.35, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * wave, 0.0, TAU, 48, Color(1.0, 0.97, 0.78, (1.0 - wave) * 0.8), 2.0, false)
	if show_hammer:
		var shadow := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			shadow.append(Vector2(cos(a) * 10.0, sin(a) * 3.5 + 1.0))
		draw_colored_polygon(shadow, Color(0.12, 0.1, 0.08, 0.5))
