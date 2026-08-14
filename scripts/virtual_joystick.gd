extends Control

## On-screen stick for touch / mobile browsers.
## Output is a Vector2 in [-1, 1]; deadzone applied.

signal vector_changed(vector: Vector2)

@export var base_radius: float = 72.0
@export var knoob_radius: float = 28.0
@export var deadzone: float = 0.12
@export var always_show: bool = false

var output: Vector2 = Vector2.ZERO

var _active: bool = false
var _pointer_id: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("virtual_joystick")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(base_radius * 2.0 + 16.0, base_radius * 2.0 + 16.0)
	_update_visibility()
	# Re-evaluate after the window is ready (web touch detection can lag).
	call_deferred("_update_visibility")
	queue_redraw()


func _update_visibility() -> void:
	# Always show on web so phones (and desktop browsers used for testing) get a stick.
	visible = always_show or OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	queue_redraw()


func get_vector() -> Vector2:
	return output


func _draw() -> void:
	if not visible:
		return
	var center := size * 0.5
	draw_circle(center, base_radius, Color(1, 1, 1, 0.12))
	draw_arc(center, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0, true)
	var knob_center := center + _knob_pos
	draw_circle(knob_center, knoob_radius, Color(0.85, 0.9, 1.0, 0.45 if _active else 0.28))


func _gui_input(event: InputEvent) -> void:
	# Only begin gestures inside the control; drag/release are tracked globally in
	# `_input` so left/down still work when the finger leaves the control rect
	# (common near screen edges).
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_begin(touch.index, touch.position)
			accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and not _active:
			_begin(-2, mouse.position)
			accept_event()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer_id:
			_update(_to_local(drag.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _pointer_id:
			_end()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_id == -2:
		_update(_to_local((event as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed and _pointer_id == -2:
			_end()
			get_viewport().set_input_as_handled()


func _to_local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos


func _begin(pointer_id: int, local_pos: Vector2) -> void:
	_active = true
	_pointer_id = pointer_id
	_origin = size * 0.5
	_update(local_pos)


func _update(local_pos: Vector2) -> void:
	var delta := local_pos - _origin
	var max_len := base_radius - knoob_radius * 0.35
	if delta.length() > max_len:
		delta = delta.normalized() * max_len
	_knob_pos = delta

	var raw := delta / max_len if max_len > 0.0 else Vector2.ZERO
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
	_knob_pos = Vector2.ZERO
	output = Vector2.ZERO
	vector_changed.emit(output)
	queue_redraw()
