extends WeaponBase

const ORB_SCENE := preload("res://scenes/weapons/libram_orb.tscn")

var _angle: float = 0.0
var _orbs: Array[Node2D] = []


func _exit_tree() -> void:
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbs.clear()


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		for orb in _orbs:
			if is_instance_valid(orb):
				orb.visible = false
				orb.monitoring = false
		return
	_ensure_orbs()
	var spin := 2.4 if is_id(&"tome_of_the_lightbringer") else 1.8
	_angle += delta * spin
	var radius := current_area()
	var count := _orbs.size()
	for i in count:
		var orb := _orbs[i]
		if not is_instance_valid(orb):
			continue
		var ang := _angle + TAU * float(i) / float(maxi(count, 1))
		orb.global_position = global_position + Vector2.from_angle(ang) * radius
		orb.rotation = ang + PI * 0.5
		orb.hit_interval = current_cooldown()
		orb.linger = is_id(&"tome_of_the_lightbringer")


func _ensure_orbs() -> void:
	var want := projectile_count()
	if is_id(&"tome_of_the_lightbringer"):
		want += 2
	while _orbs.size() > want:
		var extra: Node2D = _orbs.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	while _orbs.size() < want:
		var orb := ORB_SCENE.instantiate()
		orb.damage = current_damage()
		orb.source = self
		orb.linger = is_id(&"tome_of_the_lightbringer")
		var host := entities()
		if host != null:
			host.add_child(orb)
		else:
			add_child(orb)
		_orbs.append(orb)
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.damage = current_damage()
			orb.source = self
