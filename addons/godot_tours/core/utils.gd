class Helper:
	static func noop() -> void:
		pass


const SEP := "/"


static func find_child(node: Node, type: String, pattern := "", predicate := Helper.noop) -> Node:
	if node == null:
		return null
	var result := node.find_children(pattern, type, true, false)
	if not result.is_empty() and predicate != Helper.noop:
		result = result.filter(predicate)
	return null if result.is_empty() else result[0]


static func get_tree_item_path(item: TreeItem, column: int = 0) -> String:
	var partial_result: Array[String] = [item.get_text(column)]
	var parent: TreeItem = item.get_parent()
	while parent != null:
		partial_result.push_front(parent.get_text(0))
		parent = parent.get_parent()
	return partial_result.reduce(func(accum: String, p: String) -> String: return accum.path_join(p))


static func filter_tree_items(item: TreeItem, predicate: Callable) -> Array[TreeItem]:
	var go := func(go: Callable, root: TreeItem) -> Array[TreeItem]:
		var result: Array[TreeItem] = []
		if predicate.call(root):
			result.push_back(root)
		for child in root.get_children():
			result.append_array(go.call(go, child))
		return result
	return go.call(go, item)


## Searches children of the root TreeItem recursively and returns the first one with the given name.
## Stops at the first match found.
static func find_tree_item_by_name(tree: Tree, name: String) -> TreeItem:
	var root: TreeItem = tree.get_root()
	if root.get_text(0) == name:
		return root

	var result: TreeItem = null
	var stack: Array[TreeItem] = []
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		if item.get_text(0) == name:
			result = item
			break

		if item.get_child_count() > 0:
			stack += item.get_children()
	return result


## Finds files matching the String.match pattern in the given directory path, recursively.
static func find_files_recursively_by_match_pattern(pattern := "*", path := "res://") -> Array[String]:
	var result: Array[String] = []
	var is_file := not pattern.ends_with(SEP)

	var dir := DirAccess.open(path)
	if DirAccess.get_open_error() != OK:
		printerr("ERROR: could not open [%s]" % path)
		return result

	if dir.list_dir_begin() != OK:
		printerr("ERROR: could not list contents of [%s]" % path)
		return result

	path = dir.get_next()
	while path.is_valid_filename():
		var new_path: String = dir.get_current_dir().path_join(path)
		if dir.current_is_dir():
			if path.match(pattern.rstrip(SEP)) and not is_file:
				result.push_back(new_path)
			result += find_files_recursively_by_match_pattern(pattern, new_path)
		elif path.match(pattern):
			result.push_back(new_path)
		path = dir.get_next()

	return result


## Finds files with the given file_extension in the directory directory_path.
static func find_files_in_directory(directory_path: String, file_extension: String) -> Array[String]:
	var file_names := DirAccess.get_files_at(directory_path)
	var file_paths: Array[String] = []
	for file_name in file_names:
		if file_name.get_extension() != file_extension:
			continue
		file_paths.append(directory_path.path_join(file_name))
	return file_paths


## Returns the first child of parent_node with the given type.
static func get_child_by_type(parent_node: Control, type: String) -> Control:
	for child in parent_node.get_children():
		if child.get_class() == type:
			return child
	return null


static func unlines(lines: Array[String]) -> String:
	return "\n".join(lines)
