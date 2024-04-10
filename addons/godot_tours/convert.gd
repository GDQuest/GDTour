extends SceneTree

const Utils := preload("../gdquest_sparkly_bag/sparkly_bag_utils.gd")

const HEADER := """
extends "../../addons/godot_tours/tour.gd"

func _build() -> void:
"""
const CALLS := {
	complete_step = "\tcomplete_step()",
	bubble_set_title = """\tbubble_set_title(%s)""",
	bubble_add_text = """\tbubble_add_text([%s])""",
	gtr = """gtr("%s")"""
}

const MD_BUBBLE_TITLE := "##"
const MD_BUBBLE_ACTION := ">"


func _init() -> void:
	var md_files := Utils.fs_find("*.md", "res://tours", false)
	for md_file_path: String in md_files.result:
		convert_to_test(md_file_path)
	quit()
	return


func convert_to_test(md_file_path: String) -> void:
	var regex_md_bold := RegEx.create_from_string(r"(\*\*)(.+?)(\*\*)")

	var bubble_text_lines: Array[String] = []

	var tour_contents: Array[String] = [HEADER.strip_edges()]

	var md_file := FileAccess.open(md_file_path, FileAccess.READ)
	var lines: Array[String] = []
	lines.assign(md_file.get_as_text().strip_edges().split("\n"))

	var bubble_title: String = (
		to_bubble_title(lines.front())
		if not lines.is_empty() and lines.front().begins_with(MD_BUBBLE_TITLE)
		else ""
	)

	for line in lines:
		var new_bubble_title := bubble_title
		if line.begins_with(MD_BUBBLE_TITLE):
			new_bubble_title = to_bubble_title(line)

		elif line.begins_with(MD_BUBBLE_ACTION):
			pass

		else:
			line = regex_md_bold.sub(line, "[b]$2[/b]", true)
			bubble_text_lines.push_back(line)

		if bubble_title != new_bubble_title:
			tour_contents.push_back(CALLS.bubble_set_title % call_gtr(bubble_title))
			var bubble_text := ", ".join(strip_lines_edges(bubble_text_lines).map(call_gtr))
			if not bubble_text.is_empty():
				tour_contents.push_back(CALLS.bubble_add_text % bubble_text)
			tour_contents.push_back(CALLS.complete_step)
			tour_contents.push_back("")

			bubble_title = new_bubble_title
			bubble_text_lines = []

	var tour_file_path := "%s.gd" % md_file_path.get_basename()
	var tour_file := FileAccess.open(tour_file_path, FileAccess.WRITE)
	tour_file.store_string(join_lines(tour_contents, true, false))


func to_bubble_title(s: String) -> String:
	return s.replace(MD_BUBBLE_TITLE, "").strip_edges()


func call_gtr(s: String) -> String:
	return '""' if s.is_empty() else CALLS.gtr % sanitize(s)


func join_lines(lines: Array[String], do_strip_left := true, do_strip_right := true) -> String:
	return "\n".join(lines).strip_edges(do_strip_left, do_strip_right)


func strip_lines_edges(lines: Array[String]) -> Array[String]:
	var result: Array[String] = []
	result.assign(join_lines(lines).strip_edges().split("\n"))
	return result


func sanitize(s: String) -> String:
	return s.replace('"', '\\"')
