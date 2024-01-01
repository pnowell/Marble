@tool
extends EditorPlugin

const RAY_LENGTH = 1000

@onready var undo_redo = get_undo_redo()
var selection = get_editor_interface().get_selection()

var dragging = false
var selected : Array = []
var origin_marker : Marker3D = null
var drag_records = []
var origin_2d = null

func _enter_tree():
	selection.connect("selection_changed", _on_selection_changed)

func _handles(object):
	if object is Node3D or object.get_class() == "MultiNodeEdit":
		return true
	return false
	
func _on_selection_changed():
	var nodes = selection.get_selected_nodes()
	dragging = false
	selected = []
	origin_marker = null
	drag_records = []
	origin_2d = null
	for node in nodes:
		if not node is Node3D:
			continue
		var found_parent = false
		for potential_parent in nodes:
			if potential_parent == node:
				continue
			if potential_parent.is_ancestor_of(node):
				found_parent = true
				break
		if not found_parent:
			selected.append(node)

func _forward_3d_draw_over_viewport(overlay):
	if origin_2d != null:
		overlay.draw_circle(origin_2d, 4, Color.YELLOW)

func _forward_3d_gui_input(camera, event):
	# We need mouse events to get the cursor position
	# This means pressing V when no mouse events are being sent does nothing
	# It's rarely noticable though
	if selected.is_empty() or not event is InputEventMouse:
		return false

	#if event is InputEventMouse:
	var now_dragging = (
		event.button_mask == MOUSE_BUTTON_LEFT
		and Input.is_key_pressed(KEY_V))
	if dragging and not now_dragging and origin_marker != null:
		undo_redo.create_action("Snap Markers")
		for rec in drag_records:
			undo_redo.add_do_property(
				rec.selected,
				"global_transform",
				rec.selected.global_transform)
			undo_redo.add_undo_property(
				rec.selected,
				"global_transform",
				rec.undo_transform)
		undo_redo.commit_action()
	dragging = now_dragging

	if Input.is_key_pressed(KEY_V):
		var from = camera.project_ray_origin(event.position)
		var direction = camera.project_ray_normal(event.position)
		var to = from + direction * RAY_LENGTH

		if not dragging:
			var markers = find_markers(selected)
			origin_marker = find_closest_marker(markers, from, direction)
			drag_records = []
			if origin_marker != null:
				for sel in selected:
					var record = {
						selected = sel,
						undo_transform = sel.global_transform,
						origin_marker_from_selected =
							origin_marker.global_transform.inverse()
							* sel.global_transform
					}
					drag_records.append(record)

				if origin_marker != null:
					origin_2d = camera.unproject_position(
						origin_marker.global_transform.origin)
			else:
				origin_2d = null
			update_overlays()
		elif origin_marker != null:
			origin_2d = camera.unproject_position(
				origin_marker.global_transform.origin)
			update_overlays()
			var ids = RenderingServer.instances_cull_ray(
				from,
				to,
				origin_marker.get_world_3d().scenario)
			var objects = []
			for id in ids:
				var obj = instance_from_id(id)
				if not obj is Node3D:
					continue
				var found = false
				for sel in selected:
					if sel == obj:
						found = true
						break
					if sel.is_ancestor_of(obj):
						found = true
						break
				if !found:
					objects.append(obj)
			var markers = find_markers(objects)

			var target = find_closest_marker(markers, from, direction)
			if target != null:
				for rec in drag_records:
					rec.selected.global_transform = (
						target.global_transform.rotated_local(Vector3.UP, PI)
						* rec.origin_marker_from_selected
					)
			return true
	else:
		origin_marker = null
		origin_2d = null
		update_overlays()
	return false

func find_markers(nodes : Array) -> Array:
	var markers : Array = []
	for node in nodes:
		if node is Marker3D:
			markers.append(node)
		for child in node.get_children():
			if child is Node3D:
				markers += find_markers([child])
	return markers

func find_closest_marker(
		markers : Array,
		from : Vector3,
		direction : Vector3) -> Marker3D:
	var closest : Marker3D = null
	var closest_dist := INF

	# We will not use the distance between the vertex and the from position,
	# (that would always be the vertex closest to the camera). Instead we
	# use the distance between the vertex and the ray under the mouse cursor.
	# Ideally we would use the 2d distance of the unprojected vertices,
	# however unprojecting every vertex can have a performance penalty for
	# large meshes. This is a good balance between performance and accuracy.
	var segment_start := from
	var segment_end := from + direction

	for marker in markers:
		var marker_pos = marker.global_transform.origin
		var closest_on_ray = Geometry3D.get_closest_point_to_segment_uncapped(
			marker_pos, segment_start, segment_end)
		var dist = closest_on_ray.distance_to(marker_pos)
		if dist < closest_dist:
			closest = marker
			closest_dist = dist

	return closest
