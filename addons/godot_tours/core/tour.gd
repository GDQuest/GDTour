## Main class to use to design a tour. Provides an API to design tour steps.
##
## The tour is a series of steps, each step being a series of commands to execute.
## Commands are executed in the order they are added.
##
## This class provides many common commands to use in your tour, like selecting a node in the scene
## tree, highlighting a control, or playing a mouse animation.
##
## Each command is a [Command] object, which is a wrapper around a callable and its parameters. You can
## run any function in the editor by wrapping it in a Command object. Use the utility function [queue_command()]
## to create a Command object faster.
##
## To design a tour, override the [_build()] function and write all your tour steps in it:
##
## 1. Call API functions to queue commands required for your step.
## 2. Call [complete_step()] to complete and save the current _step_commands as a new.
##
## See the provided demo tour for an example.
extends RefCounted

## Emitted when the tour moves to the next or previous _step_commands.
signal step_changed(step_index: int)
## Emitted when the tour is closed or the user completes the last _step_commands.
signal ended()

## Represents one command to execute in a _step_commands. All commands are executed in the order they are added.
## Use the Command() function to create a Command object faster.
class Command:
	var callable := func() -> void: pass
	var parameters := []

	func _init(callable: Callable, parameters := []) -> void:
		self.callable = callable
		self.parameters = parameters

	func force() -> void:
		await callable.callv(parameters)

const Log := preload("log.gd")
const EditorInterfaceAccess := preload("editor_interface_access.gd")
const Utils := preload("utils.gd")
const Overlays := preload("overlays/overlays.gd")
const Bubble := preload("bubble/bubble.gd")
const Task := preload("bubble/task/task.gd")
const Mouse := preload("mouse/mouse.gd")
const TranslationService := preload("translation/translation_service.gd")

const WARNING_MESSAGE := "[color=orange][WARN][/color] %s for [b]'%s()'[/b] at [b]'_step_commands(=%d)'[/b]."

enum Direction {BACK = -1, NEXT = 1}
enum CanvasItemEditorZoom {_50, _100, _200}

const EVENTS := {
	shift_1 = preload("events/shift_1_input_event_key.tres"),
	_1 = preload("events/1_input_event_key.tres"),
	_2 = preload("events/2_input_event_key.tres"),
	f = preload("events/f_input_event_key.tres"),
}
## Index of the _step_commands currently running.
var index := -1: set = set_index
var _steps: Array[Array] = []
var _step_commands: Array[Command] = []


## Overlays added to the current scene to highlight a specific area.
## We don't set their owner property so they stay hidden from the scene tree, but still show in the viewport.
## They are automatically cleared on new _steps.
var game_world_overlays := []
var state := {}

var log := Log.new()
var editor_selection: EditorSelection = null
## Object that provides access to many nodes in the editor's user interface.
var interface: EditorInterfaceAccess = null
var overlays: Overlays = null
var translation_service: TranslationService = null
var mouse: Mouse = null
var bubble: Bubble = null


func _init(interface: EditorInterfaceAccess, overlays: Overlays,  translation_service: TranslationService) -> void:
	self.editor_selection = EditorInterface.get_selection()
	self.interface = interface
	self.overlays = overlays
	self.translation_service = translation_service

	var BubblePackedScene := load("res://addons/godot_tours/core/bubble/bubble.tscn")
	bubble = BubblePackedScene.instantiate()
	bubble.setup(interface, translation_service)
	bubble.back_button.pressed.connect(func():
		EditorInterface.stop_playing_scene()
		back()
	)
	bubble.next_button.pressed.connect(func():
		EditorInterface.stop_playing_scene()
		next()
	)
	bubble.close_requested.connect(func():
		clean_up()
		toggle_visible(false)
		ended.emit()
	)
	translation_service.update_tour_key(get_script().resource_path)

	# Applies the default layout so every tour starts from the same UI state.
	interface.restore_default_layout()
	_build()
	bubble.set_step_count(_steps.size())
	step_changed.connect(bubble.update_step_count_display)


## Virtual function to override to build the tour. Write all your tour steps in it.
## This function is called when the tour is created, after connecting signals and re-applying the
## editor's default layout, which helps avoid many UI edge cases.
func _build() -> void:
	pass


func clean_up() -> void:
	_clear_game_world_overlays()
	clear_mouse()
	log.clean_up()
	if is_instance_valid(bubble):
		bubble.queue_free()


