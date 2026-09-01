class_name WeaponArt
extends RefCounted

static var _cache: Dictionary = {}


static func texture(kind: StringName) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		&"shield":
			img = _shield()
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


static func _shield() -> Image:
	var img := Image.create(16, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var steel := Color("c8d0dc")
	var gold := Color("d4b43c")
	var gold_l := Color("f0e090")
	var rim := Color("6a5a28")
	for y in 18:
		var half := 3
		if y >= 2 and y < 6:
			half = 5
		elif y >= 6 and y < 12:
			half = 6
		elif y >= 12 and y < 15:
			half = 4
		elif y >= 15:
			half = 2
		for x in range(8 - half, 8 + half):
			img.set_pixel(x, y, steel)
	for x in range(3, 13):
		img.set_pixel(x, 1, rim)
	for y in range(2, 16):
		img.set_pixel(2, y, rim)
		img.set_pixel(13, y, rim)
	for y in range(3, 15):
		img.set_pixel(7, y, gold)
		img.set_pixel(8, y, gold_l)
	for x in range(5, 11):
		img.set_pixel(x, 8, gold)
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
