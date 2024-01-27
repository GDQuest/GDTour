## Base class for the text bubble used to display instructions to the user.
## Check out ["addons/godot_tours/bubble/default_bubble.gd"] for the default implementation.
@tool
extends CanvasLayer

## Emitted to go backward one step in the tour.
signal back_button_pressed
## Emitted to go forward one step in the tour.
signal next_button_pressed
## Emitted when the user confirms wanting to quit the tour.
signal close_requested
## Emitted when the user confirms wanting to finish the tour (for example, when they finish the last step).
signal finish_requested


const Task := preload("task/task.gd")
const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const TranslationService := preload("../translation/translation_service.gd")
const Debugger := preload("../debugger/debugger.gd")
const ThemeUtils := preload("../ui/theme_utils.gd")

const TaskPackedScene: PackedScene = preload("task/task.tscn")

const TWEEN_DURATION := 0.25

## Location to place and anchor the bubble relative to a given Control node [b]inside its rectangle[/b]. Used in the
## function [method move_and_anchor] and by the [member at] variable.
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
## Location of the Avatar along the top edge of the bubble.
enum AvatarAt { LEFT, CENTER, RIGHT }

var at := At.CENTER  ## Bubble location relative to a given Control node. See [enum At] for details.
var avatar_at := AvatarAt.LEFT  ## Avatar location relative to the bubble. See [enum AvatarAt] for details.

## Margin offset for [method move_and_anchor]. It keeps the bubble at [code]margin[/code] pixels away relative to
## the Control border.
var margin := 16.0
var offset_vector := Vector2.ZERO  ## Custom offset for [method move_and_anchor] for extra control.
var control: Control = null  ## Reference to the control node passed to [method move_and_anchor].
var translation_service: TranslationService = null
var step_count := 0  ## Tour step count.

var tween: Tween = null
var avatar_tween_position: Tween = null
var avatar_tween_rotation: Tween = null

@onready var panel: Control = %Panel
@onready var avatar: Node2D = %Avatar


func setup(translation_service: TranslationService, step_count: int) -> void:
	self.translation_service = translation_service
	self.step_count = step_count
	
	# We call this function that updates the position and size of the bubble.
	# RichTextLabel nodes added to the bubble can cause it to resize after 0, 1, or 2 frames. It's not reliable
	# and depends on the computer. So, it's best to let the panel container node tell us when it's been resized.
	panel.minimum_size_changed.connect(refresh)


## [b]Virtual[/b] method for reacting to the tour step change. See ["addons/godot_tours/tour.gd"]
## [code]step_changed[/code] signal for details.
func on_tour_step_changed(index: int) -> void:
	pass


## [b]Virtual[/b] method called at the beginning of every tour step for clearing anything necessary.
func clear() -> void:
	pass


## [b]Virtual[/b] method to set the bubble title.
func set_title(title_text: String) -> void:
	pass


## [b]Virtual[/b] method to insert lines of text.
func add_text(text: Array[String]) -> void:
	pass


## [b]Virtual[/b] method to insert a texture image.
func add_texture(texture: Texture2D) -> void:
	pass


## [b]Virtual[/b] method to insert a video.
func add_video(video: VideoStream) -> void:
	pass


## [b]Virtual[/b] method to insert a code snippet.
func add_code(code: Array[String]) -> void:
	pass


## [b]Virtual[/b] method to change the displayed image.
func set_background(texture: Texture2D) -> void:
	pass


## [b]Virtual[/b] method to change the header text.
func set_header(text: String) -> void:
	pass


## [b]Virtual[/b] method to change the footer text.
func set_footer(text: String) -> void:
	pass


## [b]Virtual[/b] method to change the text of the next button.
func set_finish_button_text(text: String) -> void:
	pass


## [b]Virtual[/b] method to add a task.
func add_task(

	description: String,
	repeat: int,
	repeat_callable: Callable,
	error_predicate: Callable,
) -> void:
	pass


## [b]Virtual[/b] method for checking if all tasks are done.
## Returns [code]true[/code] or [code]false[/code] based on the status of all tasks.
func check_tasks() -> bool:
	return true


## Moves and anchors the bubble relative to the given control node. Check out [member at], [member margin], and
## [member offset_vector] for details on the parameters.
func move_and_anchor(
	control: Control, at := At.CENTER, margin := 16.0, offset_vector := Vector2.ZERO
) -> void:
	self.control = control
	self.at = at
	self.margin = margin
	self.offset_vector = offset_vector


## Sets the avatar location at the top of the bubble. Check [member avatar_at] for details on the parameter.
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

	const TWEEN_DURATION_AVATAR := 0.15

	if not avatar.position.is_equal_approx(new_avatar_position):
		if avatar_tween_position != null:
			avatar_tween_position.kill()
		avatar_tween_position = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		avatar_tween_position.tween_property(
			avatar, "position", new_avatar_position, TWEEN_DURATION_AVATAR
		)

	if not avatar.position.is_equal_approx(new_avatar_position):
		if avatar_tween_rotation != null:
			avatar_tween_rotation.kill()
		avatar_tween_rotation = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		avatar_tween_rotation.tween_property(
			avatar, "rotation_degrees", new_avatar_rotation, TWEEN_DURATION_AVATAR
		)


## Refreshes the position and size of the bubble and its avatar as necessary.
## Connected to the [member minimum_size_changed] signal of the [member panel].
func refresh() -> void:
	if control == null:
		return

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
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(panel, "global_position", new_global_position, TWEEN_DURATION)
	set_avatar_at(avatar_at)


## Updates the locale of any key for the nodes given as keys in the [code]locales[/code] parameter.
##
## [codeblock]
## # `locales` schema:
## locales = {
##     node1: { prop1 = "text1", ...},
##     ...
## }
## [/codeblock]
##
## See ["addons/godot_tours/bubble/default_bubble.gd"] [code]setup[/code] function for an example usage.
func update_locale(locales: Dictionary) -> void:
	for node in locales:
		var dict: Dictionary = locales[node]
		for key in dict:
			node.set(key, translation_service.get_bubble_message(dict[key]))
