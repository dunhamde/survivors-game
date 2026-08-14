extends Node2D

@export var fire_interval: float = 0.45
@export var projectile_speed: float = 420.0
@export var projectile_damage: int = 20
@export var projectile_scene: PackedScene

var _cooldown: float = 0.0


func _ready() -> void:
	if projectile_scene == null:
		projectile_scene = preload("res://scenes/projectile.tscn")


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null or not ("alive" in player) or not player.alive:
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_fire_at(target.global_position)
	_cooldown = fire_interval


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var dist := global_position.distance_squared_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			nearest = enemy as Node2D
	return nearest


func _fire_at(target_pos: Vector2) -> void:
	var projectile := projectile_scene.instantiate() as Area2D
	var direction := (target_pos - global_position).normalized()
	projectile.global_position = global_position
	projectile.direction = direction
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_tree().current_scene.add_child(projectile)
