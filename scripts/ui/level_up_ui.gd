extends CanvasLayer

signal choice_made(choice: Dictionary)

## Target on-screen sizes in CSS pixels (points) for phone / touch web.
const CSS_TITLE := 34.0
const CSS_SUBTITLE := 20.0
const CSS_CARD_TITLE := 26.0
const CSS_CARD_DESC := 20.0
const CSS_HINT := 17.0
## Centered mobile dialog size as a fraction of the viewport.
const MOBILE_PANEL_FRACTION := 0.75

@onready var dim: ColorRect = $Dim
@onready var root: MarginContainer = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var margin: MarginContainer = $Root/Panel/Margin
@onready var vbox: VBoxContainer = $Root/Panel/Margin/VBox
@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Root/Panel/Margin/VBox/Subtitle
@onready var cards: VBoxContainer = $Root/Panel/Margin/VBox/Cards
@onready var hint_label: Label = $Root/Panel/Margin/VBox/Hint

var _choices: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_apply_layout)
	hide_ui()
	for i in cards.get_child_count():
		var button := cards.get_child(i) as Button
		button.pressed.connect(_on_card_pressed.bind(i))
	_apply_layout()


func show_choices(choices: Array[Dictionary]) -> void:
	_choices = choices
	_apply_layout()
	visible = true
	for i in cards.get_child_count():
		var button := cards.get_child(i) as Button
		var choice: Dictionary = choices[i] if i < choices.size() else {}
		button.get_node("VBox/Title").text = str(choice.get("title", ""))
		button.get_node("VBox/Desc").text = str(choice.get("desc", ""))
		button.visible = i < choices.size()
	call_deferred("_apply_layout")
	if cards.get_child_count() > 0:
		(cards.get_child(0) as Button).grab_focus()


func hide_ui() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_pick(0)
			KEY_2:
				_pick(1)
			KEY_3:
				_pick(2)


