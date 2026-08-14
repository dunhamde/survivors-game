extends WeaponBase

const SLASH_SCENE := preload("res://scenes/weapons/holy_slash.tscn")


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var target := _nearest_in_range()
	if target == null:
		return
	_fire(target)
	cooldown = current_cooldown()


func _nearest_in_range() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	var reach := current_area()
	var reach_sq := reach * reach
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var dist := global_position.distance_squared_to((enemy as Node2D).global_position)
		if dist < best and dist <= reach_sq:
			best = dist
			nearest = enemy as Node2D
	return nearest


func _fire(target: Node2D) -> void:
	var slash := SLASH_SCENE.instantiate() as Area2D
	var direction := global_position.direction_to(target.global_position)
	slash.global_position = global_position + direction * 20.0
	slash.rotation = direction.angle()
	slash.damage = current_damage()
	slash.scale = Vector2.ONE * (current_area() / 80.0)
	entities().add_child(slash)
