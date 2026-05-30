extends Entity
class_name ConveyorEntity

@export var conveyor_kind: String = "belt_right"
@export var input_offset: Vector2i = Vector2i(-1, 0)
@export var output_offset: Vector2i = Vector2i(1, 0)
@export var travel_time: float = 0.45
@export var throughput_amount: int = 1

var carried_resource: String = ""
var carried_amount: int = 0
var travel_progress: float = 0.0

@onready var _item_marker: Polygon2D = _ensure_item_marker()

func _ready() -> void:
	entity_type = conveyor_kind
	super._ready()
	is_active = true
	_update_item_marker()

func _post_ready() -> void:
	EntityManager.register_entity(self)

func _process(delta: float) -> void:
	if not is_active:
		_update_item_marker()
		return

	if carried_resource.is_empty():
		_try_pull_from_input()
	else:
		travel_progress = minf(1.0, travel_progress + (delta / maxf(travel_time, 0.01)))
		if is_equal_approx(travel_progress, 1.0) and _try_push_to_output():
			_clear_carried_item()

	_update_item_marker()

func get_status_text() -> String:
	if not is_active:
		return "Arret"
	if carried_resource.is_empty():
		return "En attente"
	if travel_progress >= 1.0:
		return "Sortie bloquee"
	return "Transport"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["conveyor_kind"] = conveyor_kind
	data["input_offset_x"] = input_offset.x
	data["input_offset_y"] = input_offset.y
	data["output_offset_x"] = output_offset.x
	data["output_offset_y"] = output_offset.y
	data["carried_resource"] = carried_resource
	data["carried_amount"] = carried_amount
	data["travel_progress"] = travel_progress
	return data

func deserialize(data: Dictionary) -> void:
	conveyor_kind = String(data.get("conveyor_kind", conveyor_kind))
	input_offset = Vector2i(int(data.get("input_offset_x", input_offset.x)), int(data.get("input_offset_y", input_offset.y)))
	output_offset = Vector2i(int(data.get("output_offset_x", output_offset.x)), int(data.get("output_offset_y", output_offset.y)))
	super.deserialize(data)
	carried_resource = String(data.get("carried_resource", ""))
	carried_amount = max(0, int(data.get("carried_amount", 0)))
	travel_progress = clampf(float(data.get("travel_progress", 0.0)), 0.0, 1.0)
	_update_item_marker()

func is_output_target(cell_pos: Vector2i) -> bool:
	return cell_position + output_offset == cell_pos

func expects_input_from(cell_pos: Vector2i) -> bool:
	return cell_position + input_offset == cell_pos

func can_accept_conveyor_item(resource_id: String, amount: int = 1) -> bool:
	if resource_id.is_empty() or amount <= 0:
		return false
	return carried_resource.is_empty()

func receive_conveyor_item(resource_id: String, amount: int = 1) -> int:
	if not can_accept_conveyor_item(resource_id, amount):
		return 0
	carried_resource = resource_id
	carried_amount = amount
	travel_progress = 0.0
	_update_item_marker()
	entity_updated.emit(self)
	return amount

func _try_pull_from_input() -> bool:
	var upstream_cell: Vector2i = cell_position + input_offset
	if _is_delivery_hub_cell(upstream_cell):
		var hub_resource: String = _choose_hub_resource()
		if hub_resource.is_empty():
			return false
		if GameManager.consume_resources({hub_resource: throughput_amount}):
			carried_resource = hub_resource
			carried_amount = throughput_amount
			travel_progress = 0.0
			entity_updated.emit(self)
			return true
		return false

	var upstream_entity: Entity = EntityManager.get_entity_at_cell(upstream_cell)
	if upstream_entity == null or upstream_entity is ConveyorEntity:
		return false

	var selected_resource: String = _choose_upstream_resource(upstream_entity)
	if selected_resource.is_empty():
		return false
	var pulled_amount: int = upstream_entity.withdraw_output(selected_resource, throughput_amount)
	if pulled_amount <= 0:
		return false

	carried_resource = selected_resource
	carried_amount = pulled_amount
	travel_progress = 0.0
	entity_updated.emit(self)
	return true