func set_index(value: int) -> void:
	var step_count := _steps.size()
	var stride := Direction.BACK if value < index else Direction.NEXT
	value = clampi(value, -1, step_count)
	for index in range(index + stride, clampi(value + stride, -1, step_count), stride):
		log.info("[_step_commands: %d]\n%s" % [index, interface.logger_rich_text_label.get_parsed_text()])
		run(_steps[index])
	index = clampi(value, 0, step_count - 1)
	bubble.back_button.visible = true
	bubble.finish_button.visible = false
	if index == 0:
		bubble.back_button.visible = false
		bubble.next_button.visible = true
		bubble.next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	elif index == step_count - 1:
		bubble.next_button.visible = false
		bubble.finish_button.visible = true
	else:
		bubble.back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bubble.next_button.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND

	step_changed.emit(index)


func back() -> void:
	set_index(index + Direction.BACK)


func next() -> void:
	set_index(index + Direction.NEXT)


## Completes the current step's commands, adding some more commands to clear the bubble, overlays, and the mouse.
## Then, this function appends the completed step (an array of Command objects) to the tour.
func complete_step() -> void:
	var step_start: Array[Command] = [
		Command.new(bubble.clear),
		Command.new(overlays.clean_up),
		Command.new(overlays.ensure_get_dimmer_for.bind(interface.base_control)),
		Command.new(clear_mouse),
		Command.new(_clear_game_world_overlays),
	]
	_step_commands.push_back(Command.new(play_mouse))
	_steps.push_back(step_start + _step_commands)
	_step_commands = []
	if index == -1:
		set_index(0)


func run(current_step: Array[Command]) -> void:
	for l in current_step:
		await l.force()


## Appends a command to the currently edited step. Commands are executed in the order they are added.
## To complete a step and start creating the next one, call [complete_step()].
func queue_command(callable: Callable, parameters := []) -> void:
	_step_commands.push_back(Command.new(callable, parameters))


func scene_open(path: String) -> void:
	if not FileAccess.file_exists(path) and path.get_extension() != "tscn":
		warn("[b]'path(=%s)'[/b] doesn't exist or has wrong extension" % path, "scene_open")
		return
	queue_command(EditorInterface.open_scene_from_path, [path])


func scene_edit_node(node: Node) -> void:
	if node == null:
		warn("Called with [b]null[/b] value", "scene_edit_node")
		return
	queue_command(EditorInterface.edit_node, [node])


func scene_select_nodes_by_path(paths: Array[String] = []) -> void:
	scene_deselect_all_nodes()
	queue_command(func() -> void:
		var root := EditorInterface.get_edited_scene_root()
		if root.name in paths:
			editor_selection.add_node(root)
		for child in root.find_children("*"):
			if child.owner == root and root.name.path_join(root.get_path_to(child)) in paths:
				editor_selection.add_node(child)
	)


func scene_toggle_lock_nodes_by_path(node_paths: Array[String] = [], is_locked := true) -> void:
	queue_command(func get_and_lock_nodes() -> void:
		var root := EditorInterface.get_edited_scene_root()
		if root.name in node_paths:
			root.set_meta("_edit_lock_", is_locked)
		for child in root.find_children("*"):
			if child.owner == root and root.name.path_join(root.get_path_to(child)) in node_paths:
				child.set_meta("_edit_lock_", is_locked)
	)


func scene_deselect_all_nodes() -> void:
	queue_command(func() -> void:
		EditorInterface.edit_node(null)
		editor_selection.clear()
	)


func tabs_set_to_index(tabs: TabBar, index: int) -> void:
	if index < 0 or index >= tabs.tab_count:
		warn("[b]'index(=%d)'[/b] not in [b]'range(0, tabs.tab_count(=%d))'[/b]." % [index, tabs.tab_count], "tabs_set_to_index")
		return
	queue_command(tabs.set_current_tab, [index])


func tabs_set_to_title(tabs: TabBar, title: String) -> void:
	var index := find_tabs_title(tabs, title)
	if index == -1:
		var titles := range(tabs.tab_count).map(func(index: int) -> String: return tabs.get_tab_title(index))
		warn("[b]'title(=%s)'[/b] not found in tabs [b]'[%s]'[/b]." % [title, ", ".join(titles)], "tabs_set_to_title")
	else:
		tabs_set_to_index(tabs, index)


