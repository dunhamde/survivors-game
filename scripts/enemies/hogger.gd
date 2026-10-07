extends Enemy

## Locked charge lanes, a cleaver slam with an expanding shockwave, and a
## warband roar. Ground warnings are independent of the sprite's hit flash.
enum Phase { CHASE, CHARGE_WARNING, CHARGE, SLAM_WARNING, SHOCKWAVE, ROAR, RECOVER }

const MINION_SCENE := preload("res://scenes/enemies/enemy.tscn")
const MINION_DATA := preload("res://data/enemies/grunt.tres")
const CHARGE_SPEED := 460.0
const CHARGE_LENGTH := 360.0
const CHARGE_HALF_WIDTH := 27.0
const SLAM_RADIUS := 108.0
const WAVE_SPEED := 190.0
const WAVE_MAX_RADIUS := 255.0
const WAVE_HALF_WIDTH := 13.0
const MINION_LIMIT := 12

var _phase: Phase = Phase.CHASE
var _phase_time: float = 0.0
var _attack_index: int = 0
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_origin: Vector2 = Vector2.ZERO
var _charge_hit: bool = false
var _wave_hit: bool = false
var _wave_origin: Vector2 = Vector2.ZERO
var _summon_positions: Array[Vector2] = []
var _enraged: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	var warning := Node2D.new()
	warning.name = "GroundWarning"
	warning.z_index = -1
	warning.show_behind_parent = true
	warning.draw.connect(_draw_warning.bind(warning))
	add_child(warning)


func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		_queue_warning()
		return
	_update_flash(delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if health <= 0 or not _player.alive:
		velocity = Vector2.ZERO
		_queue_warning()
		return
	if not _enraged and health_ratio() <= 0.5:
		_enraged = true
	_phase_time += delta
	match _phase:
		Phase.CHASE:
			_chase(delta)
			if _phase_time >= (1.8 if _enraged else 2.8):
				_begin_next_attack()
		Phase.CHARGE_WARNING:
			velocity = Vector2.ZERO
			_anim.show_attack_frame(0)
			if _phase_time >= _warning_duration():
				_enter_phase(Phase.CHARGE)
				collision_mask = COLLISION_MASK_WORLD
				_anim.start_attack()
		Phase.CHARGE:
			var previous := global_position
			velocity = _charge_dir * CHARGE_SPEED
			move_and_slide()
			_animate_walk(delta, _charge_dir)
			# Check the travelled segment so a fast charge cannot skip a player.
			if not _charge_hit and _distance_to_segment(_player.global_position, previous, global_position) <= CHARGE_HALF_WIDTH:
				_charge_hit = true
				_player.take_damage(28)
			if _phase_time >= CHARGE_LENGTH / CHARGE_SPEED or get_slide_collision_count() > 0:
				_enter_phase(Phase.RECOVER)
		Phase.SLAM_WARNING:
			velocity = Vector2.ZERO
			_anim.show_attack_frame(0)
			if _phase_time >= _warning_duration():
				_enter_phase(Phase.SHOCKWAVE)
				_wave_origin = global_position
				_wave_hit = false
				_anim.start_attack()
				_anim.attack_time = 1.0 / SheetAnimator.ATTACK_FPS
				_anim.show_attack_frame(1)
				if _player.global_position.distance_to(_wave_origin) <= SLAM_RADIUS:
					_player.take_damage(24)
		Phase.SHOCKWAVE:
			velocity = Vector2.ZERO
			_animate_walk(delta, Vector2.ZERO)
			var radius := SLAM_RADIUS + _phase_time * WAVE_SPEED
			var distance := _player.global_position.distance_to(_wave_origin)
			# Include the swept annulus between ticks, not only its newest edge.
			if not _wave_hit and distance >= radius - WAVE_HALF_WIDTH - delta * WAVE_SPEED and distance <= radius + WAVE_HALF_WIDTH:
				_wave_hit = true
				_player.take_damage(20)
			if radius >= WAVE_MAX_RADIUS:
				_enter_phase(Phase.RECOVER)
		Phase.ROAR:
			velocity = Vector2.ZERO
			_anim.show_attack_frame(0)
			if _phase_time >= 1.2:
				_summon_warband()
				_enter_phase(Phase.RECOVER)
		Phase.RECOVER:
			velocity = Vector2.ZERO
			_animate_walk(delta, Vector2.ZERO)
			if _phase_time >= 0.85:
				_enter_phase(Phase.CHASE)
	_queue_warning()


func _warning_duration() -> float:
	return 0.95 if _enraged else 1.2


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	velocity = Vector2.ZERO
	collision_mask = COLLISION_MASK_PACK
	_knockback = Vector2.ZERO


func _begin_next_attack() -> void:
	var pattern := [Phase.CHARGE_WARNING, Phase.SLAM_WARNING, Phase.CHARGE_WARNING, Phase.ROAR]
	if _enraged:
		pattern = [Phase.CHARGE_WARNING, Phase.CHARGE_WARNING, Phase.SLAM_WARNING, Phase.ROAR]
	_enter_phase(pattern[_attack_index % pattern.size()])
	_attack_index += 1
	_charge_origin = global_position
	_charge_dir = global_position.direction_to(_player.global_position)
	if _charge_dir == Vector2.ZERO:
		_charge_dir = Vector2.RIGHT
	_charge_hit = false
	_anim.set_facing_from_vector(_charge_dir)
	if _phase == Phase.ROAR:
		_prepare_warband()


func apply_knockback(_from: Vector2, _strength: float) -> void:
	# Stay aligned with the locked ground warning.
	pass


func apply_pull(_toward: Vector2, _strength: float) -> void:
	pass


func attack_label() -> String:
	var title := "Hogger — Enraged" if _enraged else "Hogger"
	match _phase:
		Phase.CHARGE_WARNING, Phase.CHARGE:
			return title + " · Cleaver Rush"
		Phase.SLAM_WARNING, Phase.SHOCKWAVE:
			return title + " · Earthbreaker"
		Phase.ROAR:
			return title + " · Warband Roar"
	return title


func _prepare_warband() -> void:
	_summon_positions.clear()
	var parent := get_parent()
	var slots := mini(6 if _enraged else 4, MINION_LIMIT - get_tree().get_nodes_in_group("hogger_minions").size())
	for i in maxi(0, slots):
		var at := global_position + Vector2.from_angle(float(i) * TAU / maxf(1.0, float(slots))) * 155.0
		if parent.has_method("snap_to_walkable"):
			at = parent.snap_to_walkable(at)
		_summon_positions.append(at)


func _summon_warband() -> void:
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	for at in _summon_positions:
		if alive >= ElwynnBeats.HARD_CAP:
			break
		var minion := MINION_SCENE.instantiate() as Enemy
		minion.global_position = at
		parent.add_child(minion)
		minion.apply_data(MINION_DATA)
		minion.add_to_group("hogger_minions")
		minion.max_health = roundi(float(minion.max_health) * 2.0)
		minion.health = minion.max_health
		alive += 1
	_summon_positions.clear()


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, finish))


