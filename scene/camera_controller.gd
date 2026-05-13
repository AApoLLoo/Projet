extends Camera2D

@export var move_speed: float = 900.0
@export var floor_path: NodePath = ^"../Floor"
@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.5
@export var zoom_step: float = 0.1

const ACTION_LEFT: StringName = &"camera_left"
const ACTION_RIGHT: StringName = &"camera_right"
const ACTION_UP: StringName = &"camera_up"
const ACTION_DOWN: StringName = &"camera_down"
const ACTION_ZOOM_IN: StringName = &"camera_zoom_in"
const ACTION_ZOOM_OUT: StringName = &"camera_zoom_out"

var _is_dragging: bool = false

func _ready() -> void:
	_ensure_input_actions()
	make_current()
	_update_limits_from_floor()
	_clamp_position_to_limits()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom_delta(-zoom_step)
				return
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom_delta(zoom_step)
				return
		if _is_pan_button(mouse_button_event.button_index):
			_is_dragging = mouse_button_event.pressed
			return

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed:
			_is_dragging = false
		return

	if _is_dragging and event is InputEventMouseMotion:
		var mouse_motion_event: InputEventMouseMotion = event
		global_position -= mouse_motion_event.relative * zoom

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(ACTION_ZOOM_IN):
		_apply_zoom_delta(-zoom_step)
	if Input.is_action_just_pressed(ACTION_ZOOM_OUT):
		_apply_zoom_delta(zoom_step)

	var direction: Vector2 = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	if direction != Vector2.ZERO:
		global_position += direction * move_speed * delta
		_clamp_position_to_limits()

func _update_limits_from_floor() -> void:
	var floor_node: Node = get_node_or_null(floor_path)
	if floor_node == null:
		return

	var grid_width_value: Variant = floor_node.get("grid_width")
	var grid_height_value: Variant = floor_node.get("grid_height")
	var cell_size_value: Variant = floor_node.get("cell_size")
	if not (grid_width_value is int and grid_height_value is int and cell_size_value is int):
		return

	var map_width: int = int(grid_width_value) * int(cell_size_value)
	var map_height: int = int(grid_height_value) * int(cell_size_value)

	limit_left = 0
	limit_top = 0
	limit_right = map_width
	limit_bottom = map_height

func refresh_limits() -> void:
	_update_limits_from_floor()
	_clamp_position_to_limits()

func set_camera_world_position(target_position: Vector2) -> void:
	global_position = target_position
	_clamp_position_to_limits()

func get_camera_world_position() -> Vector2:
	return global_position

func _is_pan_button(button_index: MouseButton) -> bool:
	return button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_MIDDLE or button_index == MOUSE_BUTTON_RIGHT

func _ensure_input_actions() -> void:
	_ensure_action_with_keys(ACTION_LEFT, [KEY_LEFT, KEY_A, KEY_Q])
	_ensure_action_with_keys(ACTION_RIGHT, [KEY_RIGHT, KEY_D])
	_ensure_action_with_keys(ACTION_UP, [KEY_UP, KEY_W, KEY_Z])
	_ensure_action_with_keys(ACTION_DOWN, [KEY_DOWN, KEY_S])
	_ensure_action_with_keys(ACTION_ZOOM_IN, [KEY_EQUAL, KEY_KP_ADD])
	_ensure_action_with_keys(ACTION_ZOOM_OUT, [KEY_MINUS, KEY_KP_SUBTRACT])

func _ensure_action_with_keys(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for keycode in keycodes:
		if _has_physical_key(existing_events, keycode):
			continue
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, input_event)

func _has_physical_key(events: Array[InputEvent], keycode: int) -> bool:
	for input_event in events:
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event
			if key_event.physical_keycode == keycode:
				return true
	return false

func _clamp_position_to_limits() -> void:
	var min_x: float = float(limit_left)
	var max_x: float = float(limit_right)
	var min_y: float = float(limit_top)
	var max_y: float = float(limit_bottom)
	var clamped_x: float = clampf(global_position.x, min_x, max_x)
	var clamped_y: float = clampf(global_position.y, min_y, max_y)
	global_position = Vector2(clamped_x, clamped_y)

func _apply_zoom_delta(delta_zoom: float) -> void:
	var next_zoom: float = clampf(zoom.x + delta_zoom, min_zoom, max_zoom)
	zoom = Vector2(next_zoom, next_zoom)
	_clamp_position_to_limits()
