@tool
extends EditorTranslationParserPlugin

const PATTERNS := [
	"""gtr\\(\\s*['"]+(.*?)['"]+\\s*(?:,\\s*['"]+(.*?)['"]+\\s*)?\\)""",
	"""gtr_n\\(\\s*['"]+(.*?)['"]+\\s*,\\s*['"]+(.*?)['"]+\\s*,\\s*(?:\\d+)\\s*(?:,\\s*['"]+(.*?)['"]+\\s*)?\\)""",
]

var regex := RegEx.new()


func _parse_file(path: String, msgids: Array[String], msgids_context_plural: Array[Array]) -> void:
	var source_code: String = load(path).source_code
	for pattern in PATTERNS:
		regex.compile(pattern)
		for regex_match in regex.search_all(source_code):
			var singular := regex_match.strings[1].replace("\\","")
			var context := regex_match.strings[2]
			var plural := ""
			if regex_match.get_group_count() > 2:
				plural = regex_match.strings[2]
				context = regex_match.strings[3]
			msgids_context_plural.push_back([singular, context, plural])


func _get_recognized_extensions() -> PackedStringArray:
	return ["gd"]
