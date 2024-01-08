extends "res://addons/godot_tours/core/tour.gd"


func _build() -> void:
	scene_open("res://tours/test_tour/test_tour.tscn")
	queue_command(func() -> void:
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(edited_scene_root is Node2D and edited_scene_root.name == "TestTour", "'edited_scene_root' should be 'TestTour'")
	)
	auto_next()
	complete_step()

	scene_select_nodes_by_path(["TestTour/NodeToEdit"])
	queue_command(func() -> void:
		var selected_nodes := editor_selection.get_selected_nodes()
		assert(selected_nodes.size() == 1, "'selected_nodes' should have size '1'")
		for selected_node in selected_nodes:
			assert(selected_node.name == "NodeToEdit", "'selected_node.name' should be 'NodeToEdit'")
	)
	auto_next()
	complete_step()

	scene_toggle_lock_nodes_by_path(["TestTour"])
	queue_command(func() -> void:
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(edited_scene_root.get_meta(&"_edit_lock_"), "'edited_scene_root' '_edit_lock_' meta should be 'true'")
	)
	auto_next()
	complete_step()

	scene_toggle_lock_nodes_by_path(["TestTour"], false)
	queue_command(func() -> void:
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(not edited_scene_root.has_meta(&"_edit_lock_"), "'edited_scene_root' '_edit_lock_' meta should not exist")
	)
	auto_next()
	complete_step()

	scene_deselect_all_nodes()
	queue_command(func() -> void:
		var selected_nodes := editor_selection.get_selected_nodes()
		assert(selected_nodes.is_empty(), "'selected_nodes' array should be empty")
	)
	auto_next()
	complete_step()
