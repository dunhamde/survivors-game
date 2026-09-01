extends Area2D

var speed: float = 210.0
var damage: int = 16
var lifetime: float = 2.8
var bounces: int = 2
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var source: WeaponBase
var leave_puddle: bool = false
var radius: float = 9.0
var _ignore: Dictionary = {}


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = WeaponArt.texture(&"shield")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
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
	rotation += delta * 8.0


func _on_body_entered(body: Node2D) -> void:
	if _ignore.has(body) or not Hittable.is_target(body):
		return
	_ignore[body] = true
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	if bounces <= 0:
		_finish(true)
		return
	bounces -= 1
	target = null
	if source != null:
		target = source.nearest_target(global_position, _ignore)
	if target == null:
		_finish(leave_puddle)


func _finish(drop_puddle: bool) -> void:
	if drop_puddle and source != null:
		source.spawn_zone(global_position, 34.0, 3, -1, {
			"show_hammer": false,
			"pulse_interval": 0.4,
		})
	queue_free()
