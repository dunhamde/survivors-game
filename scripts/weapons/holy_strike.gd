extends WeaponBase

const BOLT_SCENE := preload("res://scenes/weapons/holy_shock_bolt.tscn")


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
	var from := _body_point(player)
	var to := _body_point(target)
	var direction := from.direction_to(to)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if player.has_method("play_attack"):
		player.play_attack(direction)
	from += direction * 12.0
	var bolt := BOLT_SCENE.instantiate()
	bolt.global_position = from
	bolt.end_global = to
	bolt.damage = current_damage()
	bolt.victim = target
	entities().add_child(bolt)


func _body_point(node: Node2D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return global_position
	var sprite := node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite.global_position
	return node.global_position
