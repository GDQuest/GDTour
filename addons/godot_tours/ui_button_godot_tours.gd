@tool
extends Button

const ThemeUtils = preload("res://addons/godot_tours/theme_utils.gd")


func setup() -> void:
	theme = ThemeUtils.generate_scaled_theme(theme)
	ThemeUtils.scale_font_size(self)
