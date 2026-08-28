extends Node2D

## Elwynn Forest arena — Warcraft II summer tiles with constrained random maps.
## Terrain graph: Forest—Grass—Coast—Water, and Rocks—Coast only.

const TILE := 32
const MAP_RADIUS := 48
const SPAWN_CLEAR := 10

const T_GRASS := 0
const T_COAST := 1
const T_WATER := 2
const T_FOREST := 3
const T_ROCK := 4

const N4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

@onready var ground: TileMapLayer = $Ground

var _lantern: Texture2D
var _types: Dictionary = {} # Vector2i -> terrain type
var _blocked: Dictionary = {} # Vector2i -> bool
var _road: Dictionary = {} # Vector2i -> true
var _map_seed: int = 0
var _physics_poly := PackedVector2Array([
	Vector2(-TILE * 0.5, -TILE * 0.5),
	Vector2(TILE * 0.5, -TILE * 0.5),
	Vector2(TILE * 0.5, TILE * 0.5),
	Vector2(-TILE * 0.5, TILE * 0.5),
])


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("elwynn_map")
	_lantern = preload("res://assets/tiles/elwynn/lantern.png")
	_map_seed = randi()
	_build_tileset()
	_generate_types()
	_fill_ground()
	_scatter_props()


func _build_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1 << 4)
	tileset.set_physics_layer_collision_mask(0, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tiles/elwynn/summer_tiles.png")
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.separation = Vector2i(SummerCatalog.ATLAS_SEPARATION, SummerCatalog.ATLAS_SEPARATION)
	for y in SummerCatalog.ATLAS_ROWS:
		for x in SummerCatalog.ATLAS_COLS:
			atlas.create_tile(Vector2i(x, y))
	tileset.add_source(atlas)
	for coords in SummerCatalog.BLOCKED:
		var data := atlas.get_tile_data(coords, 0)
		if data == null:
			continue
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, _physics_poly)
	ground.tile_set = tileset
	ground.y_sort_enabled = false
	ground.z_index = -20
	ground.collision_enabled = true


func _hash(x: int, y: int, salt: int = 0) -> int:
	var n := x * 374761393 + y * 668265263 + (_map_seed + salt) * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n)


func _generate_types() -> void:
	_types.clear()
	_road.clear()
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			_types[Vector2i(x, y)] = T_GRASS

	_paint_roads()
	_paint_coast_clearings()
	_paint_water()
	_paint_rocks()
	_paint_forest()
	_enforce_buffers()
	_ensure_connected()
	_enforce_buffers()


func _paint_roads() -> void:
	var amp := 3.5 + float(_map_seed % 5)
	var freq := 0.045 + float(_hash(3, 7, 1) % 20) * 0.001
	var phase := float(_hash(9, 2, 2) % 628) * 0.01
	var width := 1
	for x in range(-MAP_RADIUS, MAP_RADIUS):
		var road_y := int(round(amp * sin(x * freq + phase)))
		for dy in range(-width, width + 1):
			_set_coast(Vector2i(x, road_y + dy), true)
		if _hash(x, road_y, 3) % 19 == 0:
			for dy in range(-width - 1, width + 2):
				_set_coast(Vector2i(x, road_y + dy), true)


func _paint_coast_clearings() -> void:
	var count := 5 + _hash(1, 1, 4) % 4
	for i in count:
		var center := Vector2i(
			_hash(i, 2, 5) % (MAP_RADIUS * 2) - MAP_RADIUS,
			_hash(i, 8, 6) % (MAP_RADIUS * 2) - MAP_RADIUS
		)
		if Vector2(center).length() < SPAWN_CLEAR + 4:
			continue
		var radius := 2 + _hash(center.x, center.y, 7) % 3
		_fill_disk(center, radius, T_COAST, [])


func _paint_water() -> void:
	var ponds := 3 + _hash(4, 4, 8) % 3
	for i in ponds:
		var center := Vector2i(
			_hash(i + 11, 3, 9) % (MAP_RADIUS * 2 - 16) - MAP_RADIUS + 8,
			_hash(i + 13, 9, 10) % (MAP_RADIUS * 2 - 16) - MAP_RADIUS + 8
		)
		if Vector2(center).length() < SPAWN_CLEAR + 6:
			continue
		var radius := 3 + _hash(center.x, center.y, 11) % 3
		_fill_disk(center, radius, T_WATER, [T_COAST])
	_dilate(T_WATER, T_COAST, 2)


