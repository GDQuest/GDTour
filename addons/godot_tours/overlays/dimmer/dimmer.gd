@tool
extends SubViewportContainer

const DimmerMaskPackedScene := preload("dimmer_mask.tscn")

@onready var window := get_window()
@onready var film_color_rect: ColorRect = %FilmColorRect


func _ready() -> void:
	window.size_changed.connect(refresh)
	refresh()


func clean_up() -> void:
	window.size_changed.disconnect(refresh)


func add_mask() -> ColorRect:
	var result := DimmerMaskPackedScene.instantiate()
	film_color_rect.add_child(result)
	return result


func refresh() -> void:
	size = window.size


func toggle_dimmer_mask(is_on: bool) -> void:
	for dimmer_mask in film_color_rect.get_children():
		dimmer_mask.visible = is_on
