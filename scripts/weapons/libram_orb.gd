extends Area2D

var damage: int = 10
var source: WeaponBase
var hit_interval: float = 0.45
var _hit_cd: Dictionary = {}
var _visual_time := 0.0
var _flash := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)
	var glow := Sprite2D.new()
	glow.texture = WeaponArt.texture(&"radiance")
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.scale = Vector2.ONE * 0.7
	add_child(glow)
	_sprite = Sprite2D.new()
	_sprite.texture = WeaponArt.texture(&"libram")
	add_child(_sprite)
	SpellRadiance.trail(self)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	_visual_time += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	_sprite.position.y = sin(_visual_time * 4.0) * 1.5
	_sprite.modulate = Color(1.0 + _flash * 0.6, 1.0 + _flash * 0.4, 1.0)
	queue_redraw()
	var expired: Array = []
	for key in _hit_cd.keys():
		_hit_cd[key] = float(_hit_cd[key]) - delta
		if float(_hit_cd[key]) <= 0.0:
			expired.append(key)
	for key in expired:
		_hit_cd.erase(key)
	for body in get_overlapping_bodies():
		_try_hit(body)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not Hittable.is_target(body):
		return
	var key := body.get_instance_id()
	if _hit_cd.has(key):
		return
	_hit_cd[key] = hit_interval
	_flash = 1.0
	SpellRadiance.impact(get_parent(), global_position)
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)


func _draw() -> void:
	# Sparse drifting scripture motes rather than a solid orbit band.
	for i in 3:
		var phase := fmod(_visual_time * 0.65 + float(i) / 3.0, 1.0)
		var at := Vector2(sin(float(i) * 2.4) * 9.0, -5.0 - phase * 15.0)
		var alpha := sin(phase * PI) * 0.7
		draw_line(at - Vector2(2, 0), at + Vector2(2, 0), Color(1.0, 0.91, 0.58, alpha), 1.0)
		draw_line(at - Vector2(0, 2), at + Vector2(0, 2), Color(1.0, 0.98, 0.8, alpha), 1.0)
