## Displays and controls overlays.
## Can dim areas of the editor and block mouse clicks, or allow mouse clicks within a restricted area.
## Dimmers and overlays start hidden by default. See toggle_dimmers() and toggle_overlays() to make
## them visible.
extends Node

const Highlight := preload("highlight/highlight.gd")
const Dimmer := preload("dimmer/dimmer.gd")
const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const Utils := preload("../utils.gd")

const HighlightPackedScene := preload("highlight/highlight.tscn")
const DimmerPackedScene := preload("dimmer/dimmer.tscn")
const OverlayPackedScene := preload("overlay.tscn")

const OVERLAY := "overlay"
const HIGHLIGHT := "highlight"
const RECT_GROW := 5

var dimmer_map := {}
## Map of Control, {overlay: ColorRect, tabs: Control}.
var overlay_map := {}
var highlight_parents := []
var popups := {}
var interface: EditorInterfaceAccess = null

## Map of Overlay, Array[Highlight].
## Keeps track of all highlights placed over an overlay ColorRect to toggle mouse filter
## on and off as the user hovers highlights.
var _highlights_map: Dictionary = {}

# We duplicate and scale the highlight stylebox so the outline scales with the editor scale.
# Duplicating here allows us to pass the style to each created highlight.
var _highlight_style_scaled: StyleBoxFlat = null


func _init(interface: EditorInterfaceAccess, editor_scale := 1.0) -> void:
	self.interface = interface

	for control: Control in [interface.base_control, interface.signals_dialog, interface.node_create_panel]:
		var dimmer := DimmerPackedScene.instantiate()
		var viewport: Viewport = control.get_viewport()
		viewport.add_child(dimmer)
		dimmer.visible = false
		dimmer_map[viewport] = dimmer
	interface.distraction_free_button.pressed.connect(refresh_all)
	for map: Dictionary in interface.controls_maps:
		for control: Control in map.controls:
			if control is Control:
				var tabs := map.get("tabs", null)
				add_overlay_to_control(control, tabs)

	for control: Control in interface.extra_draw:
		control.draw.connect(refresh_all)

	# Scale highlight stylebox based on editor scale.
	# TODO: use theme utils instead.
	_highlight_style_scaled = load("res://addons/godot_tours/core/overlays/highlight/highlight.tres").duplicate(true)

	_highlight_style_scaled.border_width_bottom *= editor_scale
	_highlight_style_scaled.border_width_left *= editor_scale
	_highlight_style_scaled.border_width_right *= editor_scale
	_highlight_style_scaled.border_width_top *= editor_scale

	_highlight_style_scaled.corner_radius_bottom_left *= editor_scale
	_highlight_style_scaled.corner_radius_bottom_right *= editor_scale
	_highlight_style_scaled.corner_radius_top_left *= editor_scale
	_highlight_style_scaled.corner_radius_top_right *= editor_scale

	_highlight_style_scaled.expand_margin_left *= editor_scale
	_highlight_style_scaled.expand_margin_right *= editor_scale
	_highlight_style_scaled.expand_margin_top *= editor_scale
	_highlight_style_scaled.expand_margin_bottom *= editor_scale


func _process(_delta: float) -> void:
	for current_overlay: ColorRect in _highlights_map:
		current_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var highlights: Array = _highlights_map[current_overlay]
		for current_highlight: Highlight in highlights:
			if current_highlight.get_global_rect().has_point(current_overlay.get_global_mouse_position()):
				current_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				break


func _on_overlay_visibility_changed(control: Control, overlay: ColorRect) -> void:
	refresh(control, overlay)


func add_overlay_to_control(control: Control, tabs: Control = null) -> void:
	var overlay := OverlayPackedScene.instantiate()
	control.add_child(overlay)
	overlay_map[control] = {overlay = overlay, tabs = tabs}
	if tabs is TabContainer or tabs is TabBar:
		tabs.drag_to_rearrange_enabled = false
		if tabs is TabContainer:
			var popup: Popup = tabs.get_popup()
			if popup != null:
				popups[tabs] = popup
				tabs.set_popup(null)

	overlay.visible = false
	overlay.visibility_changed.connect(_on_overlay_visibility_changed.bind(control, overlay))
	control.draw.connect(refresh_all)
	_on_overlay_visibility_changed(control, overlay)
	refresh_all()


