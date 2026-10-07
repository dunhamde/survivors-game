extends Node2D

signal boss_spawned(boss: Node)
signal enemy_killed

@export var enemy_scene: PackedScene
@export var troll_scene: PackedScene
@export var hogger_scene: PackedScene
@export var skeleton_data: EnemyData
@export var grunt_data: EnemyData
@export var troll_data: EnemyData
@export var ogre_data: EnemyData
@export var hogger_data: EnemyData
@export var chest_scene: PackedScene
@export var spawn_radius: float = 430.0
@export var hogger_time: float = ElwynnBeats.HOGGER_AT
@export var chest_interval: float = 36.0
@export var chest_max: int = 2

var elapsed: float = 0.0
var hogger_spawned: bool = false
var _cooldowns: Dictionary = {"skeleton": 0.0, "grunt": 0.0, "troll": 0.0, "ogre": 0.0, "chest": 18.0}
var _alive: int = 0
var _cleanup_timer: float = 0.0
var _spawn_order: int = 0


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	if "alive" in player and not player.alive:
		return

	elapsed += delta
	_alive = get_tree().get_nodes_in_group("enemies").size()
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = 2.0
		_recycle_distant_enemies(player)
	_tick_spawns(delta, player)

	if elapsed >= hogger_time and not hogger_spawned:
		_spawn_hogger(player)


func _tick_spawns(delta: float, player: Node2D) -> void:
	var cap := _alive_cap()
	var stage: Array = ElwynnBeats.STAGES[ElwynnBeats.stage_index(elapsed)]
	var pressure := ElwynnBeats.pressure(elapsed)
	if hogger_spawned:
		pressure *= 0.55
	var late := clampf((elapsed - ElwynnBeats.OGRES_AT) / 480.0, 0.0, 1.0)
	var families := [
		["skeleton", skeleton_data, int(stage[2]), float(stage[3]), 0.0, enemy_scene],
		["grunt", grunt_data, 2 + roundi(late * 4.0), lerpf(2.4, 0.8, late), ElwynnBeats.GRUNTS_AT, enemy_scene],
		["troll", troll_data, 1 + roundi(late * 2.0), lerpf(3.4, 1.6, late), ElwynnBeats.TROLLS_AT, troll_scene],
		["ogre", ogre_data, 1 + roundi(late * 2.0), lerpf(3.0, 1.5, late), ElwynnBeats.OGRES_AT, enemy_scene],
	]
	# Rotate who claims the next free crowd slot. Skeletons must not starve
	# every heavier family simply because they were checked first.
	for i in families.size():
		var family: Array = families[(i + _spawn_order) % families.size()]
		if elapsed < float(family[4]):
			continue
		var id: String = family[0]
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if float(_cooldowns[id]) <= 0.0:
			_spawn_pack(player, family[1], int(family[2]), cap, family[5])
			_cooldowns[id] = float(family[3]) / pressure
	_spawn_order = (_spawn_order + 1) % families.size()

	_cooldowns["chest"] = float(_cooldowns["chest"]) - delta
	if float(_cooldowns["chest"]) <= 0.0:
		if _chest_count() < chest_max:
			_spawn_chest(player, spawn_radius)
		_cooldowns["chest"] = chest_interval


func _alive_cap() -> int:
	return ElwynnBeats.crowd_cap(elapsed)


func _recycle_distant_enemies(player: Node2D) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_in_group("boss"):
			continue
		if enemy.global_position.distance_squared_to(player.global_position) > 1200.0 * 1200.0:
			# Despawning distant stragglers awards neither kills nor XP.
			enemy.remove_from_group("enemies")
			enemy.queue_free()
			_alive = maxi(0, _alive - 1)


func spawnable_catalog() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for raw in [skeleton_data, grunt_data, troll_data, ogre_data, hogger_data]:
		var data := raw as EnemyData
		if data == null:
			continue
		var label: String = data.display_name
		if label.is_empty():
			label = String(data.id)
		items.append({"id": data.id, "name": label})
	items.append({"id": &"chest", "name": "Chest"})
	return items


