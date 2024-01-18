@tool
extends CanvasLayer

## Emitted when the start learning button is pressed.
signal tour_start_requested(tour_path: String)
signal tour_reset_requested(tour_path: String)
## Emitted when the menu is closed.
signal closed

const UISelectableTour = preload("ui_selectable_tour.gd")
const ThemeUtils := preload("theme_utils.gd")
const GodotTourEntry = preload("../godot_tour_entry.gd")
const GodotTourList = preload("../godot_tour_list.gd")
const Tour := preload("../tour.gd")

const UISelectableTourPackedScene = preload("ui_selectable_tour.tscn")

@onready var control: Control = %Control
@onready var button: Button = %ButtonStartLearning
@onready var reset_button: TextureButton = %ResetTextureButton
@onready var tours_column: VBoxContainer = %ToursColumn
@onready var button_close: Button = %ButtonClose
@onready var label_title: Label = %LabelTitle
@onready var margin_container: MarginContainer = %MarginContainer
@onready var panel_container: PanelContainer = %PanelContainer
@onready var color_rect: ColorRect = %ColorRect


func setup(tour_list: GodotTourList) -> void:
	button_close.pressed.connect(func emit_closed_and_free() -> void:
		closed.emit()
		queue_free()
	)
	button.pressed.connect(func request_tour() -> void:
		tour_start_requested.emit(get_selectable_tour().tour_path)
	)
	reset_button.pressed.connect(func reset_tour() -> void:
		tour_reset_requested.emit(get_selectable_tour().tour_path)
	)

	for tour_entry: GodotTourEntry in tour_list.tours:
		var selectable_tour: UISelectableTour = UISelectableTourPackedScene.instantiate()
		tours_column.add_child(selectable_tour)
		selectable_tour.setup(tour_entry)

	# Scale with editor scale
	if Engine.is_editor_hint():
		panel_container.custom_minimum_size.x *= EditorInterface.get_editor_scale()
		for node: Control in [label_title, button]:
			ThemeUtils.scale_font_size(node)
		ThemeUtils.scale_margin_container_margins(margin_container)

	if tours_column.get_child_count() > 0:
		tours_column.get_child(0).select()


func get_selectable_tour() -> UISelectableTour:
	return UISelectableTour.group.get_pressed_button().owner


func toggle_dimmer(is_on := true) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP if is_on else Control.MOUSE_FILTER_IGNORE
	color_rect.mouse_filter = control.mouse_filter
