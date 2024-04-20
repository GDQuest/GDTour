@tool
extends Node3D

## Changes the size of the guide box.
var size := Vector3.ONE: set = set_size
## Offsets the child box mesh relative to this node.
var box_offset := Vector3.ZERO: set = set_box_offset
## Changes the transparency of the guide box.
var alpha := 0.4: set = set_alpha

@onready var mesh_instance_3d: MeshInstance3D = %MeshInstance3D


func _ready() -> void:
	set_size(size)
	set_box_offset(box_offset)
	set_alpha(alpha)


## Returns the axis-aligned bounding box of the guide box.
func get_aabb() -> AABB:
	if mesh_instance_3d == null:
		return AABB()
	return mesh_instance_3d.mesh.get_aabb()


func set_size(new_size: Vector3) -> void:
	size = new_size
	if mesh_instance_3d == null:
		return
	mesh_instance_3d.mesh.size = size


func set_box_offset(new_offset: Vector3) -> void:
	box_offset = new_offset
	if mesh_instance_3d == null:
		return
	mesh_instance_3d.position = box_offset


func set_alpha(new_alpha: float) -> void:
	alpha = clamp(new_alpha, 0.0, 1.0)
	if mesh_instance_3d == null:
		return
	mesh_instance_3d.mesh.material.albedo_color.a = alpha
