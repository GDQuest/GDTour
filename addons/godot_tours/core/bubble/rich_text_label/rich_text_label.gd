@tool
extends RichTextLabel


func _ready() -> void:
	meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
	meta_hover_started.connect(func(_meta: Variant) -> void: Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	meta_hover_ended.connect(func(_meta: Variant) -> void: Input.set_default_cursor_shape(Input.CURSOR_ARROW))
