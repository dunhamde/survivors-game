extends Node2D

## Elwynn Forest arena — 32px summer tiles (RTS-inspired original atlas).
## Atlas layout (see tools/gen_elwynn_tiles.py):
##   row 0: grass variants 0-5
##   row 1: dirt variants 0-3
##   row 2: grass-on-dirt transitions (N E S W NE NW SE SW NS EW …)
##   row 3: forest canopy 0-7
##   row 4: water 0-1 + shores 2-9
##   row 5: rocks 0-3

const TILE := 32
const MAP_RADIUS := 48

const T_GRASS := 0
const T_DIRT := 1
const T_WATER := 2
const T_FOREST := 3
const T_ROCK := 4

@onready var ground: TileMapLayer = $Ground

var _oak_a: Texture2D
var _oak_b: Texture2D
var _oak_c: Texture2D
var _lantern: Texture2D
var _types: Dictionary = {} # Vector2i -> terrain type


func _ready() -> void:
	y_sort_enabled = true
	_oak_a = preload("res://assets/tiles/elwynn/tree_oak_a.png")
	_oak_b = preload("res://assets/tiles/elwynn/tree_oak_b.png")
	_oak_c = preload("res://assets/tiles/elwynn/tree_oak_c.png")
	_lantern = preload("res://assets/tiles/elwynn/lantern.png")
	_build_tileset()
	_generate_types()
	_fill_ground()
	_scatter_props()


func _build_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tiles/elwynn/elwynn_tiles.png")
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for y in 6:
		for x in 12:
			atlas.create_tile(Vector2i(x, y))
	tileset.add_source(atlas)
	ground.tile_set = tileset
	ground.y_sort_enabled = false
	ground.z_index = -20


func _hash(x: int, y: int, seed: int = 0) -> int:
	var n := x * 374761393 + y * 668265263 + seed * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n)


func _generate_types() -> void:
	_types.clear()
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			_types[Vector2i(x, y)] = T_GRASS

	# Sinuous dirt road (wider path).
	for x in range(-MAP_RADIUS, MAP_RADIUS):
		var road_y := int(round(4.0 * sin(x * 0.055)))
		for dy in range(-1, 2):
			var p := Vector2i(x, road_y + dy)
			if _types.has(p):
				_types[p] = T_DIRT
		# Occasional roadside widen.
		if _hash(x, road_y, 3) % 17 == 0:
			for dy in range(-2, 3):
				var p2 := Vector2i(x, road_y + dy)
				if _types.has(p2):
					_types[p2] = T_DIRT

	# Water ponds.
	var ponds := [
		Vector2i(-22, -18), Vector2i(28, 16), Vector2i(-30, 24), Vector2i(18, -28),
	]
	for center in ponds:
		var radius := 4 + _hash(center.x, center.y, 9) % 3
		for y in range(center.y - radius - 1, center.y + radius + 2):
			for x in range(center.x - radius - 1, center.x + radius + 2):
				var p := Vector2i(x, y)
				if not _types.has(p):
					continue
				if _types[p] == T_DIRT:
					continue
				var d := Vector2(x - center.x, y - center.y).length()
				if d <= radius + 0.35:
					_types[p] = T_WATER

	# Forest patches (keep clear near spawn and road).
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var p := Vector2i(x, y)
			if _types[p] != T_GRASS:
				continue
			if Vector2(x, y).length() < 8.0:
				continue
			var road_y := int(round(4.0 * sin(x * 0.055)))
			if abs(y - road_y) <= 3:
				continue
			var n := _noise_forest(x, y)
			if n > 0.58:
				_types[p] = T_FOREST

	# Rock outcrops.
	var rocks := [
		Vector2i(-12, 14), Vector2i(20, -10), Vector2i(-26, -6), Vector2i(8, 22),
		Vector2i(32, 4), Vector2i(-8, -24),
	]
	for center in rocks:
		for y in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				var p := Vector2i(x, y)
				if not _types.has(p):
					continue
				if _types[p] == T_DIRT or _types[p] == T_WATER:
					continue
				if Vector2(x, y).length() < 6.0:
					continue
				if _hash(x, y, 11) % 3 != 0 or Vector2i(x, y) == center:
					_types[p] = T_ROCK


func _noise_forest(x: int, y: int) -> float:
	var a := sin(x * 0.11 + y * 0.07) * 0.5 + 0.5
	var b := sin(x * 0.03 - y * 0.09 + 1.7) * 0.5 + 0.5
	var c := float(_hash(x, y, 5) % 1000) / 1000.0
	return a * 0.45 + b * 0.35 + c * 0.2


func _type_at(p: Vector2i) -> int:
	return int(_types.get(p, T_GRASS))


func _fill_ground() -> void:
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var p := Vector2i(x, y)
			var atlas := _atlas_for(p)
			ground.set_cell(p, 0, atlas)


func _atlas_for(p: Vector2i) -> Vector2i:
	var t := _type_at(p)
	match t:
		T_DIRT:
			return _dirt_atlas(p)
		T_WATER:
			return _water_atlas(p)
		T_FOREST:
			return _forest_atlas(p)
		T_ROCK:
			return Vector2i(_hash(p.x, p.y, 13) % 4, 5)
		_:
			return _grass_atlas(p)


