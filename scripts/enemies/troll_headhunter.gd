extends Enemy

## The spear stays shouldered while chasing; the four attack rows show a
## wind-up, extension, full thrust, and recovery.
const ATTACK_RANGE := 62.0
const HIT_RANGE := 66.0
const ATTACK_COOLDOWN := 1.35
const HIT_TIME := 2.0 / SheetAnimator.ATTACK_FPS

var _cooldown: float = 0.5
var _thrust_time: float = 0.0
var _thrusting: bool = false
var _hit_done: bool = false
var _thrust_direction: Vector2 = Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	_update_flash(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if "alive" in _player and not _player.alive:
		velocity = Vector2.ZERO
		_animate_walk(delta, Vector2.ZERO)
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	if _thrusting:
		_tick_thrust(delta)
		return

	var to_player := _player.global_position - global_position
	if _cooldown <= 0.0 and to_player.length() <= ATTACK_RANGE:
		_begin_thrust(to_player.normalized())
		return
	_chase(delta)


func _begin_thrust(direction: Vector2) -> void:
	_thrusting = true
	_thrust_time = 0.0
	_hit_done = false
	_thrust_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	velocity = Vector2.ZERO
	_anim.set_facing_from_vector(_thrust_direction)
	_anim.start_attack()


func _tick_thrust(delta: float) -> void:
	_thrust_time += delta
	velocity = _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 520.0 * delta)
	move_and_slide()
	_anim.tick_alive(delta, Vector2.ZERO)
	if not _hit_done and _thrust_time >= HIT_TIME:
		_hit_done = true
		var to_player := _player.global_position - global_position
		if (to_player.length() <= HIT_RANGE
			and to_player.normalized().dot(_thrust_direction) >= 0.6
			and _player.has_method("take_damage")):
			_player.call("take_damage", contact_damage)
	if not _anim.attacking:
		_thrusting = false
		_cooldown = ATTACK_COOLDOWN
