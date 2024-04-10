extends Node

var reset_net_y_global_position := -10.0


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene is Node3D:
		var reset_net := Area3D.new()
		reset_net.area_entered.connect(_on_node_entered)
		reset_net.body_entered.connect(_on_node_entered)

		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = WorldBoundaryShape3D.new()
		reset_net.add_child(collision_shape)
		scene.add_child(reset_net)
		reset_net.global_position.y = reset_net_y_global_position


func _on_node_entered(node: Node3D) -> void:
	if node.has_method("reset"):
		node.reset()
