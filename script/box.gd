extends Node2D

const CELL_SIZE: int = 32
const BELT_SPEED: float = 40.0
const FRAME_CLOSED: int = 0

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _on_belt: bool = false
var _current_belt: Node = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.hframes = 2
	sprite.vframes = 5
	sprite.frame = FRAME_CLOSED
	z_index = 5
	set_process_input(true)

func _input(event: InputEvent) -> void:
	print("_input appelé")
	if _on_belt:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos: Vector2 = to_local(get_global_mouse_position())
			if abs(local_pos.x) <= CELL_SIZE / 2.0 and abs(local_pos.y) <= CELL_SIZE / 2.0:
				_dragging = true
				_drag_offset = global_position - get_global_mouse_position()
				z_index = 20
				get_viewport().set_input_as_handled()
		else:
			if _dragging:
				_dragging = false
				z_index = 5
				_snap_to_grid()
				_check_belt_under()
	if event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _on_belt:
		return
	_move_on_belt(delta)

func _snap_to_grid() -> void:
	var gx: int = int(floor(global_position.x / CELL_SIZE))
	var gy: int = int(floor(global_position.y / CELL_SIZE))
	global_position = Vector2(gx * CELL_SIZE + CELL_SIZE / 2.0, gy * CELL_SIZE + CELL_SIZE / 2.0)

func _check_belt_under() -> void:
	var cell: Vector2i = Vector2i(
		int(floor(global_position.x / CELL_SIZE)),
		int(floor(global_position.y / CELL_SIZE))
	)
	var belt = _find_belt_at(cell)
	if belt != null:
		_start_on_belt(belt)

func _find_belt_at(cell: Vector2i) -> Node:
	for belt in get_tree().get_nodes_in_group("belt"):
		if belt.has_method("get_cell") and belt.get_cell() == cell:
			return belt
	return null

func _start_on_belt(belt: Node) -> void:
	_on_belt = true
	_current_belt = belt
	sprite.frame = 1

func _move_on_belt(delta: float) -> void:
	if _current_belt == null:
		_stop_on_belt()
		return
	var target_cell: Vector2i = _current_belt.get_cell()
	var target_pos: Vector2 = Vector2(
		target_cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		target_cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)
	var dist: float = global_position.distance_to(target_pos)
	if dist <= BELT_SPEED * delta:
		global_position = target_pos
		var next_cell: Vector2i = target_cell + Vector2i(
			int(_current_belt.get_direction().x),
			int(_current_belt.get_direction().y)
		)
		var next_belt = _find_belt_at(next_cell)
		if next_belt != null:
			_current_belt = next_belt
		else:
			_stop_on_belt()
	else:
		global_position = global_position.move_toward(target_pos, BELT_SPEED * delta)

func _stop_on_belt() -> void:
	_on_belt = false
	_current_belt = null
	sprite.frame = FRAME_CLOSED
	z_index = 5
