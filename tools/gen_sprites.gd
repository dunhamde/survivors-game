extends SceneTree

# Original chunky pixel sprites for the Elwynn paladin slice.
# Run: godot --headless --path . -s res://tools/gen_sprites.gd

func _init() -> void:
	_gen_tiles()
	# Paladin uses the Warcraft II knight sheet at assets/sprites/player/paladin.png.
	# Skeleton uses tools/process_skeleton_sheet.py.
	# Grunt / ogre use tools/process_wc2_sheet.py.
	_gen_hogger()
	_gen_weapons()
	_gen_fx()
	_gen_props()
	_gen_ui()
	print("Sprites written.")
	quit()


func _run_elwynn_tile_tool() -> bool:
	# Prefer the Python atlas generator for the 32px summer set.
	var abs_script := ProjectSettings.globalize_path("res://tools/gen_elwynn_tiles.py")
	var output: Array = []
	var code := OS.execute("python3", [abs_script], output, true)
	if code != 0:
		for line in output:
			push_warning(str(line))
		return false
	for line in output:
		print(line)
	return true


func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("Failed to save %s (%s)" % [path, err])
	else:
		print("  ", path)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			_px(img, ix, iy, c)


func _outline_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for ix in range(x, x + w):
		_px(img, ix, y, c)
		_px(img, ix, y + h - 1, c)
	for iy in range(y, y + h):
		_px(img, x, iy, c)
		_px(img, x + w - 1, iy, c)


func _circle(img: Image, cx: int, cy: int, r: int, c: Color, fill: bool = true) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := Vector2(x - cx, y - cy).length()
			if fill and d <= r + 0.35:
				_px(img, x, y, c)
			elif not fill and absf(d - r) < 0.85:
				_px(img, x, y, c)


# --- palettes ---
const GOLD := Color("d4a017")
const GOLD_L := Color("f0d060")
const LEATHER := Color("5c4028")
const BLACK := Color("1a1410")
const WHITE := Color("f4f0e8")

const GNOLL := Color("c4a574")
const GNOLL_D := Color("8b6914")
const GNOLL_F := Color("6b4423")
const CLOTH_R := Color("8b2020")
const CANDLE := Color("ffcc44")

const GRASS_A := Color("3d6b2e")
const GRASS_B := Color("4a7a35")
const GRASS_C := Color("2f5624")
const GRASS_D := Color("5a8c3e")
const FLOWER := Color("e8d878")
const DIRT := Color("8a6a3c")
const DIRT_D := Color("6e5230")
const DIRT_L := Color("a48450")
const TRUNK := Color("5a3a1c")
const TRUNK_D := Color("3a2410")
const LEAF := Color("2f6b28")
const LEAF_L := Color("4a9a38")
const LEAF_D := Color("1e4a1a")


