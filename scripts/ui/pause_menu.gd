extends CanvasLayer

signal toggle_requested
signal retry_pressed
signal quit_pressed

@onready var resume_button: Button = $Center/Panel/Margin/VBox/ResumeButton
@onready var retry_button: Button = $Center/Panel/Margin/VBox/RetryButton
@onready var quit_button: Button = $Center/Panel/Margin/VBox/QuitButton
@onready var hint: Label = $Center/Panel/Margin/VBox/Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	quit_button.visible = not OS.has_feature("web")
	var touch := OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if touch:
		hint.text = "Tap Resume to continue"
	resume_button.pressed.connect(func() -> void: toggle_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())


func show_menu() -> void:
	visible = true
	resume_button.grab_focus()


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_pause_event(event):
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
