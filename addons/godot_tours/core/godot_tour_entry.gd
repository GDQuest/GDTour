extends Resource

## The title of the tour, displayed in the welcome menu to select tours upon opening Godot.
@export var title := ""
## If true, the tour is free to play.
@export var is_free := false
## If true, the tour is locked and can't be played from the welcome menu.
@export var is_locked := false

## The path to the tour's GDScript file.
@export_file("*.gd") var tour_path := ""
