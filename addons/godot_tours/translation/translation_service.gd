const Utils := preload("../utils.gd")

const LOCALE_DIR := "locale"
const UI_DIR := "ui"
const UI_KEY := "ui"

var tour_key := ""
var locale := ""
var translations := {}
var translation_remaps := {}


func _init(tour_paths: Array[String], editor_settings: EditorSettings) -> void:
	locale = editor_settings.get_setting("interface/editor/editor_language")
	load_translations(tour_paths)
	update_translation_remaps()


func get_message(key: StringName, src_message: StringName, context: StringName = "") -> String:
	var result := ""
	if has_translation(key):
		result = translations[key][locale].get_message(src_message, context)
	return src_message if result.is_empty() else result


func get_plural_message(
	key: StringName,
	src_message: StringName,
	src_plural_message: StringName,
	n: int,
	context: StringName = ""
) -> String:
	var result := ""
	if has_translation(key):
		result = translations[key][locale].get_plural_message(
			src_message, src_plural_message, n, context
		)
	return src_message if n == 1 else src_plural_message if result.is_empty() else result


func get_tour_message(src_message: StringName, context: StringName = "") -> String:
	return get_message(tour_key, src_message, context)


func get_tour_plural_message(
	src_message: StringName, src_plural_message: StringName, n: int, context: StringName = ""
) -> String:
	return get_plural_message(tour_key, src_message, src_plural_message, n, context)


func get_ui_message(src_message: StringName, context: StringName = "") -> String:
	return get_message(UI_KEY, src_message, context)


func get_resource_path(path: String) -> String:
	var suffix := ":%s" % locale
	var filtered := Array(translation_remaps.get(path, [])).filter(
		func(p: String) -> bool: return p.ends_with(suffix)
	)
	if not filtered.is_empty():
		return filtered.pop_front().trim_suffix(suffix)
	return path


func load_translations(tours_path: Array[String]) -> void:
	translations.clear()
	var locale_dir_path: String = (
		get_script()
		. resource_path
		. get_base_dir()
		. get_base_dir()
		. path_join(UI_DIR)
		. path_join(LOCALE_DIR)
	)
	load_translations_dir(locale_dir_path)

	for tour_path in tours_path:
		locale_dir_path = tour_path.get_base_dir().path_join(LOCALE_DIR)
		load_translations_dir(locale_dir_path)


func load_translations_dir(locale_dir_path: String) -> void:
	const EXTENSIONS := ["mo", "po"]
	if DirAccess.dir_exists_absolute(locale_dir_path):
		var key := locale_dir_path.trim_suffix(LOCALE_DIR).get_base_dir().get_file()
		if not key in translations:
			translations[key] = {}

		for locale_file in DirAccess.get_files_at(locale_dir_path):
			if locale_file.get_extension() in EXTENSIONS:
				var locale_file_path := locale_dir_path.path_join(locale_file)
				var locale := locale_file.get_basename()
				if not locale in translations:
					translations[key][locale] = load(locale_file_path)


func has_translation(key: StringName) -> bool:
	return key in translations and locale in translations[key]


func update_translation_remaps() -> void:
	translation_remaps.clear()
	var remaps := ProjectSettings.get_setting("internationalization/locale/translation_remaps")
	if not remaps.is_empty():
		translation_remaps = remaps.duplicate()


func update_tour_key(tour_path: String) -> void:
	tour_key = tour_path.trim_suffix(LOCALE_DIR).get_base_dir().get_file()
