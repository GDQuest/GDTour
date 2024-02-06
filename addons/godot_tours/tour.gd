## Main class used to design a tour. Provides an API to design tour steps.
##
##
## The tour is a series of steps, each step being a series of commands to execute.
## Commands are executed in the order they are added.
## [br][br]
## This class provides many common commands to use in your tour, like selecting a node in the scene
## tree, highlighting a control, or playing a mouse animation.
## [br][br]
## Each command is a ["addons/godot_tours/tour.gd".Command] object, which is a wrapper around a callable and
## its parameters. You can run any function in the editor by wrapping it in a [code]Command[/code] object.
## Use the utility function [method queue_command] to create a [code]Command[/code] and add it to
## [member step_commands] faster.
## [br][br]
## To design a tour, override the [method _build] function and write all your tour steps in it:
## [br][br]
## 1. Call API functions to queue commands required for your step. [br]
## 2. Call [method complete_step] to complete and save the current [code]step_commands[/code] as a new.
## [br][br]
## See the provided demo tour for an example.
extends Node

## Emitted when the tour moves to the next or previous [member step_commands].
signal step_changed(step_index: int)
## Emitted when the user completes the last [member step_commands].
signal ended
## Emitted when the user closes the tour.
signal closed

## Represents one command to execute in a step_commands. All commands are executed in the order they are added.
## Use the [member queue_command] function to create a [code]Command[/code] object and add it to
## [member step_commands] faster.
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
const FlashArea := preload("overlays/flash_area/flash_area.gd")

const FlashAreaPackedScene := preload("overlays/flash_area/flash_area.tscn")

const WARNING_MESSAGE := "[color=orange][WARN][/color] %s for [b]'%s()'[/b] at [b]'step_commands(=%d)'[/b]."

enum Direction {BACK = -1, NEXT = 1}

const EVENTS := {
	f = preload("events/f_input_event_key.tres"),
}
## Index of the step_commands currently running.
var index := -1: set = set_index
var steps: Array[Array] = []
var step_commands: Array[Command] = []

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
	translation_service.update_tour_key(get_script().resource_path)

	# Applies the default layout so every tour starts from the same UI state.
	interface.restore_default_layout()
	_build()
	load_bubble()
	if index == -1:
		set_index(0)


## Virtual function to override to build the tour. Write all your tour steps in it.
## This function is called when the tour is created, after connecting signals and re-applying the
## editor's default layout, which helps avoid many UI edge cases.
func _build() -> void:
	pass


func clean_up() -> void:
	clear_mouse()
	log.clean_up()
	if is_instance_valid(bubble):
		bubble.queue_free()


func set_index(value: int) -> void:
	var step_count := steps.size()
	var stride := Direction.BACK if value < index else Direction.NEXT
	value = clampi(value, -1, step_count)
	for index in range(index + stride, clampi(value + stride, -1, step_count), stride):
		log.info("[step_commands: %d]\n%s" % [index, interface.logger_rich_text_label.get_parsed_text()])
		run(steps[index])
	index = clampi(value, 0, step_count - 1)
	step_changed.emit(index)


func load_bubble(BubblePackedScene: PackedScene = null) -> void:
	if bubble != null:
		bubble.queue_free()

	if BubblePackedScene == null:
		BubblePackedScene = load("res://addons/godot_tours/bubble/default_bubble.tscn")

	bubble = BubblePackedScene.instantiate()
	interface.base_control.add_child(bubble)
	bubble.setup(translation_service, steps.size())
	bubble.back_button_pressed.connect(back)
	bubble.next_button_pressed.connect(next)
	bubble.close_requested.connect(func() -> void:
		toggle_visible(false)
		closed.emit()
		clean_up()
	)
	bubble.finish_requested.connect(func() -> void:
		toggle_visible(false)
		clean_up()
		await get_tree().process_frame
		ended.emit()
	)
	step_changed.connect(bubble.on_tour_step_changed)


## Goes back to the previous step.
func back() -> void:
	EditorInterface.stop_playing_scene()
	set_index(index + Direction.BACK)


## Goes to the next step, or shows a button to end the tour if the last step is reached.
func next() -> void:
	EditorInterface.stop_playing_scene()
	set_index(index + Direction.NEXT)


## Waits for the next frame and goes back to the previous step. Used for automated testing.
func auto_back() -> void:
	queue_command(func() -> void:
		await delay_process_frame()
		back()
	)


