extends TileMapLayer

@export var cell_size: int = 32
@export var grid_width: int = 2000  # Nombre de cases en largeur
@export var grid_height: int = 2000 # Nombre de cases en hauteur
@export var chunk_size: int = 64 # Taille d'un chunk en nombre de cases
@export var active_chunk_radius: int = 2 # Chunks chargés autour de la caméra
@export var camera_path: NodePath = ^"../Camera2D"

const SOURCE_ID := 1
const ATLAS_COORDS := Vector2i(0, 0)

var _loaded_chunks: Dictionary = {}
var _current_center_chunk: Vector2i = Vector2i(999999, 999999)
var _camera: Camera2D

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	if _camera == null:
		_camera = get_viewport().get_camera_2d()

	_refresh_chunks()

func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_node_or_null(camera_path) as Camera2D
		if _camera == null:
			_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return

	var center_chunk := _world_to_chunk(_camera.global_position)
	if center_chunk == _current_center_chunk:
		return

	_current_center_chunk = center_chunk
	_refresh_chunks()

func _refresh_chunks() -> void:
	if _camera == null:
		return

	var center_chunk := _world_to_chunk(_camera.global_position)
	_current_center_chunk = center_chunk

	var target_chunks: Dictionary = {}
	for chunk_x in range(center_chunk.x - active_chunk_radius, center_chunk.x + active_chunk_radius + 1):
		for chunk_y in range(center_chunk.y - active_chunk_radius, center_chunk.y + active_chunk_radius + 1):
			var chunk := Vector2i(chunk_x, chunk_y)
			if _is_chunk_inside_map(chunk):
				target_chunks[chunk] = true
				if not _loaded_chunks.has(chunk):
					_load_chunk(chunk)

	for chunk in _loaded_chunks.keys():
		if not target_chunks.has(chunk):
			_unload_chunk(chunk)

	_loaded_chunks = target_chunks

func _world_to_chunk(world_position: Vector2) -> Vector2i:
	var cell_x := int(floor(world_position.x / float(cell_size)))
	var cell_y := int(floor(world_position.y / float(cell_size)))
	return Vector2i(
		int(floor(cell_x / float(chunk_size))),
		int(floor(cell_y / float(chunk_size)))
	)

func _is_chunk_inside_map(chunk: Vector2i) -> bool:
	var start_x := chunk.x * chunk_size
	var start_y := chunk.y * chunk_size
	return start_x < grid_width and start_y < grid_height and (start_x + chunk_size) > 0 and (start_y + chunk_size) > 0

func _load_chunk(chunk: Vector2i) -> void:
	var start_x: int = int(max(0, chunk.x * chunk_size))
	var start_y: int = int(max(0, chunk.y * chunk_size))
	var end_x: int = int(min(grid_width, start_x + chunk_size))
	var end_y: int = int(min(grid_height, start_y + chunk_size))

	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			set_cell(Vector2i(x, y), SOURCE_ID, ATLAS_COORDS)

func _unload_chunk(chunk: Vector2i) -> void:
	var start_x: int = int(max(0, chunk.x * chunk_size))
	var start_y: int = int(max(0, chunk.y * chunk_size))
	var end_x: int = int(min(grid_width, start_x + chunk_size))
	var end_y: int = int(min(grid_height, start_y + chunk_size))

	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			erase_cell(Vector2i(x, y))

func apply_saved_state(save_state: Dictionary) -> void:
	grid_width = _to_int(save_state.get("grid_width"), grid_width)
	grid_height = _to_int(save_state.get("grid_height"), grid_height)
	cell_size = _to_int(save_state.get("cell_size"), cell_size)
	chunk_size = _to_int(save_state.get("chunk_size"), chunk_size)
	active_chunk_radius = _to_int(save_state.get("active_chunk_radius"), active_chunk_radius)

	clear()
	_loaded_chunks.clear()
	_current_center_chunk = Vector2i(999999, 999999)
	_refresh_chunks()

func get_generation_state() -> Dictionary:
	var state: Dictionary = {}
	state["grid_width"] = grid_width
	state["grid_height"] = grid_height
	state["cell_size"] = cell_size
	state["chunk_size"] = chunk_size
	state["active_chunk_radius"] = active_chunk_radius
	return state

func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback
