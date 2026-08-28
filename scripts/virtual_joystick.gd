extends Control

## Touch-anywhere movement for phones and real touchscreens.
## Press sets the movement origin; drag until release aims relative to that point.
## The corner widget is a direction indicator only (not the touch target).
## Desktop browsers use WASD / arrows — mouse is not treated as a stick.

signal vector_changed(vector: Vector2)

@export var base_radius: float = 72.0
@export var knoob_radius: float = 28.0
@export var deadzone: float = 0.12
## Viewport pixels of drag that map to full deflection.
@export var max_drag: float = 100.0
@export var always_show: bool = false

var output: Vector2 = Vector2.ZERO

var _active: bool = false
var _pointer_id: int = -1
## Touch origin in viewport coordinates.
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("virtual_joystick")
	# Visual only — touches are handled globally so any screen location works.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(base_radius * 2.0 + 16.0, base_radius * 2.0 + 16.0)
	_update_visibility()
	# Re-evaluate after the window is ready (web touch detection can lag).
	call_deferred("_update_visibility")
	queue_redraw()


func _is_desktop_web() -> bool:
	if not OS.has_feature("web"):
		return false
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return false
	return true


func _update_visibility() -> void:
	if _is_desktop_web():
		visible = always_show
	else:
		visible = (
			always_show
			or DisplayServer.is_touchscreen_available()
			or OS.has_feature("mobile")
			or OS.has_feature("web_android")
			or OS.has_feature("web_ios")
		)
	queue_redraw()


func get_vector() -> Vector2:
	return output


func _draw() -> void:
	if not visible:
		return
	var center := size * 0.5
	draw_circle(center, base_radius, Color(1, 1, 1, 0.12))
	draw_arc(center, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0, true)
	var visual_reach := base_radius - knoob_radius * 0.35
	var knob_center := center + output * visual_reach
	draw_circle(knob_center, knoob_radius, Color(0.85, 0.9, 1.0, 0.45 if _active else 0.28))


func _input(event: InputEvent) -> void:
	# Hidden on end-screen; skipped while paused so level-up buttons keep working.
	# Desktop browsers are keyboard-only so a mouse click cannot start a stick drag.
	if not visible or get_tree().paused or _is_desktop_web():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_begin(touch.index, touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _pointer_id:
			_end()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _pointer_id:
			_update(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and not _active:
			_begin(-2, mouse.position)
			get_viewport().set_input_as_handled()
		elif not mouse.pressed and _pointer_id == -2:
			_end()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _active and _pointer_id == -2:
		_update((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _begin(pointer_id: int, viewport_pos: Vector2) -> void:
	_active = true
	_pointer_id = pointer_id
	_origin = viewport_pos
	output = Vector2.ZERO
	vector_changed.emit(output)
	queue_redraw()


func _update(viewport_pos: Vector2) -> void:
	var delta := viewport_pos - _origin
	var reach := maxf(max_drag, 1.0)
	var raw := delta / reach
	if raw.length() > 1.0:
		raw = raw.normalized()

	if raw.length() < deadzone:
		output = Vector2.ZERO
	else:
		# Rescale so leaving the deadzone maps smoothly to full range.
		output = raw.normalized() * clampf((raw.length() - deadzone) / (1.0 - deadzone), 0.0, 1.0)

	vector_changed.emit(output)
	queue_redraw()


func _end() -> void:
	_active = false
	_pointer_id = -1
	_origin = Vector2.ZERO
	output = Vector2.ZERO
	vector_changed.emit(output)
	queue_redraw()