## Waits for the next frame and advances to the next step. Used for automated testing.
func auto_next() -> void:
	queue_command(func wait_for_frame_and_advance() -> void:
		await delay_process_frame()
		next()
	)

## Completes the current step's commands, adding some more commands to clear the bubble, overlays, and the mouse.
## Then, this function appends the completed step (an array of
## ["addons/godot_tours/tour.gd".Command] objects) to the tour.
func complete_step() -> void:
	var step_start: Array[Command] = [
		Command.new(func() -> void: bubble.clear()),
		Command.new(overlays.clean_up),
		Command.new(overlays.ensure_get_dimmer_for.bind(interface.base_control)),
		Command.new(clear_mouse),
	]
	step_commands.push_back(Command.new(play_mouse))
	steps.push_back(step_start + step_commands)
	step_commands = []


func run(current_step: Array[Command]) -> void:
	for l in current_step:
		await l.force()


## Appends a command to the currently edited step. Commands are executed in the order they are added.
## To complete a step and start creating the next one, call [method complete_step].
func queue_command(callable: Callable, parameters := []) -> void:
	step_commands.push_back(Command.new(callable, parameters))


func swap_bubble(BubblePackedScene: PackedScene = null) -> void:
	queue_command(load_bubble, [BubblePackedScene])


func scene_open(path: String) -> void:
	if not FileAccess.file_exists(path) and path.get_extension() != "tscn":
		warn("[b]'path(=%s)'[/b] doesn't exist or has wrong extension" % path, "scene_open")
		return
	queue_command(func() -> void:
		if path in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(path)
		else:
			EditorInterface.open_scene_from_path(path)
	)


func scene_select_nodes_by_path(paths: Array[String] = []) -> void:
	scene_deselect_all_nodes()
	queue_command(func() -> void:
		var nodes := Utils.find_children_by_path(EditorInterface.get_edited_scene_root(), paths)
		for node in nodes:
			editor_selection.add_node(node)
	)


func scene_toggle_lock_nodes_by_path(paths: Array[String] = [], is_locked := true) -> void:
	queue_command(func get_and_lock_nodes() -> void:
		var nodes := Utils.find_children_by_path(EditorInterface.get_edited_scene_root(), paths)
		var prop := &"_edit_lock_"
		for node in nodes:
			node.set_meta(prop, is_locked) if is_locked else node.remove_meta(prop)
	)


func scene_deselect_all_nodes() -> void:
	queue_command(editor_selection.clear)


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


func tabs_set_by_control(control: Control) -> void:
	const FUNC_NAME := "tabs_set_to_control"
	if control == null or (control != null and not control.get_parent() is TabContainer):
		warn("[b]'control(=%s)'[/b] is 'null' or parent is not TabContainer." % [control], FUNC_NAME)
		return

	var tab_container: TabContainer = control.get_parent()
	var tab_idx := find_tabs_control(tab_container, control)
	if tab_idx == -1:
		warn("[b]'control(=%s)'[/b] is not a child of [b]'[%s]'[/b]." % [control, tab_container], FUNC_NAME)
	else:
		tabs_set_to_index(tab_container.get_tab_bar(), tab_idx)


func tileset_tabs_set_by_control(control: Control) -> void:
	var index := interface.tileset_panels.find(control)
	if index == -1:
		warn("[b]'control(=%s)'[/] must be found in '[b]interface.tilset_controls[/b]'" % [control], "tileset_set_to_control")
	else:
		tabs_set_to_index(interface.tileset_tabs, index)


func tilemap_tabs_set_by_control(control: Control) -> void:
	var index := interface.tilemap_panels.find(control)
	if index == -1:
		warn("[b]'control(=%s)'[/] must be found in '[b]interface.tilmap_controls[/b]'" % [control], "tilemap_set_to_control")
	else:
		tabs_set_to_index(interface.tilemap_tabs, index)


func tree_activate_by_prefix(tree: Tree, prefix: String) -> void:
	queue_command(func() -> void:
		if tree == interface.node_dock_signals_tree and interface.signals_dialog_window.visible:
			return
		await delay_process_frame()
		tree.deselect_all()
		var items := Utils.filter_tree_items(
			tree.get_root(),
			func(item: TreeItem) -> bool: return item.get_text(0).begins_with(prefix)
		)
		for item in items:
			item.select(0)
		tree.item_activated.emit()
	)


