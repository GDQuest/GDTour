extends SceneTree

const Utils := preload("../gdquest_sparkly_bag/sparkly_bag_utils.gd")

const MD_BUBBLE_TITLE := "##"
const MD_CALL := ">"
const HEADER := """
extends "../../addons/godot_tours/tour.gd"

func _build() -> void:
"""
const CALLS := {
	generic = "\t%s(%s)",
	bubble_move_and_anchor = "\t%s(interface.%s, Bubble.At.%s)",
	bubble_set_title = """\tbubble_set_title(%s)""",
	bubble_add_text = """\tbubble_add_text([%s])""",
	bubble_add_task_press_button = """\t%s(interface.%s)""",
	complete_step = "\tcomplete_step()",
	scene_open = """\t%s("%s")""",
	gtr = """gtr("%s")""",
	note = "\t# %s: %s",
}


func _init() -> void:
	var md_files := Utils.fs_find("*.md", "res://tours", false)
	for md_file_path: String in md_files.result:
		convert_to_test(md_file_path)
	quit()
	return


func convert_to_test(md_file_path: String) -> void:
	var tour_file_path := "%s.gd" % md_file_path.get_basename()
	print_rich(
		"\n[color=blue]Generating[/color] '%s' from '%s'..." % [tour_file_path, md_file_path]
	)
	if FileAccess.file_exists(tour_file_path):
		print_rich("'%s' already exists. [color=yellow]SKIP[/color]..." % tour_file_path)
		return

	var regex_md_bold := RegEx.create_from_string(r"(\*\*)(.+?)(\*\*)")
	var regex_md_scene := RegEx.create_from_string(r"[^\s]+\.tscn")

	var calls := []
	var bubble_text_lines: Array[String] = []
	var tour_contents: Array[String] = [HEADER.strip_edges()]

	var md_file := FileAccess.open(md_file_path, FileAccess.READ)
	var lines: Array[String] = []
	lines.assign(strip_lines_edges(md_file.get_as_text().strip_edges().split("\n")))

	var bubble_title: String = (
		to_bubble_title(lines.front())
		if not lines.is_empty() and lines.front().begins_with(MD_BUBBLE_TITLE)
		else ""
	)

	var line_count := lines.size()
	for i in range(line_count):
		var line := lines[i]
		var new_bubble_title := bubble_title
		if line.begins_with(MD_BUBBLE_TITLE):
			new_bubble_title = to_bubble_title(line)

		elif line.begins_with(MD_CALL):
			calls.push_back(to_call(line))

		else:
			line = regex_md_bold.sub(line, "[b]$2[/b]", true).strip_edges()
			if line.begins_with("-"):
				line = "[ul]%s[/ul]" % line.lstrip("- ")
			bubble_text_lines.push_back(line)

		if bubble_title != new_bubble_title or i == line_count - 1:
			tour_contents.push_back(CALLS.bubble_set_title % call_gtr(bubble_title))
			var bubble_text := ", ".join(strip_lines_edges(bubble_text_lines).map(call_gtr))
			if not bubble_text.is_empty():
				tour_contents.push_back(CALLS.bubble_add_text % bubble_text)
			for call in calls:
				var call_fmt: String = CALLS.get(call.function, CALLS.generic)
				tour_contents.push_back(call_fmt % ([call.function] + call.parameters))
			tour_contents.push_back(CALLS.complete_step)
			tour_contents.push_back("")

			bubble_title = new_bubble_title
			bubble_text_lines = []
			calls = []

	var tour_file := FileAccess.open(tour_file_path, FileAccess.WRITE)
	tour_file.store_string(join_lines(tour_contents, true, false))


func to_bubble_title(line: String) -> String:
	return line.lstrip(MD_BUBBLE_TITLE).strip_edges()


func to_call(s: String) -> Dictionary:
	var result := {function = "", parameters = []}
	var strip_edges := func(s: String) -> String: return s.strip_edges()
	var extraction: Array = Array(s.lstrip(MD_CALL).split(":")).map(strip_edges)
	result.function = extraction.front().to_lower()
	result.parameters = Array(extraction.back().split(",")).map(strip_edges)
	if result.function == "bubble_move_and_anchor":
		result.parameters.push_back(result.parameters.pop_back().to_upper())
	elif result.function == "note" or not result.function in CALLS:
		result.parameters = [", ".join(result.parameters)]
	return result


func call_gtr(s: String) -> String:
	return '""' if s.is_empty() else CALLS.gtr % sanitize(s)


func join_lines(lines: Array, do_strip_left := true, do_strip_right := true) -> String:
	return "\n".join(lines).strip_edges(do_strip_left, do_strip_right)


func strip_lines_edges(lines: Array[String]) -> Array[String]:
	var result: Array[String] = []
	result.assign(join_lines(lines).strip_edges().split("\n"))
	return result


func sanitize(s: String) -> String:
	return s.replace('"', '\\"')
