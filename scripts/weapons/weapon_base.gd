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


func current_damage() -> int:
	return int(data.base_damage + data.damage_per_level * float(level - 1))


func current_cooldown() -> float:
	return maxf(0.12, data.base_cooldown + data.cooldown_per_level * float(level - 1))


func current_area() -> float:
	return data.base_area + data.area_per_level * float(level - 1)


func projectile_count() -> int:
	return data.base_count + int((level - 1) / 2)


func is_player_alive() -> bool:
	return player != null and is_instance_valid(player) and player.alive


func entities() -> Node:
	var node := get_tree().get_first_node_in_group("entities")
	return node if node != null else get_tree().current_scene
