extends TileMapLayer

## Nombre de cases par côté d'un chunk.
@export var chunk_size: int = 16
## Chemin vers la Camera2D de la scène.
@export var camera_path: NodePath = ^"../Camera2D"
## Chunks supplémentaires chargés autour du viewport (marge de sécurité).
@export var chunk_margin: int = 1

const SOURCE_ID    := 1
const ATLAS_COORDS := Vector2i(0, 0)

var _loaded_chunks : Dictionary = {}
var _center_chunk  : Vector2i   = Vector2i(999999, 999999)
var _camera        : Camera2D

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

	# Rafraîchir uniquement quand le chunk central change
	var cell := local_to_map(to_local(_camera.global_position))
	var new_center := Vector2i(
		floori(float(cell.x) / float(chunk_size)),
		floori(float(cell.y) / float(chunk_size))
	)
	if new_center != _center_chunk:
		_center_chunk = new_center
		_refresh_chunks()

func _refresh_chunks() -> void:
	if _camera == null:
		return

	var target := _visible_chunks()

	for chunk in target:
		if not _loaded_chunks.has(chunk):
			_load_chunk(chunk)

	for chunk in _loaded_chunks.keys():
		if not target.has(chunk):
			_unload_chunk(chunk)

	_loaded_chunks = target

## Retourne l'ensemble des chunks qui couvrent le viewport + marge.
func _visible_chunks() -> Dictionary:
	var result   : Dictionary = {}
	var vp       : Vector2   = get_viewport().get_visible_rect().size
	var zoom     : Vector2   = _camera.zoom
	var hw       : float     = vp.x * 0.5 / zoom.x
	var hh       : float     = vp.y * 0.5 / zoom.y
	var cam      : Vector2   = _camera.global_position

	# Convertir les 4 coins du viewport en coordonnées de chunk
	var corners : Array = [
		cam + Vector2(-hw, -hh),
		cam + Vector2( hw, -hh),
		cam + Vector2(-hw,  hh),
		cam + Vector2( hw,  hh),
	]

	var min_cx :=  999999; var max_cx := -999999
	var min_cy :=  999999; var max_cy := -999999

	for corner in corners:
		var c  : Vector2i = local_to_map(to_local(corner))
		var cx := floori(float(c.x) / float(chunk_size))
		var cy := floori(float(c.y) / float(chunk_size))
		if cx < min_cx: min_cx = cx
		if cx > max_cx: max_cx = cx
		if cy < min_cy: min_cy = cy
		if cy > max_cy: max_cy = cy

	for cx in range(min_cx - chunk_margin, max_cx + chunk_margin + 1):
		for cy in range(min_cy - chunk_margin, max_cy + chunk_margin + 1):
			result[Vector2i(cx, cy)] = true

	return result

func _load_chunk(chunk: Vector2i) -> void:
	# Calcul des bornes du chunk (soutenir coordonnées négatives si carte infinie)
	var sx := chunk.x * chunk_size
	var sy := chunk.y * chunk_size
	for x in range(sx, sx + chunk_size):
		for y in range(sy, sy + chunk_size):
			set_cell(Vector2i(x, y), SOURCE_ID, ATLAS_COORDS)

func _unload_chunk(chunk: Vector2i) -> void:
	var sx := chunk.x * chunk_size
	var sy := chunk.y * chunk_size
	for x in range(sx, sx + chunk_size):
		for y in range(sy, sy + chunk_size):
			erase_cell(Vector2i(x, y))

func apply_saved_state(save_state: Dictionary) -> void:
	chunk_size = _to_int(save_state.get("chunk_size"), chunk_size)
	clear()
	_loaded_chunks.clear()
	_center_chunk = Vector2i(999999, 999999)
	_refresh_chunks()

func get_generation_state() -> Dictionary:
	return {
		"chunk_size"          : chunk_size,
		"infinite_map"        : true,
		"cell_size"           : 32,
		"grid_width"          : 2000,
		"grid_height"         : 2000,
		"active_chunk_radius" : 2,
	}

func get_world_bounds() -> Rect2:
	var generation_state: Dictionary = get_generation_state()
	var cell_size_value: float = float(generation_state.get("cell_size", 32))
	var grid_width_value: float = float(generation_state.get("grid_width", 0))
	var grid_height_value: float = float(generation_state.get("grid_height", 0))
	return Rect2(
		Vector2.ZERO,
		Vector2(grid_width_value * cell_size_value, grid_height_value * cell_size_value)
	)

func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback
