@tool
extends SubViewportContainer

const DimmerMaskPackedScene := preload("dimmer_mask.tscn")

var root: Window = null

@onready var film_color_rect: ColorRect = %FilmColorRect


func _ready() -> void:
	root = get_tree().root
	root.size_changed.connect(refresh)
	refresh()


func clean_up() -> void:
	root.size_changed.disconnect(refresh)


func add_mask() -> ColorRect:
	var result := DimmerMaskPackedScene.instantiate()
	film_color_rect.add_child(result)
	return result


func refresh() -> void:
	size = root.size


func toggle_dimmer_mask(is_on: bool) -> void:
	for dimmer_mask in film_color_rect.get_children():
		dimmer_mask.visible = is_on
