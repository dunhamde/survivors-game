extends WeaponBase

## Burning earth under the paladin: scorched disc, molten seams, expanding fire wave.

const GROUND_SHADER := preload("res://shaders/consecration_ground.gdshader")
const WAVE_SHADER := preload("res://shaders/consecration_wave.gdshader")

const TEX_SIZE := 64
const WAVE_TEX := 8
const CIRCLE_UV := 0.42
const WAVE_DURATION := 0.46
const FX_Z := -8
const PACK_SEED := 18491

@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/CollisionShape2D

static var _pack: Texture2D
static var _white: Texture2D

var _fx: Node2D
var _ground: Sprite2D
var _wave: Sprite2D
var _ground_mat: ShaderMaterial
var _wave_mat: ShaderMaterial
var _pulse_u: float = 0.0
var _wave_u: float = 1.0
var _wave_playing: bool = false
var _dead_fade: float = 1.0


func setup(p_data: WeaponData, p_player: CharacterBody2D) -> void:
	super.setup(p_data, p_player)
	_apply_area()


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	hit_shape.shape = circle
	_ensure_textures()
	_build_fx()


func _exit_tree() -> void:
	if is_instance_valid(_fx) and _fx.get_parent() != self:
		_fx.queue_free()


func _physics_process(delta: float) -> void:
	_sync_fx()
	if not is_player_alive():
		_tick_dead(delta)
		return
	_dead_fade = 1.0
	_apply_area()
	_tick_visuals(delta)
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	_pulse()
	cooldown = current_cooldown()


func _apply_area() -> void:
	if data == null:
		return
	var radius := current_area()
	var circle := hit_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	if _ground != null:
		_ground.scale = Vector2.ONE * (radius / (float(TEX_SIZE) * CIRCLE_UV))
	if _wave != null:
		_wave.scale = Vector2.ONE * (radius / (float(WAVE_TEX) * CIRCLE_UV))


func _pulse() -> void:
	_pulse_u = 1.0
	_wave_u = 0.0
	_wave_playing = true
	if _wave != null:
		_wave.visible = true
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(current_damage())


func _tick_visuals(delta: float) -> void:
	if _pulse_u > 0.0:
		_pulse_u = maxf(0.0, _pulse_u - delta * 2.15)
	if _wave_playing:
		_wave_u = minf(1.0, _wave_u + delta / WAVE_DURATION)
		if _wave_u >= 1.0:
			_wave_playing = false
			if _wave != null:
				_wave.visible = false
	_push_shader_params()


func _tick_dead(delta: float) -> void:
	_dead_fade = maxf(0.0, _dead_fade - delta * 1.6)
	if _wave_playing:
		_wave_u = minf(1.0, _wave_u + delta / WAVE_DURATION)
		if _wave_u >= 1.0:
			_wave_playing = false
	_pulse_u = maxf(0.0, _pulse_u - delta * 3.0)
	_push_shader_params()
	if _fx != null:
		_fx.modulate.a = _dead_fade


func _push_shader_params() -> void:
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("pulse", _pulse_u)
		_ground_mat.set_shader_parameter("wave_progress", _wave_u)
		_ground_mat.set_shader_parameter("wave_active", 1.0 if _wave_playing else 0.0)
		_ground_mat.set_shader_parameter("radius_uv", CIRCLE_UV)
	if _wave_mat != null:
		_wave_mat.set_shader_parameter("progress", _wave_u)
		_wave_mat.set_shader_parameter("radius_uv", CIRCLE_UV)
		_wave_mat.set_shader_parameter("intensity", 1.15)


func _sync_fx() -> void:
	if is_instance_valid(_fx):
		_fx.global_position = global_position