func _on_card_pressed(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	if not visible or index < 0 or index >= _choices.size():
		return
	choice_made.emit(_choices[index])


func _window_css_size() -> Vector2:
	## On HiDPI web (iPhone), window_get_size() is device pixels. Divide by
	## screen_get_scale() (devicePixelRatio) to get CSS / layout points.
	var win := Vector2(DisplayServer.window_get_size())
	var dpr := maxf(DisplayServer.screen_get_scale(), 0.5)
	return win / dpr


func _is_compact_mobile_ui() -> bool:
	var css := _window_css_size()
	var short_side := mini(css.x, css.y)
	var touch := (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("mobile")
	)
	if short_side > 0.0 and short_side < 520.0:
		return true
	if touch and short_side > 0.0 and short_side < 720.0:
		return true
	if OS.has_feature("web") and touch:
		return true
	if OS.has_feature("mobile"):
		return true
	return false


func _vp_font_for_css(css_px: float) -> int:
	## Convert desired on-screen CSS px into a viewport font size.
	## Visual CSS ≈ font_vp * (css_short / vp_short).
	var css := _window_css_size()
	var vp := get_viewport().get_visible_rect().size
	var css_short := mini(css.x, css.y)
	var vp_short := mini(vp.x, vp.y)
	if css_short <= 1.0 or vp_short <= 1.0:
		return int(ceili(css_px * 2.2))
	var computed := int(ceili(css_px * vp_short / css_short))
	# If DPR was ignored, css_short is still device pixels and computed collapses.
	if computed < int(css_px * 1.35):
		return int(ceili(css_px * 2.2))
	return computed


func _apply_layout() -> void:
	if panel == null or root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var mobile := _is_compact_mobile_ui()

	if mobile:
		# Centered ~75% dialog — readable, but not edge-to-edge.
		var mx := int(round(vp.x * (1.0 - MOBILE_PANEL_FRACTION) * 0.5))
		var my := int(round(vp.y * (1.0 - MOBILE_PANEL_FRACTION) * 0.5))
		mx = maxi(mx, 8)
		my = maxi(my, 6)
		root.add_theme_constant_override("margin_left", mx)
		root.add_theme_constant_override("margin_top", my)
		root.add_theme_constant_override("margin_right", mx)
		root.add_theme_constant_override("margin_bottom", my)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2.ZERO
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		vbox.add_theme_constant_override("separation", 8)
		cards.add_theme_constant_override("separation", 12)
		var title_fs := _vp_font_for_css(CSS_TITLE)
		var sub_fs := _vp_font_for_css(CSS_SUBTITLE)
		var hint_fs := _vp_font_for_css(CSS_HINT)
		var card_title_fs := _vp_font_for_css(CSS_CARD_TITLE)
		var card_desc_fs := _vp_font_for_css(CSS_CARD_DESC)
		_set_label_style(title_label, title_fs, Color(0.95, 0.82, 0.4, 1), true)
		_set_label_style(subtitle_label, sub_fs, Color(0.92, 0.88, 0.78, 1), true)
		_set_label_style(hint_label, hint_fs, Color(0.85, 0.8, 0.62, 0.95), true)
		hint_label.text = "Tap a blessing to continue"
		var header_budget := float(title_fs + sub_fs + hint_fs + 40)
		var usable_h := maxf(200.0, vp.y - float(my * 2))
		# Fit cards into the 75% panel; don't force taller than available space.
		var card_h := maxf(0.0, (usable_h - header_budget) / 3.0)
		for button in cards.get_children():
			_style_card(button as Button, true, card_h, card_title_fs, card_desc_fs)
	else:
		# Desktop: keep a comfortable centered dialog with a horizontal card row.
		# Rebuild isn't needed — place cards in a wide inset panel.
		var dialog_w := mini(920.0, vp.x * 0.85)
		var dialog_h := mini(460.0, vp.y * 0.75)
		var mx := int(maxf(0.0, (vp.x - dialog_w) * 0.5))
		var my := int(maxf(0.0, (vp.y - dialog_h) * 0.5))
		root.add_theme_constant_override("margin_left", mx)
		root.add_theme_constant_override("margin_top", my)
		root.add_theme_constant_override("margin_right", mx)
		root.add_theme_constant_override("margin_bottom", my)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2.ZERO
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 16)
		vbox.add_theme_constant_override("separation", 12)
		cards.add_theme_constant_override("separation", 12)
		_set_label_style(title_label, 26, Color(0.95, 0.82, 0.4, 1), false)
		_set_label_style(subtitle_label, 14, Color(1, 1, 1, 1), false)
		_set_label_style(hint_label, 12, Color(0.8, 0.74, 0.55, 0.85), false)
		hint_label.text = "Tap a card or press 1 / 2 / 3"
		for button in cards.get_children():
			_style_card(button as Button, false, 150.0, 18, 13)


func _set_label_style(label: Label, font_size: int, color: Color, outline: bool) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline:
		var outline_size := maxi(3, int(round(float(font_size) * 0.12)))
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	else:
		label.add_theme_constant_override("outline_size", 0)


func _style_card(
	button: Button,
	mobile: bool,
	card_height: float,
	title_fs: int,
	desc_fs: int
) -> void:
	if button == null:
		return
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0 if mobile else 200, card_height)

	var card_vbox := button.get_node_or_null("VBox") as VBoxContainer
	if card_vbox == null:
		return
	card_vbox.add_theme_constant_override("separation", 8 if mobile else 8)
	if mobile:
		card_vbox.offset_left = 16.0
		card_vbox.offset_top = 12.0
		card_vbox.offset_right = -16.0
		card_vbox.offset_bottom = -12.0
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		card_vbox.offset_left = 10.0
		card_vbox.offset_top = 10.0
		card_vbox.offset_right = -10.0
		card_vbox.offset_bottom = -10.0
		card_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var card_title := card_vbox.get_node_or_null("Title") as Label
	var card_desc := card_vbox.get_node_or_null("Desc") as Label
	if card_title:
		_set_label_style(card_title, title_fs, Color(0.98, 0.9, 0.55, 1), mobile)
		card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if card_desc:
		_set_label_style(
			card_desc,
			desc_fs,
			Color(0.95, 0.92, 0.85, 1) if mobile else Color(1, 1, 1, 1),
			mobile
		)
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