func tree_activate_by_prefix(tree: Tree, prefix: String) -> void:
	queue_command(func() -> void:
		if tree == interface.node_dock_signals_tree and interface.signals_dialog_window.visible:
			return
		await tree.get_tree().process_frame
		tree.deselect_all()
		var items := Utils.filter_tree_items(
			tree.get_root(),
			func(item: TreeItem) -> bool: return item.get_text(0).begins_with(prefix)
		)
		for item in items:
			item.select(0)
		tree.item_activated.emit()
	)


func canvas_item_editor_center_at(position := Vector2.ZERO, zoom := CanvasItemEditorZoom._100) -> void:
	const zoom_to_event := {
		CanvasItemEditorZoom._50: EVENTS.shift_1,
		CanvasItemEditorZoom._100: EVENTS._1,
		CanvasItemEditorZoom._200: EVENTS._2,
	}
	queue_command(func() -> void:
		interface.canvas_item_editor.gui_input.emit(zoom_to_event[zoom])
		interface.canvas_item_editor.center_at(position)
	)


## Resets the zoom of the 2D viewport to 100%.
## FIXME: doesn't work.
func canvas_item_editor_zoom_reset() -> void:
	queue_command(func set_zoom_to_100_percent() -> void:
		interface.canvas_item_editor_viewport.grab_focus()
		interface.canvas_item_editor_zoom_button_reset.set_deferred("button_pressed", true)
	)


## Plays a flash animation in the 2D game viewport, over the desired global_rect.
func canvas_item_editor_flash_area(global_rect: Rect2) -> void:
	const FlashAreaPackedScene := preload("res://addons/godot_tours/core/overlays/flash_area/flash_area.tscn")
	queue_command(func flash_canvas_item_editor() -> void:
		var flash = FlashAreaPackedScene.instantiate()
		EditorInterface.get_edited_scene_root().add_child(flash)
		game_world_overlays.append(flash)
		flash.size = global_rect.size
		flash.global_position = global_rect.position
	)


func spatial_editor_focus() -> void:
	queue_command(func() -> void: interface.spatial_editor_surface.gui_input.emit(EVENTS.f))


func spatial_editor_focus_node_by_paths(paths: Array[String]) -> void:
	scene_select_nodes_by_path(paths)
	queue_command(func() -> void: interface.spatial_editor_surface.gui_input.emit(EVENTS.f))


func context_set(type: String) -> void:
	queue_command(EditorInterface.set_main_screen_editor, [type])


func context_set_2d() -> void:
	context_set("2D")


func context_set_3d() -> void:
	context_set("3D")


func context_set_script() -> void:
	context_set("Script")


func context_set_asset_lib() -> void:
	context_set("AssetLib")


func bubble_set_title(title_text: String) -> void:
	queue_command(bubble.set_title, [title_text])


func bubble_add_text(lines: Array[String]) -> void:
	queue_command(bubble.add_text, [lines])


func bubble_add_code(lines: Array[String]) -> void:
	queue_command(bubble.add_code, [lines])


func bubble_add_texture(texture: Texture2D) -> void:
	queue_command(bubble.add_texture, [texture])


func bubble_add_video(stream: VideoStream) -> void:
	queue_command(bubble.add_video, [stream])


func bubble_add_task(description: String, repeat: int, repeat_callable: Callable, error_predicate := noop_error_predicate) -> void:
	queue_command(bubble.add_task, [description, repeat, repeat_callable, error_predicate])


func bubble_add_task_press_button(button: Button, description := "") -> void:
	var text: String = description
	if text.is_empty():
		if button.text.is_empty():
			text = button.tooltip_text
		else:
			text = button.text
	text = text.replace(".", "")
	description = gtr("Press the [b]%s[/b] button.") % text
	bubble_add_task(
		description,
		1,
		func(task: Task) -> int: return 1 if task.is_done() or button.button_pressed else 0,
		noop_error_predicate,
	)


func bubble_add_task_toggle_button(button: Button, is_toggled := true, description := "") -> void:
	var text: String = description
	if text.is_empty():
		if button.text.is_empty():
			text = button.tooltip_text
		else:
			text = button.text
	text = text.replace(".", "")

	if not button.toggle_mode:
		warn("[b]'button(=%s)'[/b] at [b]'path(=%s)'[/b] doesn't have toggle_mode ON." % [str(button), button.get_path()], "bubble_add_task_toggle_button")
		return

	const toggle_map := {true: "ON", false: "OFF"}
	description = gtr("Turn the [b]%s[/b] button %s.") % [text, toggle_map[is_toggled]]
	bubble_add_task(
		description,
		1,
		func(_task: Task) -> int: return 1 if button.button_pressed == is_toggled else 0,
		noop_error_predicate,
	)


