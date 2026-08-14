extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var health_label: Label = $HUD/Margin/VBox/HealthLabel
@onready var kills_label: Label = $HUD/Margin/VBox/KillsLabel
@onready var time_label: Label = $HUD/Margin/VBox/TimeLabel
@onready var game_over_panel: PanelContainer = $HUD/GameOver
@onready var final_stats_label: Label = $HUD/GameOver/Margin/VBox/FinalStats

var kills: int = 0
var elapsed: float = 0.0
var running: bool = true


func _ready() -> void:
	game_over_panel.visible = false
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	_on_player_health_changed(player.health, player.max_health)
	_update_kills()
	_update_time()


func _process(delta: float) -> void:
	if not running:
		if Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return

	elapsed += delta
	_update_time()


func register_kill() -> void:
	kills += 1
	_update_kills()


func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP %d / %d" % [current, maximum]


func _update_kills() -> void:
	kills_label.text = "Kills %d" % kills


func _update_time() -> void:
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	time_label.text = "Time %02d:%02d" % [minutes, seconds]


func _on_player_died() -> void:
	running = false
	final_stats_label.text = "Survived %02d:%02d\nKills %d\n\nPress Enter to retry" % [
		int(elapsed) / 60,
		int(elapsed) % 60,
		kills,
	]
	game_over_panel.visible = true