func _grass_atlas(p: Vector2i) -> Vector2i:
	var n := _hash(p.x, p.y, 1) % 14
	if n == 0:
		return Vector2i(0, 0)
	if n == 1:
		return Vector2i(2, 0)
	if n == 2:
		return Vector2i(3, 0) # flowers
	if n == 3:
		return Vector2i(4, 0) # pebbles
	if n == 4:
		return Vector2i(5, 0)
	return Vector2i(1, 0)


func _dirt_atlas(p: Vector2i) -> Vector2i:
	# Bitmask: grass (or non-dirt) on N E S W → fringe sides.
	var mask := 0
	if _type_at(p + Vector2i(0, -1)) != T_DIRT:
		mask |= 1 # N
	if _type_at(p + Vector2i(1, 0)) != T_DIRT:
		mask |= 2 # E
	if _type_at(p + Vector2i(0, 1)) != T_DIRT:
		mask |= 4 # S
	if _type_at(p + Vector2i(-1, 0)) != T_DIRT:
		mask |= 8 # W
	match mask:
		0:
			return Vector2i(_hash(p.x, p.y, 2) % 4, 1)
		1:
			return Vector2i(0, 2) # N
		2:
			return Vector2i(1, 2) # E
		4:
			return Vector2i(2, 2) # S
		8:
			return Vector2i(3, 2) # W
		3:
			return Vector2i(4, 2) # NE
		9:
			return Vector2i(5, 2) # NW
		6:
			return Vector2i(6, 2) # SE
		12:
			return Vector2i(7, 2) # SW
		5:
			return Vector2i(8, 2) # NS
		10:
			return Vector2i(9, 2) # EW
		11:
			return Vector2i(10, 2) # NEW
		7:
			return Vector2i(11, 2) # NES
		_:
			# 3-4 sided leftovers → solid dirt variant
			return Vector2i(_hash(p.x, p.y, 2) % 4, 1)


func _water_atlas(p: Vector2i) -> Vector2i:
	var mask := 0
	if _type_at(p + Vector2i(0, -1)) != T_WATER:
		mask |= 1
	if _type_at(p + Vector2i(1, 0)) != T_WATER:
		mask |= 2
	if _type_at(p + Vector2i(0, 1)) != T_WATER:
		mask |= 4
	if _type_at(p + Vector2i(-1, 0)) != T_WATER:
		mask |= 8
	match mask:
		0:
			return Vector2i(_hash(p.x, p.y, 4) % 2, 4)
		1:
			return Vector2i(2, 4)
		2:
			return Vector2i(3, 4)
		4:
			return Vector2i(4, 4)
		8:
			return Vector2i(5, 4)
		3:
			return Vector2i(6, 4)
		9:
			return Vector2i(7, 4)
		6:
			return Vector2i(8, 4)
		12:
			return Vector2i(9, 4)
		_:
			return Vector2i(_hash(p.x, p.y, 4) % 2, 4)


func _forest_atlas(p: Vector2i) -> Vector2i:
	var n_open := _type_at(p + Vector2i(0, -1)) != T_FOREST
	var e_open := _type_at(p + Vector2i(1, 0)) != T_FOREST
	var s_open := _type_at(p + Vector2i(0, 1)) != T_FOREST
	var w_open := _type_at(p + Vector2i(-1, 0)) != T_FOREST
	if n_open and not e_open and not s_open and not w_open:
		return Vector2i(4, 3)
	if e_open and not n_open and not s_open and not w_open:
		return Vector2i(5, 3)
	if s_open and not n_open and not e_open and not w_open:
		return Vector2i(6, 3)
	if w_open and not n_open and not e_open and not s_open:
		return Vector2i(7, 3)
	var open_count := int(n_open) + int(e_open) + int(s_open) + int(w_open)
	if open_count >= 2:
		return Vector2i(3, 3) # sparse
	return Vector2i(_hash(p.x, p.y, 6) % 3, 3)


func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var half := float(MAP_RADIUS * TILE) - 64.0
	for i in 220:
		var pos := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if pos.length() < 120.0:
			continue
		var cell := ground.local_to_map(pos)
		var t := _type_at(cell)
		if t == T_DIRT or t == T_WATER or t == T_ROCK:
			continue
		# Prefer forest edges and open grass; skip deep canopy interiors somewhat.
		if t == T_FOREST and rng.randf() < 0.55:
			continue
		var tex: Texture2D = _oak_a
		var pick := rng.randi() % 3
		if pick == 1:
			tex = _oak_b
		elif pick == 2:
			tex = _oak_c
		_add_sprite(pos, tex)

	for x in range(-40, 41, 10):
		var road_y := 4.0 * sin(x * 0.055)
		var pos := Vector2(x * TILE, road_y * TILE - 28.0)
		if pos.length() < 96.0:
			continue
		_add_sprite(pos, _lantern)


func _add_sprite(pos: Vector2, tex: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.offset = Vector2(0.0, -tex.get_height() * 0.45)
	sprite.position = pos
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func is_water_world_pos(world: Vector2) -> bool:
	var cell := ground.local_to_map(to_local(world))
	return _type_at(cell) == T_WATER