func _try_push_to_output() -> bool:
	var downstream_cell: Vector2i = cell_position + output_offset
	if _is_delivery_hub_cell(downstream_cell):
		GameManager.add_resource_stock({carried_resource: carried_amount})
		return true

	var downstream_entity: Entity = EntityManager.get_entity_at_cell(downstream_cell)
	if downstream_entity == null:
		return false

	if downstream_entity is ConveyorEntity:
		var downstream_conveyor: ConveyorEntity = downstream_entity
		if not downstream_conveyor.expects_input_from(cell_position):
			return false
		return downstream_conveyor.receive_conveyor_item(carried_resource, carried_amount) == carried_amount

	if not downstream_entity.can_accept_input(carried_resource, carried_amount):
		return false
	return downstream_entity.deposit_input(carried_resource, carried_amount) == carried_amount

func _choose_upstream_resource(upstream_entity: Entity) -> String:
	var preferred_resources: Array[String] = _get_preferred_resource_ids()
	for resource_id in preferred_resources:
		if upstream_entity.has_output_resource(resource_id, throughput_amount):
			return resource_id

	var output_snapshot: Dictionary = upstream_entity.get_output_buffer_snapshot()
	for resource_id_variant in output_snapshot.keys():
		var resource_id: String = String(resource_id_variant)
		if int(output_snapshot[resource_id_variant]) >= throughput_amount:
			return resource_id
	return ""

func _choose_hub_resource() -> String:
	var preferred_resources: Array[String] = _get_preferred_resource_ids()
	for resource_id in preferred_resources:
		if GameManager.get_resource_stock(resource_id) >= throughput_amount:
			return resource_id

	var snapshot: Dictionary = GameManager.get_resource_stock_snapshot()
	for resource_id_variant in snapshot.keys():
		var resource_id: String = String(resource_id_variant)
		if int(snapshot[resource_id_variant]) >= throughput_amount:
			return resource_id
	return ""

func _get_preferred_resource_ids() -> Array[String]:
	var preferred: Array[String] = []
	var downstream_entity: Entity = EntityManager.get_entity_at_cell(cell_position + output_offset)
	if downstream_entity == null:
		return preferred
	if downstream_entity is ConveyorEntity:
		return preferred
	var inputs: Dictionary = downstream_entity.current_recipe.get("inputs", {})
	for resource_id in inputs.keys():
		preferred.append(String(resource_id))
	return preferred

func _is_delivery_hub_cell(cell_pos: Vector2i) -> bool:
	if GameManager == null:
		return false
	return GameManager.has_default_delivery_point and GameManager.default_delivery_cell == cell_pos

func _clear_carried_item() -> void:
	carried_resource = ""
	carried_amount = 0
	travel_progress = 0.0
	entity_updated.emit(self)

func _ensure_item_marker() -> Polygon2D:
	var existing_marker: Polygon2D = get_node_or_null("ItemMarker") as Polygon2D
	if existing_marker != null:
		return existing_marker

	var marker: Polygon2D = Polygon2D.new()
	marker.name = "ItemMarker"
	marker.polygon = PackedVector2Array([
		Vector2(0.0, -5.0),
		Vector2(5.0, 0.0),
		Vector2(0.0, 5.0),
		Vector2(-5.0, 0.0),
	])
	marker.z_index = 20
	add_child(marker)
	return marker

func _update_item_marker() -> void:
	if _item_marker == null:
		return
	if carried_resource.is_empty() or carried_amount <= 0:
		_item_marker.hide()
		return
	_item_marker.show()
	_item_marker.color = _get_resource_color(carried_resource)
	var start_offset: Vector2 = _offset_to_marker_position(input_offset)
	var end_offset: Vector2 = _offset_to_marker_position(output_offset)
	_item_marker.position = start_offset.lerp(end_offset, travel_progress)

func _offset_to_marker_position(offset: Vector2i) -> Vector2:
	if offset == Vector2i(1, 0):
		return Vector2(14.0, 0.0)
	if offset == Vector2i(-1, 0):
		return Vector2(-14.0, 0.0)
	if offset == Vector2i(0, 1):
		return Vector2(0.0, 14.0)
	if offset == Vector2i(0, -1):
		return Vector2(0.0, -14.0)
	return Vector2.ZERO

func _get_resource_color(resource_id: String) -> Color:
	match resource_id:
		"charbon":
			return Color(0.18, 0.18, 0.2, 0.95)
		"gaz":
			return Color(0.55, 0.86, 1.0, 0.95)
		"matiere_brute":
			return Color(0.6, 0.46, 0.31, 0.95)
		"metal":
			return Color(0.7, 0.74, 0.8, 0.95)
		"piece_base":
			return Color(0.94, 0.74, 0.34, 0.95)
		"piece_avancee":
			return Color(0.96, 0.42, 0.24, 0.95)
		_:
			return Color(0.92, 0.92, 0.92, 0.95)
