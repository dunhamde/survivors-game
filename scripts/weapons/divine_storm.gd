extends WeaponBase

const SLASH_SCENE := preload("res://scenes/weapons/holy_slash.tscn")

var _spin: float = 0.0


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	_spin += delta * 5.2
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	_swing()
	cooldown = current_cooldown()


func _swing() -> void:
	var count := projectile_count()
	var radius := current_area()
	if player.has_method("play_attack"):
		player.play_attack(Vector2.from_angle(_spin))
	for i in count:
		var ang := _spin + TAU * float(i) / float(maxi(count, 1))
		var slash := SLASH_SCENE.instantiate()
		slash.global_position = global_position + Vector2.from_angle(ang) * radius * 0.58
		slash.rotation = ang
		slash.scale = Vector2.ONE * clampf(radius / 42.0, 0.85, 1.8)
		slash.damage = current_damage()
		slash.source = self
		entities().add_child(slash)
	if is_id(&"wake_of_ashes"):
		_wake()


func _wake() -> void:
	var radius := current_area()
	for target in Hittable.all_nodes(get_tree()):
		if global_position.distance_to(target.global_position) > radius:
			continue
		if target.has_method("apply_pull"):
			target.apply_pull(global_position, 150.0)
	spawn_zone(global_position, radius, 1, -1, {
		"show_hammer": false,
		"pull_strength": 40.0,
	})
