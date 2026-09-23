@tool
extends Control

signal demo_requested

const Catalog := preload("res://addons/weapon_lab/catalog.gd")
const ArtView := preload("res://addons/weapon_lab/art_view.gd")
var catalog: Array[WeaponData] = []
var parts: Array[Dictionary] = []
var weapon_option: OptionButton
var component_option: OptionButton
var level_spin: SpinBox
var background_option: OptionButton
var facing_option: OptionButton
var views: Array = []
var info: Label
var source_button: Button
var demo_button: Button
var _loading := false


func _ready() -> void:
	custom_minimum_size = Vector2(700, 320)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var visual := VBoxContainer.new()
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(visual)
	var top := HBoxContainer.new()
	visual.add_child(top)
	var title := Label.new()
	title.text = "Inspect Art"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var zoom := OptionButton.new()
	for value in [2, 4, 8]:
		zoom.add_item("Detail %sx" % value)
	zoom.select(1)
	zoom.item_selected.connect(func(index: int) -> void:
		views[1].zoom = [2.0, 4.0, 8.0][index]
		views[1].layout())
	top.add_child(zoom)
	var view_row := HBoxContainer.new()
	view_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual.add_child(view_row)
	for index in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view_row.add_child(column)
		var label := Label.new()
		label.text = "Gameplay reference · camera 1.75x" if index == 0 else "Magnified detail"
		column.add_child(label)
		var view := ArtView.new()
		view.zoom = 1.75 if index == 0 else 4.0
		column.add_child(view)
		views.append(view)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	scroll.add_child(controls)
	weapon_option = _option(controls, "Weapon", [])
	weapon_option.item_selected.connect(_select_weapon)
	component_option = _option(controls, "Component", [])
	component_option.item_selected.connect(func(_i: int) -> void: _refresh())
	var level_label := Label.new()
	level_label.text = "Weapon level"
	controls.add_child(level_label)
	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.step = 1
	level_spin.value = 1
	level_spin.value_changed.connect(func(_v: float) -> void: _refresh())
	controls.add_child(level_spin)
	background_option = _option(controls, "Background", ["Checkerboard", "Dark", "Elwynn grass"])
	background_option.select(2)
	background_option.item_selected.connect(func(_i: int) -> void: _refresh())
	facing_option = _option(controls, "Facing", Catalog.DIRECTIONS)
	facing_option.item_selected.connect(func(_i: int) -> void: _refresh())
	var show_player := CheckBox.new()
	show_player.text = "Show Paladin for scale"
	show_player.button_pressed = true
	show_player.toggled.connect(func(enabled: bool) -> void:
		for view in views:
			view.paladin.visible = enabled)
	controls.add_child(show_player)
	source_button = _button(controls, "Open Art Source", _open_source)
	_button(controls, "Open Weapon Scene", _open_scene)
	_button(controls, "Reload Art / Catalog", reload_art)
	demo_button = _button(controls, "Launch Combat Demo", _launch)
	demo_button.tooltip_text = "Runs the selected weapon in a dedicated test scene. Enable Embed Game on Next Play to keep it inside Godot."
	reload_art()


func _option(parent: Node, label_text: String, options: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	for text in options:
		option.add_item(str(text))
	parent.add_child(option)
	return option


func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func reload_art() -> void:
	if weapon_option == null:
		return
	var previous := "res://data/weapons/avenger_shield.tres"
	if not catalog.is_empty() and weapon_option.selected >= 0:
		previous = catalog[weapon_option.selected].resource_path
	WeaponArt.clear_cache()
	catalog = Catalog.discover()
	weapon_option.clear()
	var selected := 0
	for i in catalog.size():
		weapon_option.add_item(catalog[i].display_name)
		if catalog[i].resource_path == previous:
			selected = i
	if catalog.is_empty():
		info.text = "No WeaponData resources found in data/weapons."
		demo_button.disabled = true
		return
	weapon_option.select(selected)
	_select_weapon(selected)


func _select_weapon(index: int) -> void:
	_loading = true
	var data := catalog[index]
	level_spin.max_value = data.max_level
	level_spin.value = clampi(int(level_spin.value), 1, data.max_level)
	parts = Catalog.components(data)
	component_option.clear()
	for part in parts:
		component_option.add_item(part.name)
	_loading = false
	_refresh()


func _refresh() -> void:
	if _loading or catalog.is_empty():
		return
	var data := catalog[weapon_option.selected]
	source_button.disabled = parts.is_empty()
	if parts.is_empty():
		for view in views:
			if is_instance_valid(view.weapon_sprite):
				view.weapon_sprite.hide()
		info.text = "No inspection components registered yet. Combat Demo uses this weapon's real scene."
		return
	var part := parts[maxi(0, component_option.selected)]
	for view in views:
		view.show_part(part, data, int(level_spin.value))
		view.set_background(background_option.selected)
		view.set_facing(facing_option.selected)
	var tex: Texture2D = views[0].weapon_sprite.texture
	info.text = "%s · %s×%s source pixels\n%s" % [data.display_name, tex.get_width(), tex.get_height(), part.source]
	if part.kind in ["ribbon", "burst"]:
		info.text += "\nSource texture only. Review the assembled lightning in Combat Demo."
	elif part.kind in ["ground", "wave"]:
		info.text += "\nFixed shader snapshot. Review the complete pulse in Combat Demo."
	info.text += "\nDrag a view to pan; double-click to recenter."


func _open_source() -> void:
	if parts.is_empty() or not Engine.is_editor_hint():
		return
	var path: String = parts[maxi(0, component_option.selected)].source
	EditorInterface.edit_resource(load(path))
	EditorInterface.get_file_system_dock().navigate_to_path(path)


func _open_scene() -> void:
	if not catalog.is_empty() and Engine.is_editor_hint():
		EditorInterface.open_scene_from_path(catalog[weapon_option.selected].scene.resource_path)


func _launch() -> void:
	if catalog.is_empty():
		return
	Catalog.save_settings({"weapon": catalog[weapon_option.selected].resource_path,
		"level": int(level_spin.value), "facing": facing_option.selected,
		"background": background_option.selected})
	demo_requested.emit()
