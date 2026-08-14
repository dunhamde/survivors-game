class_name UpgradePool
extends RefCounted

const HOLY := &"holy_strike"
const CONS := &"consecration"
const HAMMER := &"hammer_of_wrath"

const HOLY_DATA := preload("res://data/weapons/holy_strike.tres")
const CONS_DATA := preload("res://data/weapons/consecration.tres")
const HAMMER_DATA := preload("res://data/weapons/hammer_of_wrath.tres")


static func build_choices(controller: WeaponController) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	_maybe_unlock(pool, controller, CONS, CONS_DATA)
	_maybe_unlock(pool, controller, HAMMER, HAMMER_DATA)
	_maybe_upgrade(pool, controller, HOLY, HOLY_DATA)
	_maybe_upgrade(pool, controller, CONS, CONS_DATA)
	_maybe_upgrade(pool, controller, HAMMER, HAMMER_DATA)
	pool.shuffle()
	var choices: Array[Dictionary] = []
	var used: Dictionary = {}
	for option in pool:
		if used.has(option.id):
			continue
		used[option.id] = true
		choices.append(option)
		if choices.size() >= 3:
			break
	while choices.size() < 3:
		choices.append(_blessing_card())
	return choices


static func apply(choice: Dictionary, player: Node, controller: WeaponController) -> void:
	var choice_id: String = str(choice.get("id", ""))
	match choice_id:
		"unlock_consecration":
			controller.add_weapon(CONS_DATA)
		"unlock_hammer_of_wrath":
			controller.add_weapon(HAMMER_DATA)
		"upgrade_holy_strike":
			controller.upgrade_weapon(HOLY)
		"upgrade_consecration":
			controller.upgrade_weapon(CONS)
		"upgrade_hammer_of_wrath":
			controller.upgrade_weapon(HAMMER)
		_:
			if player.has_method("add_max_health"):
				player.add_max_health(15)


static func _maybe_unlock(pool: Array[Dictionary], controller: WeaponController, weapon_id: StringName, data: WeaponData) -> void:
	if controller.has_weapon(weapon_id):
		return
	pool.append({
		"id": "unlock_%s" % String(weapon_id),
		"title": data.display_name,
		"desc": data.description,
	})


static func _maybe_upgrade(pool: Array[Dictionary], controller: WeaponController, weapon_id: StringName, data: WeaponData) -> void:
	if not controller.has_weapon(weapon_id) or controller.is_maxed(weapon_id):
		return
	var weapon := controller.get_weapon(weapon_id)
	pool.append({
		"id": "upgrade_%s" % String(weapon_id),
		"title": "%s Lv.%d" % [data.display_name, weapon.level + 1],
		"desc": data.upgrade_hint,
	})


static func _blessing_card() -> Dictionary:
	return {
		"id": "blessing_of_kings",
		"title": "Blessing of Kings",
		"desc": "+15 maximum health and heal.",
	}
