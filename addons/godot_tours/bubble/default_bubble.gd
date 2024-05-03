## Text bubble used to display instructions to the user.
@tool
extends "bubble.gd"

const Utils := preload("../utils.gd")

const CodeEditPackedScene := preload("code_edit.tscn")
const TextureRectPackedScene := preload("texture_rect.tscn")
const VideoStreamPlayerPackedScene := preload("video_stream_player.tscn")
const RichTextLabelPackedScene := preload("rich_text_label/rich_text_label.tscn")

const CLASS_IMG := r"[img=%dx%d]res://addons/godot_tours/bubble/assets/icons/$1.svg[/img] [b]$1[/b]"

## Separation between paragraphs of text and elements in the main content in pixels.
@export var paragraph_separation := 12:
	set(new_value):
		paragraph_separation = new_value
		if main_v_box_container == null:
			await ready
		main_v_box_container.add_theme_constant_override("separation", paragraph_separation)

var img_size := 24 * EditorInterface.get_editor_scale()
var regex_class := RegEx.new()

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

@onready var view_content: VBoxContainer = %ViewContent
@onready var view_close: VBoxContainer = %ViewClose
@onready var button_close: Button = %ButtonClose
@onready var button_close_no: Button = %ButtonCloseNo
@onready var button_close_yes: Button = %ButtonCloseYes

@onready var step_count_label: Label = %StepCountLabel

@onready var label_close_tour: Label = %LabelCloseTour
@onready var label_progress_lost: Label = %LabelProgressLost

func setup(translation_service: TranslationService, step_count: int) -> void:
	super(translation_service, step_count)

	var classes := Array(ClassDB.get_class_list())
	classes.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	regex_class.compile(r"\[b\](%s)\[\/b\]" % "|".join(classes))

	update_step_count_display(0)
	Utils.update_locale(translation_service, {
		back_button: {text = "BACK"},
		next_button: {text = "NEXT STEP"},
		finish_button: {text = "END TOUR AND CONTINUE LEARNING"},
		button_close_no: {text = "NO"},
		button_close_yes: {text = "YES"},
		label_close_tour: {text = "Close the tour?"},
		label_progress_lost: {text = "Your progress will be lost."},
	})


func _ready() -> void:
	super()
	if not Engine.is_editor_hint() or EditorInterface.get_edited_scene_root() == self:
		return

	# Clear tasks etc. in case we have some for testing in the scene.
	clear_elements_and_tasks()

	back_button.pressed.connect(func() -> void: back_button_pressed.emit())
	next_button.pressed.connect(func() -> void: next_button_pressed.emit())
	button_close.pressed.connect(func() -> void:
		view_content.hide()
		view_close.show()
	)
	button_close_no.pressed.connect(func() -> void:
		view_content.show()
		view_close.hide()
	)
	button_close_yes.pressed.connect(func() -> void: close_requested.emit())
	finish_button.pressed.connect(func() -> void: finish_requested.emit())
	for node in [header_rich_text_label, main_v_box_container, tasks_v_box_container, footer_rich_text_label, footer_spacer]:
		node.visible = false

	var editor_scale := EditorInterface.get_editor_scale()
	button_close.custom_minimum_size *= editor_scale
	paragraph_separation *= editor_scale


func on_tour_step_changed(index: int) -> void:
	super(index)
	back_button.visible = true
	finish_button.visible = false
	if index == 0:
		back_button.visible = false
		next_button.visible = tasks_v_box_container.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size() == 0
		next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	elif index == step_count - 1:
		next_button.visible = false
		finish_button.visible = true
	else:
		back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		next_button.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	update_step_count_display(index)


func clear() -> void:
	next_button.visible = true
	set_header("")
	set_footer("")
	set_background(null)
	clear_elements_and_tasks()


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
		element.texture = data.texture
		if "max_height" in data:
			element.max_height = data.max_height
	elif element is VideoStreamPlayer:
		element.stream = data
		element.finished.connect(element.play)
		element.play()
		var texture: Texture2D = element.get_video_texture()
		element.custom_minimum_size.x = main_v_box_container.size.x
		element.custom_minimum_size.y = element.custom_minimum_size.x * texture.get_height() / texture.get_width()


func set_title(title_text: String) -> void:
	title_label.text = title_text


func add_text(text: Array[String]) -> void:
	for line in text:
		line = regex_class.sub(line, CLASS_IMG % [img_size, img_size], true)
		add_element(RichTextLabelPackedScene.instantiate(), line)


func add_code(code: Array[String]) -> void:
	for snippet in code:
		add_element(CodeEditPackedScene.instantiate(), snippet)


func add_texture(texture: Texture2D, max_height := 0.0) -> void:
	if texture == null:
		return
	var texture_rect := TextureRectPackedScene.instantiate()
	var data := {"texture": texture}
	if max_height > 0.0:
		data["max_height"] = max_height
	add_element(texture_rect, data)


func add_video(stream: VideoStream) -> void:
	if stream == null or not stream is VideoStream:
		return
	add_element(VideoStreamPlayerPackedScene.instantiate(), stream)


func add_task(description: String, repeat: int, repeat_callable: Callable, error_predicate: Callable) -> void:
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


func check_tasks() -> bool:
	var are_tasks_done := tasks_v_box_container.get_children().all(func(task: Task) -> bool: return task.is_done() and not task.is_queued_for_deletion())
	next_button.visible = are_tasks_done
	if are_tasks_done:
		avatar.do_wink()
	return are_tasks_done


func update_step_count_display(current_step_index: int) -> void:
	step_count_label.text = "%s/%s" % [current_step_index, step_count - 2]
	step_count_label.visible = current_step_index != 0 and current_step_index != step_count - 1


func _add_debug_shortcuts() -> void:
	next_button.shortcut = load("res://addons/godot_tours/bubble/shortcut_debug_button_next.tres")
	back_button.shortcut = load("res://addons/godot_tours/bubble/shortcut_debug_button_back.tres")
	button_close_yes.shortcut = load("res://addons/godot_tours/bubble/shortcut_debug_button_close.tres")


## [b]Virtual[/b] method to change the text of the next button.
func set_finish_button_text(text: String) -> void:
	finish_button.text = text
