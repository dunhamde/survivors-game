extends SceneTree

# Headless parity check for SheetAnimator vs the original run formulas.
# godot --headless --path . -s res://tools/verify_sheet_animator.gd

var _failed := 0


func _init() -> void:
	_test_paladin()
	_test_skeleton()
	_test_ogre()
	_test_grunt()
	_test_hogger()
	if _failed > 0:
		push_error("SheetAnimator parity: %s failed" % _failed)
		quit(1)
	else:
		print("SheetAnimator parity: all checks passed")
		quit(0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		_failed += 1
		push_error("  FAIL  " + msg)


func _test_paladin() -> void:
	print("paladin")
	var anim := SheetAnimator.from_player_defaults()
	_ok(anim.uses_sheet and anim.cols_are_dirs and anim.has_attack(), "layout")
	_ok(anim.sheet_cols == 5 and anim.sheet_rows == 11, "5x11")
	_ok(anim.attack_row == 5 and anim.attack_frames == 4, "attack rows")
	_ok(anim.death_row == 9 and anim.death_frames == 10 and not anim.death_uses_flip, "death")
	anim.set_facing_from_vector(Vector2.RIGHT)
	_ok(anim.dir_col == 2 and not anim.dir_flip, "face E")
	anim.show_walk_frame(0)
	_ok(anim.last_row == 0 and anim.last_col == 2, "walk E frame 0 -> row0 col2")
	anim.show_attack_frame(0)
	_ok(anim.last_row == 5 and anim.last_col == 2, "attack E frame 0 -> row5 col2")
	anim.show_attack_frame(3)
	_ok(anim.last_row == 8 and anim.last_col == 2, "attack E frame 3 -> row8 col2")
	anim.set_facing_from_vector(Vector2.LEFT)
	_ok(anim.dir_col == 2 and anim.dir_flip, "face W mirrors E")
	anim.set_facing_from_vector(Vector2.UP)
	_ok(anim.dir_col == 0 and not anim.dir_flip, "face N")
	anim.set_facing_from_vector(Vector2.DOWN)
	_ok(anim.dir_col == 4 and not anim.dir_flip, "face S")
	anim.set_facing_from_vector(Vector2(1, 1))
	_ok(anim.dir_col == 3 and not anim.dir_flip, "face SE")
	anim.set_facing_from_vector(Vector2(-1, 1))
	_ok(anim.dir_col == 3 and anim.dir_flip, "face SW mirrors SE")
	anim.start_death()
	anim.show_death_frame(0)
	_ok(anim.last_row == 9 and anim.last_col == 0, "death 0")
	anim.show_death_frame(5)
	_ok(anim.last_row == 10 and anim.last_col == 0, "death 5 wraps to next row")
	anim.show_death_frame(9)
	_ok(anim.last_row == 10 and anim.last_col == 4, "death 9")
	_ok(anim.tick_death(0.0) == false, "death not finished at t=0")
	# 10 frames at 10 fps + 0.4 hold = 1.4s
	anim.death_time = 0.0
	_ok(anim.tick_death(1.39) == false, "death hold not done at 1.39s")
	anim.death_time = 0.0
	_ok(anim.tick_death(1.40), "death hold done at 1.40s")


func _test_skeleton() -> void:
	print("skeleton")
	var data := load("res://data/enemies/skeleton.tres") as EnemyData
	var anim := SheetAnimator.from_enemy_data(data)
	_ok(anim.uses_sheet and not anim.cols_are_dirs and not anim.has_attack(), "row-per-dir, no attack")
	_ok(anim.sheet_cols == 5 and anim.sheet_rows == 10, "5x10")
	_ok(anim.death_row == 9 and anim.death_frames == 5 and not anim.death_uses_flip, "death row 9")
	anim.set_facing_from_vector(Vector2.RIGHT)
	_ok(anim.dir_row == 2, "E -> row 2")
	anim.show_walk_frame(0)
	_ok(anim.last_row == 2 and anim.last_col == 0, "walk E col 0")
	anim.set_facing_from_vector(Vector2.DOWN)
	_ok(anim.dir_row == 0, "S -> row 0")
	anim.set_facing_from_vector(Vector2.UP)
	_ok(anim.dir_row == 4, "N -> row 4")
	anim.set_facing_from_vector(Vector2.LEFT)
	_ok(anim.dir_row == 6, "W -> row 6")
	anim.start_death()
	anim.show_death_frame(3)
	_ok(anim.last_row == 9 and anim.last_col == 3, "death stays on row 9")
	_ok(anim.hit_style == SheetAnimator.HitStyle.ENEMY_FLASH, "hit is modulate flash")
	_assert_enemy_hit_flash(anim)


func _assert_enemy_hit_flash(anim: SheetAnimator) -> void:
	anim.trigger_enemy_flash()
	_ok(anim.is_flashing(), "surviving hit flashes")
	anim.tick_enemy_flash(0.0)
	if anim.modulate_target != null:
		_ok(anim.modulate_target.modulate == Color(1.0, 0.0, 0.0), "full red tint")


func _test_ogre() -> void:
	print("ogre")
	var data := load("res://data/enemies/ogre.tres") as EnemyData
	var anim := SheetAnimator.from_enemy_data(data)
	_ok(anim.cols_are_dirs and anim.death_uses_flip, "cols-are-dirs death flips")
	_ok(anim.death_cells.size() == 3 and anim.death_cells_south.size() == 3, "two death clips")
	anim.set_facing_from_vector(Vector2.UP)
	_ok(anim.dir_col == 0, "N col 0 uses north clip")
	anim.start_death()
	_ok(anim.playback_death_frames == 3, "clip length 3")
	anim.show_death_frame(0)
	_ok(anim.last_col == 4 and anim.last_row == 9, "north clip cell 0 (4,9)")
	anim.show_death_frame(1)
	_ok(anim.last_col == 1 and anim.last_row == 10, "north clip cell 1 (1,10)")
	anim.show_death_frame(2)
	_ok(anim.last_col == 3 and anim.last_row == 10, "north clip cell 2 (3,10)")
	anim.set_facing_from_vector(Vector2.DOWN)
	_ok(anim.dir_col == 4, "S col 4 uses south clip")
	anim.start_death()
	anim.show_death_frame(0)
	_ok(anim.last_col == 0 and anim.last_row == 10, "south clip cell 0 (0,10)")
	anim.show_death_frame(2)
	_ok(anim.last_col == 4 and anim.last_row == 10, "south clip cell 2 (4,10)")
	_assert_enemy_hit_flash(anim)


func _test_grunt() -> void:
	print("grunt")
	var data := load("res://data/enemies/grunt.tres") as EnemyData
	var anim := SheetAnimator.from_enemy_data(data)
	_ok(anim.cols_are_dirs and anim.death_uses_flip, "cols-are-dirs death flips")
	_ok(anim.death_cells.size() == 2 and anim.death_cells_south.size() == 2, "two death clips")
	_ok(anim.hit_row == 9, "directional death lead-in row")
	anim.set_facing_from_vector(Vector2.UP)
	_ok(anim.dir_col == 0, "N col 0 uses north clip")
	anim.trigger_hit()
	_ok(anim.flash_remaining > 0.0, "surviving hit flashes red")
	anim.tick_enemy_flash(0.0)
	if anim.modulate_target != null:
		_ok(anim.modulate_target.modulate == Color(1.0, 0.0, 0.0), "full red tint")
	anim.start_death()
	_ok(anim.playback_death_frames == 3, "hit plus 2 death frames")
	anim.show_death_frame(0)
	_ok(anim.last_col == 0 and anim.last_row == 9, "north death starts on hit (0,9)")
	anim.show_death_frame(1)
	_ok(anim.last_col == 3 and anim.last_row == 9, "north death cell 1 (3,9)")
	anim.show_death_frame(2)
	_ok(anim.last_col == 0 and anim.last_row == 10, "north death cell 2 (0,10)")
	anim.set_facing_from_vector(Vector2.DOWN)
	_ok(anim.dir_col == 4, "S col 4 uses south clip")
	anim.trigger_hit()
	_ok(anim.flash_remaining > 0.0, "south surviving hit flashes red")
	anim.start_death()
	anim.show_death_frame(0)
	_ok(anim.last_col == 4 and anim.last_row == 9, "south death starts on hit (4,9)")
	anim.show_death_frame(1)
	_ok(anim.last_col == 2 and anim.last_row == 9, "south death cell 1 (2,9)")
	anim.show_death_frame(2)
	_ok(anim.last_col == 4 and anim.last_row == 9, "south death cell 2 (4,9)")


func _test_hogger() -> void:
	print("hogger")
	var data := load("res://data/enemies/hogger.tres") as EnemyData
	var anim := SheetAnimator.from_enemy_data(data)
	_ok(not anim.uses_sheet and not anim.has_attack(), "static sprite")
	anim.set_facing_from_vector(Vector2.LEFT)
	_ok(anim.dir_flip, "flip on -X")
	anim.set_facing_from_vector(Vector2.RIGHT)
	_ok(not anim.dir_flip, "no flip on +X")
	_assert_enemy_hit_flash(anim)
