## UI component for one tour on Godot tour's welcome menu.
@tool
extends Control

const GodotTourEntry = preload("../godot_tour_entry.gd")

const COLOR_DISABLED_TEXT := Color(0.51764708757401, 0.59607845544815, 0.74509805440903)

static var group := ButtonGroup.new()

@export var is_free := false:
	set(value):
		is_free = value
		if not label_free:
			await ready
		label_free.visible = is_free
@export var title := "":
	set(value):
		title = value
		if not label_title:
			await ready
		label_title.text = title

@export var is_locked := false:
	set(value):
		is_locked = value
		if not label_title:
			await ready

		button.disabled = is_locked
		icon_lock.visible = is_locked
		label_symbol.visible = not is_locked
		button.mouse_default_cursor_shape = (
			Control.CURSOR_FORBIDDEN if is_locked else Control.CURSOR_POINTING_HAND
		)
		if is_locked:
			label_title.add_theme_color_override("font_color", COLOR_DISABLED_TEXT)
		else:
			label_title.remove_theme_color_override("font_color")

var tour_path := ""

@onready var icon_lock: TextureRect = %IconLock
@onready var label_symbol: Label = %LabelSymbol
@onready var label_title: Label = %LabelTitle
@onready var label_free: Label = %LabelFree
@onready var button: Button = %Button


func setup(tour_entry: GodotTourEntry) -> void:
	self.tour_path = tour_entry.tour_path
	title = tour_entry.title
	is_free = tour_entry.is_free
	is_locked = tour_entry.is_locked


func _ready() -> void:
	button.button_group = group

	if Engine.is_editor_hint():
		var editor_scale := EditorInterface.get_editor_scale()
		for label: Label in [label_free, label_title, label_symbol]:
			var title_font_size: int = label.get_theme_font_size("font_size")
			label.add_theme_font_size_override("font_size", title_font_size * editor_scale)

		icon_lock.custom_minimum_size *= editor_scale
		label_symbol.custom_minimum_size *= editor_scale


## Makes this selected, pressing the child button node and emitting the selected signal.
func select() -> void:
	button.set_pressed_no_signal(true)
