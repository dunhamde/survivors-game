extends SceneTree

## Engine integration checks for pacing, crowd limits, boss attack safety,
## and spatial targeting parity. Run with --headless --fixed-fps 60.
const Boss := preload("res://scripts/enemies/hogger.gd")
const Director := preload("res://scripts/run/wave_director.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/hogger.tscn")
const SKELETON := preload("res://data/enemies/skeleton.tres")
const HOGGER := preload("res://data/enemies/hogger.tres")
var failures: Array[String] = []

class DamageProbe extends CharacterBody2D:
	var alive := true
	var hits: Array[int] = []
	func take_damage(amount: int) -> void:
		hits.append(amount)


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	GameSettings.ensure_loaded()
	var old_numbers := GameSettings.show_damage_numbers
	GameSettings.show_damage_numbers = false
	check(ElwynnBeats.HOGGER_AT == 840.0 and ElwynnBeats.LEVEL_TARGET == 900.0, "Boss timing must leave a finale within the fifteen-minute target")
	check(ElwynnBeats.crowd_cap(765.0) >= 450, "Late surge must support a large horde")
	check(ElwynnBeats.crowd_cap(725.0) < ElwynnBeats.crowd_cap(765.0), "Recovery and surge must have different ceilings")
	for second in range(0, 1801):
		check(ElwynnBeats.crowd_cap(float(second)) <= ElwynnBeats.HARD_CAP, "Crowd cap exceeded at %s" % second)
	check(ElwynnBeats.stage_index(119.9) == 0 and ElwynnBeats.stage_index(120.0) == 1, "Stage boundary")
	var world := Node2D.new()
	world.add_to_group("entities")
	root.add_child(world)
	var player := DamageProbe.new()
	player.add_to_group("player")
	world.add_child(player)
	player.position = Vector2(200, 0)
	var boss := BOSS_SCENE.instantiate()
	world.add_child(boss)
	boss.apply_data(HOGGER)
	boss.health = boss.max_health
	boss.set_physics_process(false)
	boss._begin_next_attack()
	check(boss._phase == Boss.Phase.CHARGE_WARNING, "First attack must warn before charging")
	var aim: Vector2 = boss._charge_dir
	player.position = Vector2(200, 100)
	boss._physics_process(0.6)
	check(boss._charge_dir == aim and player.hits.is_empty(), "Warning must lock aim and cause no damage")
	boss._physics_process(0.61)
	player.position = Vector2(200, 0)
	for i in 48:
		await physics_frame
		boss._physics_process(1.0 / 60.0)
	check(player.hits == [28], "Charge should hit once across its swept path")
	check(boss.collision_mask == Enemy.COLLISION_MASK_PACK, "Charge must restore pack collisions")
	player.hits.clear()
	boss.position = Vector2.ZERO
	player.position = Vector2(0, 30)
	boss._attack_index = 1
	boss._begin_next_attack()
	boss._physics_process(0.6)
	check(player.hits.is_empty(), "Slam warning must cause no damage")
	boss._physics_process(0.61)
	check(player.hits == [24], "Slam must damage its marked area on impact")
	player.hits.clear()
	player.position = Vector2(200, 0)
	for i in 48:
		boss._physics_process(1.0 / 60.0)
	check(player.hits == [20], "Expanding shockwave must cross and hit once")
	boss.health = boss.max_health / 2
	boss._physics_process(0.01)
	check(boss._enraged and boss._warning_duration() >= 0.9, "Enrage must retain a dodge window")
	for i in 4:
		boss._prepare_warband()
		boss._summon_warband()
	check(get_nodes_in_group("hogger_minions").size() == Boss.MINION_LIMIT, "Summons must stop at twelve")
	player.hits.clear()
	boss._enter_phase(Boss.Phase.SLAM_WARNING)
	boss.take_damage(boss.health)
	boss._physics_process(2.0)
	check(player.hits.is_empty(), "Dying boss must not complete an attack")
	for child in world.get_children():
		if child != player:
			child.free()
	var director := Director.new()
	director.enemy_scene = ENEMY_SCENE
	director.skeleton_data = SKELETON
	director.hogger_scene = BOSS_SCENE
	director.hogger_data = HOGGER
	root.add_child(director)
	director.set_physics_process(false)
	director.elapsed = 765.0
	director._alive = 0
	director._spawn_pack(player, SKELETON, 498, 500)
	check(get_nodes_in_group("enemies").size() == 498, "Large packs must instantiate correctly")
	director._spawn_pack(player, SKELETON, 30, 500)
	check(get_nodes_in_group("enemies").size() == 500, "Pack spawning must obey the hard cap")
	director.spawn_debug(&"hogger")
	check(get_nodes_in_group("boss").is_empty(), "Debug spawning must obey the hard cap")
	director._spawn_hogger(player)
	check(get_nodes_in_group("boss").is_empty() and not director.hogger_spawned, "Scheduled boss must wait for a free slot and retry")
	for node in get_nodes_in_group("enemies"):
		node.set_physics_process(false)
	# Distribute real bodies across positive and negative cell boundaries.
	var targets := Hittable.all_nodes(self)
	for i in targets.size():
		targets[i].position = Vector2((i % 25) * 23 - 280, (i / 25) * 31 - 310)
	var weapon := WeaponBase.new()
	world.add_child(weapon)
	var expected: Array[Dictionary] = []
	for target in targets:
		var score := 0
		for other in targets:
			if target != other and target.position.distance_squared_to(other.position) <= 56.0 * 56.0:
				score += 1
		expected.append({"node": target, "score": score, "dist": target.position.length_squared()})
	expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.score) > int(b.score) if int(a.score) != int(b.score) else float(a.dist) < float(b.dist))
	var start := Time.get_ticks_usec()
	var selected := weapon.densest_targets(6)
	print("500-target density query: %.2f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	for i in selected.size():
		check(selected[i] == expected[i].node, "Spatial density targeting changed its ranking")
	# Recycle stragglers without emitting kill signals or creating XP motes.
	for node in get_nodes_in_group("enemies"):
		node.position = Vector2(2000, 2000)
	director._recycle_distant_enemies(player)
	await process_frame
	check(get_nodes_in_group("enemies").is_empty() and director._alive == 0, "Distant bodies must release crowd slots")
	director.free()
	world.free()
	await _review_game()
	GameSettings.show_damage_numbers = old_numbers
	print("Run pacing and Hogger: %s failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _review_game() -> void:
	# Exercise the real terrain, crowd collisions, all six weapon effects,
	# and boss warnings together, not only the isolated fixtures above.
	var game := preload("res://scenes/elwynn_run.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.director.set_physics_process(false)
	game.player.leveled_up.disconnect(game._on_leveled_up)
	game.player.max_health = 1000000
	game.player.health = game.player.max_health
	game.elapsed = 765.0
	game.director.elapsed = 765.0
	for id in ["holy_strike", "consecration", "hammer_of_wrath", "avenger_shield", "lights_hammer", "libram_of_the_light"]:
		var data := load("res://data/weapons/%s.tres" % id) as WeaponData
		game.player.weapons.add_weapon(data)
		game.player.weapons.get_weapon(data.id).level = data.max_level
	game.director._spawn_pack(game.player, SKELETON, 480, 480)
	check(get_nodes_in_group("enemies").size() == 480, "Live arena must support 480 enemies")
	for node in get_nodes_in_group("enemies"):
		node.max_health = 1000000
		node.health = node.max_health
	var started := Time.get_ticks_usec()
	for frame in 240:
		await physics_frame
	print("480 bodies + all weapons, 240 frames: %.2f ms/frame (includes rendering when enabled)" % ((Time.get_ticks_usec() - started) / 240000.0))
	var total_damage := 0
	for row in game.player.weapons.damage_rows():
		total_damage += int(row.damage)
	check(total_damage > 0, "Weapons must still hit the live crowd")
	await _capture("horde-review.png")
	game.player.weapons.process_mode = Node.PROCESS_MODE_DISABLED
	for node in get_nodes_in_group("enemies"):
		node.remove_from_group("enemies")
		node.queue_free()
	await process_frame
	# Let transient projectiles expire, then inspect ground warnings at scale.
	for frame in 300:
		await physics_frame
	game.director.spawn_debug(&"hogger")
	var boss := get_nodes_in_group("boss")[0]
	check(boss.sprite.texture.get_size() == Vector2(560, 960), "Dev-spawned Hogger must use the replacement atlas")
	boss.set_physics_process(false)
	boss.position = game.player.position + Vector2(90, 0)
	boss._begin_next_attack()
	boss._phase_time = 0.65
	boss._anim.show_attack_frame(0)
	boss._queue_warning()
	await _capture("hogger-charge-review.png")
	boss._enter_phase(Boss.Phase.SLAM_WARNING)
	boss._phase_time = 0.7
	boss._queue_warning()
	await _capture("hogger-slam-review.png")
	boss._enter_phase(Boss.Phase.SHOCKWAVE)
	boss._wave_origin = boss.global_position
	boss._phase_time = 0.35
	boss._anim.show_attack_frame(1)
	boss._queue_warning()
	await _capture("hogger-wave-review.png")
	# All phases, death, pause, and rendering share the same production scene.
	boss.health = boss.max_health / 2
	boss.set_physics_process(true)
	for frame in 900:
		await physics_frame
	check(boss._enraged, "Live boss must enter enrage at half health")
	check(get_nodes_in_group("hogger_minions").size() <= Boss.MINION_LIMIT, "Live boss summon cap")
	game.free()
	await process_frame


func _capture(file: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/" + file)
	check(error == OK, "Could not save review image: " + file)