func canvas_item_editor_center_at(position := Vector2.ZERO, zoom := 1.0) -> void:
	queue_command(func() -> void:
		await delay_process_frame()
		interface.canvas_item_editor.center_at(position)
		interface.canvas_item_editor_zoom_widget.set_zoom(zoom)
	)


## Resets the zoom of the 2D viewport to 100%.
func canvas_item_editor_zoom_reset() -> void:
	queue_command(interface.canvas_item_editor_zoom_widget.set_zoom.bind(1.0))


## Plays a flash animation in the 2D game viewport, over the desired rect.
func canvas_item_editor_flash_area(rect: Rect2) -> void:
	queue_command(func flash_canvas_item_editor() -> void:
		var flash_area := FlashAreaPackedScene.instantiate()
		overlays.ensure_get_dimmer_for(interface.canvas_item_editor).add_child(flash_area)
		interface.canvas_item_editor_viewport.draw.connect(
			flash_area.refresh.bind(interface.canvas_item_editor_viewport, rect)
		)
		flash_area.refresh(interface.canvas_item_editor_viewport, rect)
	)


# TODO: test?
func spatial_editor_focus() -> void:
	queue_command(func() -> void: interface.spatial_editor_surface.gui_input.emit(EVENTS.f))


# TODO: test?
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
	queue_command(func bubble_set_title() -> void: bubble.set_title(title_text))


func bubble_add_text(text: Array[String]) -> void:
	queue_command(func bubble_add_text() -> void: bubble.add_text(text))


func bubble_add_texture(texture: Texture2D) -> void:
	queue_command(func bubble_add_texture() -> void: bubble.add_texture(texture))


func bubble_add_code(lines: Array[String]) -> void:
	queue_command(func bubble_add_code() -> void: bubble.add_code(lines))


func bubble_add_video(stream: VideoStream) -> void:
	queue_command(func bubble_add_video() -> void: bubble.add_video(stream))


func bubble_set_header(text: String) -> void:
	queue_command(func bubble_set_header() -> void: bubble.set_header(text))


func bubble_set_footer(text: String) -> void:
	queue_command(func bubble_set_footer() -> void: bubble.set_footer(text))


func bubble_set_background(texture: Texture2D) -> void:
	queue_command(func bubble_set_background() -> void: bubble.set_background(texture))


# TODO: test?
func bubble_add_task(description: String, repeat: int, repeat_callable: Callable, error_predicate := noop_error_predicate) -> void:
	queue_command(func() -> void: bubble.add_task(description, repeat, repeat_callable, error_predicate))


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

	const TOGGLE_MAP := {true: "ON", false: "OFF"}
	description = gtr("Turn the [b]%s[/b] button %s.") % [text, TOGGLE_MAP[is_toggled]]
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
	var title := tabs.get_tab_title(index)
	description = gtr("Change to the [b]%s[/b] tab.") % [title] if description.is_empty() else description
	bubble_add_task(description, 1, func(_task: Task) -> int: return 1 if index == tabs.current_tab else 0, noop_error_predicate)


func bubble_add_task_set_tab_to_title(tabs: TabBar, title: String, description := "") -> void:
	var index := find_tabs_title(tabs, title)
	if index == -1:
		var titles := range(tabs.tab_count).map(func(index: int) -> String: return tabs.get_tab_title(index))
		warn("[b]'title(=%s)'[/b] not found in tabs [b]'[%s]'[/b]" % [title, ", ".join(titles)], "bubble_add_task_set_tab_to_title")
	else:
		bubble_add_task_set_tab_to_index(tabs, index, description)


func bubble_add_task_set_tab_by_control(control: Control, description := "") -> void:
	if control == null or (control != null and not control.get_parent() is TabContainer):
		warn("[b]'control(=%s)'[/b] is 'null' or parent is not TabContainer." % [control], "bubble_add_task_set_tab_to_title")
		return

	var tab_container: TabContainer = control.get_parent()
	var index := find_tabs_control(tab_container, control)
	var tabs := tab_container.get_tab_bar()
	bubble_add_task_set_tab_to_index(tabs, index, description)


