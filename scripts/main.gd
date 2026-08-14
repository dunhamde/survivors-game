extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var health_label: Label = $HUD/Margin/VBox/HealthLabel
@onready var kills_label: Label = $HUD/Margin/VBox/KillsLabel
@onready var time_label: Label = $HUD/Margin/VBox/TimeLabel
@onready var hint_label: Label = $HUD/Hint
@onready var game_over_panel: PanelContainer = $HUD/GameOver
@onready var final_stats_label: Label = $HUD/GameOver/Margin/VBox/FinalStats
@onready var retry_button: Button = $HUD/GameOver/Margin/VBox/RetryButton
@onready var virtual_joystick: Control = $HUD/VirtualJoystick

var kills: int = 0
var elapsed: float = 0.0
var running: bool = true


func _ready() -> void:
	game_over_panel.visible = false
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	retry_button.pressed.connect(_on_retry_pressed)
	_on_player_health_changed(player.health, player.max_health)
	_update_kills()
	_update_time()
	_update_hint()


func _process(delta: float) -> void:
	if not running:
		if Input.is_action_just_pressed("ui_accept"):
			_restart()
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


func _update_hint() -> void:
	var touch := OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if touch:
		hint_label.text = "Drag the stick to move · Auto-attack"
	else:
		hint_label.text = "WASD / Arrows to move · Auto-attack"
	if virtual_joystick != null and virtual_joystick.has_method("_update_visibility"):
		virtual_joystick.call("_update_visibility")


func _on_player_died() -> void:
	running = false
	var retry_hint := "Tap Retry" if (OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")) else "Press Enter or Retry"
	final_stats_label.text = "Survived %02d:%02d\nKills %d\n\n%s" % [
		int(elapsed) / 60,
		int(elapsed) % 60,
		kills,
		retry_hint,
	]
	game_over_panel.visible = true
	if virtual_joystick != null:
		virtual_joystick.visible = false


func _on_retry_pressed() -> void:
	_restart()


func _restart() -> void:
	get_tree().reload_current_scene()