func add_highlight_to_overlay(overlay: ColorRect, rect_getter: Callable, play_flash := false) -> void:
	if overlay == null:
		return

	# Calculate overlapping highlights to avoid stacking highlights and outlines.
	var overlaps := []
	var rect := rect_getter.call()
	for child in overlay.get_children():
		if child.is_in_group(HIGHLIGHT):
			var child_rect := Rect2(child.global_position, child.custom_minimum_size)
			if rect.grow(RECT_GROW).intersects(child_rect):
				overlaps.push_back(child)

	var highlight := HighlightPackedScene.instantiate()
	if not overlay in _highlights_map:
		_highlights_map[overlay] = []
	_highlights_map[overlay].push_back(highlight)
	highlight.tree_exiting.connect(func erase_highlight():
		_highlights_map[overlay].erase(highlight))

	overlay.add_child(highlight)
	if play_flash:
		highlight.flash()

	highlight.setup(rect_getter, get_dimmer_for(overlay), _highlight_style_scaled)
	if overlaps.is_empty():
		var overlay_parent := overlay.get_parent()
		if overlay_parent is TabBar:
			overlay_parent.tab_changed.connect(highlight.refresh_tabs.bind(overlay_parent))
			if not overlay_parent in highlight_parents:
				highlight_parents.push_back(overlay_parent)
	else:
		for other_highlight: Highlight in overlaps:
			highlight.rect_getters.append_array(other_highlight.rect_getters)
			other_highlight.free()
	highlight.refresh()


## Highlights a control, allowing the end user to interact with it using the mouse, and carving into the dimmers.
func add_highlight_to_control(control: Control, play_flash := false) -> void:
	var overlay := find_overlay_for(control)
	if control.is_in_group(HIGHLIGHT):
		overlay = control

	var rect_getter := func() -> Rect2: return control.get_global_rect()

	# A tour may highlight a node that doesn't have an overlay by default, because it's not part of the Godot editor,
	# such as an addon's panel, for example. In that case, we create an overlay for this node on the fly.
	if overlay == null:
		var highlight := HighlightPackedScene.instantiate()
		control.add_child(highlight)
		if play_flash:
			highlight.flash()

		if not control.draw.is_connected(refresh_all):
			control.draw.connect(refresh_all)
		highlight.setup(rect_getter, get_dimmer_for(control), _highlight_style_scaled)
		# Otherwise refresh gets into an infinite loop
		highlight.top_level = true
		highlight.refresh()
		if not control in highlight_parents:
			highlight_parents.push_back(control)
	else:
		add_highlight_to_overlay(overlay, rect_getter, play_flash)


func clean_up() -> void:
	interface.distraction_free_button.pressed.disconnect(refresh_all)
	var code_editors := interface.script_editor.get_open_script_editors().map(func(s: ScriptEditorBase) -> Control: return s.get_base_editor())
	for control: Control in highlight_parents + interface.extra_draw + code_editors:
		if control.draw.is_connected(refresh_all):
			control.draw.disconnect(refresh_all)

		_highlights_map.clear()
		for node: Node in control.get_children():
			if node.is_in_group(HIGHLIGHT):
				node.queue_free()

	for tabs in popups:
		tabs.drag_to_rearrange_enabled = true
		tabs.set_popup(popups[tabs])

	for control in overlay_map:
		for connection in control.draw.get_connections():
			control.draw.disconnect(connection.callable)
		overlay_map[control].overlay.queue_free()

	for dimmer in dimmer_map.values():
		dimmer.clean_up()
		dimmer.queue_free()


func clear_highlights(control: Control) -> void:
	if control == null:
		return
	elif control is TabContainer:
		control = Utils.find_child(control, "TabBar")

	for node in [control, get_overlay_for(control)]:
		if node == null:
			continue

		if node.is_in_group(OVERLAY) or node in highlight_parents:
			for connection in node.draw.get_connections():
				node.draw.disconnect(connection.callable)

		for child: Node in node.get_children():
			if child.is_in_group(HIGHLIGHT):
				if control is TabBar and control.tab_changed.is_connected(child.refresh_tabs):
					control.tab_changed.disconnect(child.refresh_tabs)
				_highlights_map.erase(child)
				child.free()
		highlight_parents.erase(node)


func clear() -> void:
	for control: Control in highlight_parents + overlay_map.keys():
		clear_highlights(control)


func refresh(control: Control, overlay: ColorRect = null) -> void:
	var rect := control.get_global_rect()
	var children := control.get_children()
	if overlay != null:
		overlay.global_position = rect.position
		overlay.size = rect.size
		children += overlay.get_children()

	for child: Node in children:
		if child.is_in_group(HIGHLIGHT):
			child.refresh()


