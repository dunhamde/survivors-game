class_name GameSettings
extends RefCounted

## Persistent game options. Survives scene reload and later sessions.
const PATH := "user://settings.cfg"
const SECTION := "display"
const GAMEPLAY_SECTION := "gameplay"
const GAME_SPEEDS: Array[int] = [1, 2, 4, 6, 8, 10]

static var show_damage_numbers: bool = true
static var show_fps: bool = false
static var game_speed: int = 1
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	show_damage_numbers = bool(cfg.get_value(SECTION, "show_damage_numbers", true))
	show_fps = bool(cfg.get_value(SECTION, "show_fps", false))
	var saved_speed := int(cfg.get_value(GAMEPLAY_SECTION, "game_speed", 1))
	game_speed = saved_speed if saved_speed in GAME_SPEEDS else 1


static func set_show_damage_numbers(value: bool) -> void:
	ensure_loaded()
	if show_damage_numbers == value:
		return
	show_damage_numbers = value
	_save()


static func set_show_fps(value: bool) -> void:
	ensure_loaded()
	if show_fps == value:
		return
	show_fps = value
	_save()


static func set_game_speed(value: int) -> void:
	ensure_loaded()
	if value not in GAME_SPEEDS:
		return
	game_speed = value
	apply_game_speed()
	_save()


static func apply_game_speed() -> void:
	ensure_loaded()
	# Preserve the normal simulation step at faster speeds, including on retries.
	var base_ticks := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	var base_steps := int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame", 8))
	Engine.physics_ticks_per_second = base_ticks * game_speed
	Engine.max_physics_steps_per_frame = base_steps * game_speed
	Engine.time_scale = float(game_speed)


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(SECTION, "show_damage_numbers", show_damage_numbers)
	cfg.set_value(SECTION, "show_fps", show_fps)
	cfg.set_value(GAMEPLAY_SECTION, "game_speed", game_speed)
	cfg.save(PATH)
