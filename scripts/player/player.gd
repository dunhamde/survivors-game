extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)

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
var xp_gained: int = 0
var _invuln_remaining: float = 0.0
var _anim: SheetAnimator
var _death_emitted: bool = false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	xp_changed.emit(xp, xp_to_next, level)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	_anim = SheetAnimator.from_player_defaults()
	_anim.bind(sprite, self)
	_anim.apply_layout()
	sprite.position = SPRITE_POS
	_anim.show_walk_frame(0)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		_animate_death(delta)
		return

	if _invuln_remaining > 0.0:
		_invuln_remaining = maxf(0.0, _invuln_remaining - delta)
		_anim.apply_player_flicker(_invuln_remaining)
	else:
		_anim.apply_player_flicker(0.0)
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
	_anim.tick_alive(delta, input_vector)


func _animate_death(delta: float) -> void:
	if _anim.tick_death(delta) and not _death_emitted:
		_death_emitted = true
		died.emit()


func play_attack(toward: Vector2) -> void:
	if not alive:
		return
	_anim.set_facing_from_vector(toward)
	_anim.start_attack()


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
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
	_anim.start_death()


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
	xp_gained += amount
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
