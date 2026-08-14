extends Node2D

const TILE := 16
const MAP_RADIUS := 90

@onready var ground: TileMapLayer = $Ground

var _oak_a: Texture2D
var _oak_b: Texture2D
var _oak_c: Texture2D
var _lantern: Texture2D


func _ready() -> void:
	y_sort_enabled = true
	_oak_a = preload("res://assets/tiles/elwynn/tree_oak_a.png")
	_oak_b = preload("res://assets/tiles/elwynn/tree_oak_b.png")
	_oak_c = preload("res://assets/tiles/elwynn/tree_oak_c.png")
	_lantern = preload("res://assets/tiles/elwynn/lantern.png")
	_build_tileset()
	_fill_ground()
	_scatter_props()


func _build_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tiles/elwynn/elwynn_tiles.png")
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in 6:
		atlas.create_tile(Vector2i(i, 0))
	tileset.add_source(atlas)
	ground.tile_set = tileset
	ground.y_sort_enabled = false
	ground.z_index = -20


func _fill_ground() -> void:
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var road_y := int(round(3.0 * sin(x * 0.07)))
			var atlas := Vector2i(1, 0)
			if abs(y - road_y) <= 1:
				atlas = Vector2i(4 if abs(y - road_y) == 0 else 5, 0)
			else:
				var n := int(abs(sin(x * 12.9898 + y * 78.233) * 43758.5453))
				var kind := n % 11
				if kind == 0:
					atlas = Vector2i(0, 0)
				elif kind == 1:
					atlas = Vector2i(2, 0)
				elif kind == 2:
					atlas = Vector2i(3, 0)
				else:
					atlas = Vector2i(1, 0)
			ground.set_cell(Vector2i(x, y), 0, atlas)


func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 160:
		var pos := Vector2(rng.randf_range(-1200.0, 1200.0), rng.randf_range(-1200.0, 1200.0))
		if pos.length() < 90.0:
			continue
		var tile := ground.local_to_map(pos)
		var cell := ground.get_cell_atlas_coords(tile)
		if cell.x >= 4:
			continue
		var tex: Texture2D = _oak_a
		var pick := rng.randi() % 3
		if pick == 1:
			tex = _oak_b
		elif pick == 2:
			tex = _oak_c
		_add_sprite(pos, tex)
	for x in range(-70, 71, 14):
		var road_y := 3.0 * sin(x * 0.07)
		var pos := Vector2(x * TILE, road_y * TILE - 18.0)
		if pos.length() < 64.0:
			continue
		_add_sprite(pos, _lantern)


func _add_sprite(pos: Vector2, tex: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	sprite.position = pos
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
