extends Node2D

@onready var player: CharacterBody2D = $World/Player
@onready var director: Node2D = $WaveDirector
@onready var health_bar: ProgressBar = $HUD/Top/Row/Left/HealthBar
@onready var health_label: Label = $HUD/Top/Row/Left/HealthLabel
@onready var xp_bar: ProgressBar = $HUD/Top/Row/Left/XPBar
@onready var level_label: Label = $HUD/Top/Row/Left/LevelLabel
@onready var time_label: Label = $HUD/Top/Row/TimeLabel
@onready var kills_label: Label = $HUD/Top/Row/Right/KillsLabel
@onready var hint_label: Label = $HUD/Hint
@onready var boss_wrap: Control = $HUD/BossWrap
@onready var boss_bar: ProgressBar = $HUD/BossWrap/BossBar
@onready var boss_label: Label = $HUD/BossWrap/BossLabel
@onready var end_panel: PanelContainer = $HUD/EndPanel
@onready var end_title: Label = $HUD/EndPanel/Margin/VBox/Title
@onready var end_stats: Label = $HUD/EndPanel/Margin/VBox/Stats
@onready var retry_button: Button = $HUD/EndPanel/Margin/VBox/RetryButton
@onready var hud_top: MarginContainer = $HUD/Top
@onready var hamburger_button: HamburgerButton = $HUD/HamburgerButton
@onready var virtual_joystick: Control = $HUD/VirtualJoystick
@onready var level_up_ui: CanvasLayer = $LevelUpUI
@onready var pause_menu: CanvasLayer = $PauseMenu

var kills: int = 0
var elapsed: float = 0.0
var running: bool = true
var _level_queue: int = 0
var _showing_level_up: bool = false
var _menu_paused: bool = false
var _boss: Node = null
var _won: bool = false


func _ready() -> void:
	_configure_phone_content_scale()
	end_panel.visible = false
	boss_wrap.visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	player.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	player.died.connect(_on_player_died)
	director.boss_spawned.connect(_on_boss_spawned)
	level_up_ui.choice_made.connect(_on_choice_made)
	pause_menu.toggle_requested.connect(_on_pause_toggle)
	pause_menu.retry_pressed.connect(_restart)
	pause_menu.quit_pressed.connect(_quit_game)
	pause_menu.spawn_enemy_requested.connect(_on_dev_spawn)
	pause_menu.setup_spawn_options(director.spawnable_catalog())
	hamburger_button.pressed.connect(_on_pause_toggle)
	_on_health_changed(player.health, player.max_health)
	_on_xp_changed(player.xp, player.xp_to_next, player.level)
	kills_label.text = "Kills 0"
	_update_time()
	_update_hint()
	_update_hamburger()
	call_deferred("_update_hamburger")
	get_viewport().size_changed.connect(_update_hamburger)


func _configure_phone_content_scale() -> void:
	## On HiDPI phone web, the 1280×720 base shrinks too far. Use a shorter
	## content base so HUD / level-up UI map larger onto CSS pixels.
	var touch_web := (
		OS.has_feature("mobile")
		or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	)
	if not touch_web:
		return
	var dpr := maxf(DisplayServer.screen_get_scale(), 0.5)
	var css := Vector2(DisplayServer.window_get_size()) / dpr
	var short_side := mini(css.x, css.y)
	if short_side <= 0.0 or short_side >= 520.0:
		return
	var win := get_window()
	if win == null:
		return
	win.content_scale_size = Vector2i(960, 540)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not running:
		if Input.is_action_just_pressed("ui_accept"):
			_restart()
		return
	elapsed += delta
	_update_time()


func _update_time() -> void:
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]


func _is_touch_ui() -> bool:
	return OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _update_hint() -> void:
	if _is_touch_ui():
		hint_label.text = "Touch & drag to move · Auto-attack · Survive until Hogger"
	else:
		hint_label.text = "WASD / Arrows to move · Auto-attack · Esc to pause · Survive until Hogger"
	if virtual_joystick != null and virtual_joystick.has_method("_update_visibility"):
		virtual_joystick.call("_update_visibility")


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP %d / %d" % [current, maximum]


func _on_xp_changed(current: int, needed: int, level: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	level_label.text = "Paladin  Lv %d" % level


func _on_leveled_up(_new_level: int) -> void:
	_level_queue += 1
	_try_show_level_up()


func _try_show_level_up() -> void:
	if _showing_level_up or _level_queue <= 0 or not running or _menu_paused:
		return
	_showing_level_up = true
	_level_queue -= 1
	var choices := UpgradePool.build_choices(player.weapons)
	level_up_ui.show_choices(choices)
	get_tree().paused = true
	_update_hamburger()


func _on_choice_made(choice: Dictionary) -> void:
	UpgradePool.apply(choice, player, player.weapons)
	_showing_level_up = false
	level_up_ui.hide_ui()
	if _level_queue > 0 and running:
		_try_show_level_up()
	elif not _menu_paused:
		get_tree().paused = false
	_update_hamburger()


func register_kill() -> void:
	kills += 1
	kills_label.text = "Kills %d" % kills


func _on_boss_spawned(boss: Node) -> void:
	_boss = boss
	boss_wrap.visible = true
	boss_label.text = "Hogger"
	if boss.has_signal("damaged"):
		boss.damaged.connect(_on_boss_damaged)
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died)
	if "health" in boss and "max_health" in boss:
		_on_boss_damaged(boss.health, boss.max_health)


func _on_boss_damaged(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_died() -> void:
	if _won or not running:
		return
	_won = true
	_end_run("Hogger Slain", "Elwynn is quieter — for now.")


func _on_player_died() -> void:
	if _won:
		return
	_end_run("You Died", "The Horde overruns the Goldshire road.")


func _on_dev_spawn(id: StringName) -> void:
	if director != null and director.has_method("spawn_debug"):
		director.spawn_debug(id)


func _on_pause_toggle() -> void:
	if not running or _showing_level_up:
		return
	if _menu_paused:
		_resume_from_pause()
	else:
		_pause_game()


func _pause_game() -> void:
	_menu_paused = true
	get_tree().paused = true
	pause_menu.show_menu()
	_update_hamburger()


func _resume_from_pause() -> void:
	_menu_paused = false
	pause_menu.hide_menu()
	_update_hamburger()
	if _level_queue > 0 and running:
		_try_show_level_up()
	elif not _showing_level_up:
		get_tree().paused = false


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _update_hamburger() -> void:
	if hamburger_button == null:
		return
	var show := _is_touch_ui() and running and not _showing_level_up and not _menu_paused
	hamburger_button.set_enabled(show)
	if hud_top == null:
		return
	var left := 16
	if show:
		left = hamburger_button.occupied_left_margin()
	hud_top.add_theme_constant_override("margin_left", left)


func _end_run(title: String, flavor: String) -> void:
	running = false
	_menu_paused = false
	get_tree().paused = false
	_showing_level_up = false
	_level_queue = 0
	level_up_ui.hide_ui()
	pause_menu.hide_menu()
	_update_hamburger()
	if virtual_joystick != null:
		virtual_joystick.visible = false
	var retry_hint := "Tap Retry" if _is_touch_ui() else "Press Enter or Retry"
	end_title.text = title
	end_stats.text = "%s\n\nTime %s   Kills %d   Level %d\n\n%s" % [
		flavor,
		time_label.text,
		kills,
		player.level,
		retry_hint,
	]
	end_panel.visible = true


func _on_retry_pressed() -> void:
	_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
