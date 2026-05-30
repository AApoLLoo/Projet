extends Node

const ORDERABLE_RESOURCE_ORDER: Array[String] = [
	"charbon",
	"gaz",
	"matiere_brute",
	"metal",
	"piece_base",
	"piece_avancee",
]

const ORDERABLE_RESOURCES: Dictionary = {
	"charbon": {"label": "Charbon", "unit_cost": 45.0},
	"gaz": {"label": "Gaz", "unit_cost": 70.0},
	"matiere_brute": {"label": "Matiere brute", "unit_cost": 55.0},
	"metal": {"label": "Metal", "unit_cost": 95.0},
	"piece_base": {"label": "Piece de base", "unit_cost": 120.0},
	"piece_avancee": {"label": "Piece avancee", "unit_cost": 240.0},
}

signal order_submitted(order)
signal delivery_started(order)
signal delivery_completed(order)
signal delivery_failed(message)
signal queue_changed(queue_size)
signal delivery_state_changed(is_active, current_order)

@export var truck_scene: PackedScene
@export var spawn_position: Vector2 = Vector2(-200, 100)
@export var exit_position: Vector2 = Vector2(1000, 600)
@export var drive_time: float = 3.0
@export var unload_time: float = 2.0

var _pending_orders: Array[Dictionary] = []
var _current_order: Dictionary = {}
var _delivery_in_progress: bool = false

func get_orderable_resources() -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	for resource_id in ORDERABLE_RESOURCE_ORDER:
		var entry: Dictionary = ORDERABLE_RESOURCES.get(resource_id, {})
		resources.append({
			"id": resource_id,
			"label": String(entry.get("label", resource_id.capitalize())),
			"unit_cost": float(entry.get("unit_cost", 0.0)),
		})
	return resources

func get_unit_cost(resource_id: String) -> float:
	return float(ORDERABLE_RESOURCES.get(resource_id, {}).get("unit_cost", 0.0))

func get_resource_label(resource_id: String) -> String:
	return String(ORDERABLE_RESOURCES.get(resource_id, {}).get("label", resource_id.capitalize()))

func is_delivery_in_progress() -> bool:
	return _delivery_in_progress

func get_queue_size() -> int:
	return _pending_orders.size()

func get_current_order() -> Dictionary:
	return _current_order.duplicate(true)

func submit_order(resource_id: String, quantity: int, custom_delivery_point: Dictionary = {}) -> bool:
	if truck_scene == null:
		_fail_delivery("Aucune scene de camion n'est assignee dans DeliveryManager.")
		return false
	if not ORDERABLE_RESOURCES.has(resource_id):
		_fail_delivery("Ressource inconnue : %s" % resource_id)
		return false

	var safe_quantity: int = maxi(1, quantity)
	var delivery_point: Dictionary = _resolve_delivery_point(custom_delivery_point)
	if not bool(delivery_point.get("has_point", false)):
		_fail_delivery("Choisis un point de livraison sur la carte avant de commander.")
		return false

	var unit_cost: float = get_unit_cost(resource_id)
	var total_cost: float = unit_cost * float(safe_quantity)
	if GameManager and GameManager.credits < total_cost:
		_fail_delivery("Credits insuffisants pour cette commande.")
		return false

	if GameManager:
		GameManager.add_credits(-total_cost)

	var order: Dictionary = {
		"resource_id": resource_id,
		"resource_label": get_resource_label(resource_id),
		"quantity": safe_quantity,
		"unit_cost": unit_cost,
		"total_cost": total_cost,
		"delivery_point": delivery_point.duplicate(true),
	}
	_pending_orders.append(order)
	order_submitted.emit(order.duplicate(true))
	queue_changed.emit(_pending_orders.size())
	_try_start_next_delivery()
	return true

func _resolve_delivery_point(custom_delivery_point: Dictionary) -> Dictionary:
	if bool(custom_delivery_point.get("has_point", false)):
		return _normalize_delivery_point(custom_delivery_point)
	if GameManager and GameManager.has_method("get_default_delivery_point_state"):
		return _normalize_delivery_point(GameManager.get_default_delivery_point_state())
	return {}

func _normalize_delivery_point(raw_state: Dictionary) -> Dictionary:
	if not bool(raw_state.get("has_point", false)):
		return {}
	return {
		"has_point": true,
		"cell_x": int(raw_state.get("cell_x", 0)),
		"cell_y": int(raw_state.get("cell_y", 0)),
		"world_x": float(raw_state.get("world_x", 0.0)),
		"world_y": float(raw_state.get("world_y", 0.0)),
	}

func _try_start_next_delivery() -> void:
	if _delivery_in_progress or _pending_orders.is_empty():
		return

	var next_order: Dictionary = _pending_orders.pop_front()
	queue_changed.emit(_pending_orders.size())
	_start_delivery(next_order)

func _start_delivery(order: Dictionary) -> void:
	var truck_instance: Node2D = truck_scene.instantiate()
	add_child(truck_instance)
	truck_instance.global_position = spawn_position

	_current_order = order.duplicate(true)
	_delivery_in_progress = true
	delivery_state_changed.emit(true, get_current_order())
	delivery_started.emit(get_current_order())

	var point_state: Dictionary = order.get("delivery_point", {})
	var target_position: Vector2 = Vector2(
		float(point_state.get("world_x", 0.0)),
		float(point_state.get("world_y", 0.0))
	)

	var tween: Tween = create_tween()
	tween.tween_property(truck_instance, "global_position", target_position, drive_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_set_truck_unloading_state(truck_instance, true)
	)
	tween.tween_interval(unload_time)
	tween.tween_callback(func():
		_set_truck_unloading_state(truck_instance, false)
		_apply_delivery_payload(order)
	)
	tween.tween_property(truck_instance, "global_position", exit_position, drive_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		truck_instance.queue_free()
		_finish_delivery(order)
	)

func _set_truck_unloading_state(truck_instance: Node2D, unloading: bool) -> void:
	var bar: ProgressBar = truck_instance.get_node_or_null("Truck/loadingbar") as ProgressBar
	var anim: AnimatedSprite2D = truck_instance.get_node_or_null("Truck") as AnimatedSprite2D
	if bar:
		bar.visible = unloading
		if unloading:
			bar.show()
			bar.z_index = 100
	if anim:
		if unloading:
			anim.play("default")
		else:
			anim.stop()
			anim.frame = 0

func _apply_delivery_payload(order: Dictionary) -> void:
	if not GameManager:
		return
	var resource_id: String = String(order.get("resource_id", ""))
	if resource_id.is_empty():
		return
	GameManager.add_resource_stock({resource_id: int(order.get("quantity", 0))})

func _finish_delivery(order: Dictionary) -> void:
	_current_order.clear()
	_delivery_in_progress = false
	delivery_completed.emit(order.duplicate(true))
	delivery_state_changed.emit(false, {})
	_try_start_next_delivery()

func _fail_delivery(message: String) -> void:
	push_warning(message)
	delivery_failed.emit(message)
