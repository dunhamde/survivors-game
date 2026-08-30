extends WeaponBase

const HAMMER_SCENE := preload("res://scenes/weapons/hammer_projectile.tscn")


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var targets := _pick_targets(projectile_count())
	if targets.is_empty():
		return
	for target in targets:
		_spawn(target)
	cooldown = current_cooldown()


func _pick_targets(count: int) -> Array[Node2D]:
	var enemies: Array = Hittable.all_nodes(get_tree())
	if enemies.is_empty():
		return []
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		var ha := 1.0
		var hb := 1.0
		if a.has_method("health_ratio"):
			ha = a.health_ratio()
		if b.has_method("health_ratio"):
			hb = b.health_ratio()
		if absf(ha - hb) > 0.001:
			return ha < hb
		var da := global_position.distance_squared_to((a as Node2D).global_position)
		var db := global_position.distance_squared_to((b as Node2D).global_position)
		return da > db
	)
	var result: Array[Node2D] = []
	for i in count:
		result.append(enemies[i % enemies.size()] as Node2D)
	return result


func _spawn(target: Node2D) -> void:
	var hammer := HAMMER_SCENE.instantiate() as Area2D
	hammer.global_position = global_position
	hammer.damage = current_damage()
	hammer.speed = 240.0 + float(level) * 12.0
	hammer.target = target
	var aim := global_position.direction_to(target.global_position)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	hammer.direction = aim
	entities().add_child(hammer)
