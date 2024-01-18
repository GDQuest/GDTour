extends RefCounted


## Forces the editor to reload a cached resource by creating a copy of it and having the new copy
## overwrite the original resource.
static func resource_force_editor_reload(resource_path: String) -> Resource:
	assert(resource_path.is_absolute_path(), "This function only works with absolute paths (like the load function).")
	var resource := FileAccess.open(resource_path, FileAccess.READ)
	if resource.get_error() != OK:
		printerr("Failed to load resource '" + resource_path + "': Error code " + str(resource.get_error()))
		return null

	var resource_ext := resource_path.get_extension()
	var intermediate_path := resource_path + "_temp_" + str(randi()) + "." + resource_ext
	while ResourceLoader.has_cached(intermediate_path):
		intermediate_path = resource_path + "_temp_" + str(randi()) + "." + resource_ext

	var intermediate_resource = FileAccess.open(intermediate_path, FileAccess.WRITE)
	if intermediate_resource.get_error() != OK:
		printerr("Failed to load resource '" + resource_path + "': Error code " + str(intermediate_resource.get_error()))
		return null

	var resource_content := resource.get_as_text()
	intermediate_resource.store_string(resource_content)
	intermediate_resource.close()
	resource.close()

	var actual_resource = ResourceLoader.load(intermediate_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	actual_resource.take_over_path(resource_path)

	DirAccess.remove_absolute(intermediate_path)
	return actual_resource
