extends Entity
class_name ConveyorEntity

const NEIGHBOR_SEARCH_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]
const ITEM_LANE_BIAS: Vector2 = Vector2(0.0, -6.0)
const BLOCKED_END_RATIO: float = 0.75
const ITEM_SPACING_PROGRESS: float = 0.28

@export var conveyor_kind: String = "belt_right"
@export var input_offset: Vector2i = Vector2i(-1, 0)
@export var output_offset: Vector2i = Vector2i(1, 0)
@export var travel_time: float = 0.45
@export var throughput_amount: int = 1
@export var max_carried_items: int = 1
var is_powered: bool = false
var carried_resource: String = ""
var carried_amount: int = 0
var travel_progress: float = 0.0
var carried_items: Array[Dictionary] = []

const ITEM_TEXTURE: Texture2D = preload("res://asset/resources_basic.png")
const GROUND_MATERIAL_SCENE: PackedScene = preload("res://scene/Materiaux.tscn")
const ITEM_FRAMES: Dictionary = {
	"charbon": 12,
	"gaz": 61,
	"matiere_brute": 35,
	"metal": 14,
	"piece_base": 45,
	"piece_avancee": 47,
}

@onready var _item_marker_root: Node2D = _ensure_item_marker_root()
func _check_neighbor_turbines():
	var rayon = 10
	
	for x in range(-rayon, rayon + 1):
		for y in range(-rayon, rayon + 1):
			if x == 0 and y == 0:
				continue
			
			if Vector2(x, y).length() > float(rayon):  # ← ajoute ça
				continue
			
			var pos = cell_position + Vector2i(x, y)
			var entity = EntityManager.get_entity_at_cell(pos)
			if entity != null and entity.entity_type == "turbine" and entity.is_active:
				if entity != null and entity.entity_type == "turbine" and entity.is_active:
					set_powered(true)
					return
	
	set_powered(false)# ← crucial : aucune turbine trouvée = pas alimenté
		
func _ready() -> void:
	entity_type = conveyor_kind
	super._ready()
	is_active = true  # ← déjà là, mais vérifie que c'est bien APRÈS super._ready()
	_update_item_markers()
	_check_neighbor_turbines.call_deferred()


func _process(delta: float) -> void:
	if not is_active or not is_powered:
		_update_item_markers()
		return

	if not carried_items.is_empty():
		_advance_items(delta)
		if _front_item_ready_to_exit():
			var pushed = _try_push_to_output()
			if pushed:
				_clear_carried_item()

	if _has_input_capacity():
		var pulled = _try_pull_from_input()
		

	_update_item_markers()
	_update_connection_color()
# Colore le tapis selon son état de connexion :
#   Blanc  = connecté des deux côtés (entrée ET sortie)
#   Orange = connecté d'un seul côté (départ ou fin de chaîne)
#   Gris   = isolé (aucune connexion)
func _update_connection_color() -> void:
	var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null:
		return
	var has_in: bool = has_input_connection()
	var has_out: bool = has_output_connection()
	if has_in and has_out:
		anim_sprite.modulate = Color.WHITE
	elif has_in or has_out:
		anim_sprite.modulate = Color(1.0, 0.75, 0.2)
	else:
		anim_sprite.modulate = Color(0.55, 0.55, 0.55)


func get_status_text() -> String:
	if not is_active:
		return "Arret"
	if carried_items.is_empty():
		return "En attente"
	if _front_item_ready_to_exit():
		return "Sortie bloquee"
	return "Transport"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["conveyor_kind"] = conveyor_kind
	data["input_offset_x"] = input_offset.x
	data["input_offset_y"] = input_offset.y
	data["output_offset_x"] = output_offset.x
	data["output_offset_y"] = output_offset.y
	data["carried_items"] = _serialize_carried_items()
	data["carried_resource"] = carried_resource
	data["carried_amount"] = carried_amount
	data["travel_progress"] = travel_progress
	return data

