extends Enemy

enum Phase { CHASE, TELEGRAPH, CHARGE, RECOVER }

const GNOLL_SCENE := preload("res://scenes/enemies/enemy.tscn")
const GNOLL_DATA := preload("res://data/enemies/gnoll.tres")

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
				modulate = Color(1.45, 0.75, 0.45)
			if _summon_cd <= 0.0:
				_summon_gnolls()
				_summon_cd = 8.0
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			if _phase_time >= 0.55:
				_charge_dir = global_position.direction_to(_player.global_position)
				_phase = Phase.CHARGE
				_phase_time = 0.0
				modulate = Color.WHITE
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


func _summon_gnolls() -> void:
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	for i in 2:
		var gnoll := GNOLL_SCENE.instantiate() as Enemy
		var offset := Vector2.from_angle(randf() * TAU) * 42.0
		gnoll.global_position = global_position + offset
		parent.add_child(gnoll)
		gnoll.apply_data(GNOLL_DATA)
		gnoll.health = gnoll.max_health
