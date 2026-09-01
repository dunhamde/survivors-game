extends WeaponBase


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var drops := _drop_count()
	var targets := densest_targets(drops)
	if targets.is_empty():
		return
	if player.has_method("play_attack"):
		player.play_attack(global_position.direction_to(targets[0].global_position))
	for target in targets:
		_drop(target.global_position)
	cooldown = current_cooldown()


func _drop_count() -> int:
	var n := projectile_count()
	if is_id(&"tyrs_deliverance"):
		n += 2
	return n


func _drop(at: Vector2) -> void:
	var pulses := 3 + int((level - 1) / 2)
	if is_id(&"tyrs_deliverance"):
		pulses += 1
	spawn_zone(at, current_area(), pulses, -1, {
		"show_hammer": true,
		"pulse_interval": 0.48,
	})
