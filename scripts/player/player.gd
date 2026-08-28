extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)

const SHEET_COLS := 5
const SHEET_ROWS := 11
const WALK_FRAMES := 5
const ATTACK_ROW := 5
const ATTACK_FRAMES := 4
const DEATH_ROW := 9
const DEATH_FRAMES := 10
const WALK_FPS := 8.0
const ATTACK_FPS := 12.0
const DEATH_FPS := 10.0
const DEATH_HOLD := 0.4
const SPRITE_POS := Vector2(0.0, -30.0)

@export var move_speed: float = 130.0
@export var max_health: int = 120
@export var invuln_time: float = 0.55
@export var magnetism: float = 56.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapons: WeaponController = $WeaponController

var health: int
var alive: bool = true
var level: int = 1
var xp: int = 0
var xp_to_next: int = 8
var _invuln_remaining: float = 0.0
var _dir_col: int = 4
var _dir_flip: bool = false
var _attacking: bool = false
var _attack_time: float = 0.0
var _walk_time: float = 0.0
var _death_time: float = 0.0
var _death_emitted: bool = false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	xp_changed.emit(xp, xp_to_next, level)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	sprite.hframes = SHEET_COLS
	sprite.vframes = SHEET_ROWS
	sprite.centered = true
	sprite.position = SPRITE_POS
	_show_walk_frame(0)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		_animate_death(delta)
		return

	if _invuln_remaining > 0.0:
		_invuln_remaining = maxf(0.0, _invuln_remaining - delta)
		modulate.a = 0.4 if fmod(_invuln_remaining, 0.1) < 0.05 else 1.0
	else:
		modulate.a = 1.0
		_apply_contact_damage()

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() < 0.0001:
		var stick := get_tree().get_first_node_in_group("virtual_joystick")
		if stick != null and stick.has_method("get_vector"):
			input_vector = stick.get_vector()
	velocity = input_vector * move_speed
	move_and_slide()
	_animate(delta, input_vector)


func _animate(delta: float, input_vector: Vector2) -> void:
	if _attacking:
		_attack_time += delta
		var attack_frame := int(_attack_time * ATTACK_FPS)
		if attack_frame >= ATTACK_FRAMES:
			_attacking = false
			_attack_time = 0.0
		else:
			_show_frame(ATTACK_ROW + attack_frame, _dir_col, _dir_flip)
			return

	if input_vector.length() > 0.1:
		_set_facing_from_vector(input_vector)
		_walk_time += delta
		_show_walk_frame(int(_walk_time * WALK_FPS) % WALK_FRAMES)
	else:
		_walk_time = 0.0
		_show_walk_frame(0)


func _animate_death(delta: float) -> void:
	_death_time += delta
	var death_frame := mini(int(_death_time * DEATH_FPS), DEATH_FRAMES - 1)
	_show_frame(DEATH_ROW + int(death_frame / SHEET_COLS), death_frame % SHEET_COLS, false)
	if _death_emitted:
		return
	if _death_time >= (float(DEATH_FRAMES) / DEATH_FPS) + DEATH_HOLD:
		_death_emitted = true
		died.emit()


func play_attack(toward: Vector2) -> void:
	if not alive:
		return
	_set_facing_from_vector(toward)
	_attacking = true
	_attack_time = 0.0
	_show_frame(ATTACK_ROW, _dir_col, _dir_flip)


func _set_facing_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	# 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE. Sheet cols are N, NE, E, SE, S.
	var octant := posmod(int(round(direction.angle() / (PI * 0.25))), 8)
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


func _show_walk_frame(walk_frame: int) -> void:
	_show_frame(walk_frame, _dir_col, _dir_flip)


func _show_frame(row: int, col: int, flip: bool) -> void:
	sprite.frame = row * SHEET_COLS + col
	sprite.flip_h = flip


func take_damage(amount: int) -> void:
	if not alive or _invuln_remaining > 0.0 or DevCheats.god_mode:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_invuln_remaining = invuln_time
	if health <= 0:
		_die()


func _die() -> void:
	alive = false
	velocity = Vector2.ZERO
	modulate.a = 1.0
	_attacking = false
	_death_time = 0.0
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
	_show_frame(DEATH_ROW, 0, false)


func heal(amount: int) -> void:
	if not alive:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func add_max_health(amount: int) -> void:
	max_health += amount
	heal(amount)


func add_magnetism(amount: float) -> void:
	magnetism = maxf(0.0, magnetism + amount)


func gain_xp(amount: int) -> void:
	if not alive or amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_for_level(level)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)


func _xp_for_level(current_level: int) -> int:
	return 6 + current_level * 3


func _apply_contact_damage() -> void:
	for body in hurtbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			var dmg := 8
			if "contact_damage" in body:
				dmg = body.contact_damage
			take_damage(dmg)
			return


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		var dmg := 8
		if "contact_damage" in body:
			dmg = body.contact_damage
		take_damage(dmg)