func deserialize(data: Dictionary) -> void:
	conveyor_kind = String(data.get("conveyor_kind", conveyor_kind))
	input_offset = Vector2i(int(data.get("input_offset_x", input_offset.x)), int(data.get("input_offset_y", input_offset.y)))
	output_offset = Vector2i(int(data.get("output_offset_x", output_offset.x)), int(data.get("output_offset_y", output_offset.y)))
	super.deserialize(data)
	_restore_carried_items(data)
	_update_item_markers()

func is_output_target(cell_pos: Vector2i) -> bool:
	return cell_position + output_offset == cell_pos

func expects_input_from(cell_pos: Vector2i) -> bool:
	return cell_position + input_offset == cell_pos

func has_input_connection() -> bool:
	var upstream_cell: Vector2i = cell_position + input_offset
	if _is_delivery_hub_cell(upstream_cell):
		return true
	var preferred_upstream: Entity = EntityManager.get_entity_at_cell(upstream_cell)
	if preferred_upstream != null:
		return true
	var upstream_entity: Entity = _find_upstream_entity(upstream_cell)
	if upstream_entity == null:
		return false
	if upstream_entity is ConveyorEntity:
		var upstream_conveyor: ConveyorEntity = upstream_entity
		return upstream_conveyor.is_output_target(cell_position)
	return true

func has_output_connection() -> bool:
	var downstream_cell: Vector2i = cell_position + output_offset
	if _is_delivery_hub_cell(downstream_cell):
		return true
	# Recherche exacte
	var preferred_downstream: Entity = EntityManager.get_entity_at_cell(downstream_cell)
	if preferred_downstream != null:
		return true
	# Recherche élargie autour de la cellule cible
	for offset in NEIGHBOR_SEARCH_OFFSETS:
		var neighbor: Entity = EntityManager.get_entity_at_cell(downstream_cell + offset)
		if neighbor == null or neighbor == self:
			continue
		if neighbor is ConveyorEntity:
			var nc: ConveyorEntity = neighbor
			if nc.expects_input_from(cell_position):
				return true
		else:
			if (downstream_cell + offset) != (cell_position + input_offset):
				return true
	return false
func is_adjacent_to_cell(target_cell: Vector2i) -> bool:
	var delta: Vector2i = target_cell - cell_position
	return max(abs(delta.x), abs(delta.y)) == 1 and delta != Vector2i.ZERO

func can_release_to_conveyor(target_cell: Vector2i) -> bool:
	if carried_items.is_empty():
		return false
	if not _front_item_ready_to_exit():
		return false
	return is_output_target(target_cell)

func can_accept_conveyor_item(resource_id: String, amount: int = 1) -> bool:
	if resource_id.is_empty() or amount <= 0:
		return false
	return _has_input_capacity()

func receive_conveyor_item(resource_id: String, amount: int = 1) -> int:
	if not can_accept_conveyor_item(resource_id, amount):
		return 0
	carried_items.append({
		"resource_id": resource_id,
		"amount": amount,
		"progress": 0.0,
	})
	_sync_primary_item_state()
	_update_item_markers()
	entity_updated.emit(self)
	return amount

func inject_manual_item(resource_id: String, amount: int = 1) -> bool:
	return receive_conveyor_item(resource_id, amount) == amount

func has_carried_item() -> bool:
	return not carried_items.is_empty()

func eject_carried_item() -> bool:
	if not has_carried_item():
		return false
	var ejected_item: Dictionary = carried_items[0]
	var material_instance: Node = GROUND_MATERIAL_SCENE.instantiate()
	if material_instance == null:
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		material_instance.queue_free()
		return false
	var item_world_position: Vector2 = global_position + _offset_to_marker_position(output_offset) * 0.6
	if material_instance.has_method("set_resource"):
		material_instance.call("set_resource", String(ejected_item.get("resource_id", "")), int(ejected_item.get("amount", 0)))
	else:
		material_instance.set("destination", String(ejected_item.get("resource_id", "")))
		material_instance.set("quantity", int(ejected_item.get("amount", 0)))
	if material_instance is Node2D:
		(material_instance as Node2D).global_position = item_world_position
	current_scene.add_child(material_instance)
	if material_instance.has_method("prepare_ground_spawn"):
		material_instance.call("prepare_ground_spawn", item_world_position)
	_clear_carried_item()
	return true

