@tool
extends ColorRect

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.play("flash")


func refresh(canvas_item_editor_viewport: Control, rect: Rect2) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	rect = canvas_item_editor_viewport.get_global_rect().intersection(
		scene_root.get_viewport().get_screen_transform() * rect
	)
	size = rect.size
	global_position = rect.position
	visible = rect != Rect2() and canvas_item_editor_viewport.is_visible_in_tree()
