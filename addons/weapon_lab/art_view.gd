@tool
extends SubViewportContainer

const Catalog := preload("res://addons/weapon_lab/catalog.gd")
const Backdrop := preload("res://addons/weapon_lab/backdrop.gd")
var zoom: float = 4.0
var viewport: SubViewport
var world: Node2D
var backdrop: Node2D
var weapon_sprite: Sprite2D
var paladin: Sprite2D
var _anim: SheetAnimator
var _pan := Vector2.ZERO


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 230)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Drag to pan. Double-click to recenter."
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)
	backdrop = Backdrop.new()
	world.add_child(backdrop)
	paladin = Sprite2D.new()
	world.add_child(paladin)
	_anim = SheetAnimator.from_player_defaults()
	_anim.bind(paladin)
	_anim.apply_layout()
	_anim.set_facing_octant(0)
	_anim.show_walk_frame(0)
	paladin.position += Vector2(-34, 25)
	resized.connect(layout)
	layout()


func show_part(part: Dictionary, data: WeaponData, level: int) -> void:
	if is_instance_valid(weapon_sprite):
		weapon_sprite.free()
	weapon_sprite = Sprite2D.new()
	Catalog.apply_part(weapon_sprite, part, data, level)
	world.add_child(weapon_sprite)
	weapon_sprite.position = Vector2(30, 0)
	if part.kind in ["ring", "ground", "wave"]:
		weapon_sprite.position = Vector2(15, 15)
		weapon_sprite.z_index = -1
		backdrop.z_index = -10
	_pan = Vector2.ZERO
	layout()


func layout() -> void:
	if world == null:
		return
	world.scale = Vector2.ONE * zoom
	world.position = size * 0.5 + _pan
	backdrop.extent = size / maxf(zoom, 1.0) + Vector2(100, 100)
	backdrop.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_pan = Vector2.ZERO
		layout()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pan += event.relative
		layout()
		accept_event()


func set_background(index: int) -> void:
	backdrop.mode = index
	backdrop.queue_redraw()


func set_facing(index: int) -> void:
	_anim.set_facing_octant(index)
	_anim.show_walk_frame(0)