func _paint_rocks() -> void:
	var count := 5 + _hash(2, 6, 12) % 4
	for i in count:
		var center := Vector2i(
			_hash(i + 21, 1, 13) % (MAP_RADIUS * 2) - MAP_RADIUS,
			_hash(i + 22, 5, 14) % (MAP_RADIUS * 2) - MAP_RADIUS
		)
		if Vector2(center).length() < SPAWN_CLEAR + 4:
			continue
		# Sit rocks in dirt: convert a small coast pad, then rocks inside it.
		_fill_disk(center, 3, T_COAST, [T_WATER])
		for y in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				var p := Vector2i(x, y)
				if not _types.has(p):
					continue
				if _types[p] != T_COAST:
					continue
				if Vector2(p).length() < SPAWN_CLEAR:
					continue
				if _road.has(p):
					continue
				if _hash(x, y, 15) % 3 != 0 or p == center:
					_types[p] = T_ROCK


func _paint_forest() -> void:
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var p := Vector2i(x, y)
			if _types[p] != T_GRASS:
				continue
			if Vector2(p).length() < SPAWN_CLEAR:
				continue
			if _road.has(p):
				continue
			if _noise_forest(x, y) > 0.56:
				_types[p] = T_FOREST


func _fill_disk(center: Vector2i, radius: int, terrain: int, skip: Array) -> void:
	for y in range(center.y - radius - 1, center.y + radius + 2):
		for x in range(center.x - radius - 1, center.x + radius + 2):
			var p := Vector2i(x, y)
			if not _types.has(p):
				continue
			if _types[p] in skip:
				continue
			if Vector2(p).length() < SPAWN_CLEAR and terrain != T_GRASS:
				continue
			if Vector2(x - center.x, y - center.y).length() <= float(radius) + 0.35:
				if terrain == T_COAST:
					_set_coast(p, false)
				else:
					_types[p] = terrain


func _set_coast(p: Vector2i, as_road: bool) -> void:
	if not _types.has(p):
		return
	if Vector2(p).length() < float(SPAWN_CLEAR) * 0.45:
		return
	if _types[p] == T_WATER:
		return
	_types[p] = T_COAST
	if as_road:
		_road[p] = true


func _dilate(src: int, into: int, steps: int) -> void:
	for _i in steps:
		var add: Array[Vector2i] = []
		for y in range(-MAP_RADIUS, MAP_RADIUS):
			for x in range(-MAP_RADIUS, MAP_RADIUS):
				var p := Vector2i(x, y)
				if _types[p] != src:
					continue
				for d in N4:
					var n: Vector2i = p + d
					if not _types.has(n):
						continue
					if _types[n] == src or _types[n] == into:
						continue
					if Vector2(n).length() < SPAWN_CLEAR:
						continue
					add.append(n)
		for n in add:
			_types[n] = into


func _enforce_buffers() -> void:
	for _pass in 4:
		var changed := false
		for y in range(-MAP_RADIUS, MAP_RADIUS):
			for x in range(-MAP_RADIUS, MAP_RADIUS):
				var p := Vector2i(x, y)
				var t: int = _types[p]
				for d in N4:
					var n: Vector2i = p + d
					if not _types.has(n):
						continue
					var nt: int = _types[n]
					if _legal_neighbors(t, nt):
						continue
					changed = true
					# Insert the missing link, preferring coast as the universal buffer.
					if t == T_WATER or nt == T_WATER:
						if t == T_WATER:
							_types[n] = T_COAST
						else:
							_types[p] = T_COAST
					elif t == T_FOREST or nt == T_FOREST:
						if t == T_FOREST:
							_types[p] = T_GRASS
						else:
							_types[n] = T_GRASS
					elif t == T_ROCK or nt == T_ROCK:
						if t == T_ROCK:
							_types[n] = T_COAST
						else:
							_types[p] = T_COAST
					else:
						_types[p] = T_GRASS
		if not changed:
			break
	# Keep spawn as open grass.
	for y in range(-SPAWN_CLEAR, SPAWN_CLEAR):
		for x in range(-SPAWN_CLEAR, SPAWN_CLEAR):
			var p := Vector2i(x, y)
			if not _types.has(p):
				continue
			if Vector2(p).length() < SPAWN_CLEAR:
				if _types[p] == T_FOREST or _types[p] == T_ROCK or _types[p] == T_WATER:
					_types[p] = T_GRASS


