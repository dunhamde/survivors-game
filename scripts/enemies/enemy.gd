class_name Enemy
extends CharacterBody2D

signal died
signal damaged(current: int, maximum: int)

@export var data: EnemyData

var max_health: int = 40
var move_speed: float = 70.0
var xp_value: int = 2
var contact_damage: int = 8
var health: int
var _player: Node2D
var _flash: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if data != null:
		apply_data(data)
	health = max_health
	_player = get_tree().get_first_node_in_group("player") as Node2D
	damaged.emit(health, max_health)


func apply_data(p_data: EnemyData) -> void:
	data = p_data
	max_health = p_data.max_health
	move_speed = p_data.move_speed
	xp_value = p_data.xp_value
	contact_damage = p_data.contact_damage
	if sprite != null and p_data.texture != null:
		sprite.texture = p_data.texture
		sprite.centered = true
		sprite.position = Vector2(0.0, -float(p_data.texture.get_height()) * 0.5)
	var circle := CircleShape2D.new()
	circle.radius = p_data.collision_radius
	collision.shape = circle
	collision.position = Vector2(0.0, -p_data.collision_radius * 0.35)


func health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_chase()


func _chase() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if "alive" in _player and not _player.alive:
		velocity = Vector2.ZERO
		return
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	if sprite != null and absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0
	move_and_slide()


func _update_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		modulate = Color(1.0, 0.55, 0.55) if _flash > 0.0 else Color.WHITE


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_flash = 0.08
	damaged.emit(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	died.emit()
	var run := get_tree().get_first_node_in_group("run")
	if run != null and run.has_method("register_kill"):
		run.register_kill()
	_drop_xp()
	queue_free()


func _drop_xp() -> void:
	if xp_value <= 0:
		return
	var mote := preload("res://scenes/xp_mote.tscn").instantiate() as Area2D
	mote.amount = xp_value
	mote.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	var parent := get_tree().get_first_node_in_group("entities")
	if parent != null:
		parent.add_child(mote)
	else:
		get_tree().current_scene.add_child(mote)
