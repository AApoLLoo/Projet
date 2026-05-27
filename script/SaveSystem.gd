extends Node

const SAVE_DIR_PATH: String = "user://saves"
const SLOT_FILE_PREFIX: String = "save_"
const NEW_SLOT_ID: String = "__new_slot__"
const MODE_NEW: StringName = &"new"
const MODE_LOAD: StringName = &"load"

const DEFAULT_GRID_WIDTH: int = 1000
const DEFAULT_GRID_HEIGHT: int = 1000
const DEFAULT_CELL_SIZE: int = 32
const DEFAULT_CHUNK_SIZE: int = 64
const DEFAULT_ACTIVE_CHUNK_RADIUS: int = 2
const DEFAULT_CAMERA_X: float = 576.0
const DEFAULT_CAMERA_Y: float = 324.0
const MAX_SAVE_NAME_LENGTH: int = 32

var launch_mode: StringName = MODE_NEW
var _active_slot_id: String = ""
var _requested_load_slot_id: String = ""

func _ready() -> void:
	_ensure_save_directory()

func request_new_game() -> void:
	launch_mode = MODE_NEW
	_active_slot_id = ""
	_requested_load_slot_id = ""

func request_load_game(slot_id: String = "") -> void:
	launch_mode = MODE_LOAD
	_requested_load_slot_id = _normalize_slot_id(slot_id)
	_active_slot_id = _requested_load_slot_id

func get_active_slot_id() -> String:
	return _active_slot_id

func set_active_slot(slot_id: String) -> void:
	_active_slot_id = _normalize_slot_id(slot_id)

func is_new_slot_id(slot_id: String) -> bool:
	return slot_id == NEW_SLOT_ID

func get_level_start_state() -> Dictionary:
	if launch_mode != MODE_LOAD:
		return get_default_state()

	var target_slot: String = _requested_load_slot_id
	if target_slot.is_empty():
		target_slot = _find_latest_saved_slot()
	if target_slot.is_empty():
		target_slot = _create_new_slot_id()

	_active_slot_id = target_slot

	var loaded_state: Dictionary = load_slot_state(target_slot)
	if loaded_state.is_empty():
		var default_state: Dictionary = get_default_state()
		default_state["save_name"] = _default_save_name()
		default_state["saved_at_unix"] = int(Time.get_unix_time_from_system())
		save_slot_state(target_slot, default_state)
		return default_state

	return loaded_state

func get_menu_preview_state() -> Dictionary:
	var latest_slot_id: String = _find_latest_saved_slot()
	if latest_slot_id.is_empty():
		return get_default_state()

	var latest_state: Dictionary = load_slot_state(latest_slot_id)
	if latest_state.is_empty():
		return get_default_state()
	return latest_state

func get_save_slots(include_new_slot: bool = false) -> Array[Dictionary]:
	_ensure_save_directory()
	var slot_ids: Array[String] = _list_slot_ids()

	var slots: Array[Dictionary] = []
	var index: int = 1
	for slot_id in slot_ids:
		var state: Dictionary = load_slot_state(slot_id)
		if state.is_empty():
			continue

		var slot_data: Dictionary = {}
		slot_data["slot_id"] = slot_id
		slot_data["label"] = "Slot %d" % index
		slot_data["save_name"] = _variant_to_string(state.get("save_name"), _default_save_name())
		slot_data["has_data"] = true
		slot_data["saved_at_unix"] = _to_int(state.get("saved_at_unix"), 0)
		slot_data["camera_x"] = _to_float(state.get("camera_x"), DEFAULT_CAMERA_X)
		slot_data["camera_y"] = _to_float(state.get("camera_y"), DEFAULT_CAMERA_Y)
		slot_data["grid_width"] = _to_int(state.get("grid_width"), DEFAULT_GRID_WIDTH)
		slot_data["grid_height"] = _to_int(state.get("grid_height"), DEFAULT_GRID_HEIGHT)
		slots.append(slot_data)
		index += 1

	if include_new_slot:
		var new_slot_data: Dictionary = {}
		new_slot_data["slot_id"] = NEW_SLOT_ID
		new_slot_data["label"] = "Nouveau slot"
		new_slot_data["save_name"] = ""
		new_slot_data["has_data"] = false
		new_slot_data["saved_at_unix"] = 0
		new_slot_data["camera_x"] = DEFAULT_CAMERA_X
		new_slot_data["camera_y"] = DEFAULT_CAMERA_Y
		new_slot_data["grid_width"] = DEFAULT_GRID_WIDTH
		new_slot_data["grid_height"] = DEFAULT_GRID_HEIGHT
		slots.append(new_slot_data)

	return slots

