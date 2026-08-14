extends Area2D

@export var amount: int = 2

@onready var sprite: Sprite2D = $Sprite2D

var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta * 6.0
	sprite.position.y = sin(_t) * 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("gain_xp"):
		body.gain_xp(amount)
		queue_free()
