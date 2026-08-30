@tool
class_name SheetAnimator
extends RefCounted

## Shared sprite-sheet playback used by the run and the Anim Preview dock.
## Frame index is always `row * sheet_cols + col` on a Sprite2D atlas.

enum State { IDLE, WALK, ATTACK, HIT, DEATH }
enum HitStyle { NONE, PLAYER_FLICKER, ENEMY_FLASH }

const WALK_FPS := 8.0
const ATTACK_FPS := 12.0
const DEATH_FPS := 10.0
const PLAYER_DEATH_HOLD := 0.4
const ENEMY_DEATH_HOLD := 0.15
const PLAYER_INVULN_TIME := 0.55
const ENEMY_FLASH_TIME := 0.2
const ENEMY_FLASH_COLOR := Color(1.0, 0.0, 0.0)
const PLAYER_SPRITE_POS := Vector2(0.0, -30.0)
const PLAYER_TEXTURE_PATH := "res://assets/sprites/player/paladin.png"
# Octants are E, SE, S, SW, W, NW, N, NE. Skeleton rows are S, SE, E, NE, N, NW, W, SW.
const DIR_ROWS := [2, 1, 0, 7, 6, 5, 4, 3]
const OCTANT_VECTORS := [
	Vector2.RIGHT,
	Vector2(1, 1),
	Vector2.DOWN,
	Vector2(-1, 1),
	Vector2.LEFT,
	Vector2(-1, -1),
	Vector2.UP,
	Vector2(1, -1),
]

var sprite: Sprite2D
var modulate_target: CanvasItem
var texture: Texture2D

var sheet_cols: int = 5
var sheet_rows: int = 1
var cols_are_dirs: bool = false
var uses_sheet: bool = false
var walk_frames: int = 5
var attack_row: int = -1
var attack_frames: int = 0
var death_row: int = 9
var death_frames: int = 5
var hit_row: int = -1
var death_hold: float = ENEMY_DEATH_HOLD
var death_uses_flip: bool = false
var death_cells: Array[Vector2i] = []
var death_cells_south: Array[Vector2i] = []
var sprite_pos: Vector2 = Vector2.ZERO
var hit_style: HitStyle = HitStyle.NONE
var hit_duration: float = 0.0

var dir_col: int = 4
var dir_row: int = 0
var dir_flip: bool = false
var last_row: int = 0
var last_col: int = 0

var attacking: bool = false
var walk_time: float = 0.0
var attack_time: float = 0.0
var death_time: float = 0.0
var flash_remaining: float = 0.0
var flicker_remaining: float = 0.0
var active_death_cells: Array[Vector2i] = []
var playback_death_frames: int = 5

var preview_state: State = State.IDLE
var preview_playing: bool = true
var preview_looping: bool = true


static func from_player_defaults() -> SheetAnimator:
	var anim := SheetAnimator.new()
	anim.sheet_cols = 5
	anim.sheet_rows = 11
	anim.cols_are_dirs = true
	anim.uses_sheet = true
	anim.walk_frames = 5
	anim.attack_row = 5
	anim.attack_frames = 4
	anim.death_row = 9
	anim.death_frames = 10
	anim.death_hold = PLAYER_DEATH_HOLD
	anim.death_uses_flip = false
	anim.sprite_pos = PLAYER_SPRITE_POS
	anim.hit_style = HitStyle.PLAYER_FLICKER
	anim.hit_duration = PLAYER_INVULN_TIME
	anim.texture = load(PLAYER_TEXTURE_PATH) as Texture2D
	return anim


static func from_enemy_data(data: EnemyData) -> SheetAnimator:
	var anim := SheetAnimator.new()
	anim.sheet_cols = maxi(1, data.sheet_cols)
	anim.sheet_rows = maxi(1, data.sheet_rows)
	anim.cols_are_dirs = data.sheet_cols_are_dirs
	anim.uses_sheet = data.sheet_cols > 1
	anim.walk_frames = maxi(1, data.walk_frames)
	anim.attack_row = -1
	anim.attack_frames = 0
	anim.death_row = data.death_row
	anim.death_frames = maxi(1, data.death_frames)
	anim.hit_row = data.hit_row
	anim.death_hold = ENEMY_DEATH_HOLD
	anim.death_uses_flip = anim.cols_are_dirs
	anim.death_cells = data.death_cells.duplicate()
	anim.death_cells_south = data.death_cells_south.duplicate()
	anim.hit_style = HitStyle.ENEMY_FLASH
	anim.hit_duration = ENEMY_FLASH_TIME
	anim.texture = data.texture
	if data.texture != null:
		if anim.uses_sheet:
			var cell_h := float(data.texture.get_height()) / float(anim.sheet_rows)
			anim.sprite_pos = Vector2(0.0, -cell_h * 0.42)
		else:
			anim.sprite_pos = Vector2(0.0, -float(data.texture.get_height()) * 0.5)
	return anim


