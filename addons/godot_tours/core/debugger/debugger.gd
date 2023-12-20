## Panel that appears when running Godot with a debug flag (see [CLI_OPTION_DEBUG] constant below).
## Provides controls to change the opacity and visibility of the overlays and dimmers,
## as well as a list of available tours.
@tool
extends PanelContainer

const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const Overlays := preload("../overlays/overlays.gd")
const TranslationService := preload("../translation/translation_service.gd")
const Tour := preload("../tour.gd")
const Utils := preload("../utils.gd")

var ResourceInvalidator := preload("resource_invalidator.gd")

## If Godot is run with this flag, the tour will be run in debug mode, displaying this debugger panel.
const CLI_OPTION_DEBUG := "--tour-debug"
const OVERLAY := "overlay"

## Reference to the currently active tour running in debug mode.
var tour: Tour = null:
	set(new_tour):
		tour = new_tour
		if tour != null:
			button_toggle_tour_visible.disabled = tour == null
			button_toggle_tour_visible.toggled.connect(tour.toggle_visible)

var plugin_path := ""
var dimmer_mask: ColorRect = null
var interface: EditorInterfaceAccess = null
var overlays: Overlays = null
var translation_service: TranslationService = null

@onready var toggle_overlays_check_button: Button = %ToggleOverlaysCheckButton
@onready var toggle_dimmers_check_button: Button = %ToggleDimmersCheckButton
@onready var overlays_alpha_h_slider: HSlider = %OverlaysAlphaHSlider
@onready var tours_item_list: ItemList = %ToursItemList
@onready var jump_button: Button = %JumpButton
@onready var jump_spin_box: SpinBox = %JumpSpinBox
@onready var button_toggle_tour_visible: CheckButton = %ButtonToggleTourVisible
@onready var button_start_tour: Button = %ButtonStartTour


func setup(plugin_path: String, interface: EditorInterfaceAccess, overlays: Overlays, translation_service: TranslationService, tour: Tour) -> void:

	if not is_inside_tree():
		await ready

	self.plugin_path = plugin_path
	self.interface = interface
	self.overlays = overlays
	self.translation_service = translation_service
	self.tour = tour

	draw.connect(refresh)
	toggle_overlays_check_button.toggled.connect(func(is_active: bool) -> void:
		overlays.toggle_overlays(is_active)
		overlays_alpha_h_slider.editable = is_active
		dimmer_mask.visible = true
	)
	toggle_dimmers_check_button.toggled.connect(overlays.toggle_dimmers)
	tours_item_list.item_selected.connect(_on_tours_item_list_item_selected)
	button_start_tour.pressed.connect(_start_selected_tour)
	overlays_alpha_h_slider.value_changed.connect(_on_overlay_alpha_h_slider_value_changed)
	overlays_alpha_h_slider.value_changed.emit(overlays_alpha_h_slider.value)
	jump_button.pressed.connect(_jump_to_step)

	dimmer_mask = overlays.get_dimmer_for(interface.base_control).add_mask()

	dimmer_mask.visible = false
	toggle_dimmers_check_button.button_pressed = dimmer_mask.visible
	overlays_alpha_h_slider.editable = toggle_overlays_check_button.button_pressed

	_update_spinbox_step_count()

	refresh()


func _enter_tree() -> void:
	if dimmer_mask != null:
		dimmer_mask.visible = true


func _exit_tree() -> void:
	_on_overlay_alpha_h_slider_value_changed(0.0)
	if dimmer_mask != null:
		dimmer_mask.visible = false


func _start_selected_tour() -> void:
	var selected := tours_item_list.get_selected_items()
	if selected.size() == 0:
		return

	var index := tours_item_list.get_selected_items()[0]
	if tour != null:
		tour.clean_up()
	var tour_path := tours_item_list.get_item_metadata(index)
	tour = ResourceInvalidator.resource_force_editor_reload(tour_path).new(interface, overlays, translation_service)
	toggle_overlays_check_button.button_pressed = true
	toggle_dimmers_check_button.button_pressed = true
	tour.toggle_visible(true)
	_update_spinbox_step_count()


func _on_tours_item_list_item_selected(index: int) -> void:
	button_start_tour.disabled = tours_item_list.get_selected_items().size() == 0


func _on_overlay_alpha_h_slider_value_changed(value: float) -> void:
	get_tree().set_group(OVERLAY, "color", Color(1, 1, 1, value))


func populate_tours_item_list(tours: Array[String]) -> void:
	tours_item_list.clear()
	for index in range(tours.size()):
		tours_item_list.add_item(tours[index].get_file())
		tours_item_list.set_item_metadata(index, tours[index])


func refresh() -> void:
	if dimmer_mask != null:
		dimmer_mask.global_position = global_position
		dimmer_mask.size = size
	if overlays != null:
		overlays.refresh_all()


func _update_spinbox_step_count() -> void:
	if tour == null:
		jump_spin_box.suffix = "/ 1"
	else:
		var max_value := tour.get_step_count()
		jump_spin_box.suffix = " / " + str(max_value)
		jump_spin_box.max_value = max_value


func _jump_to_step() -> void:
		tour.index = int(jump_spin_box.value - 1)