func _gen_tiles() -> void:
	if _run_elwynn_tile_tool():
		return
	push_warning("Falling back to minimal 32px grass/dirt atlas (Python tool failed).")
	var img := Image.create(384, 192, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 6:
		_fill_tile32(img, i, 0, GRASS_A if i != 0 else GRASS_C, GRASS_B, GRASS_C, i == 3)
	for i in 4:
		_fill_tile32(img, i, 1, DIRT if i != 1 else DIRT_L, DIRT_D, DIRT_L, false)
	_save(img, "res://assets/tiles/elwynn/elwynn_tiles.png")


func _fill_tile32(img: Image, tx: int, ty: int, a: Color, b: Color, c: Color, flowers: bool) -> void:
	var ox := tx * 32
	var oy := ty * 32
	for y in 32:
		for x in 32:
			var n := (x * 13 + y * 7 + tx * 17 + ty * 9) % 7
			var col := a
			if n == 0 or n == 1:
				col = b
			elif n == 2:
				col = c
			_px(img, ox + x, oy + y, col)
	if flowers:
		_px(img, ox + 8, oy + 10, FLOWER)
		_px(img, ox + 9, oy + 10, WHITE)
		_px(img, ox + 22, oy + 18, Color("d070a0"))
		_px(img, ox + 23, oy + 18, WHITE)


func _gen_hogger() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# legs
	_rect(img, 14, 34, 8, 13, GNOLL_F)
	_rect(img, 26, 34, 8, 13, GNOLL_F)
	_rect(img, 14, 45, 8, 3, BLACK)
	_rect(img, 26, 45, 8, 3, BLACK)
	# body
	_rect(img, 12, 20, 24, 16, CLOTH_R)
	_rect(img, 14, 22, 20, 4, GOLD)
	_rect(img, 12, 18, 24, 5, GNOLL)
	# head
	_rect(img, 14, 6, 20, 14, GNOLL)
	_rect(img, 10, 14, 8, 7, GNOLL_D) # snout
	_px(img, 12, 16, BLACK)
	_rect(img, 12, 4, 6, 8, GNOLL_D) # ear
	_rect(img, 30, 4, 6, 8, GNOLL_D)
	_rect(img, 20, 8, 6, 5, GNOLL_F) # mane
	_rect(img, 22, 12, 3, 3, BLACK)
	_rect(img, 28, 12, 3, 3, BLACK)
	# huge club
	_rect(img, 36, 16, 6, 22, Color("5a3a1c"))
	_rect(img, 34, 12, 10, 8, Color("4a2e14"))
	_rect(img, 35, 13, 8, 6, Color("6a4a28"))
	_save(img, "res://assets/sprites/enemies/hogger.png")


func _gen_weapons() -> void:
	var slash := Image.create(40, 24, false, Image.FORMAT_RGBA8)
	slash.fill(Color(0, 0, 0, 0))
	for i in 18:
		var y := 4 + int(sin(i * 0.28) * 6.0)
		_rect(slash, 4 + i * 2, y, 2, 4, GOLD_L)
		_rect(slash, 4 + i * 2, y + 1, 2, 2, WHITE)
	_save(slash, "res://assets/sprites/weapons/holy_slash.png")

	var hammer := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	hammer.fill(Color(0, 0, 0, 0))
	_rect(hammer, 7, 6, 3, 9, Color("c0c8d4"))
	_rect(hammer, 3, 2, 11, 6, GOLD)
	_rect(hammer, 4, 3, 9, 4, GOLD_L)
	_rect(hammer, 6, 14, 5, 2, LEATHER)
	_save(hammer, "res://assets/sprites/weapons/hammer.png")

	var ring := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	ring.fill(Color(0, 0, 0, 0))
	_circle(ring, 48, 48, 42, Color(0.83, 0.63, 0.09, 0.55), false)
	_circle(ring, 48, 48, 41, Color(1.0, 0.9, 0.4, 0.8), false)
	_circle(ring, 48, 48, 40, Color(1.0, 0.95, 0.7, 0.5), false)
	for a in 12:
		var ang := a * TAU / 12.0
		var x := 48 + int(cos(ang) * 28)
		var y := 48 + int(sin(ang) * 28)
		_px(ring, x, y, WHITE)
	_save(ring, "res://assets/sprites/weapons/consecration.png")


func _gen_fx() -> void:
	var mote := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	mote.fill(Color(0, 0, 0, 0))
	_rect(mote, 2, 2, 4, 4, GOLD)
	_rect(mote, 3, 3, 2, 2, WHITE)
	_px(mote, 1, 3, GOLD_L)
	_px(mote, 6, 4, GOLD_L)
	_save(mote, "res://assets/sprites/fx/xp_mote.png")

	var heart := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	heart.fill(Color(0, 0, 0, 0))
	var red := Color("c42028")
	var red_d := Color("8c1218")
	var red_l := Color("e84850")
	for p in [
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4),
		Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5),
		Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6),
		Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
		Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7),
		Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8),
		Vector2i(8, 8), Vector2i(9, 8), Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8),
		Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9),
		Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10),
		Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11),
		Vector2i(7, 12), Vector2i(8, 12),
	]:
		_px(heart, p.x, p.y, red)
	_px(heart, 3, 4, red_d)
	_px(heart, 6, 4, red_d)
	_px(heart, 9, 4, red_d)
	_px(heart, 12, 4, red_d)
	_px(heart, 2, 5, red_d)
	_px(heart, 7, 5, red_d)
	_px(heart, 8, 5, red_d)
	_px(heart, 13, 5, red_d)
	_px(heart, 4, 5, red_l)
	_px(heart, 3, 6, red_l)
	_px(heart, 4, 6, WHITE)
	_px(heart, 5, 6, red_l)
	_save(heart, "res://assets/sprites/fx/heart.png")

	var gold := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	gold.fill(Color(0, 0, 0, 0))
	_rect(gold, 4, 13, 8, 1, BLACK)
	_rect(gold, 3, 11, 10, 2, GOLD)
	_rect(gold, 4, 10, 8, 1, GOLD)
	_rect(gold, 5, 8, 6, 2, GOLD)
	_rect(gold, 6, 6, 4, 2, GOLD)
	_rect(gold, 7, 4, 2, 2, GOLD_L)
	_px(gold, 4, 11, WHITE)
	_px(gold, 7, 11, WHITE)
	_px(gold, 11, 11, WHITE)
	_px(gold, 6, 9, WHITE)
	_px(gold, 8, 8, WHITE)
	_px(gold, 7, 6, WHITE)
	_px(gold, 8, 4, WHITE)
	_save(gold, "res://assets/sprites/fx/gold_pile.png")


