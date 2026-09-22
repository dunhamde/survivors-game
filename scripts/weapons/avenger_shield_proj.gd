extends Area2D

const ShieldTrail := preload("res://scripts/weapons/shield_trail.gd")

var speed: float = 210.0
var damage: int = 16
var lifetime: float = 2.8
var bounces: int = 2
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var source: WeaponBase
var radius: float = 9.0
var _ignore: Dictionary = {}
var _trail
var _glow: Sprite2D
var _glow_time := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_glow = Sprite2D.new()
	_glow.texture = WeaponArt.texture(&"shield_glow")
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_material
	add_child(_glow)
	var sprite := Sprite2D.new()
	sprite.texture = WeaponArt.texture(&"shield")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_trail = ShieldTrail.new()
	get_parent().add_child(_trail)
	_trail.record(global_position)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var desired := global_position.direction_to(target.global_position)
		direction = direction.lerp(desired, clampf(8.0 * delta, 0.0, 1.0)).normalized()
	elif source != null:
		var next := source.nearest_target(global_position, _ignore)
		if next != null:
			target = next
	global_position += direction * speed * delta
	_trail.record(global_position)
	rotation += delta * 8.0
	_glow_time += delta
	_glow.modulate.a = 0.78 + 0.1 * sin(_glow_time * 7.0)


func _exit_tree() -> void:
	if is_instance_valid(_trail):
		_trail.finish()


func _on_body_entered(body: Node2D) -> void:
	if _ignore.has(body) or not Hittable.is_target(body):
		return
	_ignore[body] = true
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	if bounces <= 0:
		queue_free()
		return
	bounces -= 1
	target = null
	if source != null:
		target = source.nearest_target(global_position, _ignore)
	if target == null:
		queue_free()