func bubble_add_task_set_tileset_tab_by_control(control: Control, description := "") -> void:
	var index := interface.tileset_panels.find(control)
	if index == -1:
		warn("[b]'control(=%s)'[/b] must be found in '[b]interface.tilset_controls[/b]'" % [control], "bubble_add_task_set_tileset_tab_by_control")
	else:
		bubble_add_task_set_tab_to_index(interface.tileset_tabs, index, description)


func bubble_add_task_set_tilemap_tab_by_control(control: Control, description := "") -> void:
	var index := interface.tilemap_panels.find(control)
	if index == -1:
		warn("[b]'control(=%s)'[/] must be found in '[b]interface.tilmap_controls[/b]'" % [control], "bubble_add_task_set_tilemap_tab_by_control")
	else:
		bubble_add_task_set_tab_to_index(interface.tilemap_tabs, index, description)


func bubble_add_task_select_node(node_name: String) -> void:
	bubble_add_task(
		"Select the [b]" + node_name + "[/b] node in the [b]Scene Dock[/b].",
		1,
		func task_select_node(_task: Task) -> int:
			var scene_root: Node = EditorInterface.get_edited_scene_root()
			var target_node: Node = scene_root if node_name == scene_root.name else scene_root.find_child(node_name)
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


## Moves and anchors the bubble relative to the given control.
## You can optionally set a margin and an offset to fine-tune the bubble's position.
func bubble_move_and_anchor(control: Control, at := Bubble.At.CENTER, margin := 16.0, offset := Vector2.ZERO) -> void:
	queue_command(func() -> void: bubble.move_and_anchor(control, at, margin, offset))


## Places the avatar on the given side at the top of the bubble.
func bubble_set_avatar_at(at: Bubble.AvatarAt) -> void:
	queue_command(func() -> void: bubble.set_avatar_at(at))


## Changes the minimum size of the bubble, scaled by the editor scale setting.
## This is useful to have the bubble take the same space on different screens.
##
## If you want to set the minimum size for one step_commands only, for example, when using only a title
## you can call this function with a [code]size[/code] of [constant Vector2.ZERO] on the following
## [member step_commands] to let the bubble automatically control its size again.
func bubble_set_minimum_size_scaled(size := Vector2.ZERO) -> void:
	queue_command(func() -> void: bubble.panel.set_custom_minimum_size(size * EditorInterface.get_editor_scale()))


func highlight_scene_nodes_by_name(names: Array[String], button_index := -1, play_flash := true) -> void:
	queue_command(overlays.highlight_scene_nodes_by_name, [names, button_index, play_flash])


func highlight_scene_nodes_by_path(paths: Array[String], button_index := -1, play_flash := true) -> void:
	queue_command(overlays.highlight_scene_nodes_by_path, [paths, button_index, play_flash])


func highlight_filesystem_paths(paths: Array[String], play_flash := true) -> void:
	queue_command(overlays.highlight_filesystem_paths, [paths, play_flash])


func highlight_inspector_properties(names: Array[StringName], play_flash := true) -> void:
	queue_command(overlays.highlight_inspector_properties, [names, play_flash])


func highlight_signals(paths: Array[String], play_flash := true) -> void:
	queue_command(overlays.highlight_signals, [paths, play_flash])


func highlight_code(start: int, end := 0, caret := 0, do_center := true, play_flash := false) -> void:
	queue_command(overlays.highlight_code, [start, end, caret, do_center, play_flash])


func highlight_controls(controls: Array[Control], play_flash := false) -> void:
	queue_command(overlays.highlight_controls, [controls, play_flash])


func highlight_tabs_index(tabs: Control, index := -1, play_flash := true) -> void:
	queue_command(overlays.highlight_tab_index, [tabs, index, play_flash])


func highlight_tabs_title(tabs: Control, title: String, play_flash := true) -> void:
	queue_command(overlays.highlight_tab_title, [tabs, title, play_flash])


func highlight_canvas_item_editor_rect(rect: Rect2, play_flash := false) -> void:
	queue_command(func() -> void:
		var rect_getter := func() -> Rect2:
			var scene_root := EditorInterface.get_edited_scene_root()
			if scene_root == null:
				return Rect2()
			return interface.canvas_item_editor_viewport.get_global_rect().intersection(
				scene_root.get_viewport().get_screen_transform() * rect
			)
		overlays.add_highlight_to_control(interface.canvas_item_editor_viewport, rect_getter, play_flash),
	)


func highlight_tilemap_list_item(item_list: ItemList, item_index: int, play_flash := true) -> void:
	queue_command(overlays.highlight_tilemap_list_item.bind(item_list, item_index, play_flash))


func highlight_spatial_editor_camera_region(start: Vector3, end: Vector3, index := 0, play_flash := false) -> void:
	if index < 0 or index > interface.spatial_editor_cameras.size():
		warn("[b]'index(=%d)'[/b] not in [b]'range(0, interface.spatial_editor_cameras.size()(=%d))'[/b]." % [index, interface.spatial_editor_cameras.size()], "highlight_spatial_editor_camera_region")
		return
	var camera := interface.spatial_editor_cameras[index]
	queue_command(func() -> void:
		if camera.is_position_behind(start) or camera.is_position_behind(end):
			return
		var rect_getter := func() -> Rect2:
			var s := camera.unproject_position(start)
			var e := camera.unproject_position(end)
			return interface.spatial_editor_surface.get_global_rect().intersection(
				camera.get_viewport().get_screen_transform() * Rect2(Vector2(min(s.x, e.x), min(s.y, e.y)), (e - s).abs())
			)
		overlays.add_highlight_to_control(interface.spatial_editor_surface, rect_getter, play_flash),
	)


func mouse_move_by_position(from: Vector2, to: Vector2) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_move_operation(func() -> Vector2: return from, func() -> Vector2: return to)
	)


