extends Area2D

var speed: float = 240.0
var damage: int = 28
var lifetime: float = 2.6
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var source: WeaponBase


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var desired := global_position.direction_to(target.global_position)
		direction = direction.lerp(desired, clampf(7.0 * delta, 0.0, 1.0)).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if not Hittable.is_target(body):
		return
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	queue_free()
