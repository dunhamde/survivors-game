extends CanvasLayer

signal toggle_requested
signal retry_pressed
signal quit_pressed
signal spawn_enemy_requested(id: StringName)

@onready var main_box: VBoxContainer = $Center/Panel/Margin/VBox
@onready var resume_button: Button = $Center/Panel/Margin/VBox/ResumeButton
@onready var retry_button: Button = $Center/Panel/Margin/VBox/RetryButton
@onready var damage_numbers_check: CheckBox = $Center/Panel/Margin/VBox/DamageNumbers
@onready var dev_button: Button = $Center/Panel/Margin/VBox/DevButton
@onready var quit_button: Button = $Center/Panel/Margin/VBox/QuitButton
@onready var hint: Label = $Center/Panel/Margin/VBox/Hint
@onready var dev_box: VBoxContainer = $Center/Panel/Margin/DevBox
@onready var god_mode_check: CheckBox = $Center/Panel/Margin/DevBox/GodMode
@onready var spawn_list: VBoxContainer = $Center/Panel/Margin/DevBox/SpawnList
@onready var back_button: Button = $Center/Panel/Margin/DevBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dev_box.visible = false
	quit_button.visible = not OS.has_feature("web")
	var touch := OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if touch:
		hint.text = "Tap Resume to continue"
	GameSettings.ensure_loaded()
	damage_numbers_check.set_pressed_no_signal(GameSettings.show_damage_numbers)
	resume_button.pressed.connect(func() -> void: toggle_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	dev_button.pressed.connect(_show_dev)
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	god_mode_check.toggled.connect(_on_god_mode_toggled)
	back_button.pressed.connect(_show_main)


func setup_spawn_options(entries: Array) -> void:
	for child in spawn_list.get_children():
		child.queue_free()
	for entry in entries:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 36)
		button.add_theme_font_size_override("font_size", 16)
		button.text = "Spawn %s" % str(entry.get("name", entry.get("id", "Enemy")))
		button.pressed.connect(_on_spawn_pressed.bind(entry.get("id", &"")))
		spawn_list.add_child(button)


func show_menu() -> void:
	visible = true
	GameSettings.ensure_loaded()
	damage_numbers_check.set_pressed_no_signal(GameSettings.show_damage_numbers)
	_show_main()


func hide_menu() -> void:
	visible = false
	_show_main()


func _show_main() -> void:
	main_box.visible = true
	dev_box.visible = false
	resume_button.grab_focus()


func _show_dev() -> void:
	main_box.visible = false
	dev_box.visible = true
	god_mode_check.set_pressed_no_signal(DevCheats.god_mode)
	god_mode_check.grab_focus()


func _on_damage_numbers_toggled(pressed: bool) -> void:
	GameSettings.set_show_damage_numbers(pressed)


func _on_god_mode_toggled(pressed: bool) -> void:
	DevCheats.god_mode = pressed


func _on_spawn_pressed(id: StringName) -> void:
	if id == &"":
		return
	spawn_enemy_requested.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_pause_event(event):
		return
	if visible and dev_box.visible:
		_show_main()
		get_viewport().set_input_as_handled()
		return
	toggle_requested.emit()
	get_viewport().set_input_as_handled()


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			return true
	return false
