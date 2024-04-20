@tool
extends TextureRect


# This texture rect gets added to the default bubble. We need to wait for the control node
# to update its width and then force a height based on that or the texture won't display.
func _ready() -> void:
	await get_tree().process_frame
	var texture_size := texture.get_size()
	var aspect_ratio := texture_size.x / texture_size.y

	var max_height := 300.0 * EditorInterface.get_editor_scale()

	custom_minimum_size = Vector2(size.x, min(max_height, size.x / aspect_ratio))
