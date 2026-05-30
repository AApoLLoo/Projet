extends Control
class_name MinimapOverlay

signal navigate_requested(world_position: Vector2)

const BACKDROP_COLOR: Color = Color(0.06, 0.09, 0.12, 0.16)
const BORDER_COLOR: Color = Color(0.82, 0.9, 0.95, 0.42)
const WORLD_FRAME_COLOR: Color = Color(0.65, 0.78, 0.86, 0.28)
const CAMERA_FILL_COLOR: Color = Color(0.28, 0.82, 1.0, 0.12)
const CAMERA_BORDER_COLOR: Color = Color(0.42, 0.92, 1.0, 0.92)
const CONTENT_PADDING: float = 8.0
const MIN_MARKER_RADIUS: float = 2.0

var _world_rect: Rect2 = Rect2()
var _camera_rect: Rect2 = Rect2()
var _entity_markers: Array[Dictionary] = []
var _has_world_rect: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func update_state(world_rect: Rect2, camera_rect: Rect2, entity_markers: Array[Dictionary]) -> void:
	_world_rect = world_rect
	_camera_rect = camera_rect
	_entity_markers = entity_markers.duplicate(true)
	_has_world_rect = world_rect.size.x > 0.0 and world_rect.size.y > 0.0
	queue_redraw()

func clear_state() -> void:
	_world_rect = Rect2()
	_camera_rect = Rect2()
	_entity_markers.clear()
	_has_world_rect = false
	queue_redraw()

func _draw() -> void:
	var full_rect: Rect2 = Rect2(Vector2.ZERO, size)
	if full_rect.size.x <= 0.0 or full_rect.size.y <= 0.0:
		return

	draw_rect(full_rect, BACKDROP_COLOR)
	draw_rect(full_rect.grow(-1.0), BORDER_COLOR, false, 1.5)

	if not _has_world_rect:
		return

	var content_rect: Rect2 = _get_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return

	draw_rect(content_rect, WORLD_FRAME_COLOR, false, 1.0)
	_draw_markers(content_rect)
	_draw_camera_rect(content_rect)

func _gui_input(event: InputEvent) -> void:
	if not _has_world_rect:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var content_rect: Rect2 = _get_content_rect()
			if not content_rect.has_point(mouse_event.position):
				return
			navigate_requested.emit(_unproject_local_position(mouse_event.position, content_rect))
			accept_event()

func _draw_markers(content_rect: Rect2) -> void:
	for marker in _entity_markers:
		var marker_position: Variant = marker.get("position", Vector2.ZERO)
		if not (marker_position is Vector2):
			continue
		var local_position: Vector2 = _project_world_position(marker_position, content_rect)
		if not content_rect.grow(6.0).has_point(local_position):
			continue
		var marker_color: Color = marker.get("color", Color(0.9, 0.94, 0.98, 0.95))
		var marker_radius: float = maxf(float(marker.get("radius", MIN_MARKER_RADIUS)), MIN_MARKER_RADIUS)
		draw_circle(local_position, marker_radius, marker_color)

func _draw_camera_rect(content_rect: Rect2) -> void:
	if _camera_rect.size.x <= 0.0 or _camera_rect.size.y <= 0.0:
		return
	var projected_camera_rect: Rect2 = _project_world_rect(_camera_rect, content_rect)
	var clipped_camera_rect: Rect2 = projected_camera_rect.intersection(content_rect)
	if clipped_camera_rect.size.x <= 0.0 or clipped_camera_rect.size.y <= 0.0:
		return
	if clipped_camera_rect.size.x < 2.0:
		clipped_camera_rect.size.x = 2.0
	if clipped_camera_rect.size.y < 2.0:
		clipped_camera_rect.size.y = 2.0
	draw_rect(clipped_camera_rect, CAMERA_FILL_COLOR)
	draw_rect(clipped_camera_rect, CAMERA_BORDER_COLOR, false, 1.5)

func _project_world_rect(world_rect: Rect2, content_rect: Rect2) -> Rect2:
	var top_left: Vector2 = _project_world_position(world_rect.position, content_rect)
	var bottom_right: Vector2 = _project_world_position(world_rect.end, content_rect)
	return Rect2(top_left, bottom_right - top_left).abs()

func _project_world_position(world_position: Vector2, content_rect: Rect2) -> Vector2:
	var normalized: Vector2 = Vector2(
		clampf((world_position.x - _world_rect.position.x) / _world_rect.size.x, 0.0, 1.0),
		clampf((world_position.y - _world_rect.position.y) / _world_rect.size.y, 0.0, 1.0)
	)
	return Vector2(
		content_rect.position.x + normalized.x * content_rect.size.x,
		content_rect.position.y + normalized.y * content_rect.size.y
	)

func _unproject_local_position(local_position: Vector2, content_rect: Rect2) -> Vector2:
	var normalized: Vector2 = Vector2(
		clampf((local_position.x - content_rect.position.x) / maxf(content_rect.size.x, 1.0), 0.0, 1.0),
		clampf((local_position.y - content_rect.position.y) / maxf(content_rect.size.y, 1.0), 0.0, 1.0)
	)
	return Vector2(
		_world_rect.position.x + normalized.x * _world_rect.size.x,
		_world_rect.position.y + normalized.y * _world_rect.size.y
	)

func _get_content_rect() -> Rect2:
	return Rect2(
		Vector2(CONTENT_PADDING, CONTENT_PADDING),
		Vector2(
			maxf(size.x - CONTENT_PADDING * 2.0, 0.0),
			maxf(size.y - CONTENT_PADDING * 2.0, 0.0)
		)
	)