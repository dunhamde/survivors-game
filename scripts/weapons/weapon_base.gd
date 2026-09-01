class_name WeaponBase
extends Node2D

var data: WeaponData
var level: int = 1
var player: CharacterBody2D
var cooldown: float = 0.0
var damage_dealt: int = 0


func setup(p_data: WeaponData, p_player: CharacterBody2D) -> void:
	data = p_data
	player = p_player


func record_damage(amount: int) -> void:
	if amount > 0:
		damage_dealt += amount


func deal_to(target: Node, amount: int) -> int:
	if not Hittable.is_target(target):
		return 0
	var dealt: Variant = target.take_damage(amount)
	var applied := amount if typeof(dealt) != TYPE_INT else int(dealt)
	record_damage(applied)
	return applied


func weapon_id() -> StringName:
	return data.id if data != null else &""


func is_id(id_value: StringName) -> bool:
	return data != null and data.id == id_value


func current_damage() -> int:
	return int(data.base_damage + data.damage_per_level * float(level - 1))


func current_cooldown() -> float:
	var wait := data.base_cooldown + data.cooldown_per_level * float(level - 1)
	return maxf(0.12, wait * _cooldown_mult())


func current_area() -> float:
	return (data.base_area + data.area_per_level * float(level - 1)) * _area_mult()


func projectile_count() -> int:
	return maxi(1, data.base_count + int((level - 1) / 2) + _command_bonus())


func facing_dir() -> Vector2:
	if player != null and "facing" in player:
		var aim: Vector2 = player.facing
		if aim.length_squared() > 0.0001:
			return aim.normalized()
	return Vector2.RIGHT


func nearest_target(origin: Vector2, exclude: Dictionary = {}, reach: float = INF) -> Node2D:
	var nearest: Node2D = null
	var best := INF
	var reach_sq := reach * reach
	for target in Hittable.all_nodes(get_tree()):
		if exclude.has(target):
			continue
		var dist := origin.distance_squared_to(target.global_position)
		if dist < best and dist <= reach_sq:
			best = dist
			nearest = target
	return nearest


func nearest_targets(count: int, reach: float = INF) -> Array[Node2D]:
	var picked: Array[Node2D] = []
	var exclude: Dictionary = {}
	for _i in count:
		var next := nearest_target(global_position, exclude, reach)
		if next == null:
			break
		picked.append(next)
		exclude[next] = true
	return picked


func densest_targets(count: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = Hittable.all_nodes(get_tree())
	if enemies.is_empty():
		return []
	var scored: Array[Dictionary] = []
	var neighbor_r := 56.0 * 56.0
	for enemy in enemies:
		var neighbors := 0
		for other in enemies:
			if other == enemy:
				continue
			if enemy.global_position.distance_squared_to(other.global_position) <= neighbor_r:
				neighbors += 1
		scored.append({"node": enemy, "score": neighbors, "dist": global_position.distance_squared_to(enemy.global_position)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return float(a.dist) < float(b.dist)
	)
	var result: Array[Node2D] = []
	for row in scored:
		result.append(row.node as Node2D)
		if result.size() >= count:
			break
	return result


func spawn_zone(at: Vector2, radius: float, pulses: int, p_damage: int = -1, extras: Dictionary = {}) -> Node:
	var zone := preload("res://scenes/weapons/holy_zone.tscn").instantiate()
	zone.global_position = at
	zone.damage = current_damage() if p_damage < 0 else p_damage
	zone.radius = radius
	zone.pulses_left = maxi(1, pulses)
	zone.source = self
	for key in extras:
		zone.set(key, extras[key])
	var host := entities()
	if host != null:
		host.add_child(zone)
	else:
		add_child(zone)
	return zone


func _command_bonus() -> int:
	if player != null and "command_bonus" in player:
		return int(player.command_bonus)
	return 0


func _area_mult() -> float:
	if player != null and "area_mult" in player:
		return maxf(0.2, float(player.area_mult))
	return 1.0


func _cooldown_mult() -> float:
	if player != null and "cooldown_mult" in player:
		return maxf(0.2, float(player.cooldown_mult))
	return 1.0


func is_player_alive() -> bool:
	return player != null and is_instance_valid(player) and player.alive


func entities() -> Node:
	var node := get_tree().get_first_node_in_group("entities")
	return node if node != null else get_tree().current_scene
