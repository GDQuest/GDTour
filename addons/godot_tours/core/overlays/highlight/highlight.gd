## Highlights are used to show the user where to click.
## They carve into the dimmer mask ColorRect and display an outline around the clickable area.
## They can optionally play a flash animation to draw attention to a specific area of the editor.
@tool
extends Panel

const Dimmer := preload("../dimmer/dimmer.gd")

var rect_getters: Array[Callable] = []
var dimmer_mask: ColorRect = null
var control: Control = null

@onready var flash_area: ColorRect = %FlashArea


func setup(control: Control, rect_getter: Callable, dimmer: Dimmer, stylebox: StyleBoxFlat) -> void:
	self.control = control
	self.dimmer_mask = dimmer.add_mask()
	self.rect_getters.push_back(rect_getter)
	refresh.call_deferred()
	remove_theme_stylebox_override("panel")
	add_theme_stylebox_override("panel", stylebox)


func _exit_tree() -> void:
	if dimmer_mask != null:
		dimmer_mask.queue_free()


func flash() -> void:
	flash_area.visible = true


func refresh() -> void:
	var rect := Rect2()
	for index in range(rect_getters.size()):
		var new_rect := rect_getters[index].call()
		if not new_rect.position.is_zero_approx() and not new_rect.size.is_zero_approx():
			rect = (
				new_rect
				if rect.position.is_zero_approx() and rect.size.is_zero_approx()
				else rect.merge(new_rect)
			)
	global_position = rect.position
	custom_minimum_size = rect.size
	visible = rect != Rect2() and control.is_visible_in_tree()
	dimmer_mask.global_position = global_position
	dimmer_mask.size = custom_minimum_size
	dimmer_mask.visible = visible
	reset_size.call_deferred()


func refresh_tabs(_index: int) -> void:
	refresh()