func bind(p_sprite: Sprite2D, p_modulate: CanvasItem = null) -> void:
	sprite = p_sprite
	modulate_target = p_modulate if p_modulate != null else p_sprite


func has_attack() -> bool:
	return uses_sheet and attack_frames > 0


func apply_layout() -> void:
	if sprite == null:
		return
	sprite.centered = true
	if texture != null:
		sprite.texture = texture
	if uses_sheet:
		sprite.hframes = sheet_cols
		sprite.vframes = sheet_rows
	else:
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.flip_h = false
	sprite.position = sprite_pos


func set_facing_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	if not uses_sheet:
		if absf(direction.x) > 0.1:
			dir_flip = direction.x < 0.0
			if sprite != null:
				sprite.flip_h = dir_flip
		return
	var octant := posmod(int(round(direction.angle() / (PI * 0.25))), 8)
	if cols_are_dirs:
		# Sheet cols are N, NE, E, SE, S; west facings are mirrored.
		match octant:
			0:
				dir_col = 2
				dir_flip = false
			1:
				dir_col = 3
				dir_flip = false
			2:
				dir_col = 4
				dir_flip = false
			3:
				dir_col = 3
				dir_flip = true
			4:
				dir_col = 2
				dir_flip = true
			5:
				dir_col = 1
				dir_flip = true
			6:
				dir_col = 0
				dir_flip = false
			7:
				dir_col = 1
				dir_flip = false
	else:
		dir_row = DIR_ROWS[octant]
		dir_flip = false


func set_facing_octant(octant: int) -> void:
	set_facing_from_vector(OCTANT_VECTORS[posmod(octant, 8)])


func tick_alive(delta: float, input_vector: Vector2) -> void:
	if attacking:
		attack_time += delta
		var attack_frame := int(attack_time * ATTACK_FPS)
		if attack_frame >= attack_frames:
			attacking = false
			attack_time = 0.0
		else:
			show_attack_frame(attack_frame)
			return
	if input_vector.length() > 0.1:
		set_facing_from_vector(input_vector)
		walk_time += delta
		show_walk_frame(int(walk_time * WALK_FPS) % walk_frames)
	else:
		walk_time = 0.0
		show_walk_frame(0)


func tick_death(delta: float) -> bool:
	death_time += delta
	var frames := maxi(1, playback_death_frames)
	var death_frame := mini(int(death_time * DEATH_FPS), frames - 1)
	show_death_frame(death_frame)
	return death_time >= (float(frames) / DEATH_FPS) + death_hold


func start_attack() -> void:
	if not has_attack():
		return
	attacking = true
	attack_time = 0.0
	show_attack_frame(0)


func start_death() -> void:
	attacking = false
	attack_time = 0.0
	death_time = 0.0
	active_death_cells = _pick_death_leadin_cells()
	active_death_cells.append_array(_pick_death_cells())
	playback_death_frames = death_frames
	if active_death_cells.size() > 0:
		playback_death_frames = active_death_cells.size()
	if uses_sheet:
		show_death_frame(0)


func show_walk_frame(walk_frame: int) -> void:
	if not uses_sheet:
		return
	if cols_are_dirs:
		show_frame(walk_frame, dir_col, dir_flip)
	else:
		show_frame(dir_row, walk_frame, false)


func show_attack_frame(attack_frame: int) -> void:
	if not has_attack():
		return
	show_frame(attack_row + attack_frame, dir_col, dir_flip)


func show_death_frame(death_frame: int) -> void:
	if not uses_sheet:
		return
	var flip := dir_flip if death_uses_flip else false
	if active_death_cells.size() > 0:
		var cell: Vector2i = active_death_cells[clampi(death_frame, 0, active_death_cells.size() - 1)]
		show_frame(cell.y, cell.x, flip)
		return
	if cols_are_dirs:
		show_frame(death_row + int(death_frame / sheet_cols), death_frame % sheet_cols, flip)
	else:
		show_frame(death_row, death_frame, false)


func has_death_leadin_hit() -> bool:
	return hit_row >= 0


func show_frame(row: int, col: int, flip: bool) -> void:
	last_row = row
	last_col = col
	if sprite == null:
		return
	sprite.frame = row * sheet_cols + col
	sprite.flip_h = flip


func apply_player_flicker(remaining: float) -> void:
	if modulate_target == null:
		return
	if remaining > 0.0:
		modulate_target.modulate.a = 0.4 if fmod(remaining, 0.1) < 0.05 else 1.0
	else:
		modulate_target.modulate.a = 1.0


func trigger_enemy_flash() -> void:
	flash_remaining = ENEMY_FLASH_TIME


func is_flashing() -> bool:
	return flash_remaining > 0.0


func tick_enemy_flash(delta: float) -> void:
	if flash_remaining > 0.0:
		flash_remaining = maxf(0.0, flash_remaining - delta)
		if modulate_target != null:
			modulate_target.modulate = ENEMY_FLASH_COLOR if flash_remaining > 0.0 else Color.WHITE


