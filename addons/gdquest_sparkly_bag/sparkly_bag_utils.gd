const SEP := "/"

enum ReturnCode { OK, FAIL, WARN, SKIP, EXE_NOT_FOUND = 127, CODE_NOT_FOUND }


class Result:
	var return_code := ReturnCode.OK
	var result: Variant = null

	func _init(result: Variant = null) -> void:
		self.result = result


static func fs_find(pattern: String = "*", path: String = "res://", do_include_hidden := true, do_fail := true) -> Result:
	const TAG := { ReturnCode.FAIL: "FAIL", ReturnCode.SKIP: "SKIP" }

	var result: Result = Result.new([])
	var is_file := not pattern.ends_with(SEP)
	pattern = pattern.rstrip(SEP)

	var dir := DirAccess.open(path)
	dir.include_hidden = do_include_hidden

	if DirAccess.get_open_error() != OK:
		result.return_code = ReturnCode.FAIL if do_fail else ReturnCode.SKIP
		printerr("%s: could not open [%s]" % [TAG[result.return_code], path])
		return result

	if dir.list_dir_begin() != OK:
		result.return_code = ReturnCode.FAIL if do_fail else ReturnCode.SKIP
		printerr("%s: could not list contents of [%s]" % [TAG[result.return_code], path])
		return result

	path = dir.get_next()
	while path.is_valid_filename():
		var new_path: String = dir.get_current_dir().path_join(path)
		if dir.current_is_dir():
			if not is_file and (path == pattern or new_path.match(pattern)):
				result.result.push_back(new_path)
			result.result += fs_find(pattern, new_path).result
		elif path == pattern or new_path.match(pattern):
			result.result.push_back(new_path)
		path = dir.get_next()
	return result


static func fs_remove_dir(base_path: String) -> void:
	if not DirAccess.dir_exists_absolute(base_path):
		return

	var found := fs_find("*", base_path)
	for path: String in found.result:
		DirAccess.remove_absolute(path)

	found = fs_find("*/", base_path)
	found.result.reverse()
	for path in found.result:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(base_path)


static func fs_copy_dir(from_path: String, to_path: String, ignore: Array[String] = []) -> ReturnCode:
	var dir := DirAccess.open(from_path)
	from_path = dir.get_current_dir()
	var from_base_path := from_path.get_base_dir()
	var found := fs_find("*", from_path)
	if found.return_code != ReturnCode.OK:
		return found.return_code

	for file_path: String in found.result:
		if ignore.any(func(p: String) -> bool: return file_path.match(p)):
			continue
		var destination_file_path := file_path.replace(from_base_path, to_path)
		var destination_dir_path := destination_file_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(destination_dir_path)
		DirAccess.copy_absolute(file_path, destination_file_path)
	return found.return_code


static func os_execute(exe: String, args: Array, do_read_stderr := true) -> ReturnCode:
	var output := []
	var return_code := OS.execute(exe, args, output, do_read_stderr)
	for line in output:
		print_rich(line)

	var is_fail := (
		not return_code in ReturnCode.values()
		or output.any(func(s: String) -> bool: return "FAIL" in s)
	)
	return ReturnCode.FAIL if is_fail else (return_code as ReturnCode)


static func os_parse_user_args(help_description := [], supported_args := []) -> Result:
	var result := Result.new({args = {}})

	const ARG_HELP := ["-h", "--help", "Show this help message."]
	supported_args = [ARG_HELP] + supported_args

	var is_arg_predicate := func(s: String) -> bool: return s.begins_with("-")
	var arg_to_help := func(a: Array) -> String: 
		var args := a.filter(is_arg_predicate)
		var help_message := a.filter(func(s: String) -> bool: return not s.begins_with("-"))
		return "  %s" % "\n\t".join([" ".join(args), "".join(help_message)])
	var help_message := help_description + ["Arguments"] + supported_args.map(arg_to_help)
	result.result.help_message = "\n".join(help_message)

	result.result.user_args = OS.get_cmdline_user_args()
	if not ARG_HELP.filter(func(a: String) -> bool: return a in result.result.user_args).is_empty():
		print_rich(result.result.help_message)
		return result

	var flat_supported_args := flatten(supported_args).filter(is_arg_predicate)
	var unknown_args: Array[String] = []
	for arg: String in result.result.user_args:
		var parts := arg.split("=")
		var key := parts[0]
		if key in flat_supported_args:
			result.result.args[key] = parts[1] if parts.size() == 2 else null
		else:
			unknown_args.push_back(key)

	if not unknown_args.is_empty():
		var message := [
			"Unknown command-line arguments %s." % str(unknown_args),
			"Supported arguments %s." % str(flat_supported_args),
		]
		push_warning(" ".join(message))
		result.return_code = ReturnCode.WARN
	return result


static func flatten_unique(array: Array) -> Array:
	var result := {}
	for key in flatten(array):
		result[key] = null
	return result.keys()


static func flatten(array: Array) -> Array:
	return array.reduce(func(acc: Array, xs: Array) -> Array: return acc + xs, [])

