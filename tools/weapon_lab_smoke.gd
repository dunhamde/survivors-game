extends SceneTree

## Run: godot --headless --path . --script tools/weapon_lab_smoke.gd --fixed-fps 60
## Add -- --capture with a rendering display driver to save review images to .godot/.
const Catalog := preload("res://addons/weapon_lab/catalog.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var dock := preload("res://addons/weapon_lab/weapon_lab_dock.gd").new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dock)
	await process_frame
	check(not dock.catalog.is_empty(), "No weapons discovered")
	print("Reviewing %s discovered weapons" % dock.catalog.size())
	for i in dock.catalog.size():
		dock.weapon_option.select(i)
		dock._select_weapon(i)
		check(not dock.parts.is_empty(), "Missing art components: " + dock.catalog[i].display_name)
		for j in dock.parts.size():
			dock.component_option.select(j)
			dock._refresh()
			check(dock.views[0].weapon_sprite.texture != null, "Missing component texture")
	# Capture the motivating case with both scale views visible.
	for i in dock.catalog.size():
		if dock.catalog[i].id == &"avenger_shield":
			dock.weapon_option.select(i)
			dock._select_weapon(i)
	await _capture("weapon-lab-inspect.png")
	dock.free()
	var demo := preload("res://addons/weapon_lab/combat_demo.tscn").instantiate()
	root.add_child(demo)
	current_scene = demo
	for i in demo.catalog.size():
		var levels := [1, demo.catalog[i].max_level] if demo.catalog[i].max_level > 1 else [1]
		for level in levels:
			demo._loading = true
			demo.weapon_option.select(i)
			demo.level_spin.max_value = demo.catalog[i].max_level
			demo.level_spin.value = level
			demo.layout_option.select(1)
			demo._loading = false
			demo.restart()
			await create_timer(2.2).timeout
			check(demo.weapon.damage_dealt > 0, "%s L%s failed to hit targets" % [demo.catalog[i].display_name, level])
			check(get_nodes_in_group("entities").size() == 1, "Arena leaked an entities group")
			check(get_nodes_in_group("enemies").size() == 5, "Arena leaked review targets")
			print("PASS combat: %s L%s (%s damage)" % [demo.catalog[i].display_name, level, demo.weapon.damage_dealt])
	# Direction, target layout, one-shot gating, rotation diagnostic, and pause lifetime.
	for i in demo.catalog.size():
		if demo.catalog[i].id == &"avenger_shield":
			demo.weapon_option.select(i)
	demo.level_spin.max_value = 5
	demo.level_spin.value = 1
	for layout in 3:
		demo.layout_option.select(layout)
		for direction in 8:
			demo.facing_option.select(direction)
			demo.restart()
			await create_timer(0.7).timeout
			check(demo.weapon.damage_dealt > 0, "Shield failed layout %s / direction %s" % [layout, direction])
	demo.facing_option.select(0)
	demo.layout_option.select(1)
	demo.restart()
	demo.fire_once()
	demo.freeze_toggle.button_pressed = true
	await create_timer(0.12).timeout
	var shield: Node2D
	for node in demo.arena.get_children():
		if node.get_script() != null and node.get_script().resource_path.ends_with("avenger_shield_proj.gd"):
			shield = node
	check(is_instance_valid(shield), "One-shot did not spawn a shield")
	if is_instance_valid(shield):
		var before := shield.position
		demo.set_paused(true)
		await create_timer(3.2, true).timeout
		check(is_instance_valid(shield), "Projectile lifetime advanced during pause")
		if is_instance_valid(shield):
			check(shield.position == before, "Paused projectile moved")
			for child in shield.get_children():
				if child is Sprite2D:
					check(is_zero_approx(child.global_rotation), "Freeze rotation did not keep art upright")
		await _capture("weapon-lab-combat.png")
		demo.set_paused(false)
	await create_timer(3.5).timeout
	var damage: int = demo.weapon.damage_dealt
	await create_timer(2.0).timeout
	check(demo.weapon.damage_dealt == damage, "Fire once kept firing after the first volley")
	# Pause also freezes the shader clock; slow motion scales the shared simulation.
	for i in demo.catalog.size():
		if demo.catalog[i].id == &"consecration":
			demo.weapon_option.select(i)
	demo.restart()
	Engine.time_scale = 0.25
	var elapsed: float = demo._elapsed
	await create_timer(0.4, true, false, true).timeout
	var advanced: float = demo._elapsed - elapsed
	check(advanced > 0.07 and advanced < 0.14, "Slow motion did not scale the simulation")
	demo.set_paused(true)
	var shader_time: float = demo.weapon._visual_time
	await create_timer(0.4, true, false, true).timeout
	check(demo.weapon._visual_time == shader_time, "Shader clock advanced while paused")
	check(demo.weapon._ground_mat.get_shader_parameter("effect_time") == shader_time, "Ground shader is not using the simulation clock")
	demo.set_paused(false)
	Engine.time_scale = 1.0
	demo._reload_art()
	await create_timer(0.2).timeout
	demo.free()
	check(is_equal_approx(Engine.time_scale, 1.0), "Demo did not restore time scale")
	check(not paused, "Demo left the tree paused")
	print("Weapon Lab smoke test: %s failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _capture(file: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file)
