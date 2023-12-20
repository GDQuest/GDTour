@tool
extends Button

const ThemeUtils = preload("res://addons/godot_tours/theme_utils.gd")

func setup() -> void:
	var _theme_utils := ThemeUtils.new()
	theme = _theme_utils.generate_scaled_theme(theme)
	_theme_utils.scale_font_size(self)
