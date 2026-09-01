extends WeaponBase

const SHIELD_SCENE := preload("res://scenes/weapons/avenger_shield_proj.tscn")


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var targets := nearest_targets(projectile_count(), 420.0)
	if targets.is_empty():
		return
	if player.has_method("play_attack"):
		player.play_attack(global_position.direction_to(targets[0].global_position))
	for target in targets:
		_throw(target)
	cooldown = current_cooldown()


func _throw(target: Node2D) -> void:
	var shield := SHIELD_SCENE.instantiate()
	shield.global_position = global_position
	shield.damage = current_damage()
	shield.speed = 210.0 + float(level) * 10.0
	shield.bounces = _bounce_count()
	shield.target = target
	shield.source = self
	shield.leave_puddle = is_id(&"truthguard")
	shield.radius = 8.0 + current_area() * 0.08
	var aim := global_position.direction_to(target.global_position)
	shield.direction = aim if aim != Vector2.ZERO else Vector2.RIGHT
	entities().add_child(shield)


func _bounce_count() -> int:
	if is_id(&"truthguard"):
		return 5
	return 2 + int((level - 1) / 2)
