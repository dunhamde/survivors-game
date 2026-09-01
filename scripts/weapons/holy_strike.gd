extends WeaponBase

const BOLT_SCENE := preload("res://scenes/weapons/holy_shock_bolt.tscn")


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var targets := nearest_targets(projectile_count(), current_area())
	if targets.is_empty():
		return
	var aim := global_position.direction_to(targets[0].global_position)
	if player.has_method("play_attack"):
		player.play_attack(aim if aim != Vector2.ZERO else Vector2.RIGHT)
	for target in targets:
		_cast_chain(target)
	cooldown = current_cooldown()


func _cast_chain(start: Node2D) -> void:
	var hops := 5 if is_id(&"beacon_of_light") else 1
	var exclude: Dictionary = {}
	var origin: Node2D = player
	var current := start
	while current != null and hops > 0:
		_spawn_bolt(origin, current)
		exclude[current] = true
		hops -= 1
		origin = current
		current = nearest_target(origin.global_position, exclude, current_area() * 1.2)


func _spawn_bolt(from_node: Node2D, target: Node2D) -> void:
	var from := _body_point(from_node)
	var to := _body_point(target)
	var direction := from.direction_to(to)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if from_node == player:
		from += direction * 12.0
	var bolt := BOLT_SCENE.instantiate()
	bolt.global_position = from
	bolt.end_global = to
	bolt.damage = current_damage()
	bolt.victim = target
	bolt.source = self
	entities().add_child(bolt)


func _body_point(node: Node2D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return global_position
	var sprite := node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite.global_position
	return node.global_position
