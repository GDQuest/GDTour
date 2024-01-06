## Text bubble used to display instructions to the user.
@tool
extends CanvasLayer

## Emitted when the user confirms wanting to quit the tour
signal close_requested

const Task := preload("task/task.gd")
const EditorInterfaceAccess := preload("../editor_interface_access.gd")
const TranslationService := preload("../translation/translation_service.gd")
const Debugger := preload("../debugger/debugger.gd")

const RichTextLabelPackedScene := preload("rich_text_label/rich_text_label.tscn")
const CodeEditPackedScene := preload("code_edit.tscn")
const TextureRectPackedScene := preload("texture_rect.tscn")
const VideoStreamPlayerPackedScene := preload("video_stream_player.tscn")

const ThemeUtils := preload("res://addons/godot_tours/theme_utils.gd")

# We don't preload to avoid errors on a project's first import, to distribute the tour to schools
# for example.
static var TaskPackedScene: PackedScene = null

const TWEEN_DURATION := 0.1
const LOCALES := {
	PrevButton = {text = "BACK"},
	NextButton = {text = "NEXT STEP"},
}

## Location to place and anchor the bubble relative to a given Control node. Used in the function `move_and_anchor()` and by the `at` variable.
enum At {TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT, CENTER_LEFT, TOP_CENTER, BOTTOM_CENTER, CENTER_RIGHT, CENTER}
## Location of the Gobot avatar along the top edge of the bubble.
enum AvatarAt {LEFT, CENTER, RIGHT}

## Separation between paragraphs of text and elements in the main content in pixels.
@export var paragraph_separation := 12:
	set(new_value):
		paragraph_separation = new_value
		if main_v_box_container == null:
			await ready
		main_v_box_container.add_theme_constant_override("separation", paragraph_separation)

var at := At.CENTER
var avatar_at := AvatarAt.LEFT
var margin := 16.0
var offset_vector := Vector2.ZERO
var control: Control = null
var interface: EditorInterfaceAccess = null
var translation_service: TranslationService = null

@onready var panel_container: PanelContainer = %PanelContainer
@onready var background_texture_rect: TextureRect = %BackgroundTextureRect
@onready var title_label: Label = %TitleLabel
@onready var header_rich_text_label: RichTextLabel = %HeaderRichTextLabel
@onready var footer_rich_text_label: RichTextLabel = %FooterRichTextLabel
@onready var footer_spacer: Control = %FooterSpacer
@onready var main_v_box_container: VBoxContainer = %MainVBoxContainer
@onready var tasks_v_box_container: VBoxContainer = %TasksVBoxContainer
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var finish_button: Button = %FinishButton

@onready var avatar: Node2D = %Avatar
@onready var tween: Tween = null
@onready var avatar_tween_position: Tween = null
@onready var avatar_tween_rotation: Tween = null
@onready var locale_nodes: Array[Node] = [back_button, next_button]

@onready var view_content: VBoxContainer = %ViewContent
@onready var view_close: VBoxContainer = %ViewClose
@onready var button_close: Button = %ButtonClose
@onready var button_close_no: Button = %ButtonCloseNo
@onready var button_close_yes: Button = %ButtonCloseYes

@onready var step_count_label: Label = %StepCountLabel

var _step_count := 0
## Position offset applied to the avatar when anchored on the left of the bubble.


func setup(interface: EditorInterfaceAccess, translation_service: TranslationService) -> void:
	self.interface = interface
	self.translation_service = translation_service

	# Add itself as a child of the editor interface. Done after scaling to avoid UI refreshes with
	# every theme property change.
	control = interface.base_control
	control.add_child(self)

	var editor_scale := EditorInterface.get_editor_scale()
	paragraph_separation *= editor_scale

	var _theme_utils := ThemeUtils.new()
	panel_container.theme = _theme_utils.generate_scaled_theme(panel_container.theme)

	avatar.scale = avatar.scale_start * editor_scale
	panel_container.custom_minimum_size *= editor_scale

	refresh.call_deferred()
	update_locale()
	hide()
	await get_tree().physics_frame
	button_close.custom_minimum_size *= editor_scale
	show()


func set_step_count(step_count: int) -> void:
	_step_count = step_count
	update_step_count_display(0)


func _ready() -> void:
	if Debugger.CLI_OPTION_DEBUG in OS.get_cmdline_user_args():
		_add_debug_shortcuts()

	button_close.pressed.connect(func():
		view_content.hide()
		view_close.show()
	)
	button_close_no.pressed.connect(func():
		view_content.show()
		view_close.hide()
	)
	button_close_yes.pressed.connect(func():
		close_requested.emit()
	)
	finish_button.pressed.connect(func():
		close_requested.emit()
	)
	for node in [header_rich_text_label, main_v_box_container, tasks_v_box_container, footer_rich_text_label, footer_spacer]:
		node.visible = false


func clear() -> void:
	next_button.visible = true
	set_header("")
	set_footer("")
	set_background(null)
	clear_elements_and_tasks()
	if not get_tree().process_frame.is_connected(refresh):
		get_tree().process_frame.connect(refresh, CONNECT_ONE_SHOT)


func clear_elements_and_tasks() -> void:
	for control in [main_v_box_container, tasks_v_box_container]:
		for node in control.get_children():
			node.queue_free()
		control.visible = false


func add_element(element: Control, data: Variant) -> void:
	main_v_box_container.visible = true
	main_v_box_container.add_child(element)
	if element is RichTextLabel or element is CodeEdit:
		element.text = data
	elif element is TextureRect:
		element.texture = data
	elif element is VideoStreamPlayer:
		element.stream = data
		element.finished.connect(element.play)
		element.play()


