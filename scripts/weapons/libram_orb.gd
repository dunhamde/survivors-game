extends Area2D

var damage: int = 10
var source: WeaponBase
var hit_interval: float = 0.45
var linger: bool = false
var _hit_cd: Dictionary = {}
var _linger_cd: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = WeaponArt.texture(&"libram")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	_linger_cd = maxf(0.0, _linger_cd - delta)
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
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	if linger and source != null and _linger_cd <= 0.0:
		_linger_cd = 0.35
		source.spawn_zone(global_position, 22.0, 1, -1, {"show_hammer": false})