func mouse_move_by_callable(from: Callable, to: Callable) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		await delay_process_frame()
		mouse.add_move_operation(from, to),
	)


func mouse_click_drag_by_position(from: Vector2, to: Vector2, press_texture: CompressedTexture2D = null) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_press_operation(press_texture)
		mouse.add_move_operation(func() -> Vector2: return from, func() -> Vector2: return to)
		mouse.add_release_operation()
	)


func mouse_click_drag_by_callable(from: Callable, to: Callable, press_texture: CompressedTexture2D = null) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_press_operation(press_texture)
		mouse.add_move_operation(from, to)
		mouse.add_release_operation()
	)


func mouse_bounce(loops := 2, at := Callable()) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		await delay_process_frame()
		mouse.add_bounce_operation(loops, at),
	)


func mouse_press(press_texture: CompressedTexture2D = null) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_press_operation(press_texture)
	)


func mouse_release() -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_release_operation()
	)


func mouse_click(loops := 1) -> void:
	queue_command(func() -> void:
		ensure_mouse()
		mouse.add_click_operation(loops)
	)


func ensure_mouse() -> void:
	if mouse == null:
		# We don't preload to avoid errors on a project's first import, to distribute the tour to
		# schools for example.
		var MousePackedScene := load("res://addons/godot_tours/mouse/mouse.tscn")
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


func get_tilemap_global_rect_pixels(tilemap_node: TileMap) -> Rect2:
	var rect := Rect2(tilemap_node.get_used_rect())
	rect.size *= Vector2(tilemap_node.tile_set.tile_size)
	rect.position = tilemap_node.global_position
	return rect


func get_control_global_center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


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


func find_tabs_control(tab_container: TabContainer, control: Control) -> int:
	var result := -1
	var predicate := func(idx: int) -> bool: return tab_container.get_tab_control(idx) == control
	for tab_idx in range(tab_container.get_tab_count()).filter(predicate):
		result = tab_idx
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
	print_rich(WARNING_MESSAGE % [msg, func_name, steps.size()])


## Generates a BBCode [code][img][/code] tag for a Godot editor icon, scaling the image size based on the editor.
## scale.
func bbcode_generate_icon_image_string(image_filepath: String) -> String:
	const BASE_SIZE_PIXELS := 24
	var size := BASE_SIZE_PIXELS * EditorInterface.get_editor_scale()
	return "[img=%sx%s]" % [size, size] + image_filepath + "[/img]"


## Wraps the text in a [code][font_size][/code] BBCode tag, scaling the value of size_pixels based on the editor
## scale.
func bbcode_wrap_font_size(text: String, size_pixels: int) -> String:
	var size_scaled := size_pixels * EditorInterface.get_editor_scale()
	return "[font_size=%s]" % size_scaled + text + "[/font_size]"


func delay_process_frame(frames := 1) -> void:
	for _frame in range(frames):
		await interface.base_control.get_tree().process_frame
