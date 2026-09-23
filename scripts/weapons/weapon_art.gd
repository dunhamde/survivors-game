@tool
class_name WeaponArt
extends RefCounted

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func texture(kind: StringName) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		&"wrath_hammer":
			img = _wrath_hammer()
		&"wrath_hammer_glow":
			img = _wrath_hammer_glow()
		&"shield":
			img = _shield()
		&"shield_glow":
			img = _shield_glow()
		&"libram":
			img = _libram()
		&"judgement":
			img = _spear()
		&"ring":
			img = _ring()
		_:
			img = _spark()
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _wrath_hammer() -> Image:
	# Side-on warhammer: the head leads the throw, with a bright rune in its face.
	var img := Image.create(32, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var ink := Color("273143")
	var shadow := Color("435779")
	var steel := Color("7d9eba")
	var light := Color("c8e4ed")
	var gold_dark := Color("80602b")
	var gold := Color("d9ae4b")
	var gold_light := Color("ffdc7a")
	var leather := Color("705039")
	var cyan := Color("67d9f5")
	var white := Color("efffff")
	# Leather haft, pommel, and the gold collar at the head.
	img.fill_rect(Rect2i(2, 12, 18, 5), ink)
	img.fill_rect(Rect2i(4, 13, 16, 3), leather)
	img.fill_rect(Rect2i(5, 13, 14, 1), gold_dark)
	for x in [7, 11, 15]:
		img.fill_rect(Rect2i(x, 13, 2, 3), gold)
		img.set_pixel(x, 13, gold_light)
	img.fill_rect(Rect2i(1, 10, 5, 9), ink)
	img.fill_rect(Rect2i(2, 11, 3, 7), gold_dark)
	img.fill_rect(Rect2i(2, 12, 2, 4), gold)
	img.set_pixel(2, 12, gold_light)
	img.fill_rect(Rect2i(15, 9, 6, 11), ink)
	img.fill_rect(Rect2i(16, 10, 4, 9), gold_dark)
	img.fill_rect(Rect2i(17, 11, 3, 7), gold)
	img.fill_rect(Rect2i(17, 12, 1, 4), gold_light)
	# Broad beveled head with stepped striking faces and a dark outline.
	img.fill_rect(Rect2i(20, 1, 8, 26), ink)
	img.fill_rect(Rect2i(18, 4, 12, 20), ink)
	img.fill_rect(Rect2i(17, 7, 14, 14), ink)
	img.fill_rect(Rect2i(20, 2, 7, 24), gold_dark)
	img.fill_rect(Rect2i(18, 5, 11, 18), gold_dark)
	img.fill_rect(Rect2i(19, 6, 10, 16), steel)
	img.fill_rect(Rect2i(21, 3, 5, 22), steel)
	img.fill_rect(Rect2i(22, 4, 4, 19), light)
	img.fill_rect(Rect2i(18, 8, 2, 12), gold)
	img.fill_rect(Rect2i(28, 8, 2, 12), gold)
	img.fill_rect(Rect2i(20, 3, 1, 22), gold)
	img.fill_rect(Rect2i(26, 3, 1, 22), gold_dark)
	img.fill_rect(Rect2i(21, 5, 1, 18), shadow)
	img.fill_rect(Rect2i(26, 6, 2, 16), shadow)
	img.fill_rect(Rect2i(19, 6, 8, 1), gold_light)
	img.fill_rect(Rect2i(19, 21, 8, 1), gold_dark)
	# Inlaid lightning cross, gold rivets, and a cool white glint.
	img.fill_rect(Rect2i(23, 8, 2, 12), cyan)
	img.fill_rect(Rect2i(21, 12, 7, 3), cyan)
	img.fill_rect(Rect2i(23, 10, 1, 8), white)
	img.fill_rect(Rect2i(22, 13, 5, 1), white)
	img.set_pixel(19, 9, gold_light)
	img.set_pixel(19, 18, gold_light)
	img.set_pixel(28, 9, gold_light)
	img.set_pixel(28, 18, gold_light)
	img.set_pixel(22, 4, white)
	img.set_pixel(23, 3, light)
	return img


static func _wrath_hammer_glow() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(float(x) - 36.0, float(y) - 31.5)
			var r := sqrt(pow(d.x / 22.0, 2.0) + pow(d.y / 24.0, 2.0))
			var alpha := exp(-r * r * 2.3) * 0.4
			img.set_pixel(x, y, Color(0.22, 0.69, 1.0, alpha))
	return img


static func _shield() -> Image:
	# A round, blue-steel shield with a raised gold rim and holy cross.
	# The 20x23 canvas is approximately 25% larger in each dimension.
	var rows := [
		"                    ",
		"      KKKKKKKK      ",
		"     KKYYYYYYKK     ",
		"    KYYYWHHWYYYK    ",
		"   KYYWWbbbbWWYYK   ",
		"  KYYWbbbbbbbbWYGK  ",
		"  KYWbbCCHHCCbbSGK  ",
		" KYYWbCCgYYgCCbSGGK ",
		" KYWbbCCgYYgCBbbSGK ",
		" KYWbCCgYYYYgBBbSGK ",
		" KYWbggYYYYYYggbSGK ",
		" KYWbYHHHHHHHHYbSGK ",
		" KYWbggYYYYYYggbSGK ",
		" KYWbCCgYYYYgBBbSGK ",
		" KYWbbCBgYYgBBbbSGK ",
		" KYYWbBBgYYgBBbSGGK ",
		"  KYWbbBBGGBBbbSGK  ",
		"  KYGSbbbbbbbbSGGK  ",
		"   KGGSSbbbbSSGGK   ",
		"    KGGGSYYSGGGK    ",
		"     KKGGGGGGKK     ",
		"      KKKKKKKK      ",
		"                    ",
	]
	var colors := {
		"K": Color("303746"), # Dark silhouette
		"G": Color("8b672e"), # Shaded gold rim
		"Y": Color("d7b454"), # Lit gold and emblem
		"g": Color("9b722f"), # Emblem bevel
		"H": Color("fff0ae"), # Holy highlight
		"W": Color("dce8e8"), # Silver edge
		"S": Color("71879b"), # Shaded steel edge
		"b": Color("415a88"), # Blue border
		"C": Color("8aa9c6"), # Lit blue face
		"B": Color("2d416c"), # Shaded blue face
	}
	var img := Image.create(20, 23, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var pixel := row.substr(x, 1)
			if pixel != " ":
				img.set_pixel(x, y, colors[pixel])
	return img


static func _shield_glow() -> Image:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	for y in size:
		for x in size:
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var rim := exp(-pow((distance - 11.0) / 4.5, 2.0)) * 0.23
			var haze := exp(-pow((distance - 11.0) / 9.0, 2.0)) * 0.07
			img.set_pixel(x, y, Color(1.0, 0.88, 0.55, rim + haze))
	return img


static func _libram() -> Image:
	var img := Image.create(12, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cover := Color("3a4a8c")
	var page := Color("f4ecd0")
	var gold := Color("e0c050")
	for y in range(1, 13):
		for x in range(1, 11):
			img.set_pixel(x, y, cover)
	for y in range(2, 12):
		for x in range(3, 10):
			img.set_pixel(x, y, page)
	for y in range(3, 11):
		img.set_pixel(2, y, gold)
	img.set_pixel(6, 6, gold)
	img.set_pixel(6, 7, gold)
	img.set_pixel(5, 7, gold)
	img.set_pixel(7, 7, gold)
	return img


static func _spear() -> Image:
	var img := Image.create(18, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color("e8d060")
	var gold_l := Color("fff4b0")
	var steel := Color("d8e0ec")
	for x in range(2, 14):
		img.set_pixel(x, 3, gold)
		img.set_pixel(x, 4, gold_l)
	for y in range(1, 7):
		img.set_pixel(14, y, steel)
	img.set_pixel(15, 2, steel)
	img.set_pixel(15, 3, gold_l)
	img.set_pixel(15, 4, gold_l)
	img.set_pixel(15, 5, steel)
	img.set_pixel(16, 3, gold_l)
	img.set_pixel(16, 4, gold_l)
	img.set_pixel(17, 3, steel)
	return img


static func _ring() -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	for y in size:
		for x in size:
			var n := Vector2(float(x), float(y)).distance_to(center) / 28.0
			var ring := exp(-pow((n - 0.82) * 6.5, 2.0))
			var fill := exp(-n * n * 1.8) * 0.28
			var alpha := maxf(ring, fill)
			if alpha < 0.04:
				continue
			img.set_pixel(x, y, Color(1.0, 0.86, 0.38, clampf(alpha, 0.0, 1.0)))
	return img


static func _spark() -> Image:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 6):
		for x in range(2, 6):
			img.set_pixel(x, y, Color(1.0, 0.92, 0.55, 1.0))
	img.set_pixel(3, 3, Color.WHITE)
	img.set_pixel(4, 3, Color.WHITE)
	return img