func _queue_warning() -> void:
	var warning := get_node_or_null("GroundWarning") as Node2D
	if warning != null:
		warning.queue_redraw()


func _draw_warning(warning: Node2D) -> void:
	if health <= 0 or not is_instance_valid(_player) or not _player.alive:
		return
	var orange := Color(1.0, 0.4, 0.08, 0.85)
	var fill := Color(0.85, 0.16, 0.04, 0.22)
	var progress := clampf(_phase_time / _warning_duration(), 0.0, 1.0)
	match _phase:
		Phase.CHARGE_WARNING:
			var origin := warning.to_local(_charge_origin)
			var side := _charge_dir.orthogonal() * CHARGE_HALF_WIDTH
			var finish := origin + _charge_dir * CHARGE_LENGTH
			var corners := PackedVector2Array([origin + side, finish + side, finish - side, origin - side])
			warning.draw_colored_polygon(corners, fill)
			corners.append(corners[0])
			warning.draw_polyline(corners, orange, 2.0)
			warning.draw_line(origin, origin.lerp(finish, progress), orange, 4.0)
		Phase.SLAM_WARNING:
			warning.draw_circle(Vector2.ZERO, SLAM_RADIUS, fill)
			warning.draw_arc(Vector2.ZERO, SLAM_RADIUS, 0.0, TAU, 64, orange, 3.0)
			warning.draw_arc(Vector2.ZERO, SLAM_RADIUS * progress, 0.0, TAU, 64, orange, 2.0)
		Phase.SHOCKWAVE:
			var origin := warning.to_local(_wave_origin)
			var radius := minf(WAVE_MAX_RADIUS, SLAM_RADIUS + _phase_time * WAVE_SPEED)
			warning.draw_arc(origin, radius, 0.0, TAU, 64, Color(0.64, 0.34, 0.12, 0.75), WAVE_HALF_WIDTH * 2.0)
			warning.draw_arc(origin, radius, 0.0, TAU, 64, Color(1.0, 0.77, 0.33), 3.0)
		Phase.ROAR:
			for at in _summon_positions:
				var local := warning.to_local(at)
				warning.draw_circle(local, 22.0, fill)
				warning.draw_arc(local, 22.0, 0.0, TAU, 24, orange, 2.0)
		Phase.CHARGE:
			warning.draw_line(Vector2.ZERO, -_charge_dir * 55.0, Color(0.74, 0.5, 0.24, 0.65), 15.0)