func save_level_state(camera_position: Vector2, floor_state: Dictionary) -> String:
	return save_level_state_to_slot(_active_slot_id, camera_position, floor_state)

func save_level_state_to_slot(slot_id: String, camera_position: Vector2, floor_state: Dictionary, save_name: String = "") -> String:
	var normalized_slot_id: String = _normalize_slot_id(slot_id)
	if normalized_slot_id.is_empty() or normalized_slot_id == NEW_SLOT_ID:
		normalized_slot_id = _create_new_slot_id()

	_active_slot_id = normalized_slot_id

	var existing_state: Dictionary = load_slot_state(normalized_slot_id)
	var existing_name: String = _variant_to_string(existing_state.get("save_name"), _default_save_name())
	var requested_name: String = save_name.strip_edges()
	var final_name: String = existing_name if requested_name.is_empty() else requested_name
	final_name = _sanitize_save_name(final_name, _default_save_name())

	var state: Dictionary = get_default_state()
	state["camera_x"] = camera_position.x
	state["camera_y"] = camera_position.y
	state["grid_width"] = _to_int(floor_state.get("grid_width"), DEFAULT_GRID_WIDTH)
	state["grid_height"] = _to_int(floor_state.get("grid_height"), DEFAULT_GRID_HEIGHT)
	state["cell_size"] = _to_int(floor_state.get("cell_size"), DEFAULT_CELL_SIZE)
	state["chunk_size"] = _to_int(floor_state.get("chunk_size"), DEFAULT_CHUNK_SIZE)
	state["active_chunk_radius"] = _to_int(floor_state.get("active_chunk_radius"), DEFAULT_ACTIVE_CHUNK_RADIUS)
	state["saved_at_unix"] = int(Time.get_unix_time_from_system())
	state["game_day"] = TimeManager.current_day
	state["game_time"] = TimeManager.current_time
	if GameManager:
		state["credits"] = GameManager.credits
	# Sauvegarder toutes les entités actives
	var entities_array: Array = []
	for entity in EntityManager.entities.values():
		if is_instance_valid(entity):
			entities_array.append(entity.serialize())
	state["entities"] = entities_array
	state["save_name"] = final_name
	save_slot_state(normalized_slot_id, state)
	return normalized_slot_id

func delete_slot(slot_id: String) -> bool:
	_ensure_save_directory()
	var normalized_slot_id: String = _normalize_slot_id(slot_id)
	if normalized_slot_id.is_empty() or normalized_slot_id == NEW_SLOT_ID:
		return false

	var directory: DirAccess = DirAccess.open(SAVE_DIR_PATH)
	if directory == null:
		return false

	var file_name: String = "%s.json" % normalized_slot_id
	if not directory.file_exists(file_name):
		return true

	var error: Error = directory.remove(file_name)
	if error != OK:
		return false

	if _active_slot_id == normalized_slot_id:
		_active_slot_id = ""
	if _requested_load_slot_id == normalized_slot_id:
		_requested_load_slot_id = ""

	return true

func load_slot_state(slot_id: String) -> Dictionary:
	_ensure_save_directory()
	var normalized_slot_id: String = _normalize_slot_id(slot_id)
	if normalized_slot_id.is_empty() or normalized_slot_id == NEW_SLOT_ID:
		return {}

	var save_path: String = _get_slot_file_path(normalized_slot_id)
	if not FileAccess.file_exists(save_path):
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return {}

	var parsed_dictionary: Dictionary = parsed
	return _sanitize_state(parsed_dictionary)

func save_slot_state(slot_id: String, state: Dictionary) -> void:
	_ensure_save_directory()
	var normalized_slot_id: String = _normalize_slot_id(slot_id)
	if normalized_slot_id.is_empty() or normalized_slot_id == NEW_SLOT_ID:
		return

	var save_path: String = _get_slot_file_path(normalized_slot_id)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return

	var sanitized_state: Dictionary = _sanitize_state(state)
	file.store_string(JSON.stringify(sanitized_state))
	file.close()

func get_default_state() -> Dictionary:
	var state: Dictionary = {}
	state["grid_width"] = DEFAULT_GRID_WIDTH
	state["grid_height"] = DEFAULT_GRID_HEIGHT
	state["cell_size"] = DEFAULT_CELL_SIZE
	state["chunk_size"] = DEFAULT_CHUNK_SIZE
	state["active_chunk_radius"] = DEFAULT_ACTIVE_CHUNK_RADIUS
	state["camera_x"] = DEFAULT_CAMERA_X
	state["camera_y"] = DEFAULT_CAMERA_Y
	state["saved_at_unix"] = 0
	state["save_name"] = ""
	state["game_day"] = 1
	state["game_time"] = 8.0
	state["credits"] = 12500.0
	state["entities"] = []
	return state

