@tool
extends Control

const ELWYNN_GREEN := Color(0.12, 0.18, 0.1, 1.0)
const DIR_LABELS := [
	["NW", "N", "NE"],
	["W", "", "E"],
	["SW", "S", "SE"],
]
# Grid cell -> octant (E=0 ... NE=7). Empty center is unused.
const DIR_OCTANTS := [
	[5, 6, 7],
	[4, -1, 0],
	[3, 2, 1],
]
const STATE_NAMES := ["Idle", "Walk", "Attack", "Hit", "Death"]
const ZOOM_LEVELS := [2, 4, 8]

var _anim: SheetAnimator
var _char_index: int = 0
var _data_path: String = ""
var _zoom: int = 4
var _octant: int = 2

var _viewport: SubViewport
var _world: Node2D
var _sprite: Sprite2D
var _bg: ColorRect
var _ground: ColorRect
var _hud: Label
var _char_option: OptionButton
var _zoom_option: OptionButton
var _attack_btn: Button
var _play_btn: Button
var _loop_btn: CheckBox
var _state_buttons: Array[Button] = []
var _dir_buttons: Dictionary = {}


func _ready() -> void:
	set_process(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_character(0)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _anim == null:
		return
	_anim.tick_preview(delta)
	_update_hud()
	_layout_world()


func on_resources_reimported(files: PackedStringArray) -> void:
	var watch: Array[String] = []
	if _data_path != "":
		watch.append(_data_path)
	if _anim != null and _anim.texture != null:
		watch.append(_anim.texture.resource_path)
	for path in files:
		if path in watch:
			_load_character(_char_index)
			return


func _build_ui() -> void:
	if _viewport != null:
		return
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var view_col := VBoxContainer.new()
	view_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_col.add_theme_constant_override("separation", 6)
	root.add_child(view_col)

	var vp_container := SubViewportContainer.new()
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.stretch = true
	vp_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp_container.custom_minimum_size = Vector2(320, 200)
	view_col.add_child(vp_container)

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.size = Vector2i(480, 220)
	vp_container.add_child(_viewport)

	_bg = ColorRect.new()
	_bg.color = ELWYNN_GREEN
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_bg)

	_world = Node2D.new()
	_viewport.add_child(_world)

	_ground = ColorRect.new()
	_ground.color = Color(0.22, 0.32, 0.16, 1.0)
	_ground.size = Vector2(120, 2)
	_ground.position = Vector2(-60, 0)
	_world.add_child(_ground)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(_sprite)

	_hud = Label.new()
	_hud.text = ""
	_hud.autowrap_mode = TextServer.AUTOWRAP_OFF
	view_col.add_child(_hud)

	var ctrl := VBoxContainer.new()
	ctrl.custom_minimum_size = Vector2(260, 0)
	ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ctrl.add_theme_constant_override("separation", 8)
	root.add_child(ctrl)

	ctrl.add_child(_make_label("Character"))
	_char_option = OptionButton.new()
	for entry in _catalog():
		_char_option.add_item(entry["name"])
	_char_option.item_selected.connect(_load_character)
	ctrl.add_child(_char_option)

	ctrl.add_child(_make_label("Zoom"))
	_zoom_option = OptionButton.new()
	for z in ZOOM_LEVELS:
		_zoom_option.add_item("%sx" % z)
	_zoom_option.select(ZOOM_LEVELS.find(_zoom))
	_zoom_option.item_selected.connect(_on_zoom_selected)
	ctrl.add_child(_zoom_option)

	ctrl.add_child(_make_label("Direction"))
	var dir_grid := GridContainer.new()
	dir_grid.columns = 3
	dir_grid.add_theme_constant_override("h_separation", 4)
	dir_grid.add_theme_constant_override("v_separation", 4)
	ctrl.add_child(dir_grid)
	for row in 3:
		for col in 3:
			var octant: int = DIR_OCTANTS[row][col]
			if octant < 0:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(44, 28)
				dir_grid.add_child(spacer)
				continue
			var btn := Button.new()
			btn.text = DIR_LABELS[row][col]
			btn.custom_minimum_size = Vector2(44, 28)
			btn.toggle_mode = true
			btn.pressed.connect(_on_dir_pressed.bind(octant))
			dir_grid.add_child(btn)
			_dir_buttons[octant] = btn

	ctrl.add_child(_make_label("State"))
	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 4)
	ctrl.add_child(state_row)
	for i in STATE_NAMES.size():
		var btn := Button.new()
		btn.text = STATE_NAMES[i]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_state_pressed.bind(i))
		state_row.add_child(btn)
		_state_buttons.append(btn)
		if i == SheetAnimator.State.ATTACK:
			_attack_btn = btn

	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 6)
	ctrl.add_child(play_row)
	_play_btn = Button.new()
	_play_btn.toggle_mode = true
	_play_btn.button_pressed = true
	_play_btn.text = "Pause"
	_play_btn.pressed.connect(_on_play_toggled)
	play_row.add_child(_play_btn)
	var step_btn := Button.new()
	step_btn.text = "Step"
	step_btn.pressed.connect(_on_step)
	play_row.add_child(step_btn)
	_loop_btn = CheckBox.new()
	_loop_btn.text = "Loop"
	_loop_btn.button_pressed = true
	_loop_btn.toggled.connect(_on_loop_toggled)
	play_row.add_child(_loop_btn)
	var reload_btn := Button.new()
	reload_btn.text = "Reload"
	reload_btn.pressed.connect(func() -> void: _load_character(_char_index))
	play_row.add_child(reload_btn)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _catalog() -> Array:
	return [
		{"id": "paladin", "name": "Paladin", "data": ""},
		{"id": "skeleton", "name": "Skeleton", "data": "res://data/enemies/skeleton.tres"},
		{"id": "grunt", "name": "Grunt", "data": "res://data/enemies/grunt.tres"},
		{"id": "ogre", "name": "Ogre", "data": "res://data/enemies/ogre.tres"},
		{"id": "hogger", "name": "Hogger", "data": "res://data/enemies/hogger.tres"},
	]


