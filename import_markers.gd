@tool # Needed so it runs in editor.
extends EditorScenePostImport

var _empty_meta := "empty_draw_type"
var _axis_meta_values := ["ARROWS", "PLAIN_AXES"]

# This sample changes all node names.
# Called right after the scene is imported and gets the root node.
func _post_import(scene):
	# Change all node names to "modified_[oldnodename]"
	iterate(scene, scene)
	return scene # Remember to return the imported scene

# Recursive function that is called on every node
# (for demonstration purposes; EditorScenePostImport only requires a `_post_import(scene)` function).
func iterate(node, scene):
	if node == null:
		return

	for child in node.get_children():
		iterate(child, scene)
	
	if (node is Node3D &&
			node.has_meta(_empty_meta) &&
			node.get_meta(_empty_meta) in _axis_meta_values):
		var parent : Node = node.get_parent();
		var marker := Marker3D.new()
		parent.add_child(marker)
		marker.set_owner(scene)
		marker.transform = node.transform
		marker.name = node.name
		parent.remove_child(node)
