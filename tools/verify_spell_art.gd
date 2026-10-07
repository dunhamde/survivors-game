extends SceneTree

## Combat semantics, effect cleanup and optional Weapon Lab screenshots.
## godot --headless --path . --fixed-fps 60 -s res://tools/verify_spell_art.gd
## For rendered reviews omit --headless and add -- --capture.
const Catalog := preload("res://addons/weapon_lab/catalog.gd")
var failures: Array[String] = []

class Probe extends CharacterBody2D:
	var hits: Array[int] = []
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		add_to_group("enemies")
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 1.0
		shape.shape = circle
		add_child(shape)
	func take_damage(amount: int) -> int:
		hits.append(amount)
		return amount


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	# Deferred zone entry/impact and overlap reports must finish before checking.
	await process_frame


func _run() -> void:
	check(Catalog.discover().size() == 7, "Weapon Lab must contain seven remaining spells")
	var host := Node2D.new()
	host.position = Vector2(80, 60)
	root.add_child(host)
	var source := WeaponBase.new()
	host.add_child(source)
	var inside := Probe.new()
	host.add_child(inside)
	var outside := Probe.new()
	outside.position = Vector2(46, 0)
	host.add_child(outside)
	var zone = load("res://scenes/weapons/holy_zone.tscn").instantiate()
	zone.damage = 11
	zone.radius = 40.0
	zone.pulses_left = 3
	zone.pulse_interval = 0.48
	zone.show_hammer = true
	zone.source = source
	host.add_child(zone)
	await frames(5)
	check(inside.hits == [11], "Lightning impact must deliver exactly the first zone hit")
	check(outside.hits.is_empty(), "Lightning art must not damage beyond the circle")
	check(zone._hammer.visible, "Impact must leave a visible grounded hammer")
	for child in host.get_children():
		if child.get_script() == load("res://scripts/weapons/holy_shock_bolt.gd"):
			check(child.global_position == zone.global_position + Vector2(-18, -190), "Sky strike must align in a translated world")
	check(zone._hammer.global_position == zone.global_position + Vector2(0, -17), "Ground hammer anchor")
	await frames(80)
	check(inside.hits == [11, 11, 11], "Hammer must keep its three original damage pulses")
	check(source.damage_dealt == 33, "Lightning art must not double-count zone damage")
	check(not is_instance_valid(zone), "Ground effect must finish and free itself")
	host.free()

	host = Node2D.new()
	root.add_child(host)
	var target := Probe.new()
	target.position = Vector2(45, 0)
	host.add_child(target)
	var bolt = load("res://scenes/weapons/judgement_bolt.tscn").instantiate()
	bolt.damage = 14
	host.add_child(bolt)
	await frames(15)
	check(target.hits == [14], "Judgement pierce must hit each body once despite its contact flash")
	await frames(50)
	check(not is_instance_valid(bolt), "Judgement lifetime")
	for child in host.get_children():
		check(not child is SpellRadiance, "Projectile trails and contact sparks must drain after expiry")
	host.free()

	host = Node2D.new()
	root.add_child(host)
	target = Probe.new()
	host.add_child(target)
	var orb = load("res://scenes/weapons/libram_orb.tscn").instantiate()
	orb.damage = 10
	orb.hit_interval = 0.45
	host.add_child(orb)
	await frames(5)
	check(target.hits == [10], "Libram first contact")
	await frames(27)
	check(target.hits == [10, 10], "Libram flash must respect its contact damage cooldown")
	orb.free()
	await frames(20)
	for child in host.get_children():
		check(not child is SpellRadiance, "Libram trail must clean up after its owner is removed")
	host.free()
	if "--capture" in OS.get_cmdline_user_args():
		await _capture_lab()
	print("Spell art and combat: %s failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _capture_lab() -> void:
	var demo = load("res://addons/weapon_lab/combat_demo.tscn").instantiate()
	root.add_child(demo)
	current_scene = demo
	await frames(3)
	demo._loading = true
	demo.level_spin.value = 1
	demo.zoom_option.select(3)
	demo.loop_toggle.set_pressed_no_signal(false)
	demo.layout_option.select(0)
	demo._loading = false
	for id in ["judgement", "lights_hammer", "libram_of_the_light"]:
		for i in demo.catalog.size():
			if demo.catalog[i].id == StringName(id):
				demo.weapon_option.select(i)
		demo.restart()
		await frames(7)
		await _capture(id + "-impact.png")
		await frames(19)
		await _capture(id + "-settled.png")
		# Max-level scaling, volleys and orbit count; rotated target arrangement.
		demo._loading = true
		demo.level_spin.value = 5
		demo.facing_option.select(5)
		demo.layout_option.select(2)
		demo._loading = false
		demo.restart()
		await frames(9)
		await _capture(id + "-level5.png")
		demo.zoom_option.select(1)
		demo._update_zoom()
		await frames(2)
		await _capture(id + "-gameplay.png")
		demo.zoom_option.select(3)
		demo._loading = true
		demo.level_spin.value = 1
		demo.facing_option.select(0)
		demo.layout_option.select(0)
		demo._loading = false
	demo.free()


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/" + file) == OK, "Capture " + file)
