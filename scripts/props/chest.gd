class_name Chest
extends CharacterBody2D

const SHEET_COLS := 8
const SHEET_ROWS := 5
const OPEN_FRAMES := 4
const OPEN_FPS := 10.0
const HOLD_OPEN := 2.4
const FADE_TIME := 0.55
const HEART_SCENE := preload("res://scenes/pickups/heart.tscn")
const GOLD_SCENE := preload("res://scenes/pickups/gold_pile.tscn")

@export var max_health: int = 1

var health: int
var _opening: bool = false
var _loot_dropped: bool = false
var _open_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("chests")
	health = max_health
	sprite.hframes = SHEET_COLS
	sprite.vframes = SHEET_ROWS
	sprite.frame = 0
	sprite.centered = true


func health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)


func take_damage(amount: int) -> void:
	if _opening or health <= 0 or amount <= 0:
		return
	health = 0
	_opening = true
	remove_from_group("chests")
	if collision != null:
		collision.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if not _opening:
		return
	_open_time += delta
	var frame := mini(int(_open_time * OPEN_FPS), OPEN_FRAMES - 1)
	sprite.frame = frame
	if not _loot_dropped and frame >= OPEN_FRAMES - 1:
		_loot_dropped = true
		call_deferred("_drop_loot")
	var fade_at := float(OPEN_FRAMES) / OPEN_FPS + HOLD_OPEN
	if _open_time >= fade_at:
		var fade := 1.0 - (_open_time - fade_at) / FADE_TIME
		modulate.a = clampf(fade, 0.0, 1.0)
		if fade <= 0.0:
			queue_free()


func _drop_loot() -> void:
	if not is_instance_valid(self):
		return
	var scene := HEART_SCENE if randf() < 0.5 else GOLD_SCENE
	var loot := scene.instantiate() as Area2D
	var spawn_pos := global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-10.0, -2.0))
	var parent := get_tree().get_first_node_in_group("entities")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(loot)
	loot.global_position = spawn_pos
