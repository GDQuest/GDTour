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

	context_set_2d()
	queue_command(func() -> void:
		await interface.base_control.get_tree().process_frame
	)
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

	context_set("2D")
	queue_command(func() -> void:
		assert(
			interface.context_switcher_2d_button.button_pressed == true,
			"'interface.context_switcher_2d_button' should be pressed",
		)
	)
	auto_next()
	complete_step()

	context_set("3D")
	queue_command(func() -> void:
		assert(
			interface.context_switcher_3d_button.button_pressed == true,
			"'interface.context_switcher_3d_button' should be pressed",
		)
	)
	auto_next()
	complete_step()

	context_set("Script")
	queue_command(func() -> void:
		assert(
			interface.context_switcher_script_button.button_pressed == true,
			"'interface.context_switcher_script_button' should be pressed"
		)
	)
	auto_next()
	complete_step()

	context_set("AssetLib")
	queue_command(func() -> void:
		assert(
			interface.context_switcher_asset_lib_button.button_pressed == true,
			"'interface.context_switcher_asset_lib_button' should be pressed",
		)
	)
	auto_next()
	complete_step()

	var title := "Test Title"
	bubble_set_title(title)
	queue_command(func() -> void:
		assert(
			bubble.title_label.text == title, "'bubble.title_label.text' should be 'Test Title'"
		)
	)
	auto_next()
	complete_step()

	var lines: Array[String] = ["Test Line 1", "Test Line 2"]
	bubble_add_text(lines)
	queue_command(func() -> void:
		await bubble.get_tree().process_frame
		assert(bubble.main_v_box_container.get_child_count() == 2, "'bubble.main_v_box_container' should have '2' children")
		var elements := bubble.main_v_box_container.get_children()
		for i in range(bubble.main_v_box_container.get_child_count()):
			var element := elements[i]
			var line := lines[i]
			assert(
				element is RichTextLabel and element.text == line,
				"'bubble.main_v_box_container' '%d' element should have text '%s'" % [i, line],
			)
	)
	auto_next()
	complete_step()

	lines = ["Code Line 1", "Code Line 2", "Code Line 3"]
	bubble_add_code(lines)
	queue_command(func() -> void:
		await bubble.get_tree().process_frame
		assert(bubble.main_v_box_container.get_child_count() == 3, "'bubble.main_v_box_container' should have '3' children")
		var elements := bubble.main_v_box_container.get_children()
		for i in range(bubble.main_v_box_container.get_child_count()):
			var element := elements[i]
			var line := lines[i]
			assert(
				element is CodeEdit and element.text == line,
				"'bubble.main_v_box_container' '%d' element should have text '%s'" % [i, line],
			)
	)
	auto_next()
	complete_step()

	var texture := load("res://icon.svg")
	bubble_add_texture(texture)
	queue_command(func() -> void:
		await bubble.get_tree().process_frame
		for element: TextureRect in bubble.main_v_box_container.get_children():
			assert(
				element.texture == texture,
				"'bubble.main_v_box_container' element should a 'TextureRect' set to 'icon.svg'",
			)
	)
	auto_next()
	complete_step()
