extends CharacterBody2D

signal died

@export var move_speed: float = 90.0
@export var max_health: int = 40

var health: int
var _player: Node2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	if "alive" in _player and not _player.alive:
		velocity = Vector2.ZERO
		return

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	modulate = Color(1.0, 0.55, 0.55)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(self):
			modulate = Color.WHITE
	)
	if health <= 0:
		died.emit()
		queue_free()