func _gen_props() -> void:
	# Trees / lantern / Goldshire are produced by tools/gen_elwynn_tiles.py via _gen_tiles().
	# Keep a GDScript fallback if that tool was unavailable.
	if FileAccess.file_exists("res://assets/tiles/elwynn/tree_oak_a.png"):
		return
	_gen_tree("res://assets/tiles/elwynn/tree_oak_a.png", 64, 80, 0)
	_gen_tree("res://assets/tiles/elwynn/tree_oak_b.png", 72, 88, 1)
	_gen_tree("res://assets/tiles/elwynn/tree_oak_c.png", 56, 72, 2)
	_gen_lantern()
	_gen_goldshire()


func _gen_tree(path: String, w: int, h: int, variant: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tw := 6 + variant
	var tx := int(w / 2.0) - int(tw / 2.0)
	_rect(img, tx, h - 22, tw, 22, TRUNK)
	_rect(img, tx + 1, h - 22, 2, 22, TRUNK_D)
	var cx := int(w / 2.0)
	var canopies := [
		Vector2i(cx, h - 36),
		Vector2i(cx - 6, h - 28),
		Vector2i(cx + 6, h - 28),
		Vector2i(cx, h - 24),
	]
	if variant == 1:
		canopies.append(Vector2i(cx - 4, h - 40))
	for p in canopies:
		_circle(img, p.x, p.y, 10 + variant, LEAF)
		_circle(img, p.x - 2, p.y - 2, 6, LEAF_L)
		_circle(img, p.x + 3, p.y + 2, 5, LEAF_D)
	_save(img, path)


func _gen_lantern() -> void:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 7, 10, 2, 22, Color("4a3a28"))
	_rect(img, 4, 4, 8, 8, Color("3a3020"))
	_rect(img, 5, 5, 6, 6, CANDLE)
	_rect(img, 6, 6, 4, 4, WHITE)
	_save(img, "res://assets/tiles/elwynn/lantern.png")


func _gen_goldshire() -> void:
	var img := Image.create(256, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var roofs := [20, 52, 88, 120, 160, 198]
	for rx in roofs:
		_rect(img, rx, 18, 28, 22, Color("3a2a18"))
		_rect(img, rx + 2, 10, 24, 10, Color("6a2a18"))
		_px(img, rx + 8, 24, CANDLE)
		_px(img, rx + 9, 24, CANDLE)
		_px(img, rx + 16, 28, CANDLE)
	_rect(img, 0, 40, 256, 8, Color("1e3318"))
	_save(img, "res://assets/tiles/elwynn/goldshire_silhouette.png")


func _gen_ui() -> void:
	var panel := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	panel.fill(Color("2a1c10"))
	_outline_rect(panel, 0, 0, 16, 16, GOLD)
	_save(panel, "res://assets/sprites/ui/panel.png")
