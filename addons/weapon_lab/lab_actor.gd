extends CharacterBody2D

## Stationary review actor: real sheet animation, no AI, loot, or run progression.
var alive := true
var facing := Vector2.RIGHT
var command_bonus := 0
var area_mult := 1.0
var cooldown_mult := 1.0
var health := 1000
var total_damage := 0
var hits := 0
var is_dummy := false
var anim: SheetAnimator


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	if is_dummy:
		add_to_group("enemies")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		add_child(shape)
		anim = SheetAnimator.from_enemy_data(load("res://data/enemies/skeleton.tres") as EnemyData)
	else:
		add_to_group("player")
		collision_layer = 0
		collision_mask = 0
		anim = SheetAnimator.from_player_defaults()
	anim.bind(sprite)
	anim.apply_layout()
	anim.set_facing_from_vector(facing)
	anim.show_walk_frame(0)


func _physics_process(delta: float) -> void:
	anim.tick_alive(delta, Vector2.ZERO)
	anim.tick_enemy_flash(delta)


func play_attack(toward: Vector2) -> void:
	anim.set_facing_from_vector(toward)
	anim.start_attack()


func take_damage(amount: int) -> int:
	total_damage += amount
	hits += 1
	anim.trigger_enemy_flash()
	return amount


func health_ratio() -> float:
	return 1.0


func heal(_amount: int) -> void:
	pass


func apply_pull(_from: Vector2, _strength: float) -> void:
	# Keep the review layout stable across repeated attacks.
	pass


func apply_knockback(_from: Vector2, _strength: float) -> void:
	pass
