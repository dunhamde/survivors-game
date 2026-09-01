extends Area2D

var damage: int = 10
var radius: float = 36.0
var pulses_left: int = 3
var pulse_interval: float = 0.5
var source: WeaponBase
var knockback_strength: float = 0.0
var pull_strength: float = 0.0
var heal_amount: int = 0
var show_hammer: bool = false

var _wait: float = 1.0
var _started: bool = false
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
	add_child(_ring)
	if show_hammer:
		_hammer = Sprite2D.new()
		_hammer.texture = preload("res://assets/sprites/weapons/hammer.png")
		_hammer.position = Vector2(0.0, -10.0)
		add_child(_hammer)
	_apply_radius()
	_wait = 1.0
	call_deferred("_first_pulse")


func _first_pulse() -> void:
	if not is_instance_valid(self):
		return
	_started = true
	_pulse()
	pulses_left -= 1
	if pulses_left <= 0:
		_finish_soon()
	else:
		_wait = pulse_interval


func _physics_process(delta: float) -> void:
	if not _started:
		return
	_wait -= delta
	if _ring != null:
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		_ring.modulate.a = pulse
	if _wait > 0.0 or pulses_left <= 0:
		return
	_pulse()
	pulses_left -= 1
	if pulses_left <= 0:
		_finish_soon()
	else:
		_wait = pulse_interval


func _apply_radius() -> void:
	var circle := _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	if _ring != null:
		_ring.scale = Vector2.ONE * (radius / 28.0)


func _pulse() -> void:
	if _ring != null:
		_ring.modulate = Color(1.15, 1.0, 0.7, 1.0)
	var hit_any := false
	for body in get_overlapping_bodies():
		if not Hittable.is_target(body):
			continue
		if source != null:
			source.deal_to(body, damage)
		else:
			body.take_damage(damage)
		hit_any = true
		if knockback_strength > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(global_position, knockback_strength)
		if pull_strength > 0.0 and body.has_method("apply_pull"):
			body.apply_pull(global_position, pull_strength)
	if hit_any and heal_amount > 0 and source != null and source.player != null and source.player.has_method("heal"):
		source.player.heal(heal_amount)


func _finish_soon() -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var timer := tree.create_timer(0.22)
	timer.timeout.connect(queue_free)