func refresh_all() -> void:
	for control: Control in overlay_map:
		refresh.call_deferred(control, overlay_map[control].overlay)

	for control: Control in highlight_parents:
		refresh.call_deferred(control)


func toggle_overlays(is_on: bool) -> void:
	for control in overlay_map:
		get_overlay_for(control).visible = is_on

	for dimmer in dimmer_map.values():
		dimmer.toggle_dimmer_mask(is_on)


func toggle_dimmers(is_on: bool) -> void:
	for dimmer in dimmer_map.values():
		dimmer.visible = is_on


func get_overlay_for(control: Node) -> ColorRect:
	return overlay_map.get(control, {}).get("overlay", null)


func get_dimmer_for(control: Node) -> Dimmer:
	return dimmer_map.get(control.get_viewport(), null) if control != null else null


func find_overlay_for(control: Node) -> ColorRect:
	var result: Node = get_overlay_for(control)
	if control == null:
		return result

	var viewport := control.get_viewport()
	while result == null and control != viewport:
		control = control.get_parent()
		result = get_overlay_for(control)
	return result


func find_highlights_for(control: Control) -> Array[Highlight]:
	var result: Array[Highlight] = []
	var overlay: ColorRect = null
	if control == null:
		return result
	elif control.is_in_group(OVERLAY):
		control = overlay
	else:
		overlay = find_overlay_for(control)
	var children := control.get_children()
	if overlay != null:
		children += overlay.get_children()
	result.assign(children.filter(func(c: Node) -> bool: return c.is_in_group(HIGHLIGHT)))
	return result


func highlight_tree_items(tree: Tree, overlay: ColorRect, predicate: Callable, play_flash := false, button_index := -1) -> void:
	var root := tree.get_root()
	if root == null:
		return
	for item in Utils.filter_tree_items(root, predicate):
		interface.unfold_tree_item(item)
		tree.scroll_to_item(item)

		var item_path := Utils.get_tree_item_path(item)
		var rect_getter := func() -> Rect2:
			const height_fix := 6
			for the_item in Utils.filter_tree_items(
				tree.get_root(),
				func(ti: TreeItem) -> bool: return item_path == Utils.get_tree_item_path(ti),
			):
				var rect := tree.get_global_transform() * tree.get_item_area_rect(the_item, 0, button_index)
				rect.position.y += height_fix - tree.get_scroll().y
				return rect.intersection(tree.get_global_rect())
			return Rect2()
		add_highlight_to_overlay.call_deferred(overlay, rect_getter, play_flash)


func highlight_scene_node(path: String, play_flash := false, button_index := -1) -> void:
	highlight_tree_items(
		interface.scene_tree,
		get_overlay_for(interface.scene_dock),
		func(item: TreeItem) -> bool: return path == Utils.get_tree_item_path(item),
		play_flash,
		button_index,
	)


func highlight_scene_nodes(paths: Array[String], play_flash := false, button_index := -1) -> void:
	for path in paths:
		highlight_scene_node(path, play_flash, button_index)


func clear_scene_node_highlights() -> void:
	clear_highlights(get_overlay_for(interface.scene_dock))


func highlight_filesystem_paths(paths: Array[String], play_flash := false) -> void:
	for path in paths:
		if path.is_empty():
			return
		highlight_tree_items(
			interface.filesystem_tree,
			get_overlay_for(interface.filesystem_dock),
			func(item: TreeItem) -> bool: return path == Utils.get_tree_item_path(item),
			play_flash,
		)


func clear_filesystem_highlights() -> void:
	clear_highlights(get_overlay_for(interface.filesystem_dock))


func highlight_inspector_properties(names: Array[StringName], play_flash := false) -> void:
	for name in names:
		var property: EditorProperty = Utils.find_child(
			interface.inspector_editor,
			"EditorProperty",
			"",
			func(ep: EditorProperty) -> bool: return ep.get_edited_property() == name,
		)
		if property != null:
			# Unfold parent sections recursively if necessary.
			var current_parent: Node = property.get_parent()
			var last_section = null
			const MAX_ITERATION_COUNT := 10
			for i in MAX_ITERATION_COUNT:
				if current_parent.get_class() == "EditorInspectorSection":
					current_parent.unfold()
				current_parent = current_parent.get_parent()
				if current_parent == interface.inspector_editor:
					break
	
			if last_section:
				await last_section.draw
	
			interface.inspector_editor.ensure_control_visible(property)
			var overlay := get_overlay_for(interface.inspector_dock)
			var rect_getter := func() -> Rect2:
				var rect := property.get_global_rect()
				rect.position.x = overlay.global_position.x
				rect.size.x = overlay.size.x
				return rect
			add_highlight_to_overlay.call_deferred(overlay, rect_getter, play_flash)


