class_name Hittable
extends RefCounted

## Shared target filter so weapons can strike enemies and environment props.


static func is_target(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and node.has_method("take_damage")
		and (node.is_in_group("enemies") or node.is_in_group("chests"))
	)


static func all_nodes(tree: SceneTree) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for group_name in [&"enemies", &"chests"]:
		for node in tree.get_nodes_in_group(group_name):
			if node is Node2D and is_instance_valid(node):
				out.append(node)
	return out