func _try_pull_from_input() -> bool:
	var upstream_cell: Vector2i = cell_position + input_offset
	if _is_delivery_hub_cell(upstream_cell):
		var hub_resource: String = _choose_hub_resource()
		if hub_resource.is_empty():
			return false
		if GameManager.consume_resources({hub_resource: throughput_amount}):
			return receive_conveyor_item(hub_resource, throughput_amount) == throughput_amount
		return false

	var upstream_entity: Entity = _find_upstream_entity(upstream_cell)
	if upstream_entity == null:
		return false

	if upstream_entity is ConveyorEntity:
		var upstream_conveyor: ConveyorEntity = upstream_entity
		return _try_pull_from_upstream_conveyor(upstream_conveyor, upstream_cell)

	var selected_resource: String = _choose_upstream_resource(upstream_entity)
	if selected_resource.is_empty():
		return false
	var pulled_amount: int = upstream_entity.withdraw_output(selected_resource, throughput_amount)
	if pulled_amount <= 0:
		return false
	return receive_conveyor_item(selected_resource, pulled_amount) == pulled_amount
	
func _try_pull_from_upstream_conveyor(upstream_conveyor: ConveyorEntity, expected_upstream_cell: Vector2i) -> bool:
	var exact_upstream_match: bool = upstream_conveyor.cell_position == expected_upstream_cell
	if not exact_upstream_match and not upstream_conveyor.can_release_to_conveyor(cell_position):
		return false
	var front_item: Dictionary = upstream_conveyor._get_front_item()
	var resource_id: String = String(front_item.get("resource_id", ""))
	var amount: int = int(front_item.get("amount", 0))
	if receive_conveyor_item(resource_id, amount) != amount:
		return false
	upstream_conveyor._clear_carried_item()
	return true

func _try_push_to_output() -> bool:
	var front_item: Dictionary = _get_front_item()
	if front_item.is_empty():
		return false
	var resource_id: String = String(front_item.get("resource_id", ""))
	var amount: int = int(front_item.get("amount", 0))
	var downstream_cell: Vector2i = cell_position + output_offset

	if _is_delivery_hub_cell(downstream_cell):
		GameManager.add_resource_stock({resource_id: amount})
		return true

	var downstream_entity: Entity = _find_downstream_entity(downstream_cell)
	if downstream_entity == null:
		return false

	if downstream_entity is ConveyorEntity:
		var downstream_conveyor: ConveyorEntity = downstream_entity
		var exact_downstream_match: bool = downstream_conveyor.cell_position == downstream_cell
		if not exact_downstream_match and not downstream_conveyor.expects_input_from(cell_position):
			return false
		return downstream_conveyor.receive_conveyor_item(resource_id, amount) == amount

	if not downstream_entity.can_accept_input(resource_id, amount):
		return false
	return downstream_entity.deposit_input(resource_id, amount) == amount
func _find_upstream_entity(preferred_cell: Vector2i) -> Entity:
	var preferred_entity: Entity = EntityManager.get_entity_at_cell(preferred_cell)
	if preferred_entity != null:
		return preferred_entity

	for offset in NEIGHBOR_SEARCH_OFFSETS:
		var neighbor: Entity = EntityManager.get_entity_at_cell(cell_position + offset)
		if neighbor == null or neighbor == self:
			continue
		if neighbor is ConveyorEntity:
			var neighbor_conveyor: ConveyorEntity = neighbor
			if neighbor_conveyor.is_output_target(cell_position):
				return neighbor_conveyor
		else:
			# Bâtiment non-tapis adjacent : valide comme source si pas du côté sortie
			if cell_position + offset != cell_position + output_offset:
				return neighbor
	return null

