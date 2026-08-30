extends Area2D

var damage: int = 18
var source: WeaponBase
var _hit: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_hit_overlaps")
	var timer := get_tree().create_timer(0.16)
	timer.timeout.connect(queue_free)


func _hit_overlaps() -> void:
	if not is_instance_valid(self):
		return
	for body in get_overlapping_bodies():
		_try_hit(body)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if _hit.has(body):
		return
	if body.is_in_group("enemies"):
		_hit[body] = true
		if source != null:
			source.deal_to(body, damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
