extends Node2D

## Instant holy lightning: jagged core, soft additive glow, short return-stroke flicker.

const DURATION := 0.26
const HALO := Color(1.0, 0.68, 0.22, 0.28)
const GLOW := Color(1.0, 0.82, 0.38, 0.55)
const SHEATH := Color(1.0, 0.94, 0.72, 0.9)
const CORE := Color(1.0, 0.99, 0.96, 1.0)

static var _ribbon: Texture2D
static var _burst: Texture2D
static var _add_mat: CanvasItemMaterial

var damage: int = 18
var end_global: Vector2 = Vector2.ZERO
var victim: Node2D
var source: WeaponBase

var _age: float = 0.0
var _restrike_done: bool = false
var _cores: Array = []
var _layers: Array = []
var _impact: Sprite2D
var _muzzle: Sprite2D


func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_assets()
	_build()
	_apply_hit()


func _process(delta: float) -> void:
	_age += delta
	var u := _age / DURATION
	if u >= 1.0:
		queue_free()
		return
	if not _restrike_done and u >= 0.44:
		_restrike_done = true
		_jitter_cores()
		_refresh_lines()
	var energy := _stroke_energy(u)
	modulate = Color(1.0, 1.0, 1.0, energy)
	for layer in _layers:
		var line: Line2D = layer.line
		line.width = float(layer.base_width) * lerpf(0.78, 1.18, energy)
	if _impact != null:
		var impact_s := lerpf(0.35, 0.95, energy)
		_impact.scale = Vector2.ONE * impact_s
		_impact.modulate.a = energy
	if _muzzle != null:
		_muzzle.scale = Vector2.ONE * lerpf(0.2, 0.48, energy)
		_muzzle.modulate.a = energy * 0.85


func _apply_hit() -> void:
	if not is_instance_valid(victim):
		return
	if not victim.is_in_group("enemies"):
		return
	if source != null:
		source.deal_to(victim, damage)
	elif victim.has_method("take_damage"):
		victim.take_damage(damage)


func _build() -> void:
	var local_end := end_global - global_position
	if local_end.length_squared() < 16.0:
		local_end = Vector2.RIGHT * 12.0
	var main := _fractal_bolt(Vector2.ZERO, local_end, 0.2, _generations_for(local_end.length()))
	var main_curve := _width_curve(true)
	_add_layered(main, 1.0, 1.0, main_curve, true)

	var branch_count := randi_range(3, 5)
	for _i in branch_count:
		var branch := _make_branch(main, local_end)
		if branch.size() < 2:
			continue
		_add_layered(branch, randf_range(0.32, 0.5), randf_range(0.4, 0.65), _width_curve(false), false)

	var spark_count := randi_range(3, 5)
	for _j in spark_count:
		var ang := randf() * TAU
		var spark_end := local_end + Vector2.from_angle(ang) * randf_range(7.0, 16.0)
		var spark := _fractal_bolt(local_end, spark_end, 0.38, 3)
		_add_layered(spark, 0.28, 0.55, _width_curve(false), false)

	_muzzle = _make_burst_sprite(Vector2.ZERO, 0.32, Color(1.0, 0.9, 0.55, 0.9))
	_impact = _make_burst_sprite(local_end, 0.7, Color(1.0, 0.95, 0.8, 1.0))


func _add_layered(core: PackedVector2Array, width_mul: float, color_mul: float, curve: Curve, include_halo: bool) -> void:
	var core_idx := _cores.size()
	_cores.append(core)
	if include_halo:
		_add_line(core_idx, &"halo", 24.0 * width_mul, Color(HALO.r, HALO.g, HALO.b, HALO.a * color_mul), curve)
	_add_line(core_idx, &"glow", 12.0 * width_mul, Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * color_mul), curve)
	_add_line(core_idx, &"sheath", 5.0 * width_mul, Color(SHEATH.r, SHEATH.g, SHEATH.b, SHEATH.a * color_mul), curve)
	_add_line(core_idx, &"core", 1.85 * width_mul, Color(CORE.r, CORE.g, CORE.b, CORE.a * color_mul), curve)


func _add_line(core_idx: int, kind: StringName, width: float, color: Color, curve: Curve) -> void:
	var core: PackedVector2Array = _cores[core_idx]
	var line := Line2D.new()
	line.points = _points_for(kind, core)
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.texture = _ribbon
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	line.material = _add_mat
	line.width_curve = curve
	line.round_precision = 8
	add_child(line)
	_layers.append({
		"line": line,
		"core_idx": core_idx,
		"kind": kind,
		"base_width": width,
	})


func _points_for(kind: StringName, core: PackedVector2Array) -> PackedVector2Array:
	match kind:
		&"halo":
			return _downsample(core, 4)
		&"glow":
			return _downsample(core, 2)
		_:
			return core


