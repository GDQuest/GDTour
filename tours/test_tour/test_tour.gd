extends "res://addons/godot_tours/core/tour.gd"


func _build() -> void:
	scene_open("res://tours/test_tour/test_tour.tscn")
	bubble_add_text(["Test text"])
	highlight_scene_nodes_by_name(["TestTour"])
	queue_command(func() -> void:
		assert(not overlays.ensure_get_dimmer_for(interface.base_control).get_child_count() == 1, "One highlight")
		var scene_root := EditorInterface.get_edited_scene_root()
		assert(scene_root is Node2D and scene_root.name == "TestTour", "Correct scene tree")
		assert(is_instance_valid(bubble), "Valid bubble")
	)
	auto_next()
	complete_step()