func _sanitize_state(raw_state: Dictionary) -> Dictionary:
	var state: Dictionary = get_default_state()
	state["grid_width"] = max(1, _to_int(raw_state.get("grid_width"), DEFAULT_GRID_WIDTH))
	state["grid_height"] = max(1, _to_int(raw_state.get("grid_height"), DEFAULT_GRID_HEIGHT))
	state["cell_size"] = max(1, _to_int(raw_state.get("cell_size"), DEFAULT_CELL_SIZE))
	state["chunk_size"] = max(1, _to_int(raw_state.get("chunk_size"), DEFAULT_CHUNK_SIZE))
	state["active_chunk_radius"] = max(1, _to_int(raw_state.get("active_chunk_radius"), DEFAULT_ACTIVE_CHUNK_RADIUS))
	state["camera_x"] = _to_float(raw_state.get("camera_x"), DEFAULT_CAMERA_X)
	state["camera_y"] = _to_float(raw_state.get("camera_y"), DEFAULT_CAMERA_Y)
	state["saved_at_unix"] = max(0, _to_int(raw_state.get("saved_at_unix"), 0))
	state["game_day"] = max(1, _to_int(raw_state.get("game_day"), 1))
	state["game_time"] = _to_float(raw_state.get("game_time"), 8.0)
	state["credits"] = _to_float(raw_state.get("credits"), 12500.0)
	# Préserver le tableau des entités tel quel (validé case par case à la restauration)
	var raw_entities: Variant = raw_state.get("entities")
	state["entities"] = raw_entities if raw_entities is Array else []
	var raw_name: String = _variant_to_string(raw_state.get("save_name"), _default_save_name())
	state["save_name"] = _sanitize_save_name(raw_name, _default_save_name())
	return state

func _find_latest_saved_slot() -> String:
	var slot_ids: Array[String] = _list_slot_ids()
	var best_slot_id: String = ""
	var best_time: int = -1

	for slot_id in slot_ids:
		var slot_state: Dictionary = load_slot_state(slot_id)
		if slot_state.is_empty():
			continue

		var slot_time: int = _to_int(slot_state.get("saved_at_unix"), 0)
		if slot_time > best_time:
			best_time = slot_time
			best_slot_id = slot_id

	return best_slot_id

func _list_slot_ids() -> Array[String]:
	_ensure_save_directory()
	var directory: DirAccess = DirAccess.open(SAVE_DIR_PATH)
	if directory == null:
		return []

	var slot_ids: Array[String] = []
	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		if directory.current_is_dir():
			continue
		if not entry.ends_with(".json"):
			continue
		var slot_id: String = entry.trim_suffix(".json")
		slot_id = _normalize_slot_id(slot_id)
		if slot_id.is_empty() or slot_id == NEW_SLOT_ID:
			continue
		slot_ids.append(slot_id)
	directory.list_dir_end()

	slot_ids.sort()
	return slot_ids

func _create_new_slot_id() -> String:
	var base_id: String = "%s%d" % [SLOT_FILE_PREFIX, int(Time.get_unix_time_from_system())]
	var candidate_id: String = base_id
	var counter: int = 1
	while FileAccess.file_exists(_get_slot_file_path(candidate_id)):
		candidate_id = "%s_%d" % [base_id, counter]
		counter += 1
	return candidate_id

func _normalize_slot_id(slot_id: String) -> String:
	var normalized: String = slot_id.strip_edges()
	if normalized.is_empty():
		return ""
	normalized = normalized.replace("/", "_")
	normalized = normalized.replace("\\", "_")
	normalized = normalized.replace(":", "_")
	normalized = normalized.replace("..", "_")
	normalized = normalized.replace(" ", "_")
	return normalized

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR_PATH):
		DirAccess.make_dir_absolute(SAVE_DIR_PATH)

func _get_slot_file_path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIR_PATH, slot_id]

func _default_save_name() -> String:
	var existing_count: int = _list_slot_ids().size()
	return "Sauvegarde %d" % (existing_count + 1)

func _sanitize_save_name(save_name: String, fallback: String) -> String:
	var trimmed: String = save_name.strip_edges()
	if trimmed.is_empty():
		return fallback
	if trimmed.length() > MAX_SAVE_NAME_LENGTH:
		return trimmed.substr(0, MAX_SAVE_NAME_LENGTH)
	return trimmed

func _variant_to_string(value: Variant, fallback: String) -> String:
	if value is String:
		return value
	return fallback

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
