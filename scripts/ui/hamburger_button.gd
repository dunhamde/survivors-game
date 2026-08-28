class_name HamburgerButton
extends Button

## Small top-left pause control for touch / mobile web.

const CSS_SIZE := 44.0
const CSS_MARGIN := 8.0

var enabled: bool = true


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	flat = true
	text = ""
	add_to_group("hud_touch_blockers")
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	call_deferred("_apply_layout")


func set_enabled(value: bool) -> void:
	enabled = value
	_apply_layout()


func occupied_left_margin() -> int:
	if not visible:
		return 16
	return maxi(16, int(round(offset_right)) + 8)


func _is_touch_ui() -> bool:
	return OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _window_css_size() -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	var dpr := maxf(DisplayServer.screen_get_scale(), 0.5)
	return win / dpr


func _vp_for_css(css_px: float) -> int:
	var css := _window_css_size()
	var vp := get_viewport().get_visible_rect().size
	var css_short := mini(css.x, css.y)
	var vp_short := mini(vp.x, vp.y)
	if css_short <= 1.0 or vp_short <= 1.0:
		return int(ceili(css_px * 2.2))
	var computed := int(ceili(css_px * vp_short / css_short))
	if computed < int(css_px * 1.35):
		return int(ceili(css_px * 2.2))
	return computed


func _apply_layout() -> void:
	visible = enabled and _is_touch_ui()
	if not visible:
		return
	var side := _vp_for_css(CSS_SIZE)
	var margin := _vp_for_css(CSS_MARGIN)
	custom_minimum_size = Vector2(side, side)
	offset_left = float(margin)
	offset_top = float(margin)
	offset_right = float(margin + side)
	offset_bottom = float(margin + side)
	queue_redraw()


func _draw() -> void:
	var bg := Color(0.12, 0.08, 0.04, 0.88)
	if is_pressed():
		bg = Color(0.22, 0.16, 0.08, 0.94)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.65, 0.22, 1), false, 2.0)
	var pad := size.x * 0.24
	var line_h := maxf(2.5, size.y * 0.09)
	var inner := size.y - pad * 2.0
	var gap := (inner - line_h * 3.0) / 2.0
	var color := Color(0.95, 0.86, 0.5, 1)
	var width := size.x - pad * 2.0
	for i in 3:
		var y := pad + float(i) * (line_h + gap)
		draw_rect(Rect2(pad, y, width, line_h), color)