func bubble_add_task_set_tab_to_index(tabs: TabBar, index: int, description := "") -> void:
	if index < 0 or index >= tabs.tab_count:
		warn("[b]'index(=%d)'[/b] not in [b]'range(0, tabs.tab_count(=%d))'[/b]" % [index, tabs.tab_count], "bubble_add_task_set_tab_to_index")
		return
	var which_tabs: String = "[b]%s[/b] tabs" % interface.tabs_text.get(tabs, "")
	description = gtr("Set %s to tab with index [b]%d[/b].") % [which_tabs, index] if description.is_empty() else description
	queue_command(bubble.add_task, [description, 1, func(_task: Task) -> int: return 1 if index == tabs.current_tab else 0, noop_error_predicate])


func bubble_add_task_set_tab_to_title(tabs: TabBar, title: String, description := "") -> void:
	var index := find_tabs_title(tabs, title)
	if index == -1:
		var titles := range(tabs.tab_count).map(func(index: int) -> String: return tabs.get_tab_title(index))
		warn("[b]'title(=%s)'[/b] not found in tabs [b]'[%s]'[/b]" % [title, ", ".join(titles)], "bubble_add_task_set_tab_to_title")
	else:
		var which_tabs: String = "[b]%s[/b] tabs" % interface.tabs_text.get(tabs, "")
		description = gtr("Change the tab to [b]%s[/b].") % [title] if description.is_empty() else description
		bubble_add_task_set_tab_to_index(tabs, index, description)


func bubble_add_task_select_node(node_name: String) -> void:
	bubble_add_task(
		"Select the [b]" + node_name + "[/b] node in the [b]Scene Dock[/b].",
		1,
		func task_select_node(_task: Task) -> int:
			var scene_root: Node = EditorInterface.get_edited_scene_root()
			var target_node: Node = scene_root.find_child(node_name)
			var selected_nodes := EditorInterface.get_selection().get_selected_nodes()
			return 1 if selected_nodes.size() == 1 and selected_nodes.front() == target_node else 0,
	)


func bubble_add_task_set_ranges(ranges: Dictionary, label_text: String, description := "") -> void:
	var controls := ranges.keys()
	if controls.any(func(n: Node) -> bool: return not n is Range):
		var classes := controls.map(func(x: Node) -> String: return x.get_class())
		warn("Not all 'ranges' are of type 'Range' [b]'[%s]'[/b]" % [classes], "bubble_add_task_set_range_value")
	else:
		if description.is_empty():
			description = gtr(
				"""Set [b]%s[/b] to [code]%s[/code]"""
				% [
					label_text,
					"x".join(ranges.keys().map(func(r: Range) -> String: return str(snappedf(ranges[r], r.step)))),
				]
			)
		bubble_add_task(
			description,
			1,
			func set_ranges(_task: Task) -> int:
				return 1 if ranges.keys().all(func(r: Range) -> bool: return r.value == ranges[r]) else 0,
		)


func bubble_set_header(text: String) -> void:
	queue_command(bubble.set_header, [text])


func bubble_set_footer(text: String) -> void:
	queue_command(bubble.set_footer, [text])


func bubble_set_background(texture: Texture2D) -> void:
	queue_command(bubble.set_background, [texture])


## Moves and anchors the bubble relative to the given control.
## You can optionally set a margin and an offset to fine-tune the bubble's position.
func bubble_move_and_anchor(control: Control, at := Bubble.At.CENTER, margin := 16.0, offset := Vector2.ZERO) -> void:
	queue_command(bubble.move_and_anchor, [control, at, margin, offset])


## Places the avatar on the given side at the top of the bubble.
func bubble_set_avatar_at(at: Bubble.AvatarAt) -> void:
	queue_command(bubble.set_avatar_at, [at])


## Changes the minimum size of the bubble, scaled by the editor scale setting.
## This is useful to have the bubble take the same space on different screens.
##
## If you want to set the minimum size for one _step_commands only, for example, when using only a title
## you can call this function with a `size` of `Vector2.ZERO` on the following _step_commands to let the bubble
## automatically control its size again.
func bubble_set_minimum_size_scaled(size := Vector2.ZERO) -> void:
	queue_command(bubble.set_custom_minimum_size, [size * EditorInterface.get_editor_scale()])


