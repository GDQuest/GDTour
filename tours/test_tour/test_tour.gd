extends "res://addons/godot_tours/core/tour.gd"


func are_tasks_done() -> bool:
	return bubble.tasks_v_box_container.get_children().all(func(task: Task) -> bool: return task.is_done())


func delay(frames: int = 1) -> void:
	for _frame in range(frames):
		await interface.base_control.get_tree().process_frame


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
		await delay()
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
		await delay()
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
		await delay()
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
		await delay()
		for element: TextureRect in bubble.main_v_box_container.get_children():
			assert(
				element.texture == texture,
				"'bubble.main_v_box_container' element should a 'TextureRect' set to 'res://icon.svg'",
			)
	)
	auto_next()
	complete_step()

	var stream := load("res://tours/test_tour/test_video.ogv")
	bubble_add_video(stream)
	queue_command(func() -> void:
		await delay()
		for element: VideoStreamPlayer in bubble.main_v_box_container.get_children():
			assert(
				element.stream == stream,
				"'bubble.main_v_box_container' element should a 'VideoStreamPlayer' set to 'res://tours/test_tour/test_video.ogv'",
			)
	)
	auto_next()
	complete_step()

	bubble_add_task_press_button(interface.run_bar_play_current_button)
	queue_command(func() -> void:
		EditorInterface.play_current_scene()
		await delay()
		EditorInterface.stop_playing_scene()
		assert(are_tasks_done(), "'bubble_add_task_press_button()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_toggle_button(interface.context_switcher_2d_button)
	queue_command(func() -> void:
		EditorInterface.set_main_screen_editor("2D")
		await delay()
		assert(are_tasks_done(), "'bubble_add_task_toggle_button()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_set_tab_to_index(interface.inspector_tabs, 1)
	queue_command(func() -> void:
		interface.inspector_tabs.set_current_tab(1)
		await delay()
		assert(are_tasks_done(), "'bubble_add_task_set_tab_to_index()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_set_tab_to_title(interface.inspector_tabs, "Inspector")
	queue_command(func() -> void:
		interface.inspector_tabs.set_current_tab(0)
		await delay()
		assert(are_tasks_done(), "'bubble_add_task_set_tab_to_title()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_select_node("NodeToEdit")
	queue_command(func() -> void:
		editor_selection.clear()
		editor_selection.add_node(EditorInterface.get_edited_scene_root().find_child("NodeToEdit"))
		await delay()
		assert(are_tasks_done(), "'bubble_add_task_select_node()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_set_ranges({
		interface.snap_options_grid_step_controls[1]: 32,
		interface.snap_options_grid_step_controls[2]: 32,
	},
		interface.snap_options_grid_step_controls[0].text
	)
	queue_command(func() -> void:
		interface.snap_options_grid_step_controls[1].value = 32
		interface.snap_options_grid_step_controls[2].value = 32
		await delay()
		assert(are_tasks_done(), "'bubble_add_task_set_ranges()' all tasks should be done")
	)
	auto_next()
	complete_step()

	var text := "Text Header"
	bubble_set_header(text)
	queue_command(func() -> void:
		assert(
			bubble.header_rich_text_label.text == text,
			"'bubble.header_rich_text_label.text' should be '%s'" % text
		)
	)
	auto_next()
	complete_step()

	text = "Text Footer"
	bubble_set_footer(text)
	queue_command(func() -> void:
		assert(
			bubble.footer_rich_text_label.text == text,
			"'bubble.footer_rich_text_label.text' should be '%s'" % text
		)
	)
	auto_next()
	complete_step()

	bubble_set_background(texture)
	queue_command(func() -> void:
		assert(
			bubble.background_texture_rect.texture == texture,
			"'bubble.background_texture_rect.texture' should be 'res://icon.svg'",
		)
	)
	auto_next()
	complete_step()

	bubble_move_and_anchor(interface.main_screen, Bubble.At.TOP_RIGHT, 0)
	queue_command(func() -> void:
		await delay(2)
		await bubble.tween.finished
		var should_be_global_position := interface.main_screen.global_position + Vector2(interface.main_screen.size.x - bubble.panel_container.size.x, 0)
		assert(
			bubble.at == Bubble.At.TOP_RIGHT and bubble.panel_container.global_position.is_equal_approx(should_be_global_position),
			"'bubble_move_and_anchor()' should place the bubble at the top right of main screen",
		)
	)
	auto_next()
	complete_step()

	bubble_move_and_anchor(interface.main_screen)
	bubble_set_avatar_at(Bubble.AvatarAt.RIGHT)
	queue_command(func() -> void:
		await delay(2)
		await bubble.avatar_tween_position.finished
		var editor_scale := EditorInterface.get_editor_scale()
		var should_be_position := Vector2(bubble.panel_container.size.x + 3.0 * editor_scale, -8.0 * editor_scale)
		assert(
			bubble.avatar_at == Bubble.AvatarAt.RIGHT and bubble.avatar.position.is_equal_approx(should_be_position),
			"'bubble_set_avatar_at()' should place the bubble avatar at right",
		)
	)
	auto_next()
	complete_step()

	var size := Vector2(640, 480)
	bubble_set_avatar_at(Bubble.AvatarAt.LEFT)
	bubble_set_minimum_size_scaled(size)
	queue_command(func() -> void:
		size *= EditorInterface.get_editor_scale()
		assert(
			bubble.panel_container.custom_minimum_size.is_equal_approx(size),
			"'bubble_set_minimum_size_scaled()' should set the bubble minimum size to '%s'" % str(size),
		)
	)
	auto_next()
	complete_step()
