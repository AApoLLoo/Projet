extends Node

const SETTINGS_FILE_PATH: String = "user://settings.json"
const MAIN_MENU_SCENE: String = "res://scene/main_menu.tscn"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var _settings: Dictionary = {}
var _return_scene_path: String = MAIN_MENU_SCENE
var _return_slot_id: String = ""

func _ready() -> void:
	_settings = _load_settings()
	_apply_settings(_settings)

func get_resolution_options() -> Array[Vector2i]:
	return RESOLUTIONS

func supports_window_controls() -> bool:
	return not _is_embedded_editor_run()

func get_settings() -> Dictionary:
	return _settings.duplicate(true)

func update_settings(new_settings: Dictionary) -> void:
	_settings = _sanitize_settings(new_settings)
	_save_settings(_settings)
	_apply_settings(_settings)

func reset_to_defaults() -> void:
	_settings = _default_settings()
	_save_settings(_settings)
	_apply_settings(_settings)

func set_return_target(scene_path: String, slot_id: String = "") -> void:
	if scene_path.strip_edges().is_empty():
		_return_scene_path = MAIN_MENU_SCENE
	else:
		_return_scene_path = scene_path
	_return_slot_id = slot_id

func get_return_scene_path() -> String:
	return _return_scene_path

func get_return_slot_id() -> String:
	return _return_slot_id

func _load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return _default_settings()

	var file: FileAccess = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file == null:
		return _default_settings()

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return _default_settings()

	var parsed_dictionary: Dictionary = parsed
	return _sanitize_settings(parsed_dictionary)

func _save_settings(settings_data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(settings_data))
	file.close()

func _default_settings() -> Dictionary:
	var defaults: Dictionary = {}
	defaults["resolution_index"] = _find_closest_resolution_index(DisplayServer.window_get_size())
	defaults["fullscreen"] = false
	defaults["master_volume"] = 80.0
	defaults["music_volume"] = 80.0
	defaults["sfx_volume"] = 80.0
	return defaults

func _sanitize_settings(raw: Dictionary) -> Dictionary:
	var defaults: Dictionary = _default_settings()
	var max_index: int = max(0, RESOLUTIONS.size() - 1)
	var resolution_index: int = clampi(_to_int(raw.get("resolution_index"), _to_int(defaults["resolution_index"], 0)), 0, max_index)

	var sanitized: Dictionary = {}
	sanitized["resolution_index"] = resolution_index
	sanitized["fullscreen"] = _to_bool(raw.get("fullscreen"), _to_bool(defaults["fullscreen"], false))
	sanitized["master_volume"] = clampf(_to_float(raw.get("master_volume"), _to_float(defaults["master_volume"], 80.0)), 0.0, 100.0)
	sanitized["music_volume"] = clampf(_to_float(raw.get("music_volume"), _to_float(defaults["music_volume"], 80.0)), 0.0, 100.0)
	sanitized["sfx_volume"] = clampf(_to_float(raw.get("sfx_volume"), _to_float(defaults["sfx_volume"], 80.0)), 0.0, 100.0)
	return sanitized

func _apply_settings(settings_data: Dictionary) -> void:
	var can_control_window: bool = supports_window_controls()
	var fullscreen: bool = _to_bool(settings_data.get("fullscreen"), false)
	var resolution_index: int = _to_int(settings_data.get("resolution_index"), 0)
	resolution_index = clampi(resolution_index, 0, max(0, RESOLUTIONS.size() - 1))
	var resolution: Vector2i = RESOLUTIONS[resolution_index]

	if can_control_window:
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			var current_screen: int = DisplayServer.window_get_current_screen()
			var screen_position: Vector2i = DisplayServer.screen_get_position(current_screen)
			var screen_size: Vector2i = DisplayServer.screen_get_size(current_screen)
			var centered_x: int = screen_position.x + int((screen_size.x - resolution.x) / 2.0)
			var centered_y: int = screen_position.y + int((screen_size.y - resolution.y) / 2.0)
			DisplayServer.window_set_position(Vector2i(centered_x, centered_y))

	_apply_audio_percent("Master", _to_float(settings_data.get("master_volume"), 80.0), false)
	_apply_audio_percent("Music", _to_float(settings_data.get("music_volume"), 80.0), true)
	_apply_audio_percent("SFX", _to_float(settings_data.get("sfx_volume"), 80.0), true)

func _apply_audio_percent(bus_name: String, volume_percent: float, create_if_missing: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1 and create_if_missing:
		bus_index = _create_audio_bus(bus_name)
	if bus_index == -1:
		return

	var linear_value: float = clampf(volume_percent / 100.0, 0.0, 1.0)
	var volume_db: float = -80.0 if linear_value <= 0.0 else linear_to_db(linear_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)

func _create_audio_bus(bus_name: String) -> int:
	var existing_index: int = AudioServer.get_bus_index(bus_name)
	if existing_index != -1:
		return existing_index

	var bus_count: int = AudioServer.get_bus_count()
	AudioServer.add_bus(bus_count)
	AudioServer.set_bus_name(bus_count, bus_name)
	AudioServer.set_bus_send(bus_count, "Master")
	return bus_count

func _find_closest_resolution_index(target_size: Vector2i) -> int:
	var best_index: int = 0
	var best_distance: int = 2147483647

	for index in range(RESOLUTIONS.size()):
		var resolution: Vector2i = RESOLUTIONS[index]
		var dx: int = resolution.x - target_size.x
		var dy: int = resolution.y - target_size.y
		var distance: int = dx * dx + dy * dy
		if distance < best_distance:
			best_distance = distance
			best_index = index

	return best_index

func _is_embedded_editor_run() -> bool:
	return OS.has_feature("editor")

func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback

func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return float(value)
	if value is int:
		return float(value)
	return fallback

func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return bool(value)
	return fallback
