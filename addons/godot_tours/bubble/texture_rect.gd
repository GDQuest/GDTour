@tool
extends TextureRect

## Limits the height of the texture in the bubble.
var max_height := 300.0 * EditorInterface.get_editor_scale():
	set = set_max_height


func _ready() -> void:
	set_max_height(max_height)


func set_max_height(new_max_height: float) -> void:
	if new_max_height > 0.0:
		max_height = new_max_height

	if not is_inside_tree():
		return

	await get_tree().process_frame
	custom_minimum_size = Vector2(size.x, min(max_height, texture.get_size().y))
