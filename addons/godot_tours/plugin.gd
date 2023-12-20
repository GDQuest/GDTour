@tool
extends EditorPlugin

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

var tour_list = get_tours()

var tour: Tour = null
## Button to open the tour selection menu, sitting in the editor top bar.
## This button only shows when there's no tour active and the welcome menu is hidden.
var button_top_bar: Button = null

## Looks for a godot_tours.tres file at the root of the project. This file should contain an array of
## TourMetadata. Finds and loads the tours.
func get_tours():
	const TOUR_LIST_FILE_PATH := "res://godot_tours.tres"
	if not FileAccess.file_exists(TOUR_LIST_FILE_PATH):
		push_warning("Godot Tours: no tours found. Create a GodotTourList resource file named '%s' to list and register tours.")
		return

	return load(TOUR_LIST_FILE_PATH)


func _enter_tree() -> void:
	await get_tree().physics_frame
	get_viewport().mode = Window.MODE_MAXIMIZED

	add_translation_parser_plugin(translation_parser)
	var editor_settings := EditorInterface.get_editor_settings()
	var is_single_window_mode := editor_settings.get_setting(SINGLE_WINDOW_MODE_PROPERTY)
	if not is_single_window_mode:
		editor_settings.set_setting(SINGLE_WINDOW_MODE_PROPERTY, true)
		EditorInterface.restart_editor()

	translation_service = TranslationService.new(plugin_path, editor_settings)
	editor_interface_access = EditorInterfaceAccess.new()
	overlays = Overlays.new(editor_interface_access, EditorInterface.get_editor_scale())
	EditorInterface.get_base_control().add_child(overlays)

	# Add button to the editor top bar, right before the run buttons
	button_top_bar = UI_BUTTON_GODOT_TOURS.instantiate()
	button_top_bar.setup()
	editor_interface_access.run_bar.add_sibling(button_top_bar)
	button_top_bar.get_parent().move_child(button_top_bar, editor_interface_access.run_bar.get_index())
	button_top_bar.pressed.connect(_show_welcome_menu)
	_show_welcome_menu()

	ensure_pot_generation(plugin_path)

	if Debugger.CLI_OPTION_DEBUG in OS.get_cmdline_user_args():
		toggle_debugger()


func _show_welcome_menu() -> void:
	button_top_bar.hide()
	var welcome_menu := UI_WELCOME_MENU_SCENE.instantiate()
	EditorInterface.get_base_control().add_child(welcome_menu)
	welcome_menu.setup(tour_list)
	welcome_menu.tour_start_requested.connect(func start_tour(tour_path: String) -> void:
		welcome_menu.queue_free()
		tour = load(tour_path).new(editor_interface_access, overlays, translation_service)
		tour.ended.connect(button_top_bar.show)
	)
	welcome_menu.closed.connect(button_top_bar.show)


func _exit_tree() -> void:
	if debugger != null:
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


func ensure_pot_generation(plugin_path: String, do_clean_up := false) -> void:
	const key := "internationalization/locale/translations_pot_files"
	var tour_paths := Utils.get_tour_paths(plugin_path)
	var tour_base_script_file_path := plugin_path.path_join("core").path_join("tour.gd")
	var pot_files_setting := ProjectSettings.get_setting(key, PackedStringArray())
	for file_path in [tour_base_script_file_path] + tour_paths:
		var is_file_path_in: bool = file_path in pot_files_setting
		if is_file_path_in and do_clean_up:
			pot_files_setting.remove_at(pot_files_setting.find(file_path))
		elif not is_file_path_in and not do_clean_up:
			pot_files_setting.push_back(file_path)
	ProjectSettings.set_setting(key, null if pot_files_setting.is_empty() else pot_files_setting)
	ProjectSettings.save()


func toggle_debugger() -> void:
	if debugger == null:
		debugger = UI_DEBUGGER_DOCK_SCENE.instantiate()
		debugger.setup(plugin_path, editor_interface_access, overlays, translation_service, tour)

	if not debugger.is_inside_tree():
		add_control_to_dock(DOCK_SLOT_LEFT_UL, debugger)
	else:
		remove_control_from_docks(debugger)
