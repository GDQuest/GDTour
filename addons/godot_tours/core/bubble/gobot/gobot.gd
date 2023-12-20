@tool
extends Node2D

enum Expressions {NEUTRAL, HAPPY, SURPRISED}

@export_range(-1.0, 1.0, 0.1) var tilt_x : float = 0.0 : set = _set_tilt_x
@export_range(-1.0, 1.0, 0.1) var tilt_y : float = 0.0 : set = _set_tilt_y

@export var expression := Expressions.NEUTRAL: set = set_expression
@export var look_at_cursor := false: set = set_look_at_cursor

## Stores the initial scale of the avatar from the scene instance.
@onready var scale_start := scale

@onready var animation_tree: AnimationTree = %AnimationTree
# Character nodes
@onready var eye_r: Node2D = %EyeR
@onready var eye_l: Node2D = %EyeL
@onready var nose: Sprite2D = %Nose
@onready var jaw: Sprite2D = %Jaw
@onready var horns: Sprite2D = %Horns
@onready var bolts: Node2D = %Bolts
@onready var bolt_l: Sprite2D = %BoltL
@onready var bolt_r: Sprite2D = %BoltR


func do_wink() -> void:
	animation_tree.set("parameters/OneShot/request", true)


func set_expression(value: Expressions) -> void:
	expression = value
	if not is_node_ready():
		return
	animation_tree.set("parameters/Transition/transition_request", Expressions.find_key(expression).to_lower())


func set_look_at_cursor(state: bool) -> void:
	if look_at_cursor == state or not is_node_ready():
		return
	look_at_cursor = state
	animation_tree.active = not state
	animation_tree.set("parameters/AddTilt/add_amount", float(animation_tree.active))


func _set_tilt_x(value: float) -> void:
	if not is_node_ready() or tilt_x == value:
		return

	tilt_x = value
	eye_l.scale.x = remap(clamp(tilt_x, -1.0, 0.0), -1.0, 0.0, 0.75, 1.0)
	eye_r.scale.x = remap(clamp(tilt_x, 0.0, 1.0), 0.0, 1.0, 1.0, 0.75)
	horns.scale.x = remap(clamp(abs(tilt_x), 0.0, 1.0), 1.0, 0.0, 0.96, 1.0)
	bolts.scale.x = remap(clamp(abs(tilt_x), 0.0, 1.0), 1.0, 0.0, 0.96, 1.0)

	eye_l.position.x = tilt_x * 16.0
	eye_r.position.x = tilt_x * 16.0
	nose.position.x = tilt_x * 24.0
	jaw.position.x = tilt_x * 20.0
	horns.position.x = -tilt_x * 8.0
	bolts.position.x = -tilt_x * 8.0


func _set_tilt_y(value: float) -> void:
	if not is_node_ready() or tilt_y == value:
		return

	tilt_y = value
	eye_l.scale.y = remap(clamp(abs(tilt_y), 0.0, 1.0), 1.0, 0.0, 0.9, 1.0)
	eye_r.scale.y = eye_l.scale.y
	horns.scale.y = remap(clamp(abs(tilt_y), 0.0, 1.0), 1.0, 0.0, 0.98, 1.0)

	eye_l.position.y = tilt_y * 8.0
	eye_r.position.y = tilt_y * 8.0
	nose.position.y = tilt_y * 8.0
	jaw.position.y = tilt_y * 8.0
	horns.position.y = -tilt_y * 4.0


func _process(_delta: float) -> void:
	if look_at_cursor:
		var vector = get_global_mouse_position() - global_position
		var angle = vector.angle()
		var distance = vector.length()
		var direction = Vector2.from_angle(angle) * (clamp(distance, 0.0, 200.0) / 200.0)
		tilt_x = direction.x
		tilt_y = direction.y
