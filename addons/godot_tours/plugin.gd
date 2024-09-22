@tool
extends EditorPlugin

## Path to the file from which the plugin finds and registers tours.
## Contains an array of tour entries. See the file godot_tour_entry.gd for more information.
const TOUR_LIST_FILE_PATH := "res://godot_tours.tres"
const SINGLE_WINDOW_MODE_PROPERTY := "interface/editor/single_window_mode"

const GodotTourList := preload("godot_tour_list.gd")
const Utils := preload("utils.gd")
const EditorInterfaceAccess := preload("editor_interface_access.gd")
const Tour := preload("tour.gd")
const Overlays := preload("overlays/overlays.gd")
const Debugger := preload("debugger/debugger.gd")
const TranslationParser := preload("translation/translation_parser.gd")
const TranslationService := preload("translation/translation_service.gd")
const UIWelcomeMenu := preload("ui/ui_welcome_menu.gd")

const DebuggerPackedScene := preload("debugger/debugger.tscn")
const UIWelcomeMenuPackedScene = preload("ui/ui_welcome_menu.tscn")
const UIButtonGodotToursPackedScene = preload("ui/ui_button_godot_tours.tscn")

var plugin_path: String = get_script().resource_path.get_base_dir()
var translation_parser := TranslationParser.new()
var translation_service: TranslationService = null
var debugger: Debugger = null
var editor_interface_access: EditorInterfaceAccess = null
var overlays: Overlays = null
var welcome_menu: UIWelcomeMenu = null

## Resource of type godot_tour_list.gd. Contains an array of tour entries.
var tour_list := get_tours()
## Index of the currently running tour in the tour list.
var _current_tour_index := 0
## File paths to the tours.
var _tour_paths: Array[String] = []

## The currently running tour, if any.
var tour: Tour = null

## Button to open the tour selection menu, sitting in the editor top bar.
## This button only shows when there's no tour active and the welcome menu is hidden.
var _button_top_bar: Button = null


func _enter_tree() -> void:
	if tour_list == null:
		push_warning("Godot Tours: no tours found. The user interface will not be modified.")
		return

	# Hack for `EditorInterface.open_scene_from_path()`, see: https://github.com/godotengine/godot/issues/86869
	for _frame in range(10):
		await get_tree().process_frame

	_tour_paths.assign(
		tour_list.tours.map(func get_tour_path(tour_entry) -> String: return tour_entry.tour_path)
	)

	await get_tree().physics_frame
	get_viewport().mode = Window.MODE_MAXIMIZED

	var editor_settings := EditorInterface.get_editor_settings()

	add_translation_parser_plugin(translation_parser)
	translation_service = TranslationService.new(_tour_paths, editor_settings)
	editor_interface_access = EditorInterfaceAccess.new()

	overlays = Overlays.new(editor_interface_access)
	EditorInterface.get_base_control().add_child(overlays)

	# Add button to the editor top bar, right before the run buttons
	_add_top_bar_button()
	_show_welcome_menu()
	ensure_pot_generation(plugin_path)

	var is_single_window_mode := editor_settings.get_setting(SINGLE_WINDOW_MODE_PROPERTY)
	if not is_single_window_mode:
		editor_settings.set_setting(SINGLE_WINDOW_MODE_PROPERTY, true)
		EditorInterface.restart_editor(false)

	if Debugger.CLI_OPTION_DEBUG in OS.get_cmdline_user_args():
		toggle_debugger()


## Adds a button labeled Godot Tours to the editor top bar, right before the run buttons.
## This button only shows when there are tours in the project, there's no tour active, and the welcome menu is hidden.
func _add_top_bar_button() -> void:
	if tour_list == null:
		return

	_button_top_bar = UIButtonGodotToursPackedScene.instantiate()
	_button_top_bar.setup()
	editor_interface_access.run_bar.add_sibling(_button_top_bar)
	_button_top_bar.get_parent().move_child(
		_button_top_bar, editor_interface_access.run_bar.get_index()
	)
	_button_top_bar.pressed.connect(_show_welcome_menu)


## Shows the welcome menu, which lists all the tours in the file res://godot_tours.tres.
func _show_welcome_menu() -> void:
	if tour_list == null and not Debugger.CLI_OPTION_DEBUG in OS.get_cmdline_user_args():
		return

	_button_top_bar.hide()

	welcome_menu = UIWelcomeMenuPackedScene.instantiate()
	tree_exiting.connect(welcome_menu.queue_free)

	EditorInterface.get_base_control().add_child(welcome_menu)
	welcome_menu.setup(translation_service, tour_list)
	welcome_menu.tour_start_requested.connect(start_tour)
	welcome_menu.tour_reset_requested.connect(func reset_tour(tour_path: String) -> void:
		var was_reset_successful := _reset_tour_files(tour_path)
		if was_reset_successful:
			welcome_menu.show_reset_success()
		else:
			welcome_menu.show_reset_failure()
	)
	welcome_menu.closed.connect(_button_top_bar.show)


