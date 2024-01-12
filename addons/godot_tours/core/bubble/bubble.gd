## Text bubble used to display instructions to the user.
@tool
extends CanvasLayer

signal back_button_pressed
signal next_button_pressed
## Emitted when the user confirms wanting to quit the tour
signal close_requested

const Task := preload("task/task.gd")
const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const TranslationService := preload("../translation/translation_service.gd")
const Debugger := preload("../debugger/debugger.gd")

const ThemeUtils := preload("res://addons/godot_tours/theme_utils.gd")

const TaskPackedScene: PackedScene = preload("res://addons/godot_tours/core/bubble/task/task.tscn")

const TWEEN_DURATION := 0.1

## Location to place and anchor the bubble relative to a given Control node. Used in the function `move_and_anchor()` and by the `at` variable.
enum At {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT,
	CENTER_LEFT,
	TOP_CENTER,
	BOTTOM_CENTER,
	CENTER_RIGHT,
	CENTER,
}
## Location of the Gobot avatar along the top edge of the bubble.
enum AvatarAt { LEFT, CENTER, RIGHT }

var at := At.CENTER
var avatar_at := AvatarAt.LEFT
var margin := 16.0
var offset_vector := Vector2.ZERO
var control: Control = null
var translation_service: TranslationService = null
var step_count := 0

var tween: Tween = null
var avatar_tween_position: Tween = null
var avatar_tween_rotation: Tween = null

@onready var panel: Control = %Panel
@onready var avatar: Node2D = %Avatar


func setup(translation_service: TranslationService, step_count: int) -> void:
	self.translation_service = translation_service
	self.step_count = step_count


func on_tour_step_changed(index: int) -> void:
	pass


func clear() -> void:
	pass


func set_title(title_text: String) -> void:
	pass


func add_task(
	description: String,
	repeat: int,
	repeat_callable: Callable,
	error_predicate: Callable,
) -> void:
	pass


func check_tasks() -> bool:
	return true


## Moves and anchors the bubble relative to the given control node.
func move_and_anchor(
	control: Control, at := At.CENTER, margin := 16.0, offset_vector := Vector2.ZERO
) -> void:
	self.control = control
	self.at = at
	self.margin = margin
	self.offset_vector = offset_vector
	refresh()


func set_avatar_at(at := AvatarAt.LEFT) -> void:
	avatar_at = at
	var editor_scale := EditorInterface.get_editor_scale()
	var at_offset := {
		AvatarAt.LEFT: Vector2(-8.0, -6.0) * editor_scale,
		AvatarAt.CENTER: Vector2(panel.size.x / 2.0, -8.0 * editor_scale),
		AvatarAt.RIGHT: Vector2(panel.size.x + 3.0 * editor_scale, -8.0 * editor_scale),
	}
	var new_avatar_position: Vector2 = at_offset[at]

	const target_rotation_degrees := {
		AvatarAt.LEFT: -15.0,
		AvatarAt.CENTER: -4.0,
		AvatarAt.RIGHT: 7.5,
	}
	var new_avatar_rotation: float = target_rotation_degrees[at]

	if not avatar.position.is_equal_approx(new_avatar_position):
		if avatar_tween_position != null:
			avatar_tween_position.kill()
		avatar_tween_position = create_tween().set_ease(Tween.EASE_IN)
		avatar_tween_position.tween_property(
			avatar, "position", new_avatar_position, TWEEN_DURATION
		)

	if not avatar.position.is_equal_approx(new_avatar_position):
		if avatar_tween_rotation != null:
			avatar_tween_rotation.kill()
		avatar_tween_rotation = create_tween().set_ease(Tween.EASE_IN)
		avatar_tween_rotation.tween_property(
			avatar, "rotation_degrees", new_avatar_rotation, TWEEN_DURATION
		)


func refresh() -> void:
	if control == null:
		return

	# We delay for one frame because it can take that amount of time for RichTextLabel nodes to update their state.
	# Without this, the bubble can end up being too tall.
	await get_tree().process_frame
	panel.reset_size()
	var at_offset := {
		At.TOP_LEFT: margin * Vector2.ONE,
		At.TOP_CENTER: Vector2((control.size.x - panel.size.x) / 2.0, 0.0) + margin * Vector2.DOWN,
		At.TOP_RIGHT: Vector2(control.size.x - panel.size.x, 0.0) + margin * Vector2(-1.0, 1.0),
		At.BOTTOM_RIGHT: control.size - panel.size - margin * Vector2.ONE,
		At.BOTTOM_CENTER: Vector2(0.5, 1.0) * (control.size - panel.size) + margin * Vector2.UP,
		At.BOTTOM_LEFT: Vector2(0.0, control.size.y - panel.size.y) + margin * Vector2(1.0, -1.0),
		At.CENTER_LEFT:
		Vector2(0.0, (control.size.y - panel.size.y) / 2.0) + margin * Vector2.RIGHT,
		At.CENTER_RIGHT: Vector2(1.0, 0.5) * (control.size - panel.size) + margin * Vector2.LEFT,
		At.CENTER: (control.size - panel.size) / 2.0,
	}
	var new_global_position: Vector2 = control.global_position + at_offset[at] + offset_vector
	if not panel.global_position.is_equal_approx(new_global_position):
		if tween != null:
			tween.kill()
		tween = create_tween().set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "global_position", new_global_position, TWEEN_DURATION)
	set_avatar_at(avatar_at)


func update_locale(locales: Dictionary) -> void:
	for node in locales:
		var dict: Dictionary = locales[node]
		for key in dict:
			node.set(key, translation_service.get_bubble_message(dict[key]))
