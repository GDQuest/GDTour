@tool
extends Button

const ThemeUtils = preload("theme_utils.gd")


func setup() -> void:
	theme = ThemeUtils.generate_scaled_theme(theme)
	ThemeUtils.scale_font_size(self)
