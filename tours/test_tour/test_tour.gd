extends "res://addons/godot_tours/core/tour.gd"


func _build() -> void:
	scene_open("res://tours/test_tour/test_tour.tscn")
	queue_command(func() -> void:
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(edited_scene_root is Node2D and edited_scene_root.name == "TestTour", "'edited_scene_root' should be 'TestTour'")
	)
	auto_next()
	complete_step()

	scene_select_nodes_by_path(["TestTour", "TestTour/NodeToEdit"])
	queue_command(func() -> void:
		var selected_nodes := editor_selection.get_selected_nodes()
		assert(selected_nodes.size() == 2, "'selected_nodes' should have size '2'")
		for selected_node in selected_nodes:
			assert(selected_node.name in ["TestTour", "NodeToEdit"], "'selected_node.name' should be one of ['TestTour', 'NodeToEdit']")
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

	tabs_set_to_index(interface.inspector_tabs, 1)
	queue_command(func() -> void:
		assert(interface.inspector_tabs.current_tab == 1, "'interface.inspector_tabs.current_tab' should be '1'")
	)
	tabs_set_to_index(interface.inspector_tabs, 0)
	auto_next()
	complete_step()

	tabs_set_to_title(interface.scene_tabs, "Import")
	queue_command(func() -> void:
		assert(interface.scene_tabs.current_tab == 1, "'interface.scene_tabs.current_tab' should be '1'")
	)
	tabs_set_to_index(interface.scene_tabs, 0)
	auto_next()
	complete_step()

	context_set("2D")
	canvas_item_editor_center_at(Vector2.ZERO, CanvasItemEditorZoom._50)
	queue_command(func() -> void:
		var scene_viewport := EditorInterface.get_edited_scene_root().get_viewport()
		assert(
			Vector2i(scene_viewport.global_canvas_transform.origin) == scene_viewport.size / 2,
			"'scene_viewport.global_canvas_transform.origin' should be 'screen_viewport.size / 2'",
		)
	)
	auto_next()
	complete_step()

	canvas_item_editor_zoom_reset()
	queue_command(func() -> void:
		assert(
			is_equal_approx(interface.canvas_item_editor_zoom_widget.get_zoom(), 1.0),
			"'interface.canvas_item_editor_zoom_widget' 'zoom' should be equal to '1.0'",
		)
	)
	auto_next()
	complete_step()

	canvas_item_editor_flash_area(Rect2(0, 0, 100, 200))
	queue_command(func() -> void:
		var predicate := func(n: Node) -> bool: return n is FlashArea
		assert(
			overlays.ensure_get_dimmer_for(interface.base_control).get_children().filter(predicate).size() == 1,
			"'FlashArea' instance should be a child of the main screen 'Dimmer'",
		)
	)
	auto_next()
	complete_step()
