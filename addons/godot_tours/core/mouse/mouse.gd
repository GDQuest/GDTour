## Animated mouse cursor for the tutorial.
## Moves to a desired point to indicate where to click or where to drag and drop something.
## Call functions add_*_operation() to queue animations, then call play() to run the animations.
## See tour.gd for utility functions that simplify usage of the mouse cursor.
@tool
extends CanvasGroup

var first_from := Callable()
var operations: Array[Callable] = []
@onready var pointer_sprite: Sprite2D = %PointerSprite2D
@onready var press_sprite: Sprite2D = %PressSprite2D
@onready var tween := create_tween()


func _ready() -> void:
	tween.kill()


func play() -> void:
	if operations.is_empty() or first_from.is_null():
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
	if first_from.is_null():
		first_from = from
	const SPEED := 400
	operations.push_back(func() -> void:
		tween.tween_method(
			func(param: float) -> void:
				global_position = from.call().lerp(to.call(), param),
			0.0,
			1.0,
			from.call().distance_to(to.call()) / SPEED
		)
	)


func add_press_operation() -> void:
	const ON_DURATION := 0.2
	operations.push_back(func() -> void:
		tween.tween_property(press_sprite, "scale", Vector2.ONE, ON_DURATION).from(Vector2.ZERO)
	)


func add_release_operation() -> void:
	const OFF_DURATION := 0.1
	operations.push_back(func() -> void:
		tween.tween_property(press_sprite, "scale", Vector2.ZERO, OFF_DURATION).from(Vector2.ONE)
	)


func add_click_operation() -> void:
	const ON_DURATION := 0.2
	const OFF_DURATION := 0.1
	operations.push_back(func() -> void:
		tween.tween_property(press_sprite, "scale", Vector2.ONE, ON_DURATION).from(Vector2.ZERO)
		tween.tween_property(press_sprite, "scale", Vector2.ZERO, OFF_DURATION)
	)
