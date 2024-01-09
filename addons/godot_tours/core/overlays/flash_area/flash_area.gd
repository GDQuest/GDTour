@tool
extends ColorRect

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.play("flash")


func refresh(canvas_item_editor_viewport: Control, global_rect: Rect2) -> void:
	global_rect = (
		EditorInterface.get_edited_scene_root().get_viewport().get_screen_transform() * global_rect
	)
	size = global_rect.size
	global_position = global_rect.position
	visible = global_rect != Rect2() and canvas_item_editor_viewport.is_visible_in_tree()
