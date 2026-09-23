@tool
extends EditorPlugin

const DOCK := preload("res://addons/weapon_lab/weapon_lab_dock.gd")
const DEMO := "res://addons/weapon_lab/combat_demo.tscn"
var _dock: Control


func _enter_tree() -> void:
	_dock = DOCK.new()
	add_control_to_bottom_panel(_dock, "Weapon Lab")
	_dock.demo_requested.connect(_launch_demo)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_reimported)


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.resources_reimported.is_connected(_reimported):
		fs.resources_reimported.disconnect(_reimported)
	if is_instance_valid(_dock):
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()


func _reimported(_files: PackedStringArray) -> void:
	_dock.reload_art()


func _launch_demo() -> void:
	# A dedicated game process keeps physics groups and time scale out of the editor.
	EditorInterface.play_custom_scene(DEMO)
