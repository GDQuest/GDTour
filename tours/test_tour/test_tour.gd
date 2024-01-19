## Integration test for the tour framework. Runs many of the tour APIs and uses asserts to verify the results.
## Because of the nature of interactive tours and the complex interactions with the Godot editor, we can't rely on
## unit tests to verify the results. This is why we have this integration test.
extends "../../addons/godot_tours/tour.gd"

const Highlight := preload("../../addons/godot_tours/overlays/highlight/highlight.gd")

const HIGHLIGHT_GROUP := "highlight"


func get_highlights() -> Array[Highlight]:
	await delay_process_frame()
	var result: Array[Highlight] = []
	var dimmer := overlays.ensure_get_dimmer_for(interface.base_control)
	result.assign(dimmer.get_tree().get_nodes_in_group(HIGHLIGHT_GROUP))
	return result


func _build() -> void:
	var TestTourBubblePackedScene := load("res://test_tour_bubble.tscn")
	swap_bubble(TestTourBubblePackedScene)
	auto_next()
	complete_step()

	swap_bubble()
	auto_next()
	complete_step()

	var file_path := "res://test_tour_2d.tscn"
	scene_open(file_path)
	queue_command(func() -> void:
		var name := "TestTour2D"
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(edited_scene_root is Node2D and edited_scene_root.name == name, "'edited_scene_root' should be '%s'" % name)
	)
	auto_next()
	complete_step()

	scene_select_nodes_by_path(["TestTour2D", "TestTour2D/NodeToEdit"])
	queue_command(func() -> void:
		var names: Array[String] = ["TestTour2D", "NodeToEdit"]
		var selected_nodes := editor_selection.get_selected_nodes()
		assert(selected_nodes.size() == 2, "'selected_nodes' should have size '2'")
		for selected_node in selected_nodes:
			assert(selected_node.name in names, "'selected_node.name' should be one of '%s'" % ", ".join(names))
	)
	auto_next()
	complete_step()

	scene_toggle_lock_nodes_by_path(["TestTour2D"])
	queue_command(func() -> void:
		var edited_scene_root := EditorInterface.get_edited_scene_root()
		assert(edited_scene_root.get_meta(&"_edit_lock_"), "'edited_scene_root' '_edit_lock_' meta should be 'true'")
	)
	auto_next()
	complete_step()

	scene_toggle_lock_nodes_by_path(["TestTour2D"], false)
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
		await delay_process_frame()
	)
	canvas_item_editor_center_at(Vector2.ZERO, 0.5)
	queue_command(func() -> void:
		await delay_process_frame()
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

	canvas_item_editor_flash_area(Rect2(0, 0, 1200, 900))
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
	queue_command(func() -> void: bubble.add_text(lines))
	queue_command(func() -> void:
		await delay_process_frame()
		assert(bubble.main_v_box_container.get_child_count() == 2, "'bubble.main_v_box_container' should have '2' children")
		var elements: Array[Node] = bubble.main_v_box_container.get_children()
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
	queue_command(func() -> void: bubble.add_code(lines))
	queue_command(func() -> void:
		await delay_process_frame()
		assert(bubble.main_v_box_container.get_child_count() == 3, "'bubble.main_v_box_container' should have '3' children")
		var elements: Array[Node] = bubble.main_v_box_container.get_children()
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

	file_path = "res://icon.svg"
	var texture := load(file_path)
	queue_command(func() -> void: bubble.add_texture(texture))
	queue_command(func() -> void:
		await delay_process_frame()
		for element: TextureRect in bubble.main_v_box_container.get_children():
			assert(
				element.texture == texture,
				"'bubble.main_v_box_container' element should a 'TextureRect' set to '%s'" % file_path,
			)
	)
	auto_next()
	complete_step()

	file_path = "res://test_video.ogv"
	var stream := load(file_path)
	queue_command(func() -> void: bubble.add_video(stream))
	queue_command(func() -> void:
		await delay_process_frame()
		for element: VideoStreamPlayer in bubble.main_v_box_container.get_children():
			assert(
				element.stream == stream,
				"'bubble.main_v_box_container' element should a 'VideoStreamPlayer' set to '%s'" % file_path,
			)
	)
	auto_next()
	complete_step()

	bubble_add_task_press_button(interface.run_bar_play_current_button)
	queue_command(func() -> void:
		EditorInterface.play_current_scene()
		await delay_process_frame()
		EditorInterface.stop_playing_scene()
		assert(bubble.check_tasks(), "'bubble_add_task_press_button()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_toggle_button(interface.context_switcher_2d_button)
	queue_command(func() -> void:
		EditorInterface.set_main_screen_editor("2D")
		await delay_process_frame()
		assert(bubble.check_tasks(), "'bubble_add_task_toggle_button()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_set_tab_to_index(interface.inspector_tabs, 1)
	queue_command(func() -> void:
		interface.inspector_tabs.set_current_tab(1)
		await delay_process_frame()
		assert(bubble.check_tasks(), "'bubble_add_task_set_tab_to_index()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_set_tab_to_title(interface.inspector_tabs, "Inspector")
	queue_command(func() -> void:
		interface.inspector_tabs.set_current_tab(0)
		await delay_process_frame()
		assert(bubble.check_tasks(), "'bubble_add_task_set_tab_to_title()' all tasks should be done")
	)
	auto_next()
	complete_step()

	bubble_add_task_select_node("NodeToEdit")
	queue_command(func() -> void:
		editor_selection.clear()
		editor_selection.add_node(EditorInterface.get_edited_scene_root().find_child("NodeToEdit"))
		await delay_process_frame()
		assert(bubble.check_tasks(), "'bubble_add_task_select_node()' all tasks should be done")
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
		await delay_process_frame()
		assert(bubble.check_tasks(), "'bubble_add_task_set_ranges()' all tasks should be done")
	)
	auto_next()
	complete_step()

	var text := "Text Header"
	queue_command(func() -> void: bubble.set_header(text))
	queue_command(func() -> void:
		assert(
			bubble.header_rich_text_label.text == text,
			"'bubble.header_rich_text_label.text' should be '%s'" % text
		)
	)
	auto_next()
	complete_step()

	text = "Text Footer"
	queue_command(func() -> void: bubble.set_footer(text))
	queue_command(func() -> void:
		assert(
			bubble.footer_rich_text_label.text == text,
			"'bubble.footer_rich_text_label.text' should be '%s'" % text
		)
	)
	auto_next()
	complete_step()

	queue_command(func() -> void: bubble.set_background(texture))
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
		await delay_process_frame(2)
		await bubble.tween.finished
		var should_be_global_position := interface.main_screen.global_position + Vector2(interface.main_screen.size.x - bubble.panel.size.x, 0)
		assert(
			bubble.at == Bubble.At.TOP_RIGHT and bubble.panel.global_position.is_equal_approx(should_be_global_position),
			"'bubble_move_and_anchor()' should place the bubble at the top right of main screen",
		)
	)
	auto_next()
	complete_step()

	bubble_move_and_anchor(interface.main_screen)
	bubble_set_avatar_at(Bubble.AvatarAt.RIGHT)
	queue_command(func() -> void:
		await delay_process_frame(2)
		await bubble.avatar_tween_position.finished
		var editor_scale := EditorInterface.get_editor_scale()
		var should_be_position := Vector2(bubble.panel.size.x + 3.0 * editor_scale, -8.0 * editor_scale)
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
			bubble.panel.custom_minimum_size.is_equal_approx(size),
			"'bubble_set_minimum_size_scaled()' should set the bubble minimum size to '%s'" % str(size),
		)
	)
	auto_next()
	complete_step()

	var node_names: Array[String] = ["NodeToEdit"]
	bubble_set_minimum_size_scaled()
	highlight_scene_nodes_by_name(node_names)
	queue_command(func() -> void:
		var dimmer := overlays.ensure_get_dimmer_for(interface.base_control)
		await delay_process_frame()
		var highlights := dimmer.get_tree().get_nodes_in_group(HIGHLIGHT_GROUP)
		assert(highlights.size() == 1, "'highlight_scene_nodes_by_name()' highlights '%s'" % ", ".join(node_names))
		for highlight: Highlight in highlights:
			assert(
				interface.scene_dock.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_scene_nodes_by_name()' places highlight in Scene dock"
			)
	)
	auto_next()
	complete_step()

	var node_paths: Array[String] = ["TestTour2D", "TestTour2D/NodeToEdit"]
	highlight_scene_nodes_by_path(node_paths)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_scene_nodes_by_path()' highlights '%s' Scene dock nodes" % ", ".join(node_paths))
		for highlight in highlights:
			assert(
				interface.scene_dock.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_scene_nodes_by_path()' places highlight in Scene dock"
			)
	)
	auto_next()
	complete_step()

	var filesystem_paths: Array[String] = ["res://icon.svg"]
	highlight_filesystem_paths(filesystem_paths)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_filesystem_paths()' highlights '%s'" % ", ".join(filesystem_paths))
		for highlight in highlights:
			assert(
				interface.filesystem_dock.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_filesystem_paths()' places highlight in FileSystem dock"
			)
	)
	auto_next()
	complete_step()

	var inspector_properties: Array[StringName] = [&"position", &"scale"]
	scene_select_nodes_by_path(["TestTour2D/NodeToEdit"])
	highlight_inspector_properties(inspector_properties)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 2, "'highlight_inspector_properties()' highlights '%s'" % ", ".join(inspector_properties))
		for highlight in highlights:
			assert(
				interface.inspector_dock.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_inspector_properties()' places highlight in Inspector dock"
			)
	)
	auto_next()
	complete_step()

	var signals: Array[String] = ["draw", "hidden"]
	tabs_set_to_index(interface.inspector_tabs, 1)
	queue_command(func() -> void: interface.node_dock_signals_button.pressed.emit())
	highlight_signals(signals)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_signals()' highlights '%s'" % ", ".join(signals))
		for highlight in highlights:
			assert(
				interface.node_dock.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_signals()' places highlight in Node dock"
			)
	)
	auto_next()
	complete_step()

	file_path = "res://test_tour_2d.gd"
	var script := load(file_path)
	context_set_script()
	queue_command(EditorInterface.edit_script.bind(script))
	highlight_code(3, 4)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_code()' highlights lines '3 - 4'")
		for highlight in highlights:
			assert(
				interface.script_editor_code_panel.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_code()' places highlight in code editor"
			)
	)
	auto_next()
	complete_step()

	highlight_controls([interface.run_bar])
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_controls()' highlights 'interface.run_bar'")
		for highlight in highlights:
			assert(
				interface.run_bar.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_controls()' places highlight in 'interface.run_bar'"
			)
	)
	auto_next()
	complete_step()

	var tab_index := 0
	highlight_tabs_index(interface.inspector_tabs, tab_index)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_tabs_index()' highlights 'interface.inspector_tabs' index '%d'" % [tab_index])
		for highlight in highlights:
			assert(
				interface.inspector_tabs.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_tabs_index()' places highlight in 'interface.run_bar'"
			)
	)
	auto_next()
	complete_step()

	var tab_title := "Import"
	highlight_tabs_title(interface.scene_tabs, tab_title)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_tabs_title()' highlights 'interface.scene_tabs' titled '%s'" % [tab_title])
		for highlight in highlights:
			assert(
				interface.scene_tabs.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_tabs_title()' places highlight in 'interface.scene_tabs'"
			)
	)
	auto_next()
	complete_step()

	var canvas_item_highlight_rect := Rect2(0, 0, 800, 800)
	context_set_2d()
	highlight_canvas_item_editor_rect(canvas_item_highlight_rect)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_canvas_item_editor_rect()' highlights part of 'interface.canvas_item_editor_viewport'")
		for highlight in highlights:
			assert(
				interface.canvas_item_editor_viewport.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_tabs_title()' places highlight in 'interface.canvas_item_editor_viewport'"
			)
	)
	auto_next()
	complete_step()

	var item_index := 1
	scene_select_nodes_by_path(["TestTour2D/TileMap"])
	tabs_set_to_index(interface.tilemap_tabs, 0)
	queue_command(func() -> void:
		interface.bottom_button_tilemap.pressed.emit()
		await delay_process_frame(2)
	)
	highlight_tilemap_list_item(interface.tilemap_tiles, item_index)
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'highlight_tilemap_list_item()' highlights item '%d' of 'interface.tilemap_tiles'" % [item_index])
		for highlight in highlights:
			assert(
				interface.tilemap_tiles.get_global_rect().encloses(highlight.get_global_rect()),
				"'highlight_tilemap_list_item()' places highlight in 'interface.tilemap_tiles'"
			)
	)
	auto_next()
	complete_step()

	context_set_3d()
	queue_command(func() -> void:
		interface.bottom_button_tilemap.toggled.emit(false)
		await delay_process_frame(2)
	)
	highlight_spatial_editor_camera_region(Vector3.ZERO, Vector3(2, 0, 3))
	queue_command(func() -> void:
		var highlights := await get_highlights()
		assert(highlights.size() == 1, "'higlight_spatial_editor_camera_region()' highlights part of 'interface.spatial_editor_surface'")
		for highlight in highlights:
			assert(
				interface.spatial_editor_surface.get_global_rect().encloses(highlight.get_global_rect()),
				"'higlight_spatial_editor_camera_region()' places highlight in 'interface.spatial_editor_surface'"
			)
	)
	auto_next()
	complete_step()

	var to := Vector2(400, 600)
	context_set_2d()
	mouse_move_by_position(200 * Vector2.ONE, to)
	mouse_bounce()
	auto_next()
	complete_step()
