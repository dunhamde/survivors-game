extends WeaponBase

@onready var ring: Sprite2D = $Ring
@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var _pulse_alpha: float = 0.0


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	hit_shape.shape = circle
	ring.modulate.a = 0.25


func _physics_process(delta: float) -> void:
	if not is_player_alive():
		return
	_apply_area()
	if _pulse_alpha > 0.0:
		_pulse_alpha = maxf(0.0, _pulse_alpha - delta * 2.4)
		ring.modulate.a = lerpf(0.22, 0.95, _pulse_alpha)
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	_pulse()
	cooldown = current_cooldown()


func _apply_area() -> void:
	var radius := current_area()
	var circle := hit_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	var tex_size := 96.0
	ring.scale = Vector2.ONE * ((radius * 2.0) / tex_size)


func _pulse() -> void:
	_pulse_alpha = 1.0
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(current_damage())
