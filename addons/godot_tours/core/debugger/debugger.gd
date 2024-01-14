## Panel that appears when running Godot with a debug flag (see [CLI_OPTION_DEBUG] constant below).
## Provides controls to change the opacity and visibility of the overlays and dimmers,
## as well as a list of available tours.
@tool
extends PanelContainer

const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const Highlight := preload("../overlays/highlight/highlight.gd")
const Overlays := preload("../overlays/overlays.gd")
const TranslationService := preload("../translation/translation_service.gd")
const Tour := preload("../tour.gd")
const Utils := preload("../utils.gd")

var ResourceInvalidator := preload("resource_invalidator.gd")

## If Godot is run with this flag, the tour will be run in debug mode, displaying this debugger panel.
const CLI_OPTION_DEBUG := "--tour-debug"
const DIMMER_GROUP: StringName = "dimmer"

## Reference to the currently active tour running in debug mode.
var tour: Tour = null:
	set(new_tour):
		tour = new_tour
		if tour != null and button_toggle_tour_visible != null:
			button_toggle_tour_visible.disabled = tour == null
			button_toggle_tour_visible.toggled.connect(tour.toggle_visible)

var plugin_path := ""
var interface: EditorInterfaceAccess = null
var overlays: Overlays = null
var translation_service: TranslationService = null
var tour_paths: Array[String] = []

@onready var toggle_dimmers_check_button: CheckButton = %ToggleDimmersCheckButton
@onready var toggle_bubble_check_button: CheckButton = %ToggleBubbleCheckButton
@onready var dimmers_alpha_h_slider: HSlider = %OverlaysAlphaHSlider
@onready var tours_item_list: ItemList = %ToursItemList
@onready var jump_button: Button = %JumpButton
@onready var jump_spin_box: SpinBox = %JumpSpinBox
@onready var button_toggle_tour_visible: CheckButton = %ButtonToggleTourVisible
@onready var button_start_tour: Button = %ButtonStartTour


func setup(plugin_path: String, interface: EditorInterfaceAccess, overlays: Overlays, translation_service: TranslationService, tour: Tour, tour_paths: Array[String]) -> void:
	self.plugin_path = plugin_path
	self.interface = interface
	self.overlays = overlays
	self.translation_service = translation_service
	self.tour = tour
	self.tour_paths = tour_paths


func _ready() -> void:
	overlays.cleaned_up.connect(overlays.add_highlight_to_control.bind(self))
	toggle_dimmers_check_button.button_pressed = not overlays.dimmers.is_empty()
	toggle_dimmers_check_button.toggled.connect(func(is_active: bool) -> void:
		overlays.toggle_dimmers(is_active)
		dimmers_alpha_h_slider.editable = is_active
	)
	toggle_bubble_check_button.toggled.connect(func(is_toggled: bool) -> void:
		if tour != null:
			tour.bubble.visible = is_toggled
	)
	tours_item_list.item_selected.connect(_on_tours_item_list_item_selected)
	button_start_tour.pressed.connect(_start_selected_tour)
	dimmers_alpha_h_slider.value_changed.connect(_on_overlay_alpha_h_slider_value_changed)
	jump_button.pressed.connect(_jump_to_step)

	dimmers_alpha_h_slider.editable = toggle_dimmers_check_button.button_pressed
	overlays.add_highlight_to_control(self)
	_on_overlay_alpha_h_slider_value_changed(dimmers_alpha_h_slider.value)
	_update_spinbox_step_count()
	populate_tours_item_list()
	toggle_bubble_check_button.button_pressed = tour != null


func _exit_tree() -> void:
	overlays.cleaned_up.disconnect(overlays.add_highlight_to_control)
	_on_overlay_alpha_h_slider_value_changed(1.0)
	for child in overlays.ensure_get_dimmer_for(self).get_children():
		if child is Highlight and child.control == self:
			child.queue_free()
			break


func _start_selected_tour() -> void:
	var selected := tours_item_list.get_selected_items()
	if selected.size() == 0:
		return

	var index := tours_item_list.get_selected_items()[0]
	if tour != null:
		tour.clean_up()
	var tour_path := tours_item_list.get_item_metadata(index)
	tour = ResourceInvalidator.resource_force_editor_reload(tour_path).new(interface, overlays, translation_service)
	toggle_dimmers_check_button.button_pressed = true
	toggle_bubble_check_button.button_pressed = true
	tour.toggle_visible(true)
	_update_spinbox_step_count()


func _on_tours_item_list_item_selected(index: int) -> void:
	button_start_tour.disabled = tours_item_list.get_selected_items().size() == 0


func _on_overlay_alpha_h_slider_value_changed(value: float) -> void:
	get_tree().set_group(DIMMER_GROUP, "modulate", Color(1, 1, 1, value))
	toggle_dimmers_check_button.set_pressed_no_signal(not is_zero_approx(value))


func populate_tours_item_list() -> void:
	tours_item_list.clear()
	for index in range(tour_paths.size()):
		tours_item_list.add_item(tour_paths[index].get_file())
		tours_item_list.set_item_metadata(index, tour_paths[index])


func _update_spinbox_step_count() -> void:
	if tour == null:
		jump_spin_box.suffix = "/ 1"
	else:
		var max_value := tour.steps.size()
		jump_spin_box.suffix = " / " + str(max_value)
		jump_spin_box.max_value = max_value


func _jump_to_step() -> void:
		tour.index = int(jump_spin_box.value - 1)