func bubble_set_avatar_neutral() -> void:
	queue_command(bubble.avatar.set_expression, [bubble.avatar.Expressions.NEUTRAL])


func bubble_set_avatar_happy() -> void:
	queue_command(bubble.avatar.set_expression, [bubble.avatar.Expressions.HAPPY])


func bubble_set_avatar_surprised() -> void:
	queue_command(bubble.avatar.set_expression, [bubble.avatar.Expressions.SURPRISED])


func highlight_scene_nodes_by_name(names: Array[String], play_flash := true, button_index := -1) -> void:
	queue_command(overlays.highlight_scene_nodes_by_name, [names, play_flash, button_index])


func highlight_scene_nodes_by_path(paths: Array[String], play_flash := true, button_index := -1) -> void:
	queue_command(overlays.highlight_scene_nodes_by_path, [paths, play_flash, button_index])


func highlight_filesystem_paths(paths: Array[String], play_flash := true) -> void:
	queue_command(overlays.highlight_filesystem_paths, [paths, play_flash])


func highlight_inspector_properties(names: Array[StringName], play_flash := true) -> void:
	queue_command(overlays.highlight_inspector_properties, [names, play_flash])


func highlight_signals(paths: Array[String], play_flash := true) -> void:
	queue_command(overlays.highlight_signals, [paths, play_flash])


func highlight_code(start: int, end := 0, caret := 0, play_flash := false, do_center := true) -> void:
	queue_command(overlays.highlight_code, [start, end, caret, play_flash, do_center])


func highlight_controls(controls: Array[Control], play_flash := false) -> void:
	queue_command(overlays.highlight_controls, [controls, play_flash])


func highlight_tabs_index(tabs: Control, play_flash := true, index := -1) -> void:
	queue_command(overlays.highlight_tab_index, [tabs, play_flash, index])


func highlight_tabs_title(tabs: Control, title: String, play_flash := true) -> void:
	queue_command(overlays.highlight_tab_title, [tabs, title, play_flash])


func highlight_canvas_item_editor_rect(rect: Rect2, play_flash := false) -> void:
	queue_command(func() -> void:
		var rect_getter := func() -> Rect2:
			return EditorInterface.get_edited_scene_root().get_viewport().get_screen_transform() * rect
		overlays.add_highlight_to_control(interface.canvas_item_editor, rect_getter, play_flash),
	)


func highlight_tilemap_list_item(item_list: ItemList, item_index: int, play_flash := true) -> void:
	queue_command(overlays.highlight_tilemap_list_item.bind(item_list, item_index, play_flash))


func higlight_spatial_editor_camera_region(start: Vector3, end: Vector3, index := 0, play_flash := false) -> void:
	if index < 0 or index > interface.spatial_editor_cameras.size():
		warn("[b]'index(=%d)'[/b] not in [b]'range(0, interface.spatial_editor_cameras.size()(=%d))'[/b]." % [index, interface.spatial_editor_cameras.size()], "higlight_spatial_editor_camera_region")
		return
	var camera := interface.spatial_editor_cameras[index]
	queue_command(func() -> void:
		if camera.is_position_behind(start) or camera.is_position_behind(end):
			return
		var rect_getter := func() -> Rect2:
			var s := camera.unproject_position(start)
			var e := camera.unproject_position(end)
			return camera.get_viewport().get_screen_transform() * Rect2(Vector2(min(s.x, e.x), min(s.y, e.y)), (e - s).abs())
		overlays.add_highlight_to_control(interface.spatial_editor, rect_getter, play_flash),
	)


func mouse_move_by_position(from: Vector2, to: Vector2) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_move_operation(func() -> Vector2: return from, func() -> Vector2: return to)
	)


func mouse_move_by_callable(from: Callable, to: Callable) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		await mouse.get_tree().process_frame
		mouse.add_move_operation(from, to),
	)


func mouse_press() -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_press_operation()
	)


func mouse_release() -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_release_operation()
	)


func mouse_click() -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_click_operation()
	)


func mouse_double_click() -> void:
	pass


func ensure_mouse() -> void:
	if mouse == null:
		# We don't preload to avoid errors on a project's first import, to distribute the tour to
		# schools for example.
		var MousePackedScene := load("res://addons/godot_tours/core/mouse/mouse.tscn")
		mouse = MousePackedScene.instantiate()
		interface.base_control.get_viewport().add_child(mouse)


