extends Area2D

const HammerCharge := preload("res://scripts/weapons/hammer_charge.gd")
const HammerImpact := preload("res://scripts/weapons/hammer_impact.gd")
const HammerTrail := preload("res://scripts/weapons/hammer_trail.gd")

var speed: float = 240.0
var damage: int = 28
var lifetime: float = 2.6
var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var source: WeaponBase
var _trail
var _glow: Sprite2D
var _charge_time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_glow = Sprite2D.new()
	_glow.texture = WeaponArt.texture(&"wrath_hammer_glow")
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_material
	add_child(_glow)
	var sprite := Sprite2D.new()
	sprite.texture = WeaponArt.texture(&"wrath_hammer")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	add_child(HammerCharge.new())
	_trail = HammerTrail.new()
	get_parent().add_child(_trail)
	_trail.record(global_position)
	var timer := get_tree().create_timer(lifetime, false)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var desired := global_position.direction_to(target.global_position)
		direction = direction.lerp(desired, clampf(7.0 * delta, 0.0, 1.0)).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	_trail.record(global_position)
	_charge_time += delta
	_glow.modulate.a = 0.75 + 0.2 * sin(_charge_time * 13.0)


func _exit_tree() -> void:
	if is_instance_valid(_trail):
		_trail.finish()


func _on_body_entered(body: Node2D) -> void:
	if not Hittable.is_target(body):
		return
	if source != null:
		source.deal_to(body, damage)
	else:
		body.take_damage(damage)
	var impact := HammerImpact.new()
	get_parent().add_child(impact)
	impact.global_position = global_position
	queue_free()
