class_name WeaponController
extends Node2D

@export var starting_weapon: WeaponData

var weapons: Dictionary = {}


func _ready() -> void:
	if starting_weapon != null:
		add_weapon(starting_weapon)


func add_weapon(weapon_data: WeaponData) -> void:
	if weapon_data == null or weapons.has(weapon_data.id):
		return
	var instance := weapon_data.scene.instantiate() as WeaponBase
	add_child(instance)
	instance.setup(weapon_data, get_parent() as CharacterBody2D)
	weapons[weapon_data.id] = instance


func upgrade_weapon(weapon_id: StringName) -> bool:
	if not weapons.has(weapon_id):
		return false
	var weapon: WeaponBase = weapons[weapon_id]
	if weapon.level >= weapon.data.max_level:
		return false
	weapon.level += 1
	return true


func has_weapon(weapon_id: StringName) -> bool:
	return weapons.has(weapon_id)


func get_weapon(weapon_id: StringName) -> WeaponBase:
	return weapons.get(weapon_id)


func is_maxed(weapon_id: StringName) -> bool:
	if not weapons.has(weapon_id):
		return false
	var weapon: WeaponBase = weapons[weapon_id]
	return weapon.level >= weapon.data.max_level


func damage_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for weapon_id in weapons:
		var weapon: WeaponBase = weapons[weapon_id]
		var display := String(weapon_id)
		if weapon.data != null and weapon.data.display_name != "":
			display = weapon.data.display_name
		rows.append({
			"id": weapon_id,
			"name": display,
			"damage": weapon.damage_dealt,
			"level": weapon.level,
		})
	return rows
