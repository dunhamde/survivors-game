extends Area2D

@export var amount: int = 2
@export var pull_speed: float = 180.0
@export var pull_accel: float = 520.0

@onready var sprite: Sprite2D = $Sprite2D

var _t: float = 0.0
var _pull_time: float = 0.0
var _pulled: bool = false
var _player: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_t += delta * 6.0
	sprite.position.y = sin(_t) * 2.0
	_try_magnet(delta)


func _try_magnet(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	if "alive" in _player and not _player.alive:
		return
	var radius := 0.0
	if "magnetism" in _player:
		radius = float(_player.magnetism)
	if not _pulled:
		if radius <= 0.0:
			return
		if global_position.distance_squared_to(_player.global_position) > radius * radius:
			return
		_pulled = true
	_pull_time += delta
	var speed := pull_speed + _pull_time * pull_accel
	global_position = global_position.move_toward(_player.global_position, speed * delta)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("gain_xp"):
		body.gain_xp(amount)
		queue_free()
