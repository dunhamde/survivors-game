extends WeaponBase

const BOLT_SCENE := preload("res://scenes/weapons/judgement_bolt.tscn")


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	if Hittable.all_nodes(get_tree()).is_empty():
		return
	var aim := facing_dir()
	if player.has_method("play_attack"):
		player.play_attack(aim)
	var count := projectile_count()
	for i in count:
		var spread := 0.0
		if count > 1:
			spread = deg_to_rad(14.0) * (float(i) - float(count - 1) * 0.5)
		_fire(aim.rotated(spread))
	cooldown = current_cooldown()


func _fire(direction: Vector2) -> void:
	var bolt := BOLT_SCENE.instantiate()
	bolt.global_position = global_position + direction * 14.0
	bolt.direction = direction
	bolt.damage = current_damage()
	bolt.speed = 280.0 + float(level) * 12.0
	bolt.pierce = 99 if is_id(&"greater_judgement") else 1 + level
	bolt.explode = is_id(&"greater_judgement")
	bolt.explode_radius = current_area()
	bolt.source = self
	entities().add_child(bolt)
