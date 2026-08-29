@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/anim_preview/anim_preview_dock.tscn")

var _dock: Control


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_dock = DOCK_SCENE.instantiate()
		add_control_to_bottom_panel(_dock, "Anim Preview")
		var fs := EditorInterface.get_resource_filesystem()
		if not fs.resources_reimported.is_connected(_on_resources_reimported):
			fs.resources_reimported.connect(_on_resources_reimported)


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.resources_reimported.is_connected(_on_resources_reimported):
		fs.resources_reimported.disconnect(_on_resources_reimported)
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null


func _on_resources_reimported(files: PackedStringArray) -> void:
	if _dock != null and _dock.has_method("on_resources_reimported"):
		_dock.on_resources_reimported(files)