func _exit_tree() -> void:
	if _button_top_bar != null:
		_button_top_bar.queue_free()

	if tour_list == null:
		return

	if debugger != null:
		if debugger.is_inside_tree():
			remove_control_from_docks(debugger)
		debugger.queue_free()

	editor_interface_access.clean_up()
	overlays.clean_up()
	overlays.queue_free()
	if tour != null:
		tour.clean_up()

	remove_translation_parser_plugin(translation_parser)
	ensure_pot_generation(plugin_path, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F10 and event.ctrl_pressed and event.pressed:
		toggle_debugger()


## Registers and unregisters translation files for the tours.
func ensure_pot_generation(plugin_path: String, do_clean_up := false) -> void:
	if tour_list == null:
		return

	const key := "internationalization/locale/translations_pot_files"
	var tour_base_script_file_path := plugin_path.path_join("tour.gd")
	var pot_files_setting := ProjectSettings.get_setting(key, PackedStringArray())
	for file_path in [tour_base_script_file_path] + _tour_paths:
		var is_file_path_in: bool = file_path in pot_files_setting
		if is_file_path_in and do_clean_up:
			pot_files_setting.remove_at(pot_files_setting.find(file_path))
		elif not is_file_path_in and not do_clean_up:
			pot_files_setting.push_back(file_path)
	ProjectSettings.set_setting(key, null if pot_files_setting.is_empty() else pot_files_setting)
	ProjectSettings.save()


## Toggles the debugger dock. If it's not present, it's added to the upper-left dock slot.
func toggle_debugger() -> void:
	if debugger == null:
		debugger = DebuggerPackedScene.instantiate()
		debugger.setup(
			plugin_path, editor_interface_access, overlays, translation_service, tour, _tour_paths
		)

	if debugger.is_inside_tree():
		remove_control_from_docks(debugger)
		debugger.queue_free()
		debugger = null
		if welcome_menu == null and tour == null:
			_show_welcome_menu()
		else:
			_button_top_bar.show()
	else:
		add_control_to_dock(DOCK_SLOT_LEFT_UL, debugger)
		if welcome_menu != null:
			welcome_menu.queue_free()
		else:
			_button_top_bar.hide()


## Looks for a godot_tours.tres file at the root of the project. This file should contain an array of
## TourMetadata. Finds and loads the tours.
func get_tours() -> GodotTourList:
	if not FileAccess.file_exists(TOUR_LIST_FILE_PATH):
		push_warning(
			(
				"Godot Tours: no tours found. Create a GodotTourList resource file named '%s' to list and register tours."
				% TOUR_LIST_FILE_PATH
			)
		)
		return null
	return load(TOUR_LIST_FILE_PATH)


func start_tour(tour_index: int) -> void:
	if welcome_menu != null:
		welcome_menu.queue_free()
		welcome_menu = null

	if tour != null and is_instance_valid(tour):
		tour.queue_free()
		tour = null

	_current_tour_index = tour_index
	var tour_path: String = tour_list.tours[tour_index].tour_path
	tour = load(tour_path).new(editor_interface_access, overlays, translation_service)
	EditorInterface.get_base_control().add_child(tour)
	if _current_tour_index < tour_list.tours.size() - 1:
		tour.bubble.set_finish_button_text("Continue to the next tour")

	tour.closed.connect(_button_top_bar.show)
	tour.ended.connect(_on_tour_ended)


func _on_tour_ended() -> void:
	if _current_tour_index < tour_list.tours.size() - 1:
		start_tour(_current_tour_index + 1)
	else:
		_button_top_bar.show()


## Finds GDScript, tscn, and tres files in the tour source directory, next to the tour's .gd file, and copies them to the root directory.
## Returns true if the operation was successful, false otherwise.
## We assume that files in the tour source directory are the starting files required by the tour. All assets and other files you don't want to copy or overwrite should be in a separate subdirectory (example: "res://assets", "res://scenes"...).
func _reset_tour_files(tour_path: String) -> bool:
	var was_reset_successful := true
	const PREFIX := &"res://"

	var tour_dir_path := "%s/" % tour_path.get_base_dir()
	var tour_file_paths := Utils.fs_find("*", tour_dir_path).filter(
		func(path: String) -> bool: return not (path.get_extension() == "import" or path.get_extension() == "md" or path == tour_path)
	)

	var open_scene_paths := EditorInterface.get_open_scenes()
	var reload_scene_paths: Array[String] = []
	for tour_file_path: String in tour_file_paths:
		var destination_file_path := PREFIX.path_join(tour_file_path.replace(tour_dir_path, ""))

		var destination_dir_path := destination_file_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(destination_dir_path)

		var extension := tour_file_path.get_extension()
		if extension in ["gd", "tscn", "tres"]:
			var contents := FileAccess.get_file_as_string(tour_file_path)
			contents = contents.replace(tour_dir_path, destination_dir_path)
			var file_access := FileAccess.open(destination_file_path, FileAccess.WRITE)
			if file_access == null:
				push_error(
					"Godot Tours: could not open file '%s' for writing. Resetting the tour '%s' was not successful." % [destination_file_path, tour_path]
				)
				was_reset_successful = false
				break
			file_access.store_string(contents)
			if destination_file_path in open_scene_paths:
				reload_scene_paths.push_back(destination_file_path)
		else:
			var error := DirAccess.copy_absolute(tour_file_path, destination_file_path)
			if error != OK:
				push_error(
					"Godot Tours: could not copy folder '%s' to '%s'. Resetting the tour '%s' was not successful." % [tour_file_path, destination_file_path, tour_path]
				)
				was_reset_successful = false
				break

	EditorInterface.get_resource_filesystem().scan()
	while EditorInterface.get_resource_filesystem().is_scanning():
		pass

	for scene_path: String in reload_scene_paths:
		EditorInterface.reload_scene_from_path(scene_path)
	return was_reset_successful