func _find_downstream_entity(preferred_cell: Vector2i) -> Entity:
	# 1. Recherche exacte sur la cellule cible
	var preferred_entity: Entity = EntityManager.get_entity_at_cell(preferred_cell)
	if preferred_entity != null:
		return preferred_entity

	# 2. Recherche élargie : si un bâtiment non-tapis occupe une cellule
	#    adjacente à preferred_cell (cas entrepôt multi-cellule)
	for offset in NEIGHBOR_SEARCH_OFFSETS:
		var neighbor_cell: Vector2i = preferred_cell + offset
		var neighbor: Entity = EntityManager.get_entity_at_cell(neighbor_cell)
		if neighbor == null or neighbor == self:
			continue
		if neighbor is ConveyorEntity:
			var nc: ConveyorEntity = neighbor
			if nc.expects_input_from(cell_position):
				return nc
		else:
			# Bâtiment non-tapis (entrepôt, usine) : accepte s'il n'est pas derrière nous
			if neighbor_cell != cell_position + input_offset:
				return neighbor
	return null

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
	if not carried_items.is_empty():
		carried_items.remove_at(0)
	_sync_primary_item_state()
	entity_updated.emit(self)

func _ensure_item_marker_root() -> Node2D:
	var legacy_marker: Polygon2D = get_node_or_null("ItemMarker") as Polygon2D
	if legacy_marker != null:
		legacy_marker.queue_free()

	var legacy_sprite: Sprite2D = get_node_or_null("ItemSprite") as Sprite2D
	if legacy_sprite != null:
		legacy_sprite.queue_free()

	var existing_root: Node2D = get_node_or_null("ItemMarkers") as Node2D
	if existing_root != null:
		return existing_root

	var marker_root: Node2D = Node2D.new()
	marker_root.name = "ItemMarkers"
	marker_root.z_index = 20
	add_child(marker_root)
	return marker_root

func _update_item_markers() -> void:
	if _item_marker_root == null:
		return
	_ensure_item_marker_count(carried_items.size())
	var markers: Array = _item_marker_root.get_children()
	for index in range(markers.size()):
		var marker: Sprite2D = markers[index] as Sprite2D
		if marker == null:
			continue
		if index >= carried_items.size():
			marker.hide()
			continue
		var item: Dictionary = carried_items[index]
		var item_progress: float = clampf(float(item.get("progress", 0.0)), 0.0, 1.0)
		var start_offset: Vector2 = _offset_to_marker_position(input_offset)
		var end_offset: Vector2 = _offset_to_marker_position(output_offset)
		if index == 0 and item_progress >= 1.0 and not has_output_connection():
			end_offset *= BLOCKED_END_RATIO
		marker.show()
		marker.frame = int(ITEM_FRAMES.get(String(item.get("resource_id", "")), 0))
		marker.modulate = Color.WHITE
		marker.position = start_offset.lerp(end_offset, item_progress) + ITEM_LANE_BIAS
		marker.z_index = 20 + index

func _ensure_item_marker_count(required_count: int) -> void:
	if _item_marker_root == null:
		return
	while _item_marker_root.get_child_count() < required_count:
		var marker: Sprite2D = Sprite2D.new()
		marker.texture = ITEM_TEXTURE
		marker.hframes = 11
		marker.vframes = 11
		marker.centered = true
		marker.scale = Vector2(0.55, 0.55)
		marker.hide()
		_item_marker_root.add_child(marker)

func _advance_items(delta: float) -> void:
	if carried_items.is_empty():
		return
	var progress_delta: float = delta / maxf(travel_time, 0.01)
	for index in range(carried_items.size()):
		var item: Dictionary = carried_items[index]
		var max_progress: float = 1.0
		if index > 0:
			max_progress = maxf(0.0, float(carried_items[index - 1].get("progress", 0.0)) - ITEM_SPACING_PROGRESS)
		item["progress"] = minf(max_progress, float(item.get("progress", 0.0)) + progress_delta)
		carried_items[index] = item
	_sync_primary_item_state()

