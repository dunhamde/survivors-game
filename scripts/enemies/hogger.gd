extends Enemy

enum Phase { CHASE, TELEGRAPH, CHARGE, RECOVER }

const MINION_SCENE := preload("res://scenes/enemies/enemy.tscn")
const MINION_DATA := preload("res://data/enemies/skeleton.tres")

var _phase: Phase = Phase.CHASE
var _phase_time: float = 0.0
var _summon_cd: float = 5.0
var _charge_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	add_to_group("boss")


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if "alive" in _player and not _player.alive:
		velocity = Vector2.ZERO
		return
	if health <= 0:
		velocity = Vector2.ZERO
		return

	_summon_cd -= delta
	_phase_time += delta
	match _phase:
		Phase.CHASE:
			var direction := global_position.direction_to(_player.global_position)
			velocity = direction * move_speed
			if sprite != null and absf(direction.x) > 0.1:
				sprite.flip_h = direction.x < 0.0
			if _phase_time >= 4.2:
				_phase = Phase.TELEGRAPH
				_phase_time = 0.0
				velocity = Vector2.ZERO
				_set_body_modulate(Color(1.45, 0.75, 0.45))
			if _summon_cd <= 0.0:
				_summon_minions()
				_summon_cd = 8.0
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			if _phase_time >= 0.55:
				_charge_dir = global_position.direction_to(_player.global_position)
				_phase = Phase.CHARGE
				_phase_time = 0.0
				_set_body_modulate(Color.WHITE)
		Phase.CHARGE:
			velocity = _charge_dir * 270.0
			if _phase_time >= 0.48:
				_phase = Phase.RECOVER
				_phase_time = 0.0
		Phase.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _phase_time >= 0.65:
				_phase = Phase.CHASE
				_phase_time = 0.0
	move_and_slide()


func _on_hit_flash_ended() -> void:
	if _phase == Phase.TELEGRAPH:
		_set_body_modulate(Color(1.45, 0.75, 0.45))
	else:
		super._on_hit_flash_ended()


func _set_body_modulate(color: Color) -> void:
	if _anim.is_flashing():
		return
	modulate = color


func _summon_minions() -> void:
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	for i in 2:
		var minion := MINION_SCENE.instantiate() as Enemy
		var offset := Vector2.from_angle(randf() * TAU) * 42.0
		var desired := global_position + offset
		if parent.has_method("snap_to_walkable"):
			desired = parent.snap_to_walkable(desired)
		minion.global_position = desired
		parent.add_child(minion)
		minion.apply_data(MINION_DATA)
		minion.health = minion.max_health
