@tool
extends RefCounted

const SETTINGS := "res://.godot/weapon_lab.cfg"
const WEAPONS := "res://data/weapons/"
const ART := "res://scripts/weapons/weapon_art.gd"
const CONSECRATION := preload("res://scripts/weapons/consecration.gd")
const LIGHTNING := preload("res://scripts/weapons/holy_shock_bolt.gd")
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


static func discover() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for file in DirAccess.get_files_at(WEAPONS):
		if file.ends_with(".tres"):
			var data := load(WEAPONS + file) as WeaponData
			if data != null and data.scene != null:
				result.append(data)
	result.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return result


static func components(data: WeaponData) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	match data.scene.resource_path.get_file().get_basename():
		"avenger_shield":
			parts.append(_generated("Shield", "shield"))
		"libram_of_the_light":
			parts.append(_generated("Orbiting libram", "libram"))
		"judgement":
			parts.append(_generated("Judgement projectile", "judgement"))
		"hammer_of_wrath":
			parts.append(_generated("Hammer of Wrath", "wrath_hammer"))
			parts.append(_generated("Divine electricity", "wrath_hammer_glow"))
		"divine_storm":
			parts.append(_image("Slash", "holy_slash"))
		"lights_hammer":
			parts.append(_image("Hammer", "hammer"))
			parts.append(_generated("Ground ring", "ring"))
		"consecration":
			parts.append({"name": "Scorched ground (shader snapshot)", "kind": "ground",
				"source": "res://shaders/consecration_ground.gdshader"})
			parts.append({"name": "Fire wave (shader snapshot)", "kind": "wave",
				"source": "res://shaders/consecration_wave.gdshader"})
		"holy_strike":
			parts.append({"name": "Lightning glow ribbon (source texture)", "kind": "ribbon",
				"source": "res://scripts/weapons/holy_shock_bolt.gd"})
			parts.append({"name": "Lightning impact (source texture)", "kind": "burst",
				"source": "res://scripts/weapons/holy_shock_bolt.gd"})
	return parts


static func _generated(label: String, kind: String) -> Dictionary:
	return {"name": label, "kind": kind, "source": ART}


static func _image(label: String, file: String) -> Dictionary:
	return {"name": label, "kind": "image", "source": "res://assets/sprites/weapons/%s.png" % file}


static func texture(part: Dictionary) -> Texture2D:
	match str(part.kind):
		"image":
			return load(part.source) as Texture2D
		"ground":
			return ImageTexture.create_from_image(CONSECRATION._make_pack())
		"wave":
			var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			return ImageTexture.create_from_image(img)
		"ribbon":
			return LIGHTNING._make_ribbon()
		"burst":
			return LIGHTNING._make_burst()
		_:
			return WeaponArt.texture(StringName(part.kind))


static func apply_part(sprite: Sprite2D, part: Dictionary, data: WeaponData, level: int) -> void:
	var radius := data.base_area + data.area_per_level * (level - 1)
	sprite.texture = texture(part)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match str(part.kind):
		"ring":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.scale = Vector2.ONE * radius / 28.0
		"wrath_hammer_glow":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		"ground", "wave":
			var mat := ShaderMaterial.new()
			mat.shader = load(part.source) as Shader
			mat.set_shader_parameter("effect_time", 0.12)
			if part.kind == "ground":
				mat.set_shader_parameter("pulse", 0.7)
			else:
				mat.set_shader_parameter("progress", 0.3)
				mat.set_shader_parameter("intensity", 1.15)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.material = mat
			sprite.scale = Vector2.ONE * radius / (sprite.texture.get_width() * 0.42)
		"ribbon", "burst":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		"image":
			if str(part.source).ends_with("holy_slash.png"):
				sprite.scale = Vector2.ONE * clampf(radius / 42.0, 0.85, 1.8)


static func read_settings() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return {}
	var result := {}
	for key in config.get_section_keys("lab"):
		result[key] = config.get_value("lab", key)
	return result


static func save_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("lab", key, settings[key])
	var err := config.save(SETTINGS)
	if err != OK:
		push_warning("Weapon Lab: could not save demo selection (%s)." % error_string(err))
