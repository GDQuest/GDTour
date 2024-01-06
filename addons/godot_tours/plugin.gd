@tool
extends EditorPlugin

## Path to the file from which the plugin finds and registers tours.
## Contains an array of tour entries. See the file godot_tour_entry.gd for more information.
const TOUR_LIST_FILE_PATH := "res://godot_tours.tres"
const SINGLE_WINDOW_MODE_PROPERTY := "interface/editor/single_window_mode"

const Utils := preload("core/utils.gd")
const EditorInterfaceAccess := preload("core/editor_interface_access.gd")
const Tour := preload("core/tour.gd")
const Overlays := preload("core/overlays/overlays.gd")
const Debugger := preload("core/debugger/debugger.gd")
const TranslationParser := preload("core/translation/translation_parser.gd")
const TranslationService := preload("core/translation/translation_service.gd")

const UI_DEBUGGER_DOCK_SCENE := preload("core/debugger/debugger.tscn")
const UI_WELCOME_MENU_SCENE = preload("ui_welcome_menu.tscn")
const UI_BUTTON_GODOT_TOURS = preload("ui_button_godot_tours.tscn")

var plugin_path: String = get_script().resource_path.get_base_dir()
var translation_parser := TranslationParser.new()
var translation_service: TranslationService = null
var debugger: Debugger = null
var editor_interface_access: EditorInterfaceAccess = null
var overlays: Overlays = null

## Resource of type godot_tour_list.gd. Contains an array of tour entries.
var tour_list = get_tours()
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

	_tour_paths.assign(tour_list.tours.map(
		func get_tour_path(tour_entry) -> String:
			return tour_entry.tour_path
	))

	await get_tree().physics_frame
	get_viewport().mode = Window.MODE_MAXIMIZED

	add_translation_parser_plugin(translation_parser)
	var editor_settings := EditorInterface.get_editor_settings()
	var is_single_window_mode := editor_settings.get_setting(SINGLE_WINDOW_MODE_PROPERTY)
	if not is_single_window_mode:
		editor_settings.set_setting(SINGLE_WINDOW_MODE_PROPERTY, true)
		EditorInterface.restart_editor()

	translation_service = TranslationService.new(_tour_paths, editor_settings)
	editor_interface_access = EditorInterfaceAccess.new()
	overlays = Overlays.new(editor_interface_access)
	EditorInterface.get_base_control().add_child(overlays)

	# Add button to the editor top bar, right before the run buttons
	if tour_list != null:
		_add_top_bar_button()
		_show_welcome_menu()
		ensure_pot_generation(plugin_path)

	if Debugger.CLI_OPTION_DEBUG in OS.get_cmdline_user_args():
		toggle_debugger()


## Adds a button labeled Godot Tours to the editor top bar, right before the run buttons.
## This button only shows when there are tours in the project, there's no tour active, and the welcome menu is hidden.
func _add_top_bar_button() -> void:
	_button_top_bar = UI_BUTTON_GODOT_TOURS.instantiate()
	_button_top_bar.setup()
	editor_interface_access.run_bar.add_sibling(_button_top_bar)
	_button_top_bar.get_parent().move_child(_button_top_bar, editor_interface_access.run_bar.get_index())
	_button_top_bar.pressed.connect(_show_welcome_menu)


## Shows the welcome menu, which lists all the tours in the file res://godot_tours.tres.
func _show_welcome_menu() -> void:
	if tour_list == null:
		return

	_button_top_bar.hide()

	var welcome_menu := UI_WELCOME_MENU_SCENE.instantiate()
	tree_exiting.connect(welcome_menu.queue_free)

	EditorInterface.get_base_control().add_child(welcome_menu)
	welcome_menu.setup(tour_list)
	welcome_menu.tour_start_requested.connect(func start_tour(tour_path: String) -> void:
		welcome_menu.queue_free()
		tour = load(tour_path).new(editor_interface_access, overlays, translation_service)
		tour.ended.connect(_button_top_bar.show)
	)
	welcome_menu.closed.connect(_button_top_bar.show)


func _exit_tree() -> void:
	if _button_top_bar != null:
		_button_top_bar.queue_free()

	if tour_list == null:
		return

	if debugger != null:
		remove_control_from_docks(debugger)
		debugger.queue_free()

	editor_interface_access.clean_up()
	overlays.clean_up()
	overlays.queue_free()
	if tour != null:
		tour.clean_up()

	remove_translation_parser_plugin(translation_parser)
	if tour_list != null:
		ensure_pot_generation(plugin_path, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F10 and event.ctrl_pressed and event.pressed:
		toggle_debugger()


## Registers and unregisters translation files for the tours.
func ensure_pot_generation(plugin_path: String, do_clean_up := false) -> void:
	const key := "internationalization/locale/translations_pot_files"
	var tour_base_script_file_path := plugin_path.path_join("core").path_join("tour.gd")
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
		debugger = UI_DEBUGGER_DOCK_SCENE.instantiate()
		debugger.setup(plugin_path, editor_interface_access, overlays, translation_service, tour)
		debugger.populate_tours_item_list(_tour_paths)

	if not debugger.is_inside_tree():
		add_control_to_dock(DOCK_SLOT_LEFT_UL, debugger)
	else:
		remove_control_from_docks(debugger)


## Looks for a godot_tours.tres file at the root of the project. This file should contain an array of
## TourMetadata. Finds and loads the tours.
func get_tours():
	if not FileAccess.file_exists(TOUR_LIST_FILE_PATH):
		push_warning("Godot Tours: no tours found. Create a GodotTourList resource file named '%s' to list and register tours." % TOUR_LIST_FILE_PATH)
		return null

	return load(TOUR_LIST_FILE_PATH)


