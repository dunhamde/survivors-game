class_name GameSettings
extends RefCounted

## Persistent display options. Survives scene reload and later sessions.
const PATH := "user://settings.cfg"
const SECTION := "display"

static var show_damage_numbers: bool = true
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	show_damage_numbers = bool(cfg.get_value(SECTION, "show_damage_numbers", true))


static func set_show_damage_numbers(value: bool) -> void:
	ensure_loaded()
	if show_damage_numbers == value:
		return
	show_damage_numbers = value
	_save()


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(SECTION, "show_damage_numbers", show_damage_numbers)
	cfg.save(PATH)