func _front_item_ready_to_exit() -> bool:
	if carried_items.is_empty():
		return false
	return float(carried_items[0].get("progress", 0.0)) >= 1.0

func _has_input_capacity() -> bool:
	if carried_items.size() >= max_carried_items:
		return false
	if carried_items.is_empty():
		return true
	var tail_item: Dictionary = carried_items[carried_items.size() - 1]
	return float(tail_item.get("progress", 0.0)) >= ITEM_SPACING_PROGRESS

func _get_front_item() -> Dictionary:
	if carried_items.is_empty():
		return {}
	return carried_items[0]

func _sync_primary_item_state() -> void:
	if carried_items.is_empty():
		carried_resource = ""
		carried_amount = 0
		travel_progress = 0.0
		return
	var front_item: Dictionary = carried_items[0]
	carried_resource = String(front_item.get("resource_id", ""))
	carried_amount = int(front_item.get("amount", 0))
	travel_progress = clampf(float(front_item.get("progress", 0.0)), 0.0, 1.0)

func _serialize_carried_items() -> Array[Dictionary]:
	var serialized_items: Array[Dictionary] = []
	for item in carried_items:
		serialized_items.append({
			"resource_id": String(item.get("resource_id", "")),
			"amount": max(0, int(item.get("amount", 0))),
			"progress": clampf(float(item.get("progress", 0.0)), 0.0, 1.0),
		})
	return serialized_items

func _restore_carried_items(data: Dictionary) -> void:
	carried_items.clear()
	var restored_items_variant: Variant = data.get("carried_items", [])
	if restored_items_variant is Array:
		for item_variant in restored_items_variant:
			if not (item_variant is Dictionary):
				continue
			var item_data: Dictionary = item_variant
			var resource_id: String = String(item_data.get("resource_id", ""))
			var amount: int = max(0, int(item_data.get("amount", 0)))
			if resource_id.is_empty() or amount <= 0:
				continue
			carried_items.append({
				"resource_id": resource_id,
				"amount": amount,
				"progress": clampf(float(item_data.get("progress", 0.0)), 0.0, 1.0),
			})
	if carried_items.is_empty():
		var legacy_resource_id: String = String(data.get("carried_resource", ""))
		var legacy_amount: int = max(0, int(data.get("carried_amount", 0)))
		if not legacy_resource_id.is_empty() and legacy_amount > 0:
			carried_items.append({
				"resource_id": legacy_resource_id,
				"amount": legacy_amount,
				"progress": clampf(float(data.get("travel_progress", 0.0)), 0.0, 1.0),
			})
	_sync_primary_item_state()

func _offset_to_marker_position(offset: Vector2i) -> Vector2:
	if offset == Vector2i(1, 0):
		return Vector2(14.0, 0.0)
	if offset == Vector2i(-1, 0):
		return Vector2(-14.0, 0.0)
	if offset == Vector2i(0, 1):
		return Vector2(0.0, 14.0)
	if offset == Vector2i(0, -1):
		return Vector2(0.0, -14.0)
	if offset == Vector2i(1, -1):
		return Vector2(22.0, -11.0)
	if offset == Vector2i(-1, 1):
		return Vector2(-22.0, 11.0)
	if offset == Vector2i(1, 1):
		return Vector2(22.0, 11.0)
	if offset == Vector2i(-1, -1):
		return Vector2(-22.0, -11.0)
	return Vector2.ZERO
# Dans ConveyorEntity.gd

func refresh_power_state() -> void:
	_check_neighbor_turbines.call_deferred()
	
func set_powered(active: bool) -> void:
	is_powered = active
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null:
		return
	if is_powered:
		anim.play()
	else:
		anim.stop()
		anim.frame = 0
