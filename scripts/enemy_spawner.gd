extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.2
@export var spawn_radius: float = 520.0
@export var max_enemies: int = 60
@export var difficulty_ramp: float = 0.02

var _elapsed: float = 0.0
var _spawn_timer: float = 0.0
var _player: Node2D


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemy.tscn")
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	if "alive" in _player and not _player.alive:
		return

	_elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return

	_spawn_enemy()
	var interval := maxf(0.35, spawn_interval - _elapsed * difficulty_ramp)
	_spawn_timer = interval


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	var angle := randf() * TAU
	enemy.global_position = _player.global_position + Vector2.from_angle(angle) * spawn_radius
	get_parent().add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("register_kill"):
		main.register_kill()
