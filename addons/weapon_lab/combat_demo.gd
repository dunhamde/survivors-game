extends Control

const Catalog := preload("res://addons/weapon_lab/catalog.gd")
const Actor := preload("res://addons/weapon_lab/lab_actor.gd")
const Backdrop := preload("res://addons/weapon_lab/backdrop.gd")
const Overlays := preload("res://addons/weapon_lab/overlays.gd")

var catalog: Array[WeaponData] = []
var weapon: WeaponBase
var player: CharacterBody2D
var arena: Node2D
var backdrop: Node2D
var overlay: Node2D
var viewport: SubViewport
var weapon_option: OptionButton
var level_spin: SpinBox
var layout_option: OptionButton
var facing_option: OptionButton
var background_option: OptionButton
var zoom_option: OptionButton
var loop_toggle: CheckBox
var pause_button: Button
var fire_button: Button
var freeze_toggle: CheckBox
var status: Label
var _armed := true
var _loading := false
var _speed := 1.0
var _elapsed := 0.0
var _camera: Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	catalog = Catalog.discover()
	_build_ui()
	var settings := Catalog.read_settings()
	_loading = true
	for i in catalog.size():
		weapon_option.add_item(catalog[i].display_name)
		if catalog[i].resource_path == settings.get("weapon", "res://data/weapons/avenger_shield.tres"):
			weapon_option.select(i)
	facing_option.select(clampi(int(settings.get("facing", 0)), 0, 7))
	background_option.select(clampi(int(settings.get("background", 2)), 0, 2))
	if not catalog.is_empty():
		level_spin.max_value = catalog[weapon_option.selected].max_level
		level_spin.value = clampi(int(settings.get("level", 1)), 1, int(level_spin.max_value))
	_loading = false
	restart()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var visual := VBoxContainer.new()
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(visual)
	var title := Label.new()
	title.text = "WEAPON LAB  /  Combat Demo"
	title.add_theme_font_size_override("font_size", 22)
	visual.add_child(title)
	var host := SubViewportContainer.new()
	host.stretch = true
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.add_child(host)
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.world_2d = World2D.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	scroll.add_child(controls)
	weapon_option = _option(controls, "Weapon", [])
	weapon_option.item_selected.connect(func(_index: int) -> void:
		_loading = true
		level_spin.max_value = catalog[weapon_option.selected].max_level
		level_spin.value = mini(int(level_spin.value), int(level_spin.max_value))
		_loading = false
		restart())
	_label(controls, "Level")
	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 5
	level_spin.step = 1
	level_spin.value_changed.connect(func(_value: float) -> void: restart())
	controls.add_child(level_spin)
	layout_option = _option(controls, "Targets", ["Single target", "Bounce chain", "Crowded group"])
	layout_option.select(1)
	layout_option.item_selected.connect(func(_i: int) -> void: restart())
	facing_option = _option(controls, "Facing / target direction", Catalog.DIRECTIONS)
	facing_option.item_selected.connect(func(_i: int) -> void: restart())
	background_option = _option(controls, "Background", ["Checkerboard", "Dark", "Elwynn grass"])
	background_option.select(2)
	background_option.item_selected.connect(func(index: int) -> void:
		if is_instance_valid(backdrop):
			backdrop.mode = index
			backdrop.queue_redraw())
	zoom_option = _option(controls, "Camera zoom", ["1x", "Gameplay · 1.75x", "2x", "4x"])
	zoom_option.select(1)
	zoom_option.item_selected.connect(func(_i: int) -> void: _update_zoom())
	var speed := _option(controls, "Playback speed", ["0.1x", "0.25x", "0.5x", "1x"])
	speed.select(3)
	speed.item_selected.connect(func(index: int) -> void:
		_speed = [0.1, 0.25, 0.5, 1.0][index]
		Engine.time_scale = _speed)
	loop_toggle = _check(controls, "Loop attacks", true)
	loop_toggle.toggled.connect(func(enabled: bool) -> void:
		if enabled and is_instance_valid(weapon):
			weapon.cooldown = 0.0)
	var playback := HBoxContainer.new()
	controls.add_child(playback)
	fire_button = _button(playback, "Fire once", fire_once)
	pause_button = _button(playback, "Pause", func() -> void: set_paused(not get_tree().paused))
	_button(controls, "Restart demo", restart)
	_button(controls, "Reload art / restart", _reload_art)
	freeze_toggle = _check(controls, "Freeze rotation (diagnostic)", false)
	freeze_toggle.tooltip_text = "Keeps shield and libram art upright. Travel, orbits, and collision shapes are unchanged."
	var collisions := _check(controls, "Collision outlines", false)
	collisions.toggled.connect(func(enabled: bool) -> void:
		if is_instance_valid(overlay):
			overlay.show_collisions = enabled
			overlay.queue_redraw())
	var targets := _check(controls, "Target markers / hit counts", true)
	targets.toggled.connect(func(enabled: bool) -> void:
		if is_instance_valid(overlay):
			overlay.show_targets = enabled
			overlay.queue_redraw())
	# Preserve diagnostic choices when rebuilding the arena.
	collisions.name = "CollisionToggle"
	targets.name = "TargetToggle"
	var note := _label(controls, "Targets stay in place and never die.\nOrbiting weapons remain active.\nFor code edits, stop and relaunch the demo.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _option(parent: Node, title: String, options: Array) -> OptionButton:
	_label(parent, title)
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	for text in options:
		option.add_item(str(text))
	parent.add_child(option)
	return option


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _check(parent: Node, text: String, enabled: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = enabled
	parent.add_child(check)
	return check


func restart() -> void:
	if _loading or catalog.is_empty():
		return
	set_paused(false)
	if is_instance_valid(arena):
		arena.free()
	seed(18491)
	_elapsed = 0.0
	_armed = true
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.add_to_group("entities")
	viewport.add_child(arena)
	backdrop = Backdrop.new()
	backdrop.mode = background_option.selected
	backdrop.extent = Vector2(1600, 1000)
	backdrop.z_index = -100
	arena.add_child(backdrop)
	_camera = Camera2D.new()
	_camera.position = Vector2(30, -5)
	arena.add_child(_camera)
	_update_zoom()
	player = Actor.new()
	player.facing = Vector2.from_angle(facing_option.selected * PI / 4.0)
	arena.add_child(player)
	var data := catalog[weapon_option.selected]
	var radius := data.base_area + data.area_per_level * (level_spin.value - 1)
	var family := data.scene.resource_path.get_file().get_basename()
	_spawn_targets(family, radius)
	weapon = data.scene.instantiate() as WeaponBase
	player.add_child(weapon)
	weapon.level = int(level_spin.value)
	weapon.setup(data, player)
	# Drive only the equipped weapon here, leaving its real child/projectile scripts
	# to the engine. INF suppresses new casts while existing effects finish.
	weapon.set_physics_process(false)
	overlay = Overlays.new()
	overlay.arena = arena
	overlay.z_index = 100
	overlay.show_collisions = (find_child("CollisionToggle", true, false) as CheckBox).button_pressed
	overlay.show_targets = (find_child("TargetToggle", true, false) as CheckBox).button_pressed
	arena.add_child(overlay)
	var persistent := family == "libram_of_the_light"
	fire_button.disabled = persistent
	fire_button.tooltip_text = "Orbiting weapons remain active; use Pause or Restart." if persistent else "Starts one volley or pulse; existing effects finish naturally."
	freeze_toggle.disabled = family not in ["avenger_shield", "libram_of_the_light"]


func _spawn_targets(family: String, radius: float) -> void:
	var count: int = [1, 5, 9][layout_option.selected]
	var radial := family in ["consecration", "divine_storm", "libram_of_the_light"]
	for i in count:
		var dummy := Actor.new()
		dummy.is_dummy = true
		var at: Vector2
		if radial:
			var distance := radius if family == "libram_of_the_light" else radius * 0.58
			at = Vector2.from_angle(TAU * i / count) * distance
		elif layout_option.selected == 2:
			at = Vector2(80 + (i % 3) * 26, (int(i / 3) - 1) * 26)
		else:
			at = Vector2(80 + i * 30, 0 if i < 3 else (i % 2 * 2 - 1) * 26)
		dummy.position = at.rotated(player.facing.angle())
		dummy.facing = -player.facing
		arena.add_child(dummy)


func _update_zoom() -> void:
	if is_instance_valid(_camera):
		_camera.zoom = Vector2.ONE * [1.0, 1.75, 2.0, 4.0][zoom_option.selected]


func fire_once() -> void:
	loop_toggle.set_pressed_no_signal(false)
	_armed = true
	if is_instance_valid(weapon):
		weapon.cooldown = 0.0
	set_paused(false)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_button.text = "Resume" if paused else "Pause"


func _physics_process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(weapon):
		return
	_elapsed += delta
	if not loop_toggle.button_pressed and not _armed:
		weapon.cooldown = INF
	weapon.call("_physics_process", delta)
	if _armed and weapon.cooldown > 0.0:
		_armed = false
	_freeze_visual_rotation()
	overlay.queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(weapon):
		return
	_freeze_visual_rotation()
	status.text = "%s · Level %s · %.2fs · %sx speed · %s damage\n%s" % [
		weapon.data.display_name, weapon.level, _elapsed, _speed, weapon.damage_dealt,
		"Paused — effects and lifetimes are frozen." if get_tree().paused else weapon.data.description]


func _freeze_visual_rotation() -> void:
	for node in arena.get_children():
		if node.get_script() == null:
			continue
		var path: String = node.get_script().resource_path
		if path.ends_with("avenger_shield_proj.gd") or path.ends_with("libram_orb.gd"):
			for child in node.get_children():
				if child is Sprite2D:
					child.rotation = -node.rotation if freeze_toggle.button_pressed else 0.0


func _reload_art() -> void:
	WeaponArt.clear_cache()
	Catalog.CONSECRATION._pack = null
	Catalog.CONSECRATION._white = null
	Catalog.LIGHTNING._add_mat = null
	# Image/shader resources are replaced in-place, so existing references stay valid.
	for data in catalog:
		for part in Catalog.components(data):
			var path: String = part.source
			if not path.ends_with(".gd"):
				ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	restart()