func spawn_debug(id: StringName) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	if id == &"chest":
		_spawn_chest(player, 200.0)
		return
	var is_hogger := hogger_data != null and hogger_data.id == id
	if is_hogger and hogger_spawned:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ElwynnBeats.HARD_CAP:
		return
	var is_troll := troll_data != null and troll_data.id == id
	var scene := hogger_scene if is_hogger else (troll_scene if is_troll else enemy_scene)
	var data := hogger_data if is_hogger else _data_by_id(id)
	if scene == null or data == null:
		return
	var enemy := scene.instantiate() as Enemy
	var desired := player.global_position + Vector2.from_angle(randf() * TAU) * 200.0
	enemy.global_position = _snap_spawn(parent, desired)
	parent.add_child(enemy)
	enemy.apply_data(data)
	enemy.health = enemy.max_health
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if is_hogger:
		hogger_spawned = true
		boss_spawned.emit(enemy)


func _data_by_id(id: StringName) -> EnemyData:
	for raw in [skeleton_data, grunt_data, troll_data, ogre_data]:
		var data := raw as EnemyData
		if data != null and data.id == id:
			return data
	return null


func _spawn_pack(player: Node2D, data: EnemyData, count: int, cap: int, scene: PackedScene = null) -> void:
	if scene == null:
		scene = enemy_scene
	if data == null or scene == null:
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var base_angle := randf() * TAU
	for i in count:
		if _alive >= mini(cap, ElwynnBeats.HARD_CAP):
			return
		var enemy := scene.instantiate() as Enemy
		# Alternate surrounding packs and a directional front, leaving escape
		# routes instead of packing every batch onto one point.
		var spread := TAU if ElwynnBeats.pressure(elapsed) <= 1.0 else 1.3
		var angle := base_angle + (float(i) / maxf(1.0, float(count))) * spread + randf_range(-0.12, 0.12)
		var dist := spawn_radius + randf_range(-18.0, 24.0)
		var desired := player.global_position + Vector2.from_angle(angle) * dist
		enemy.global_position = _snap_spawn(parent, desired)
		parent.add_child(enemy)
		enemy.apply_data(data)
		enemy.max_health = roundi(float(enemy.max_health) * ElwynnBeats.health_multiplier(elapsed))
		enemy.health = enemy.max_health
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
		_alive += 1


func _spawn_hogger(player: Node2D) -> void:
	if hogger_spawned or hogger_scene == null or hogger_data == null:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ElwynnBeats.HARD_CAP:
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var hogger := hogger_scene.instantiate() as Enemy
	hogger.global_position = _snap_spawn(parent, player.global_position + Vector2.RIGHT * spawn_radius)
	parent.add_child(hogger)
	hogger.apply_data(hogger_data)
	hogger.health = hogger.max_health
	if not hogger.died.is_connected(_on_enemy_died):
		hogger.died.connect(_on_enemy_died)
	hogger_spawned = true
	boss_spawned.emit(hogger)


func _chest_count() -> int:
	return get_tree().get_nodes_in_group("chests").size()


func _spawn_chest(player: Node2D, distance: float) -> void:
	if chest_scene == null:
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var chest := chest_scene.instantiate() as Node2D
	var angle := randf() * TAU
	var dist := distance + randf_range(-18.0, 24.0)
	var desired := player.global_position + Vector2.from_angle(angle) * dist
	chest.global_position = _snap_spawn(parent, desired)
	parent.add_child(chest)


func _snap_spawn(map: Node, desired: Vector2) -> Vector2:
	if map != null and map.has_method("snap_to_walkable"):
		return map.snap_to_walkable(desired)
	return desired


func _on_enemy_died() -> void:
	enemy_killed.emit()