func clear_mouse() -> void:
	if mouse != null:
		mouse.queue_free()
		mouse = null


func play_mouse() -> void:
	ensure_mouse()
	mouse.play()


func get_scene_node_by_path(path: String) -> Node:
	var result: Node = null
	var root := EditorInterface.get_edited_scene_root()
	if root.name == path:
		result = root
	else:
		for child in root.find_children("*"):
			if child.owner == root and root.name.path_join(root.get_path_to(child)) == path:
				result = child
				break
	return result


func get_scene_nodes_by_path(paths: Array[String]) -> Array[Node]:
	var result: Array[Node] = []
	for path in paths:
		var node := get_scene_node_by_path(path)
		if node != null:
			result.push_back(node)
	return result


func get_scene_nodes_by_prefix(prefix: String) -> Array[Node]:
	var result: Array[Node] = []
	var root := EditorInterface.get_edited_scene_root()
	result.assign(root.find_children("%s*" % prefix).filter(func(n: Node) -> bool: return n.owner == root))
	return result


func get_tree_item_center_by_path(tree: Tree, path: String, button_index := -1) -> Vector2:
	var result := Vector2.ZERO
	var root := tree.get_root()
	if root == null:
		return result
	for item in Utils.filter_tree_items(root, func(ti: TreeItem) -> bool: return path == Utils.get_tree_item_path(ti)):
		var rect := tree.get_global_transform() * tree.get_item_area_rect(item, 0, button_index)
		rect.position.y -= tree.get_scroll().y
		result = rect.get_center()
		break
	return result


func get_tree_item_center_by_name(tree: Tree, name: String) -> Vector2:
	var result := Vector2.ZERO
	var root := tree.get_root()
	if root == null:
		return result

	var item := Utils.find_tree_item_by_name(tree, name)
	var rect := tree.get_global_transform() * tree.get_item_area_rect(item, 0)
	rect.position.y -= tree.get_scroll().y
	result = rect.get_center()
	return result


func node_find_path(node_name: String) -> String:
	var root_node := EditorInterface.get_edited_scene_root()
	var found_node := root_node.find_child(node_name)
	if found_node == null:
		return ""
	var path_from_root: String = root_node.name.path_join(root_node.get_path_to(found_node))
	return path_from_root


func find_tabs_title(tabs: TabBar, title: String) -> int:
	var result := -1
	for index in range(tabs.tab_count):
		var tab_title: String = tabs.get_tab_title(index)
		if title == tab_title or tabs == interface.main_screen_tabs and "%s(*)" % title == tab_title:
			result = index
			break
	return result


## Toggles the visibility of all the tour-specific nodes: overlays, bubble, and mouse.
func toggle_visible(is_visible: bool) -> void:
	for node in [bubble, mouse]:
		if node != null:
			node.visible = is_visible
	overlays.toggle_dimmers(is_visible)


func noop_error_predicate(_task: Task) -> bool:
	return false


func gtr(src_message: StringName, context: StringName = "") -> String:
	return translation_service.get_tour_message(src_message, context)


func gtr_n(src_message: StringName, src_plural_message: StringName, n: int, context: StringName = "") -> String:
	return translation_service.get_tour_plural_message(src_message, src_plural_message, n, context)


func ptr(resource_path: String) -> String:
	return translation_service.get_resource_path(resource_path)


func warn(msg: String, func_name: String) -> void:
	print_rich(WARNING_MESSAGE % [msg, func_name, _steps.size()])


func get_step_count() -> int:
	return _steps.size()


func _clear_game_world_overlays():
	for node in game_world_overlays:
		node.queue_free()


## Generates a BBCode [img] tag for a Godot editor icon, scaling the image size based on the editor
## scale.
func bbcode_generate_icon_image_string(image_filepath: String) -> String:
	const base_size_pixels := 24
	var size := base_size_pixels * EditorInterface.get_editor_scale()
	return "[img=%sx%s]" % [size, size] + image_filepath + "[/img]"


## Wraps the text in a [font_size] BBCode tag, scaling the value of size_pixels based on the editor
## scale.
func bbcode_wrap_font_size(text: String, size_pixels: int) -> String:
	var size_scaled := size_pixels * EditorInterface.get_editor_scale()
	return "[font_size=%s]" % size_scaled + text + "[/font_size]"