func set_title(title_text: String) -> void:
	title_label.text = title_text


func add_text(text: Array[String]) -> void:
	for line in text:
		add_element(RichTextLabelPackedScene.instantiate(), line)


func add_code(code: Array[String]) -> void:
	for snippet in code:
		add_element(CodeEditPackedScene.instantiate(), code)


func add_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	add_element(TextureRectPackedScene.instantiate(), texture)


func add_video(stream: VideoStream) -> void:
	if stream == null or not stream is VideoStream:
		return
	add_element(VideoStreamPlayerPackedScene.instantiate(), stream)


func add_task(description: String, repeat: int, repeat_callable: Callable, error_predicate: Callable) -> void:
	if TaskPackedScene == null:
		TaskPackedScene = load("res://addons/godot_tours/core/bubble/task/task.tscn")

	tasks_v_box_container.visible = true
	var task := TaskPackedScene.instantiate()
	tasks_v_box_container.add_child(task)
	task.status_changed.connect(check_tasks)
	task.setup(description, repeat, repeat_callable, error_predicate)
	check_tasks()


func set_header(text: String) -> void:
	header_rich_text_label.text = text
	header_rich_text_label.visible = not text.is_empty()


func set_footer(text: String) -> void:
	footer_rich_text_label.text = text
	footer_rich_text_label.visible = not text.is_empty()
	footer_spacer.visible = footer_rich_text_label.visible


func set_background(texture: Texture2D) -> void:
	background_texture_rect.texture = texture
	background_texture_rect.visible = texture != null


## Moves and anchors the bubble relative to the given control node.
func move_and_anchor(control: Control, at := At.CENTER, margin := 16.0, offset_vector := Vector2.ZERO) -> void:
	self.control = control
	self.at = at
	self.margin = margin
	self.offset_vector = offset_vector
	refresh.call_deferred()

func set_avatar_at(at := AvatarAt.LEFT) -> void:
	avatar_at = at
	var editor_scale := EditorInterface.get_editor_scale()
	var at_offset := {
		AvatarAt.LEFT: Vector2(-8.0, -6.0) * editor_scale,
		AvatarAt.CENTER: Vector2(panel_container.size.x / 2.0, -8.0 * editor_scale),
		AvatarAt.RIGHT: Vector2(panel_container.size.x + 3.0 * editor_scale, -8.0 * editor_scale),
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
		avatar_tween_position.tween_property(avatar, "position", new_avatar_position, TWEEN_DURATION)

	if not avatar.position.is_equal_approx(new_avatar_position):
		if avatar_tween_rotation != null:
			avatar_tween_rotation.kill()
		avatar_tween_rotation = create_tween().set_ease(Tween.EASE_IN)
		avatar_tween_rotation.tween_property(avatar, "rotation_degrees", new_avatar_rotation, TWEEN_DURATION)


func refresh() -> void:
	if control == null:
		return

	# We delay for one frame because it can take that amount of time for RichTextLabel nodes to update their state.
	# Without this, the bubble can end up being too tall.
	await get_tree().process_frame

	panel_container.reset_size()
	var at_offset := {
		At.TOP_LEFT: margin * Vector2.ONE,
		At.TOP_CENTER: Vector2((control.size.x - panel_container.size.x) / 2.0, 0.0) + margin * Vector2.DOWN,
		At.TOP_RIGHT: Vector2(control.size.x - panel_container.size.x, 0.0) + margin * Vector2(-1.0, 1.0),
		At.BOTTOM_RIGHT: control.size - panel_container.size - margin * Vector2.ONE,
		At.BOTTOM_CENTER: Vector2(0.5, 1.0) * (control.size - panel_container.size) + margin * Vector2.UP,
		At.BOTTOM_LEFT: Vector2(0.0, control.size.y - panel_container.size.y) + margin * Vector2(1.0, -1.0),
		At.CENTER_LEFT: Vector2(0.0, (control.size.y - panel_container.size.y) / 2.0) + margin * Vector2.RIGHT,
		At.CENTER_RIGHT: Vector2(1.0, 0.5) * (control.size - panel_container.size) + margin * Vector2.LEFT,
		At.CENTER: (control.size - panel_container.size) / 2.0,
	}
	var new_global_position: Vector2 = control.global_position + at_offset[at] + offset_vector
	if not panel_container.global_position.is_equal_approx(new_global_position):
		if tween != null:
			tween.kill()
		tween = create_tween().set_ease(Tween.EASE_IN)
		tween.tween_property(panel_container, "global_position", new_global_position, TWEEN_DURATION)
	set_avatar_at(avatar_at)


func check_tasks() -> void:
	var are_tasks_done := tasks_v_box_container.get_children().all(func(task: Task) -> bool: return task.is_done())
	next_button.visible = are_tasks_done
	if are_tasks_done:
		avatar.do_wink()


func update_locale() -> void:
	for node in locale_nodes:
		if node.name in LOCALES:
			var dict: Dictionary = LOCALES[node.name]
			for key in dict:
				node.set(key, translation_service.get_bubble_message(dict[key]))


func update_step_count_display(current_step_index: int) -> void:
	step_count_label.text = "%s/%s" % [current_step_index, _step_count - 2]
	step_count_label.visible = current_step_index != 0 and current_step_index != _step_count - 1


func _add_debug_shortcuts() -> void:
	next_button.shortcut = load("res://addons/godot_tours/core/bubble/shortcut_debug_button_next.tres")
	back_button.shortcut = load("res://addons/godot_tours/core/bubble/shortcut_debug_button_back.tres")
	button_close_yes.shortcut = load("res://addons/godot_tours/core/bubble/shortcut_debug_button_close.tres")