func _legal_neighbors(a: int, b: int) -> bool:
	if a == b:
		return true
	var pair := _ordered_pair(a, b)
	return pair != Vector2i(-1, -1)


func _ordered_pair(a: int, b: int) -> Vector2i:
	## (filled_type, other) matching SummerCatalog MIXED keys, or (-1,-1).
	if (a == T_WATER and b == T_COAST) or (a == T_COAST and b == T_WATER):
		return Vector2i(T_WATER, T_COAST)
	if (a == T_ROCK and b == T_COAST) or (a == T_COAST and b == T_ROCK):
		return Vector2i(T_ROCK, T_COAST)
	if (a == T_COAST and b == T_GRASS) or (a == T_GRASS and b == T_COAST):
		return Vector2i(T_COAST, T_GRASS)
	if (a == T_FOREST and b == T_GRASS) or (a == T_GRASS and b == T_FOREST):
		return Vector2i(T_FOREST, T_GRASS)
	return Vector2i(-1, -1)


func _is_walkable_type(t: int) -> bool:
	return t == T_GRASS or t == T_COAST


func _ensure_connected() -> void:
	var origin := Vector2i.ZERO
	var seen: Dictionary = {}
	var q: Array[Vector2i] = [origin]
	seen[origin] = true
	var qi := 0
	while qi < q.size():
		var p: Vector2i = q[qi]
		qi += 1
		for d in N4:
			var n: Vector2i = p + d
			if not _types.has(n) or seen.has(n):
				continue
			if not _is_walkable_type(_types[n]):
				continue
			seen[n] = true
			q.append(n)
	# Punch coast corridors to unreachable walkable pockets.
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var p := Vector2i(x, y)
			if not _is_walkable_type(_types[p]) or seen.has(p):
				continue
			var path := _path_to_seen(p, seen)
			for step in path:
				if not _is_walkable_type(_types[step]):
					if _types[step] == T_WATER or _types[step] == T_ROCK:
						_types[step] = T_COAST
					else:
						_types[step] = T_GRASS
				seen[step] = true


