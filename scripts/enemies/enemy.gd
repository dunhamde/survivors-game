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
var _anim: SheetAnimator
var _dying: bool = false
var _death_finishing: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_anim = SheetAnimator.new()
	_anim.bind(sprite, self)
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
	_anim = SheetAnimator.from_enemy_data(p_data)
	_anim.bind(sprite, self)
	_anim.apply_layout()
	if _anim.uses_sheet:
		_anim.show_walk_frame(0)
	var circle := CircleShape2D.new()
	circle.radius = p_data.collision_radius
	collision.shape = circle
	collision.position = Vector2(0.0, -p_data.collision_radius * 0.35)


func health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)


func _physics_process(delta: float) -> void:
	if _dying:
		_update_flash(delta)
		_animate_death(delta)
		return
	_update_flash(delta)
	_chase(delta)


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if "alive" in _player and not _player.alive:
		velocity = Vector2.ZERO
		_animate_walk(delta, Vector2.ZERO)
		return
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_animate_walk(delta, direction)


func _animate_walk(delta: float, direction: Vector2) -> void:
	_anim.tick_alive(delta, direction)


func _animate_death(delta: float) -> void:
	if _death_finishing:
		return
	if _anim.tick_death(delta):
		_death_finishing = true
		set_physics_process(false)
		call_deferred("_finish_death")


func _update_flash(delta: float) -> void:
	_anim.tick_enemy_flash(delta)


func take_damage(amount: int) -> int:
	if health <= 0:
		return 0
	if DevCheats.god_mode:
		amount = health
	var dealt := mini(amount, health)
	health = maxi(0, health - amount)
	_anim.trigger_enemy_flash()
	damaged.emit(health, max_health)
	if health <= 0:
		_die()
	return dealt


func _die() -> void:
	died.emit()
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	if collision != null:
		collision.set_deferred("disabled", true)
	var run := get_tree().get_first_node_in_group("run")
	if run != null and run.has_method("register_kill"):
		run.register_kill()
	if _anim.uses_sheet:
		_dying = true
		_anim.start_death()
		return
	set_physics_process(false)
	# Spawning an Area2D (XP mote) during body_entered / overlapping-body
	# queries changes monitoring while the physics server is flushing.
	call_deferred("_finish_death")


func _finish_death() -> void:
	if not is_instance_valid(self):
		return
	_drop_xp()
	queue_free()


func _drop_xp() -> void:
	if xp_value <= 0:
		return
	var mote := preload("res://scenes/xp_mote.tscn").instantiate() as Area2D
	mote.amount = xp_value
	var spawn_pos := global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(mote)
	mote.global_position = spawn_pos