func _build_fx() -> void:
	_fx = Node2D.new()
	_fx.name = "ConsecrationFX"
	_fx.z_as_relative = true
	_fx.z_index = FX_Z
	_fx.y_sort_enabled = false
	_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_SHADER
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.texture = _pack
	_ground.material = _ground_mat
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx.add_child(_ground)

	_wave_mat = ShaderMaterial.new()
	_wave_mat.shader = WAVE_SHADER
	_wave = Sprite2D.new()
	_wave.name = "Wave"
	_wave.texture = _white
	_wave.material = _wave_mat
	_wave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_wave.visible = false
	_fx.add_child(_wave)

	var host := entities()
	if host != null:
		host.add_child(_fx)
	else:
		add_child(_fx)
	_fx.global_position = global_position
	if data != null:
		_apply_area()
	_push_shader_params()


static func _ensure_textures() -> void:
	if _pack != null:
		return
	_pack = ImageTexture.create_from_image(_make_pack())
	var white := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(white)


static func _make_pack() -> Image:
	var size := TEX_SIZE
	var heat: Array = []
	var pool: Array = []
	var ash: Array = []
	heat.resize(size * size)
	pool.resize(size * size)
	ash.resize(size * size)
	heat.fill(0.0)
	pool.fill(0.0)
	ash.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = PACK_SEED
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius := float(size) * CIRCLE_UV
	_stamp_cracks(heat, pool, size, center, radius, rng)
	_fill_ash(ash, size, rng)

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var inv := 1.0 / float(size)
	for y in size:
		for x in size:
			var idx := y * size + x
			var px := Vector2(float(x), float(y))
			var uv_r := px.distance_to(center) * inv
			var ang := atan2(px.y - center.y, px.x - center.x)
			var edge_n := (_value_noise(px * 0.1, 19) - 0.5) * 0.1
			edge_n += sin(ang * 2.0 + _value_noise(px * 0.06, 5) * 5.0) * 0.045
			var limit := CIRCLE_UV + edge_n
			var radial := 1.0 - _smoothstep(limit * 0.48, limit, uv_r)
			var blotch := _value_noise(px * 0.08, 41)
			if blotch < 0.38:
				blotch = 0.0
			else:
				blotch = (blotch - 0.38) * 1.45
			var earth_amt := maxf(heat[idx] * 1.3, blotch * 0.95)
			var cover := clampf(earth_amt * radial, 0.0, 1.0)
			if cover < 0.04 and heat[idx] < 0.12:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var h := 0.0
			if heat[idx] > 0.55:
				h = 1.0
			elif heat[idx] > 0.22:
				h = 0.55
			var a := 0.0
			if ash[idx] > 0.66:
				a = 1.0
			elif ash[idx] > 0.33:
				a = 0.5
			var p := 1.0 if pool[idx] > 0.4 else 0.0
			img.set_pixel(x, y, Color(h, a, p, cover))
	return img


static func _stamp_cracks(
		heat: Array,
		pool: Array,
		size: int,
		center: Vector2,
		radius: float,
		rng: RandomNumberGenerator
) -> void:
	_stamp_blob(pool, size, center, 2.8, 1.0)
	_stamp_blob(heat, size, center, 2.4, 1.0)
	for _cross in 2:
		var ang := rng.randf() * TAU
		var half := radius * rng.randf_range(0.14, 0.24)
		var path := _crack_path(
			center + Vector2.from_angle(ang) * -half,
			center + Vector2.from_angle(ang) * half,
			rng,
			2
		)
		_stamp_path(heat, size, path, 1.6, 1.0)

	var major := 5
	for i in major:
		var ang := TAU * float(i) / float(major) + rng.randf_range(-0.32, 0.32)
		var inner := rng.randf_range(0.04, 0.12) * radius
		var outer := rng.randf_range(0.55, 0.8) * radius
		var path := _crack_path(
			center + Vector2.from_angle(ang) * inner,
			center + Vector2.from_angle(ang) * outer,
			rng,
			2
		)
		_stamp_path(heat, size, path, 1.7, 1.0)
		_maybe_pools(pool, heat, size, path, rng, 0.35)
		if path.size() < 4 or rng.randf() < 0.35:
			continue
		var branch_at := rng.randi_range(int(path.size() * 0.35), int(path.size() * 0.7))
		var origin: Vector2 = path[branch_at]
		var tangent := (path[mini(branch_at + 1, path.size() - 1)] - path[maxi(branch_at - 1, 0)]).normalized()
		if tangent == Vector2.ZERO:
			tangent = Vector2.from_angle(ang)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var blen := radius * rng.randf_range(0.16, 0.28)
		var dest := origin + tangent.rotated(side * deg_to_rad(rng.randf_range(36.0, 72.0))) * blen
		if dest.distance_to(center) > radius * 0.82:
			dest = center + (dest - center).normalized() * radius * 0.78
		var branch := _crack_path(origin, dest, rng, 2)
		_stamp_path(heat, size, branch, 1.5, 0.9)