func trigger_hit() -> void:
	match hit_style:
		HitStyle.PLAYER_FLICKER:
			flicker_remaining = hit_duration
		HitStyle.ENEMY_FLASH:
			trigger_enemy_flash()
		_:
			pass


func clear_hit_visual() -> void:
	flicker_remaining = 0.0
	flash_remaining = 0.0
	if modulate_target == null:
		return
	modulate_target.modulate = Color.WHITE


func play_preview(state: State) -> void:
	preview_state = state
	walk_time = 0.0
	attack_time = 0.0
	death_time = 0.0
	attacking = false
	clear_hit_visual()
	match state:
		State.IDLE:
			show_walk_frame(0)
		State.WALK:
			show_walk_frame(0)
		State.ATTACK:
			start_attack()
		State.HIT:
			show_walk_frame(0)
			trigger_hit()
		State.DEATH:
			start_death()


func tick_preview(delta: float) -> void:
	if not preview_playing:
		_tick_hit_preview(delta)
		return
	match preview_state:
		State.IDLE:
			show_walk_frame(0)
		State.WALK:
			walk_time += delta
			show_walk_frame(int(walk_time * WALK_FPS) % walk_frames)
		State.ATTACK:
			if not has_attack():
				return
			attack_time += delta
			var attack_frame := int(attack_time * ATTACK_FPS)
			if attack_frame >= attack_frames:
				if preview_looping:
					start_attack()
				else:
					play_preview(State.IDLE)
			else:
				show_attack_frame(attack_frame)
		State.HIT:
			show_walk_frame(0)
			_tick_hit_preview(delta)
			if _hit_preview_done() and preview_looping:
				trigger_hit()
			elif _hit_preview_done():
				play_preview(State.IDLE)
		State.DEATH:
			if not uses_sheet:
				return
			if tick_death(delta) and preview_looping:
				start_death()


func step_preview() -> void:
	preview_playing = false
	match preview_state:
		State.IDLE:
			show_walk_frame(0)
		State.WALK:
			var frame := int(walk_time * WALK_FPS) % walk_frames
			frame = (frame + 1) % walk_frames
			walk_time = float(frame) / WALK_FPS
			show_walk_frame(frame)
		State.ATTACK:
			if not has_attack():
				return
			var frame := int(attack_time * ATTACK_FPS) + 1
			if frame >= attack_frames:
				frame = 0 if preview_looping else attack_frames - 1
			attack_time = float(frame) / ATTACK_FPS
			show_attack_frame(frame)
		State.HIT:
			show_walk_frame(0)
			trigger_hit()
		State.DEATH:
			if not uses_sheet:
				return
			var frames := maxi(1, playback_death_frames)
			var frame := mini(int(death_time * DEATH_FPS), frames - 1) + 1
			if frame >= frames:
				if preview_looping:
					start_death()
					return
				frame = frames - 1
			death_time = float(frame) / DEATH_FPS
			show_death_frame(frame)


func current_fps() -> float:
	match preview_state:
		State.WALK:
			return WALK_FPS
		State.ATTACK:
			return ATTACK_FPS
		State.DEATH:
			return DEATH_FPS
		State.HIT:
			return 0.0
		_:
			return 0.0


func layout_mode_name() -> String:
	if not uses_sheet:
		return "static"
	if cols_are_dirs:
		return "cols-are-dirs"
	return "rows-are-dirs"


func debug_line() -> String:
	var frame := 0
	if sprite != null:
		frame = sprite.frame
	var flip := false
	if sprite != null:
		flip = sprite.flip_h
	var fps := current_fps()
	var fps_text := "—" if fps <= 0.0 else ("%s fps" % str(fps))
	return "frame=%s  row=%s col=%s  flip_h=%s  %s  %s" % [
		frame, last_row, last_col, flip, fps_text, layout_mode_name()
	]


func _pick_death_cells() -> Array[Vector2i]:
	return _pick_facing_cells(death_cells, death_cells_south)


func _pick_death_leadin_cells() -> Array[Vector2i]:
	if hit_row >= 0 and cols_are_dirs:
		return [Vector2i(dir_col, hit_row)]
	return []


func _pick_facing_cells(north: Array[Vector2i], south: Array[Vector2i]) -> Array[Vector2i]:
	if south.size() > 0 and dir_col >= 2:
		return south.duplicate()
	return north.duplicate()


func _tick_hit_preview(delta: float) -> void:
	match hit_style:
		HitStyle.PLAYER_FLICKER:
			if flicker_remaining > 0.0:
				flicker_remaining = maxf(0.0, flicker_remaining - delta)
			apply_player_flicker(flicker_remaining)
		HitStyle.ENEMY_FLASH:
			tick_enemy_flash(delta)
		_:
			pass


func _hit_preview_done() -> bool:
	match hit_style:
		HitStyle.PLAYER_FLICKER:
			return flicker_remaining <= 0.0
		HitStyle.ENEMY_FLASH:
			return flash_remaining <= 0.0
		_:
			return true