func _path_to_seen(start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var came: Dictionary = {}
	var q: Array[Vector2i] = [start]
	var vis: Dictionary = {start: true}
	var qi := 0
	var goal := Vector2i.ZERO
	var found := false
	while qi < q.size():
		var p: Vector2i = q[qi]
		qi += 1
		if seen.has(p):
			goal = p
			found = true
			break
		for d in N4:
			var n: Vector2i = p + d
			if not _types.has(n) or vis.has(n):
				continue
			vis[n] = true
			came[n] = p
			q.append(n)
	if not found:
		return []
	var path: Array[Vector2i] = []
	var cur := goal
	while cur != start:
		path.append(cur)
		cur = came[cur]
	path.append(start)
	return path


func _noise_forest(x: int, y: int) -> float:
	var a := sin(x * 0.11 + y * 0.07 + float(_map_seed % 17) * 0.2) * 0.5 + 0.5
	var b := sin(x * 0.03 - y * 0.09 + 1.7 + float(_map_seed % 11) * 0.15) * 0.5 + 0.5
	var c := float(_hash(x, y, 16) % 1000) / 1000.0
	return a * 0.45 + b * 0.35 + c * 0.2


func _type_at(p: Vector2i) -> int:
	return int(_types.get(p, T_GRASS))


func _fill_rank(t: int) -> int:
	match t:
		T_FOREST:
			return 4
		T_ROCK:
			return 3
		T_WATER:
			return 2
		T_COAST:
			return 1
		_:
			return 0


func _vertex_type(vx: int, vy: int) -> int:
	var cells := [
		_type_at(Vector2i(vx - 1, vy - 1)),
		_type_at(Vector2i(vx, vy - 1)),
		_type_at(Vector2i(vx - 1, vy)),
		_type_at(Vector2i(vx, vy)),
	]
	var counts: Dictionary = {}
	for t in cells:
		counts[t] = int(counts.get(t, 0)) + 1
	var best := T_GRASS
	var best_n := -1
	var best_rank := -1
	for t in counts.keys():
		var n: int = counts[t]
		var rank := _fill_rank(int(t))
		if n > best_n or (n == best_n and rank > best_rank):
			best = int(t)
			best_n = n
			best_rank = rank
	return best


func _fill_ground() -> void:
	_blocked.clear()
	for y in range(-MAP_RADIUS, MAP_RADIUS):
		for x in range(-MAP_RADIUS, MAP_RADIUS):
			var p := Vector2i(x, y)
			var atlas := _atlas_for(p)
			ground.set_cell(p, 0, atlas)
			_blocked[p] = SummerCatalog.is_blocked_atlas(atlas)


func _atlas_for(p: Vector2i) -> Vector2i:
	var nw := _vertex_type(p.x, p.y)
	var ne := _vertex_type(p.x + 1, p.y)
	var sw := _vertex_type(p.x, p.y + 1)
	var se := _vertex_type(p.x + 1, p.y + 1)
	var corners := [nw, ne, sw, se]
	var uniq: Dictionary = {}
	for t in corners:
		uniq[t] = true
	if uniq.size() == 1:
		return _solid_atlas(int(corners[0]), p)
	if uniq.size() > 2:
		var cell_t := _type_at(p)
		for i in 4:
			if not _legal_neighbors(cell_t, int(corners[i])):
				corners[i] = cell_t
		uniq.clear()
		for t in corners:
			uniq[t] = true
		if uniq.size() == 1:
			return _solid_atlas(int(corners[0]), p)
	var types: Array = uniq.keys()
	if types.size() != 2:
		return _solid_atlas(_type_at(p), p)
	var pair := _ordered_pair(int(types[0]), int(types[1]))
	if pair.x < 0:
		return _solid_atlas(_type_at(p), p)
	var filled := pair.x
	var other := pair.y
	var bits := 0
	if int(corners[0]) == filled:
		bits |= 1
	if int(corners[1]) == filled:
		bits |= 2
	if int(corners[2]) == filled:
		bits |= 4
	if int(corners[3]) == filled:
		bits |= 8
	if bits == 0:
		return _solid_atlas(other, p)
	if bits == 15:
		return _solid_atlas(filled, p)
	var slot: int = int(SummerCatalog.CORNER_SLOT.get(bits, -1))
	if slot < 0:
		return _solid_atlas(_type_at(p), p)
	var opts: Array = SummerCatalog.mixed_for(filled, other, slot)
	if opts.is_empty():
		return _solid_atlas(_type_at(p), p)
	return opts[_hash(p.x, p.y, 20) % opts.size()]


func _solid_atlas(terrain: int, p: Vector2i) -> Vector2i:
	var opts := SummerCatalog.solids_for(terrain)
	if opts.is_empty():
		opts = SummerCatalog.SOLID_GRASS
	return opts[_hash(p.x, p.y, 21) % opts.size()]


func _scatter_props() -> void:
	for x in range(-40, 41, 10):
		var amp := 3.5 + float(_map_seed % 5)
		var freq := 0.045 + float(_hash(3, 7, 1) % 20) * 0.001
		var phase := float(_hash(9, 2, 2) % 628) * 0.01
		var road_y := amp * sin(x * freq + phase)
		var pos := Vector2(x * TILE, road_y * TILE - 28.0)
		if pos.length() < 96.0:
			continue
		var cell := Vector2i(x, int(round(road_y)))
		if _type_at(cell) != T_COAST:
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
	if ground == null or ground.tile_set == null:
		return false
	var cell := ground.local_to_map(to_local(world))
	return _type_at(cell) == T_WATER


func is_blocked_world_pos(world: Vector2) -> bool:
	if ground == null or ground.tile_set == null:
		return false
	var cell := ground.local_to_map(to_local(world))
	return bool(_blocked.get(cell, false))


func is_walkable_world_pos(world: Vector2) -> bool:
	return not is_blocked_world_pos(world)


func snap_to_walkable(world: Vector2) -> Vector2:
	if ground == null or ground.tile_set == null:
		return world
	if is_walkable_world_pos(world):
		return world
	var origin := ground.local_to_map(to_local(world))
	for r in range(1, 18):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(abs(dx), abs(dy)) != r:
					continue
				var p := origin + Vector2i(dx, dy)
				if not _types.has(p):
					continue
				if bool(_blocked.get(p, false)):
					continue
				if not _is_walkable_type(_type_at(p)):
					continue
				return to_global(ground.map_to_local(p))
	return Vector2.ZERO
