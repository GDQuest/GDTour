## Animated mouse cursor for the tutorial.
## Moves to a desired point to indicate where to click or where to drag and drop something.
## Call functions add_*_operation() to queue animations, then call play() to run the animations.
## See tour.gd for utility functions that simplify usage of the mouse cursor.
@tool
extends CanvasGroup

const DEFAULT_PRESS_TEXTURE := preload("../assets/icons/white_circle.png")

var first_from := Callable()
var last_to := Callable()
var operations: Array[Callable] = []
var editor_scale: float = EditorInterface.get_editor_scale()

@onready var pointer_sprite: Sprite2D = %PointerSprite2D
@onready var press_sprite: Sprite2D = %PressSprite2D
@onready var tween := create_tween()


func _ready() -> void:
	scale *= editor_scale
	tween.kill()


func play() -> void:
	if operations.is_empty() or (first_from.is_null() and last_to.is_null()):
		return
	const ON_DURATION := 0.2
	const OFF_DURATION := 0.1
	const WAIT := 0.6

	tween.kill()
	tween = create_tween().set_loops().set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: global_position = first_from.call())
	tween.tween_property(self, "modulate:a", 1.0, ON_DURATION)
	for operation in operations:
		operation.call()
	tween.tween_interval(WAIT)
	tween.tween_property(self, "modulate:a", 0.0, OFF_DURATION)


func add_move_operation(from: Callable, to: Callable) -> void:
	last_to = to
	if first_from.is_null():
		first_from = from

	var speed := 400 * editor_scale
	operations.push_back(func() -> void:
		tween.tween_method(
			func(param: float) -> void:
				global_position = from.call().lerp(to.call(), param),
			0.0,
			1.0,
			from.call().distance_to(to.call()) / speed
		)
	)


func add_press_operation(texture: CompressedTexture2D = null) -> void:
	if texture == null:
		texture = DEFAULT_PRESS_TEXTURE

	const ON_DURATION := 0.2

	operations.push_back(func() -> void:
		press_sprite.texture = texture
		tween.tween_property(press_sprite, "scale", Vector2.ONE, ON_DURATION).from(Vector2.ZERO)
	)


func add_release_operation() -> void:
	const OFF_DURATION := 0.1
	operations.push_back(func() -> void:
		tween.tween_property(press_sprite, "scale", Vector2.ZERO, OFF_DURATION).from(Vector2.ONE)
	)


func add_click_operation(loops := 1) -> void:
	const ON_DURATION := 0.2
	const OFF_DURATION := 0.1
	for _loop in range(loops):
		operations.push_back(func() -> void:
			tween.tween_property(press_sprite, "scale", Vector2.ONE, ON_DURATION).from(Vector2.ZERO)
			tween.tween_property(press_sprite, "scale", Vector2.ZERO, OFF_DURATION)
		)


func add_bounce_operation(loops := 2, at := Callable()) -> void:
	if not at.is_null():
		last_to = at

	if first_from.is_null():
		first_from = at

	const WAIT := 0.3

	const SCALE_Y := 0.7
	const SCALE_DURATION := 0.1

	const UP_DURATION := 0.25
	const DOWN_DURATION := 0.4
	var amplitude := 30 * Vector2.UP * editor_scale

	for _loop in range(loops):
		operations.push_back(func() -> void:
			tween.tween_property(pointer_sprite, "scale:y", SCALE_Y, SCALE_DURATION).from(1.0).set_delay(WAIT)
			tween.tween_property(pointer_sprite, "scale:y", 1.0, SCALE_DURATION).from(SCALE_Y)
			tween.parallel().tween_method(
				func(param: float) -> void:
					var at_vector: Vector2 = last_to.call()
					global_position = at_vector.lerp(at_vector + amplitude, param),
				0.0,
				1.0,
				UP_DURATION,
			).set_trans(Tween.TRANS_SINE)
			tween.tween_method(
				func(param: float) -> void:
					var at_vector: Vector2 = last_to.call()
					global_position = (at_vector + amplitude).lerp(at_vector, param),
				0.0,
				1.0,
				DOWN_DURATION,
			).set_trans(Tween.TRANS_BOUNCE)
	)