func _load_character(index: int) -> void:
	_char_index = clampi(index, 0, _catalog().size() - 1)
	if _char_option != null and _char_option.selected != _char_index:
		_char_option.select(_char_index)
	var entry: Dictionary = _catalog()[_char_index]
	_data_path = str(entry.get("data", ""))
	if _data_path == "":
		_anim = SheetAnimator.from_player_defaults()
	else:
		var data := load(_data_path) as EnemyData
		if data == null:
			push_warning("Anim Preview: failed to load %s" % _data_path)
			return
		_anim = SheetAnimator.from_enemy_data(data)
	_anim.bind(_sprite, _sprite)
	_anim.apply_layout()
	_anim.preview_playing = _play_btn.button_pressed if _play_btn != null else true
	_anim.preview_looping = _loop_btn.button_pressed if _loop_btn != null else true
	if _attack_btn != null:
		_attack_btn.disabled = not _anim.has_attack()
	_anim.set_facing_octant(_octant)
	_anim.play_preview(SheetAnimator.State.IDLE)
	_sync_dir_buttons()
	_sync_state_buttons()
	_layout_world()
	_update_hud()


func _on_dir_pressed(octant: int) -> void:
	if _anim == null:
		return
	_octant = octant
	_anim.set_facing_octant(octant)
	_anim.play_preview(_anim.preview_state)
	_sync_dir_buttons()


func _on_state_pressed(state: int) -> void:
	if _anim == null:
		return
	if state == SheetAnimator.State.ATTACK and not _anim.has_attack():
		_sync_state_buttons()
		return
	_anim.play_preview(state)
	_sync_state_buttons()


func _on_play_toggled() -> void:
	if _anim == null:
		return
	_anim.preview_playing = _play_btn.button_pressed
	_play_btn.text = "Pause" if _anim.preview_playing else "Play"


func _on_loop_toggled(pressed: bool) -> void:
	if _anim == null:
		return
	_anim.preview_looping = pressed


func _on_step() -> void:
	if _anim == null:
		return
	_play_btn.set_pressed_no_signal(false)
	_play_btn.text = "Play"
	_anim.step_preview()
	_update_hud()


func _on_zoom_selected(index: int) -> void:
	_zoom = ZOOM_LEVELS[clampi(index, 0, ZOOM_LEVELS.size() - 1)]
	_layout_world()


func _sync_dir_buttons() -> void:
	for octant in _dir_buttons:
		var btn: Button = _dir_buttons[octant]
		btn.set_pressed_no_signal(int(octant) == _octant)


func _sync_state_buttons() -> void:
	for i in _state_buttons.size():
		_state_buttons[i].set_pressed_no_signal(i == _anim.preview_state)


func _layout_world() -> void:
	if _viewport == null or _world == null:
		return
	var vp_size := Vector2(_viewport.size)
	if vp_size.x < 2.0 or vp_size.y < 2.0:
		return
	_world.scale = Vector2(_zoom, _zoom)
	_world.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.72)
	if _bg != null:
		_bg.size = vp_size


func _update_hud() -> void:
	if _hud == null or _anim == null:
		return
	_hud.text = _anim.debug_line()
