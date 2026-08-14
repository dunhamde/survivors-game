extends CanvasLayer

signal choice_made(choice: Dictionary)

@onready var dim: ColorRect = $Dim
@onready var center: CenterContainer = $Center
@onready var panel: PanelContainer = $Center/Panel
@onready var margin: MarginContainer = $Center/Panel/Margin
@onready var vbox: VBoxContainer = $Center/Panel/Margin/VBox
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var cards: GridContainer = $Center/Panel/Margin/VBox/Cards
@onready var hint_label: Label = $Center/Panel/Margin/VBox/Hint

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


func _is_compact_mobile_ui() -> bool:
	## iPhone / small touch screens: window CSS pixels are far smaller than the
	## 1280x720 game viewport, so fixed dialog sizes become hard to read.
	var win := DisplayServer.window_get_size()
	var short_side := mini(win.x, win.y)
	if short_side <= 0:
		return OS.has_feature("mobile")
	# Phone-class CSS short edge (iPhone landscape is typically ~320–430).
	if short_side < 500:
		return true
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	# Larger phones / small tablets with touch still need bigger type.
	return touch and short_side < 600


func _apply_layout() -> void:
	if panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var mobile := _is_compact_mobile_ui()

	if mobile:
		# Nearly full-screen panel so cards use the phone display.
		# Fonts are oversized in viewport space because iPhone canvas scale is ~0.5x.
		# Stack cards vertically so each blessing gets full width and readable type.
		panel.custom_minimum_size = Vector2(vp.x * 0.96, vp.y * 0.94)
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 12)
		vbox.add_theme_constant_override("separation", 10)
		cards.columns = 1
		cards.add_theme_constant_override("h_separation", 12)
		cards.add_theme_constant_override("v_separation", 12)
		_set_label_style(title_label, 44, Color(0.95, 0.82, 0.4, 1), true)
		_set_label_style(subtitle_label, 26, Color(0.92, 0.88, 0.78, 1), true)
		_set_label_style(hint_label, 22, Color(0.85, 0.8, 0.62, 0.95), true)
		hint_label.text = "Tap a blessing to continue"
		for button in cards.get_children():
			_style_card(button as Button, true)
	else:
		panel.custom_minimum_size = Vector2.ZERO
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 16)
		vbox.add_theme_constant_override("separation", 12)
		cards.columns = 3
		cards.add_theme_constant_override("h_separation", 12)
		cards.add_theme_constant_override("v_separation", 12)
		_set_label_style(title_label, 26, Color(0.95, 0.82, 0.4, 1), false)
		_set_label_style(subtitle_label, 14, Color(1, 1, 1, 1), false)
		_set_label_style(hint_label, 12, Color(0.8, 0.74, 0.55, 0.85), false)
		hint_label.text = "Tap a card or press 1 / 2 / 3"
		for button in cards.get_children():
			_style_card(button as Button, false)


func _set_label_style(label: Label, font_size: int, color: Color, outline: bool) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline:
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	else:
		label.add_theme_constant_override("outline_size", 0)


func _style_card(button: Button, mobile: bool) -> void:
	if button == null:
		return
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if mobile:
		# Wide full-width rows; height shared across the three stacked cards.
		button.custom_minimum_size = Vector2(0, 140)
	else:
		button.custom_minimum_size = Vector2(200, 160)

	var card_vbox := button.get_node_or_null("VBox") as VBoxContainer
	if card_vbox == null:
		return
	card_vbox.add_theme_constant_override("separation", 8 if mobile else 8)
	if mobile:
		card_vbox.offset_left = 18.0
		card_vbox.offset_top = 12.0
		card_vbox.offset_right = -18.0
		card_vbox.offset_bottom = -12.0
	else:
		card_vbox.offset_left = 10.0
		card_vbox.offset_top = 10.0
		card_vbox.offset_right = -10.0
		card_vbox.offset_bottom = -10.0

	var card_title := card_vbox.get_node_or_null("Title") as Label
	var card_desc := card_vbox.get_node_or_null("Desc") as Label
	if card_title:
		_set_label_style(
			card_title,
			32 if mobile else 18,
			Color(0.98, 0.9, 0.55, 1),
			mobile
		)
		card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if card_desc:
		_set_label_style(
			card_desc,
			26 if mobile else 13,
			Color(0.95, 0.92, 0.85, 1) if mobile else Color(1, 1, 1, 1),
			mobile
		)
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