func clear_inspector_highlights() -> void:
	clear_highlights(get_overlay_for(interface.inspector_dock))


func highlight_signals(signal_names: Array[String], play_flash := false) -> void:
	for signal_name in signal_names:
		if signal_name.is_empty():
			continue

		highlight_tree_items(
			interface.node_dock_signals_tree,
			get_overlay_for(interface.node_dock_signals_editor),
			func(item: TreeItem) -> bool: return item.get_text(0).begins_with(signal_name),
			play_flash,
		)


func clear_signal_highlights() -> void:
	clear_highlights(get_overlay_for(interface.signals_dock))


# TODO: add flash if play_flash is true.
func highlight_code(start: int, end := 0, caret := 0, play_flash := false, do_center := true) -> void:
	start -= 1
	end = start if end < 1 else (end - 1)
	if caret == 0:
		caret = end
	var script_editor := interface.script_editor
	var code_editor: CodeEdit = script_editor.get_current_editor().get_base_editor()
	if start < 0 or end > code_editor.get_line_count() or start > end:
		return

	if not code_editor.draw.is_connected(refresh_all):
		code_editor.draw.connect(refresh_all)
	script_editor.goto_line(start)
	code_editor.grab_focus()
	if do_center:
		code_editor.set_line_as_center_visible((start + end) / 2)
	code_editor.scroll_horizontal = 0
	code_editor.set_caret_line.call_deferred(caret)
	code_editor.set_caret_column.call_deferred(code_editor.get_line(caret).length())
	var overlay := get_overlay_for(interface.script_editor_code_panel)
	var rect_getter := func() -> Rect2:
		var rect_start := code_editor.get_rect_at_line_column(start, 0)
		var rect_end := code_editor.get_rect_at_line_column(end, 0)
		var rect := Rect2()
		if rect_start.position != -Vector2i.ONE and rect_end.position != -Vector2i.ONE:
			rect = code_editor.get_global_transform() * Rect2(rect_start.merge(rect_end))
			rect.position.x = code_editor.global_position.x
			rect.size.x = code_editor.size.x
		return rect
	add_highlight_to_overlay.call_deferred(overlay, rect_getter)


func clear_code_highlights() -> void:
	clear_highlights(get_overlay_for(interface.script_editor_code_panel))


func highlight_controls(controls: Array[Control], play_flash := false) -> void:
	for control in controls:
		if control == null:
			continue
		add_highlight_to_control(control, play_flash)


func highlight_tab_index(tabs: Control, index := -1) -> void:
	var tab_bar: TabBar = Utils.find_child(tabs, "TabBar") if tabs is TabContainer else tabs
	var overlay := get_overlay_for(tab_bar)
	if overlay == null or tab_bar == null or index < -1 or index >= tab_bar.tab_count:
		return

	var rect_getter := func() -> Rect2:
		return tab_bar.get_global_rect() if index == -1 else tab_bar.get_global_transform() * tab_bar.get_tab_rect(index)
	add_highlight_to_overlay(overlay, rect_getter)


func highlight_tab_title(tabs: Control, title: String) -> void:
	if not (tabs is TabContainer or tabs is TabBar):
		return

	for index in range(tabs.get_tab_count()):
		var tab_title: String = tabs.get_tab_title(index)
		if title == tab_title or tabs == interface.main_screen_tabs and "%s(*)" % title == tab_title:
			highlight_tab_index(tabs, index)


## Highlights a ListItem in the TileMap dock, such as a tile or a terrain's drawing mode or terrain
## tile.
func highlight_tilemap_list_item(item_list: ItemList, item_index: int) -> void:
	if item_list == null or item_index < 0 or item_index >= item_list.item_count:
		return

	var overlay := get_overlay_for(interface.tilemap)
	var rect_getter := func() -> Rect2:
			var rect := item_list.get_item_rect(item_index)
			rect.position += item_list.global_position
			return rect
	add_highlight_to_overlay(overlay, rect_getter)
