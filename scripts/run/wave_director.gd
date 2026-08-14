extends Node2D

signal boss_spawned(boss: Node)
signal enemy_killed

@export var enemy_scene: PackedScene
@export var hogger_scene: PackedScene
@export var gnoll_data: EnemyData
@export var kobold_data: EnemyData
@export var murloc_data: EnemyData
@export var hogger_data: EnemyData
@export var spawn_radius: float = 430.0
@export var hogger_time: float = ElwynnBeats.HOGGER_AT

var elapsed: float = 0.0
var hogger_spawned: bool = false
var _cooldowns: Dictionary = {"gnoll": 0.0, "kobold": 0.0, "murloc": 0.0}


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	if "alive" in player and not player.alive:
		return

	elapsed += delta
	_tick_spawns(delta, player)

	if elapsed >= hogger_time and not hogger_spawned:
		hogger_spawned = true
		_spawn_hogger(player)


func _tick_spawns(delta: float, player: Node2D) -> void:
	var cap := _alive_cap()
	_cooldowns["gnoll"] = float(_cooldowns["gnoll"]) - delta
	if float(_cooldowns["gnoll"]) <= 0.0:
		_spawn_pack(player, gnoll_data, 1, cap)
		_cooldowns["gnoll"] = _gnoll_interval()

	if elapsed >= 90.0:
		_cooldowns["kobold"] = float(_cooldowns["kobold"]) - delta
		if float(_cooldowns["kobold"]) <= 0.0:
			_spawn_pack(player, kobold_data, 4, cap)
			_cooldowns["kobold"] = _kobold_interval()

	if elapsed >= 180.0:
		_cooldowns["murloc"] = float(_cooldowns["murloc"]) - delta
		if float(_cooldowns["murloc"]) <= 0.0:
			_spawn_pack(player, murloc_data, 5, cap)
			_cooldowns["murloc"] = _murloc_interval()


func _alive_cap() -> int:
	if elapsed >= hogger_time:
		return 48
	if elapsed >= 300.0:
		return 85
	if elapsed >= 180.0:
		return 70
	if elapsed >= 90.0:
		return 55
	return 32


func _gnoll_interval() -> float:
	if elapsed >= hogger_time:
		return 1.5
	if elapsed >= 300.0:
		return 0.7
	return 0.85


func _kobold_interval() -> float:
	if elapsed >= hogger_time:
		return 2.8
	if elapsed >= 300.0:
		return 1.7
	return 2.4


func _murloc_interval() -> float:
	if elapsed >= hogger_time:
		return 2.6
	if elapsed >= 300.0:
		return 1.5
	return 2.1


func _spawn_pack(player: Node2D, data: EnemyData, count: int, cap: int) -> void:
	if data == null or enemy_scene == null:
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var base_angle := randf() * TAU
	for i in count:
		if alive >= cap:
			return
		var enemy := enemy_scene.instantiate() as Enemy
		var angle := base_angle + randf_range(-0.22, 0.22)
		var dist := spawn_radius + randf_range(-18.0, 24.0)
		enemy.global_position = player.global_position + Vector2.from_angle(angle) * dist
		parent.add_child(enemy)
		enemy.apply_data(data)
		enemy.health = enemy.max_health
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
		alive += 1


func _spawn_hogger(player: Node2D) -> void:
	if hogger_scene == null or hogger_data == null:
		return
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var hogger := hogger_scene.instantiate() as Enemy
	hogger.global_position = player.global_position + Vector2.RIGHT * spawn_radius
	parent.add_child(hogger)
	hogger.apply_data(hogger_data)
	hogger.health = hogger.max_health
	if not hogger.died.is_connected(_on_enemy_died):
		hogger.died.connect(_on_enemy_died)
	boss_spawned.emit(hogger)


func _on_enemy_died() -> void:
	enemy_killed.emit()
