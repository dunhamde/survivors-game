class_name Enemy
extends CharacterBody2D

signal died
signal damaged(current: int, maximum: int)

const WALK_FPS := 8.0
const DEATH_FPS := 10.0
const DEATH_HOLD := 0.15
# Octants are E, SE, S, SW, W, NW, N, NE. Skeleton rows are S, SE, E, NE, N, NW, W, SW.
const DIR_ROWS := [2, 1, 0, 7, 6, 5, 4, 3]

@export var data: EnemyData

var max_health: int = 40
var move_speed: float = 70.0
var xp_value: int = 2
var contact_damage: int = 8
var health: int
var _player: Node2D
var _flash: float = 0.0
var _dir_row: int = 0
var _dir_col: int = 4
var _dir_flip: bool = false
var _walk_time: float = 0.0
var _dying: bool = false
var _death_time: float = 0.0
var _death_finishing: bool = false
var _uses_sheet: bool = false
var _sheet_cols: int = 5
var _cols_are_dirs: bool = false
var _walk_frames: int = 5
var _death_row: int = 9
var _death_frames: int = 5

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
	_uses_sheet = p_data.sheet_cols > 1
	_sheet_cols = maxi(1, p_data.sheet_cols)
	_cols_are_dirs = p_data.sheet_cols_are_dirs
	_walk_frames = maxi(1, p_data.walk_frames)
	_death_row = p_data.death_row
	_death_frames = maxi(1, p_data.death_frames)
	if sprite != null and p_data.texture != null:
		sprite.texture = p_data.texture
		sprite.centered = true
		if _uses_sheet:
			sprite.hframes = p_data.sheet_cols
			sprite.vframes = p_data.sheet_rows
			var cell_h := float(p_data.texture.get_height()) / float(p_data.sheet_rows)
			sprite.position = Vector2(0.0, -cell_h * 0.42)
			_show_walk_frame(0)
		else:
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.flip_h = false
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
	if not _uses_sheet:
		if sprite != null and absf(direction.x) > 0.1:
			sprite.flip_h = direction.x < 0.0
		return
	if direction.length() > 0.1:
		_set_facing_from_vector(direction)
		_walk_time += delta
		_show_walk_frame(int(_walk_time * WALK_FPS) % _walk_frames)
	else:
		_walk_time = 0.0
		_show_walk_frame(0)


func _animate_death(delta: float) -> void:
	_death_time += delta
	var death_frame := mini(int(_death_time * DEATH_FPS), _death_frames - 1)
	if _cols_are_dirs:
		_show_frame(_death_row + int(death_frame / _sheet_cols), death_frame % _sheet_cols, false)
	else:
		_show_frame(_death_row, death_frame, false)
	if _death_finishing:
		return
	if _death_time >= (float(_death_frames) / DEATH_FPS) + DEATH_HOLD:
		_death_finishing = true
		set_physics_process(false)
		call_deferred("_finish_death")


func _set_facing_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var octant := posmod(int(round(direction.angle() / (PI * 0.25))), 8)
	if _cols_are_dirs:
		# Sheet cols are N, NE, E, SE, S; west facings are mirrored.
		match octant:
			0:
				_dir_col = 2
				_dir_flip = false
			1:
				_dir_col = 3
				_dir_flip = false
			2:
				_dir_col = 4
				_dir_flip = false
			3:
				_dir_col = 3
				_dir_flip = true
			4:
				_dir_col = 2
				_dir_flip = true
			5:
				_dir_col = 1
				_dir_flip = true
			6:
				_dir_col = 0
				_dir_flip = false
			7:
				_dir_col = 1
				_dir_flip = false
	else:
		_dir_row = DIR_ROWS[octant]


func _show_walk_frame(walk_frame: int) -> void:
	if _cols_are_dirs:
		_show_frame(walk_frame, _dir_col, _dir_flip)
	else:
		_show_frame(_dir_row, walk_frame, false)


func _show_frame(row: int, col: int, flip: bool) -> void:
	if sprite == null:
		return
	sprite.frame = row * _sheet_cols + col
	sprite.flip_h = flip


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
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	if collision != null:
		collision.set_deferred("disabled", true)
	var run := get_tree().get_first_node_in_group("run")
	if run != null and run.has_method("register_kill"):
		run.register_kill()
	if _uses_sheet:
		_dying = true
		_death_time = 0.0
		_show_frame(_death_row, 0, false)
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