func _make_branch(main: PackedVector2Array, local_end: Vector2) -> PackedVector2Array:
	if main.size() < 4:
		return PackedVector2Array()
	var idx := randi_range(maxi(1, int(main.size() * 0.18)), maxi(2, int(main.size() * 0.72)))
	idx = mini(idx, main.size() - 2)
	var origin: Vector2 = main[idx]
	var tangent := (main[idx + 1] - main[maxi(idx - 1, 0)]).normalized()
	if tangent == Vector2.ZERO:
		tangent = local_end.normalized()
	var side := -1.0 if randf() < 0.5 else 1.0
	var remaining := origin.distance_to(local_end)
	var length := remaining * randf_range(0.22, 0.48)
	var dest := origin + tangent.rotated(side * deg_to_rad(randf_range(28.0, 72.0))) * length
	return _fractal_bolt(origin, dest, 0.32, _generations_for(length) - 1)


func _fractal_bolt(from: Vector2, to: Vector2, chaos: float, generations: int) -> PackedVector2Array:
	var pts: Array[Vector2] = [from, to]
	var amplitude := clampf(from.distance_to(to) * chaos, 5.0, 22.0)
	generations = maxi(generations, 3)
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
				var mag := randf_range(-1.0, 1.0)
				if randf() < 0.2 and amplitude > 3.5:
					mag *= 1.55
				mid += perp * mag * amplitude
			next.append(a)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		amplitude *= 0.5
	var chord := to - from
	var chord_len := chord.length()
	if chord_len > 0.001:
		var perp := Vector2(-chord.y, chord.x) / chord_len
		for i in range(1, pts.size() - 1):
			var t := float(i) / float(pts.size() - 1)
			pts[i] += perp * randf_range(-1.35, 1.35) * sin(t * PI)
	return PackedVector2Array(pts)


func _jitter_cores() -> void:
	for i in _cores.size():
		var path: PackedVector2Array = _cores[i]
		if path.size() < 3:
			continue
		var chord := path[path.size() - 1] - path[0]
		var chord_len := chord.length()
		if chord_len < 0.001:
			continue
		var perp := Vector2(-chord.y, chord.x) / chord_len
		for p in range(1, path.size() - 1):
			path[p] += perp * randf_range(-1.8, 1.8)
		_cores[i] = path


func _refresh_lines() -> void:
	for layer in _layers:
		var line: Line2D = layer.line
		var core: PackedVector2Array = _cores[int(layer.core_idx)]
		line.points = _points_for(layer.kind, core)


func _downsample(path: PackedVector2Array, step: int) -> PackedVector2Array:
	if path.size() <= 2 or step <= 1:
		return path
	var out := PackedVector2Array()
	out.append(path[0])
	var i := step
	while i < path.size() - 1:
		out.append(path[i])
		i += step
	out.append(path[path.size() - 1])
	return out


func _width_curve(main_bolt: bool) -> Curve:
	var curve := Curve.new()
	curve.min_value = 0.4
	curve.max_value = 1.4
	curve.add_point(Vector2(0.0, randf_range(0.62, 0.82)))
	var t := randf_range(0.12, 0.2)
	while t < 0.92:
		var lo := 0.72 if main_bolt else 0.55
		var hi := 1.28 if main_bolt else 1.1
		curve.add_point(Vector2(t, randf_range(lo, hi)))
		t += randf_range(0.1, 0.2)
	curve.add_point(Vector2(1.0, randf_range(0.85, 1.2)))
	return curve


func _generations_for(length: float) -> int:
	if length > 40.0:
		return 6
	if length > 22.0:
		return 5
	return 4


func _stroke_energy(u: float) -> float:
	if u < 0.08:
		return u / 0.08
	if u < 0.34:
		return 1.0
	if u < 0.44:
		return 0.16
	if u < 0.6:
		return 0.88
	return maxf(0.0, 1.0 - (u - 0.6) / 0.4)


func _make_burst_sprite(at: Vector2, scale: float, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _burst
	sprite.position = at
	sprite.scale = Vector2.ONE * scale
	sprite.modulate = color
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = _add_mat
	add_child(sprite)
	return sprite


static func _ensure_assets() -> void:
	if _add_mat != null:
		return
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_ribbon = _make_ribbon()
	_burst = _make_burst()


static func _make_ribbon() -> Texture2D:
	var height := 64
	var img := Image.create(8, height, false, Image.FORMAT_RGBA8)
	var mid := float(height - 1) * 0.5
	for y in height:
		var n := absf(float(y) - mid) / mid
		var alpha := exp(-n * n * 5.2)
		if alpha < 0.02:
			alpha = 0.0
		var col := Color(1.0, 1.0, 1.0, alpha)
		for x in 8:
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _make_burst() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var max_r := center.x
	for y in size:
		for x in size:
			var n := Vector2(float(x), float(y)).distance_to(center) / max_r
			var alpha := exp(-n * n * 6.4)
			if alpha < 0.02:
				alpha = 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)
