extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)

@export var move_speed: float = 220.0
@export var max_health: int = 100
@export var contact_damage: int = 10
@export var invuln_time: float = 0.6

@onready var weapon: Node = $Weapon
@onready var hurtbox: Area2D = $Hurtbox

var health: int
var _invuln_remaining: float = 0.0
var alive: bool = true


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	if _invuln_remaining > 0.0:
		_invuln_remaining = maxf(0.0, _invuln_remaining - delta)
		modulate.a = 0.45 if fmod(_invuln_remaining, 0.1) < 0.05 else 1.0
	else:
		modulate.a = 1.0
		_apply_contact_damage()

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed
	move_and_slide()


func take_damage(amount: int) -> void:
	if not alive or _invuln_remaining > 0.0:
		return

	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_invuln_remaining = invuln_time

	if health <= 0:
		alive = false
		velocity = Vector2.ZERO
		died.emit()


func _apply_contact_damage() -> void:
	for body in hurtbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			take_damage(contact_damage)
			return


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		take_damage(contact_damage)
