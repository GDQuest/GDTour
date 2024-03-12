@tool
extends PanelContainer

signal status_changed

enum Status { DONE, NOT_DONE, ERROR }

const COLOR_BLUE := Color("4e719d")
const COLOR_GREEN := Color("4bff2e")
const COLOR_ORANGE := Color("ff8a00")

var status := Status.NOT_DONE:
	set(value):
		if value == status:
			return
		status = value

		checkmark.visible = status != Status.ERROR
		exclamation_mark.visible = status == Status.ERROR
		if status == Status.DONE:
			_panel_stylebox.bg_color = COLOR_GREEN
			checkmark.modulate.a = 1.0
		elif status == Status.NOT_DONE:
			_panel_stylebox.bg_color = COLOR_BLUE
			checkmark.modulate.a = 0.5
		elif status == Status.ERROR:
			_panel_stylebox.bg_color = COLOR_ORANGE
		status_changed.emit()

var description := "":
	set(value):
		description_rich_text_label.text = value

var error := "":
	set(value):
		error_label.text = value
		error_label.visible = not value.is_empty()

var repeat: int = 1:
	set(value):
		repeat = max(1, value)
		repeat_label.visible = repeat != 1
		repeat_label.text = "0 / %d" % [repeat]

var repeat_callable := Callable()
var error_predicate := Callable()

var _panel_stylebox: StyleBoxFlat = null

@onready var checkbox: Panel = %Checkbox
@onready var checkmark: TextureRect = %Checkmark
@onready var exclamation_mark: TextureRect = %ExclamationMark

@onready var description_rich_text_label: RichTextLabel = %DescriptionRichTextLabel
@onready var repeat_label: Label = %RepeatLabel
@onready var error_label: Label = %ErrorLabel


func setup(
	description: String, repeat: int, repeat_callable: Callable, error_predicate: Callable
) -> void:
	self.description = description
	self.repeat = repeat
	self.repeat_callable = repeat_callable
	self.error_predicate = error_predicate

	# We duplicate the stylebox on each task entry to change its color independently.
	_panel_stylebox = get_theme_stylebox("panel", "TaskCheckboxPanel")
	if _panel_stylebox == null:
		printerr(
			"Could not get task checkbox panel stylebox. Task scene instance will not render properly."
		)
	else:
		_panel_stylebox = _panel_stylebox.duplicate()
		checkbox.add_theme_stylebox_override("panel", _panel_stylebox)

	if Engine.is_editor_hint():
		checkbox.custom_minimum_size *= EditorInterface.get_editor_scale()


# The `button.button_pressed` state isn't properly set when the button isn't a toggle button.
# We can't reliably check in the `repeat_callable` if `button.button_pressed` is true unless
# we connect `button.pressed` signal to this hack function.
func _on_button_pressed_hack(button: BaseButton) -> void:
	if button.toggle_mode:
		return

	# Toggle mode hack so we can check `button.button_pressed` in task `_process()`
	if not button.button_pressed:
		button.toggle_mode = true
		button.set_pressed_no_signal(true)
		await get_tree().process_frame
		await get_tree().process_frame
		button.toggle_mode = false


func _process(_delta: float) -> void:
	if repeat_callable.is_null() or error_predicate.is_null():
		return

	var current_repeat := repeat_callable.call(self)
	status = (
		Status.ERROR
		if error_predicate.call(self)
		else (Status.DONE if current_repeat == repeat else Status.NOT_DONE)
	)
	if status == Status.ERROR:
		repeat_label.text = "? / %d" % [repeat]
	else:
		repeat_label.text = "%d / %d" % [current_repeat, repeat]


func is_done() -> bool:
	return status == Status.DONE
