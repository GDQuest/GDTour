## Collects info about the system and logs messages to a log file.
## Use this log file for debugging purposes when users report errors.
extends RefCounted

const LOG_FILE_PATH := "res://godot_tours.log"

enum Level {DEBUG, INFO, WARN, ERROR, FATAL}

var log_file := FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)


func _init() -> void:
	info(str(get_info()))


func clean_up() -> void:
	log_file.close()


func debug(msg: String) -> void:
	write(Level.DEBUG, msg)


func info(msg: String) -> void:
	write(Level.INFO, msg)


func warn(msg: String) -> void:
	write(Level.WARN, msg)


func error(msg: String) -> void:
	write(Level.ERROR, msg)


func fatal(msg: String) -> void:
	write(Level.FATAL, msg)


func write(level: Level, msg: String) -> void:
	log_file.store_string(
		"%s:%s: %s\n" % [Time.get_datetime_string_from_system(true), Level.keys()[level], msg]
	)
	log_file.flush()


func get_info() -> Dictionary:
	return {
		"OS": OS.get_name(),
		"video_adapter_driver_info": OS.get_video_adapter_driver_info(),
		"screen_size": DisplayServer.screen_get_size(),
		"screen_dpi": DisplayServer.screen_get_dpi(),
		"screen_scale": DisplayServer.screen_get_scale(),
		"cores": OS.get_processor_count(),
		"locale": OS.get_locale(),
	}
