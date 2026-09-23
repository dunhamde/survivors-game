class_name UpgradePool
extends RefCounted

const HOLY := &"holy_strike"
const CONS := &"consecration"
const HAMMER := &"hammer_of_wrath"
const SHIELD := &"avenger_shield"
const STORM := &"divine_storm"
const JUDGEMENT := &"judgement"
const LIGHTS := &"lights_hammer"
const LIBRAM := &"libram_of_the_light"

const SEAL_COMMAND := &"seal_of_command"
const SEAL_RIGHTEOUS := &"seal_of_righteousness"
const INFUSION := &"infusion_of_light"
const BLESSING := &"blessing_of_kings"

const HOLY_DATA := preload("res://data/weapons/holy_strike.tres")
const CONS_DATA := preload("res://data/weapons/consecration.tres")
const HAMMER_DATA := preload("res://data/weapons/hammer_of_wrath.tres")
const SHIELD_DATA := preload("res://data/weapons/avenger_shield.tres")
const STORM_DATA := preload("res://data/weapons/divine_storm.tres")
const JUDGEMENT_DATA := preload("res://data/weapons/judgement.tres")
const LIGHTS_DATA := preload("res://data/weapons/lights_hammer.tres")
const LIBRAM_DATA := preload("res://data/weapons/libram_of_the_light.tres")


static func build_choices(controller: WeaponController, player: Node = null) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	_maybe_unlock(pool, controller, CONS, CONS_DATA)
	_maybe_unlock(pool, controller, HAMMER, HAMMER_DATA)
	_maybe_unlock(pool, controller, SHIELD, SHIELD_DATA)
	_maybe_unlock(pool, controller, STORM, STORM_DATA)
	_maybe_unlock(pool, controller, JUDGEMENT, JUDGEMENT_DATA)
	_maybe_unlock(pool, controller, LIGHTS, LIGHTS_DATA)
	_maybe_unlock(pool, controller, LIBRAM, LIBRAM_DATA)
	_maybe_upgrade(pool, controller, HOLY, HOLY_DATA)
	_maybe_upgrade(pool, controller, CONS, CONS_DATA)
	_maybe_upgrade(pool, controller, HAMMER, HAMMER_DATA)
	_maybe_upgrade(pool, controller, SHIELD, SHIELD_DATA)
	_maybe_upgrade(pool, controller, STORM, STORM_DATA)
	_maybe_upgrade(pool, controller, JUDGEMENT, JUDGEMENT_DATA)
	_maybe_upgrade(pool, controller, LIGHTS, LIGHTS_DATA)
	_maybe_upgrade(pool, controller, LIBRAM, LIBRAM_DATA)
	_maybe_seals(pool, player)
	pool.append_array(_stat_cards())
	pool.shuffle()
	var choices: Array[Dictionary] = []
	var used: Dictionary = {}
	_fill(choices, used, pool, 3)
	var fillers := _stat_cards()
	fillers.shuffle()
	_fill(choices, used, fillers, 3)
	while choices.size() < 3:
		choices.append(_blessing_card())
	return choices


static func apply(choice: Dictionary, player: Node, controller: WeaponController) -> void:
	var choice_id: String = str(choice.get("id", ""))
	var unlocks := {
		"unlock_consecration": CONS_DATA,
		"unlock_hammer_of_wrath": HAMMER_DATA,
		"unlock_avenger_shield": SHIELD_DATA,
		"unlock_divine_storm": STORM_DATA,
		"unlock_judgement": JUDGEMENT_DATA,
		"unlock_lights_hammer": LIGHTS_DATA,
		"unlock_libram_of_the_light": LIBRAM_DATA,
	}
	if unlocks.has(choice_id):
		controller.add_weapon(unlocks[choice_id])
		return
	var upgrades := {
		"upgrade_holy_strike": HOLY,
		"upgrade_consecration": CONS,
		"upgrade_hammer_of_wrath": HAMMER,
		"upgrade_avenger_shield": SHIELD,
		"upgrade_divine_storm": STORM,
		"upgrade_judgement": JUDGEMENT,
		"upgrade_lights_hammer": LIGHTS,
		"upgrade_libram_of_the_light": LIBRAM,
	}
	if upgrades.has(choice_id):
		controller.upgrade_weapon(upgrades[choice_id])
		return
	match choice_id:
		"seal_of_command", "seal_of_righteousness", "infusion_of_light":
			if player.has_method("add_seal"):
				player.add_seal(StringName(choice_id))
		"magnetism":
			if player.has_method("add_magnetism"):
				player.add_magnetism(32.0)
		_:
			if player.has_method("add_max_health"):
				player.add_max_health(15)
			if player.has_method("add_seal"):
				player.add_seal(BLESSING)


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


static func _maybe_seals(pool: Array[Dictionary], player: Node) -> void:
	if player == null or not player.has_method("has_seal"):
		return
	if not player.has_seal(SEAL_COMMAND):
		pool.append({
			"id": "seal_of_command",
			"title": "Seal of Command",
			"desc": "+1 projectile and slash count.",
		})
	if not player.has_seal(SEAL_RIGHTEOUS):
		pool.append({
			"id": "seal_of_righteousness",
			"title": "Seal of Righteousness",
			"desc": "+20% weapon area.",
		})
	if not player.has_seal(INFUSION):
		pool.append({
			"id": "infusion_of_light",
			"title": "Infusion of Light",
			"desc": "Abilities trigger 18% faster, except Shield and Hammer of Wrath.",
		})


static func _stat_cards() -> Array[Dictionary]:
	return [
		_blessing_card(),
		{
			"id": "magnetism",
			"title": "Magnetism",
			"desc": "+32 gold pickup range.",
		},
	]


static func _blessing_card() -> Dictionary:
	return {
		"id": "blessing_of_kings",
		"title": "Blessing of Kings",
		"desc": "+15 maximum health and heal.",
	}


static func _fill(choices: Array[Dictionary], used: Dictionary, source: Array[Dictionary], limit: int) -> void:
	for option in source:
		if choices.size() >= limit:
			return
		var option_id: String = str(option.get("id", ""))
		if option_id == "" or used.has(option_id):
			continue
		used[option_id] = true
		choices.append(option)
