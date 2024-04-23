## Functions to process UI Theme properties. In particular, provides functions to scale theme values with the editor scale.
@tool

const FALLBACK_FONT_LANGUAGES := ["ja"]
const FALLBACK_FONT_FMT := "res://addons/godot_tours/assets/fonts/fallback/noto_sans%s_%s.ttf"
const FALLBACK_FONT_MAP := {
	"bold_font": "bold",
	"italics_font": "italic",
	"mono_font": "mono",
	"normal_font": "regular",
	"font": "regular"
}


## Gets and scales the font_size theme override of the input text_node using the editor scale.
## Adds a font size override to text_node directly.
static func scale_font_size(text_node: Control) -> void:
	var editor_scale := EditorInterface.get_editor_scale()
	var title_font_size: int = text_node.get_theme_font_size("font_size")
	text_node.add_theme_font_size_override("font_size", title_font_size * editor_scale)


## Gets and scales the margins of the input margin_container using the editor scale.
## Adds a theme constant override for each margin property directly.
static func scale_margin_container_margins(margin_container: MarginContainer) -> void:
	var editor_scale := EditorInterface.get_editor_scale()
	for property in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		var margin: int = margin_container.get_theme_constant(property)
		margin_container.add_theme_constant_override(property, margin * editor_scale)


## Returns a new theme object, a deep copy of theme_resource, with properties scaled
## using the editor scale.
## Making a deep copy ensures values don't get scaled and saved when working on an addon's
## user interface.
static func generate_scaled_theme(theme_resource: Theme) -> Theme:
	var new_theme = theme_resource.duplicate(true)
	var editor_scale := EditorInterface.get_editor_scale()

	# Scale font sizes
	# We take two measures into account when scaling the interface. Users may have changed their
	# editor scale, but they can also change the main font size without changing the editor scale.
	# If they changed the main font size, we increase the size of every font accordingly.
	var editor_settings := EditorInterface.get_editor_settings()
	var main_font_size := editor_settings.get_setting("interface/editor/main_font_size")
	var base_font_size := max(new_theme.default_font_size, main_font_size)
	var size_difference: int = max(main_font_size - new_theme.default_font_size, 0)

	new_theme.default_font_size = base_font_size * editor_scale
	var theme_types := Array(new_theme.get_font_size_type_list()) + ["TitleLabel"]
	for theme_type in theme_types:
		for font_size_property in new_theme.get_font_size_list(theme_type):
			var font_size: int = (
				new_theme.get_font_size(font_size_property, theme_type) + size_difference
			)
			var new_font_size: int = font_size * editor_scale
			new_theme.set_font_size(font_size_property, theme_type, new_font_size)

	# Scale margins
	for theme_type in new_theme.get_constant_type_list():
		for constant in new_theme.get_constant_list(theme_type):
			var constant_value: int = new_theme.get_constant(constant, theme_type)
			var new_value: int = constant_value * editor_scale
			new_theme.set_constant(theme_type, constant, new_value)

	for stylebox_type in new_theme.get_stylebox_type_list():
		for stylebox_name in new_theme.get_stylebox_list(stylebox_type):
			var stylebox: StyleBox = new_theme.get_stylebox(stylebox_name, stylebox_type)
			if stylebox is StyleBoxFlat:
				stylebox.border_width_bottom *= editor_scale
				stylebox.border_width_left *= editor_scale
				stylebox.border_width_right *= editor_scale
				stylebox.border_width_top *= editor_scale

				stylebox.corner_radius_bottom_left *= editor_scale
				stylebox.corner_radius_bottom_right *= editor_scale
				stylebox.corner_radius_top_left *= editor_scale
				stylebox.corner_radius_top_right *= editor_scale

				stylebox.shadow_offset *= editor_scale
				stylebox.shadow_size *= editor_scale

				stylebox.content_margin_left *= editor_scale
				stylebox.content_margin_right *= editor_scale
				stylebox.content_margin_top *= editor_scale
				stylebox.content_margin_bottom *= editor_scale

	return new_theme


static func request_fallback_font(theme: Theme) -> Theme:
	var settings := EditorInterface.get_editor_settings()
	var language: String = settings.get("interface/editor/editor_language")
	if not language in FALLBACK_FONT_LANGUAGES:
		return theme

	language = "_%s" % language
	var result := theme.duplicate()
	result.default_font = load(FALLBACK_FONT_FMT % [language, "regular"])
	for type in result.get_font_type_list():
		for font: String in result.get_font_list(type):
			if result.has_font(font, type):
				var font_file_path: String = FALLBACK_FONT_FMT % [language, FALLBACK_FONT_MAP[font]]
				prints(font, font_file_path, FileAccess.file_exists(font_file_path))
				if FileAccess.file_exists(font_file_path):
					result.set_font(font, type, load(font_file_path))
	return result
