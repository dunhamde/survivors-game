extends Area2D

var speed: float = 280.0
var damage: int = 14
var lifetime: float = 0.7
var pierce: int = 2
var direction: Vector2 = Vector2.RIGHT
var source: WeaponBase
var _hit: Dictionary = {}


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = WeaponArt.texture(&"judgement")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 8)
	shape.shape = rect
	add_child(shape)
	var timer := get_tree().create_timer(lifetime, false)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit.has(body) or not Hittable.is_target(body):
		return
	_hit[body] = true
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	pierce -= 1
	if pierce < 0:
		queue_free()
