@tool
extends Control

const UI_SELECTABLE_TOUR_SCENE = preload("ui_selectable_tour.tscn")
const UiSelectableTour = preload("res://addons/godot_tours/ui_selectable_tour.gd")
const GodotTourEntry = preload("res://addons/godot_tours/core/godot_tour_entry.gd")
const GodotTourList = preload("res://addons/godot_tours/core/godot_tour_list.gd")
const Tour := preload("res://addons/godot_tours/core/tour.gd")
const ThemeUtils := preload("res://addons/godot_tours/theme_utils.gd")

## Emitted when the start learning button is pressed.
signal tour_start_requested(tour_path: String)
## Emitted when the menu is closed.
signal closed

var selected_tour_path := ""

@onready var button: Button = %ButtonStartLearning
@onready var tours_column: VBoxContainer = %ToursColumn
@onready var button_close: Button = %ButtonClose
@onready var label_title: Label = %LabelTitle
@onready var margin_container: MarginContainer = %MarginContainer
@onready var panel_container: PanelContainer = %PanelContainer


var _theme_utils: ThemeUtils = ThemeUtils.new()

func _ready() -> void:
	button_close.pressed.connect(func emit_closed_and_free():
		closed.emit()
		queue_free()
	)


func setup(tour_list: GodotTourList) -> void:
	for tour: GodotTourEntry in tour_list.tours:
		var selectable_tour: UiSelectableTour = UI_SELECTABLE_TOUR_SCENE.instantiate()
		selectable_tour.title = tour.title
		selectable_tour.is_free = tour.is_free
		selectable_tour.is_locked = tour.is_locked

		tours_column.add_child(selectable_tour)
		selectable_tour.pressed.connect(func change_selected_path():
			selected_tour_path = tour.tour_path
		)
		selectable_tour.setup()

	button.pressed.connect(func request_tour():
		if selected_tour_path == "":
			return
		tour_start_requested.emit(selected_tour_path)
	)

	# Scale with editor scale
	if Engine.is_editor_hint():
		panel_container.custom_minimum_size.x *= EditorInterface.get_editor_scale()
		[label_title, button].map(_theme_utils.scale_font_size)
		_theme_utils.scale_margin_container_margins(margin_container)
	
	if tours_column.get_child_count() > 0:
		tours_column.get_child(0).select()
