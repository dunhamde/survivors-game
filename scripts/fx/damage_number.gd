class_name DamageNumber
extends Node2D

const RISE_PX := 42.0
const DURATION := 0.75
const FADE_DELAY := 0.28
const ENEMY_COLOR := Color(1.0, 0.92, 0.42)
const PLAYER_COLOR := Color(1.0, 0.38, 0.28)


static func spawn(target: Node2D, amount: int, color: Color = ENEMY_COLOR) -> void:
	GameSettings.ensure_loaded()
	if not GameSettings.show_damage_numbers or amount <= 0:
		return
	if target == null or not is_instance_valid(target):
		return
	var tree := target.get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.get_first_node_in_group("entities")
	if parent == null:
		return
	var node := DamageNumber.new()
	parent.add_child(node)
	node._play(target, amount, color)


func _play(target: Node2D, amount: int, color: Color) -> void:
	z_index = 40
	top_level = true
	global_position = _anchor(target) + Vector2(randf_range(-8.0, 8.0), 0.0)

	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.92))
	add_child(label)
	label.reset_size()
	label.position = Vector2(-label.size.x * 0.5, -label.size.y)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - RISE_PX, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION - FADE_DELAY).set_delay(FADE_DELAY)
	tween.chain().tween_callback(queue_free)


func _anchor(target: Node2D) -> Vector2:
	var sprite := target.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite.global_position + Vector2(0.0, -18.0)
	return target.global_position + Vector2(0.0, -36.0)