static func _maybe_pools(
		pool: Array,
		heat: Array,
		size: int,
		path: PackedVector2Array,
		rng: RandomNumberGenerator,
		chance: float
) -> void:
	if path.size() < 3 or rng.randf() > chance:
		return
	var at: Vector2 = path[rng.randi_range(1, path.size() - 2)]
	var rad := rng.randf_range(1.6, 2.6)
	_stamp_blob(pool, size, at, rad, 0.95)
	_stamp_blob(heat, size, at, rad * 0.75, 0.8)


static func _crack_path(from: Vector2, to: Vector2, rng: RandomNumberGenerator, generations: int) -> PackedVector2Array:
	var pts: Array[Vector2] = [from, to]
	var amplitude := clampf(from.distance_to(to) * 0.22, 1.4, 6.0)
	generations = maxi(generations, 2)
	for _g in generations:
		var next: Array[Vector2] = []
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var mid := (a + b) * 0.5
			var seg := b - a
			var slen := seg.length()
			if slen > 0.001:
				var perp := Vector2(-seg.y, seg.x) / slen
				mid += perp * rng.randf_range(-1.0, 1.0) * amplitude
			next.append(a)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		amplitude *= 0.48
	return PackedVector2Array(pts)


static func _stamp_path(buf: Array, size: int, path: PackedVector2Array, radius: float, strength: float) -> void:
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var steps := maxi(1, int(a.distance_to(b)))
		for s in steps + 1:
			var t := float(s) / float(steps)
			_stamp_blob(buf, size, a.lerp(b, t), radius, strength)


static func _stamp_blob(buf: Array, size: int, pos: Vector2, radius: float, strength: float) -> void:
	var r := int(ceil(radius))
	var x0 := clampi(int(pos.x) - r, 0, size - 1)
	var y0 := clampi(int(pos.y) - r, 0, size - 1)
	var x1 := clampi(int(pos.x) + r, 0, size - 1)
	var y1 := clampi(int(pos.y) + r, 0, size - 1)
	var rsq := radius * radius
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - pos.x
			var dy := float(y) - pos.y
			var dsq := dx * dx + dy * dy
			if dsq > rsq:
				continue
			var t := 1.0 - sqrt(dsq) / radius
			var v := strength * t * t
			var idx := y * size + x
			if v > buf[idx]:
				buf[idx] = v


static func _fill_ash(ash: Array, size: int, rng: RandomNumberGenerator) -> void:
	var ox := rng.randf() * 40.0
	var oy := rng.randf() * 40.0
	for y in size:
		for x in size:
			var n := _value_noise(Vector2(float(x) + ox, float(y) + oy) * 0.09, 7)
			n = n * 0.75 + _value_noise(Vector2(float(x) + ox, float(y) + oy) * 0.18, 23) * 0.25
			ash[y * size + x] = n


static func _value_noise(p: Vector2, salt: int) -> float:
	var i := Vector2(floor(p.x), floor(p.y))
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash2(i, salt)
	var b := _hash2(i + Vector2(1.0, 0.0), salt)
	var c := _hash2(i + Vector2(0.0, 1.0), salt)
	var d := _hash2(i + Vector2(1.0, 1.0), salt)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _hash2(p: Vector2, salt: int) -> float:
	var n := sin(p.dot(Vector2(127.1, 311.7)) + float(salt) * 19.13) * 43758.5453
	return n - floor(n)


static func _smoothstep(e0: float, e1: float, x: float) -> float:
	if e1 <= e0:
		return 0.0 if x < e0 else 1.0
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
