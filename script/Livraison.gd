extends Node

const JOB_IMPORT: String = "import"
const JOB_EXPORT: String = "export"
const EXPORT_MARGIN_FACTOR: float = 0.28
const EXPORT_ENERGY_COST_PER_KW_MINUTE: float = 0.25
const EXPORT_TIME_COST_PER_SECOND: float = 1.5
@export var delivery_offset: Vector2 = Vector2(60,110)  # décalage à gauche
const ORDERABLE_RESOURCE_ORDER: Array[String] = [
	"charbon",
	"gaz",
	"matiere_brute",
	"metal",
	"piece_base",
	"piece_avancee",
]

const RESOURCE_CATALOG: Dictionary = {
	"charbon": {
		"label": "Charbon",
		"import_unit_cost": 45.0,
		"export_unit_value": 0.0,
		"can_import": true,
		"can_export": false,
	},
	"gaz": {
		"label": "Gaz",
		"import_unit_cost": 70.0,
		"export_unit_value": 0.0,
		"can_import": true,
		"can_export": false,
	},
	"matiere_brute": {
		"label": "Matiere brute",
		"import_unit_cost": 55.0,
		"export_unit_value": 0.0,
		"can_import": true,
		"can_export": false,
	},
	"metal": {
		"label": "Metal",
		"import_unit_cost": 95.0,
		"export_unit_value": 0.0,
		"can_import": true,
		"can_export": false,
	},
	"piece_base": {
		"label": "Piece de base",
		"import_unit_cost": 120.0,
		"export_unit_value": 180.0,  
		"can_import": false,
		"can_export": true,
	},
	"piece_avancee": {
		"label": "Piece avancee",
		"import_unit_cost": 240.0,
		"export_unit_value": 420.0,   
		"can_import": false,
		"can_export": true,
	},
}

signal order_submitted(order)
signal delivery_started(order)
signal delivery_completed(order)
signal delivery_failed(message)
signal queue_changed(queue_size)
signal delivery_state_changed(is_active, current_order)

@export var truck_scene: PackedScene
@export var materiau_scene: PackedScene  
@export var spawn_position: Vector2 = Vector2(-200, 100)
@export var exit_position: Vector2 = Vector2(1000, 600)
@export var drive_time: float = 3.0
@export var unload_time: float = 2.0

var _pending_orders: Array[Dictionary] = []
var _current_order: Dictionary = {}
var _delivery_in_progress: bool = false

func get_orderable_resources(job_type: String = JOB_IMPORT) -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	for resource_id in ORDERABLE_RESOURCE_ORDER:
		if not _is_resource_available_for_job(resource_id, job_type):
			continue
		var entry: Dictionary = RESOURCE_CATALOG.get(resource_id, {})
		resources.append({
			"id": resource_id,
			"label": String(entry.get("label", resource_id.capitalize())),
			"unit_cost": get_unit_cost(resource_id, job_type),
			"estimated_production_cost": get_estimated_production_cost(resource_id),
			"margin_value": get_margin_value(resource_id),
			"margin_percent": get_margin_percent(resource_id),
			"job_type": job_type,
		})
	return resources

func get_unit_cost(resource_id: String, job_type: String = JOB_IMPORT) -> float:
	var resource_entry: Dictionary = RESOURCE_CATALOG.get(resource_id, {})
	if job_type == JOB_EXPORT:
		return _get_export_unit_value(resource_id)
	return float(resource_entry.get("import_unit_cost", 0.0))

func get_resource_label(resource_id: String) -> String:
	return String(RESOURCE_CATALOG.get(resource_id, {}).get("label", resource_id.capitalize()))

func get_estimated_production_cost(resource_id: String) -> float:
	return _get_estimated_production_cost(resource_id)

func get_margin_value(resource_id: String) -> float:
	return _get_export_unit_value(resource_id) - _get_estimated_production_cost(resource_id)

func get_margin_percent(resource_id: String) -> float:
	var production_cost: float = _get_estimated_production_cost(resource_id)
	if is_zero_approx(production_cost):
		return 0.0
	return get_margin_value(resource_id) / production_cost

func is_delivery_in_progress() -> bool:
	return _delivery_in_progress

func get_queue_size() -> int:
	return _pending_orders.size()

func get_current_order() -> Dictionary:
	return _current_order.duplicate(true)

func submit_order(resource_id: String, quantity: int, custom_delivery_point: Dictionary = {}) -> bool:
	return _submit_job(JOB_IMPORT, resource_id, quantity, custom_delivery_point)

func submit_export(resource_id: String, quantity: int, custom_delivery_point: Dictionary = {}) -> bool:
	return _submit_job(JOB_EXPORT, resource_id, quantity, custom_delivery_point)

func _submit_job(job_type: String, resource_id: String, quantity: int, custom_delivery_point: Dictionary = {}) -> bool:
	if truck_scene == null:
		_fail_delivery("Aucune scene de camion n'est assignee dans DeliveryManager.")
		return false
	if not RESOURCE_CATALOG.has(resource_id):
		_fail_delivery("Ressource inconnue : %s" % resource_id)
		return false
	if not _is_resource_available_for_job(resource_id, job_type):
		_fail_delivery("Cette ressource ne peut pas etre %see." % [_get_job_action_label(job_type)])
		return false

	var safe_quantity: int = maxi(1, quantity)
	var delivery_point: Dictionary = _resolve_delivery_point(custom_delivery_point)
	if not bool(delivery_point.get("has_point", false)):
		_fail_delivery("Choisis un point de livraison sur la carte avant de lancer ce trajet.")
		return false

	var unit_cost: float = get_unit_cost(resource_id, job_type)
	var total_cost: float = unit_cost * float(safe_quantity)
	if job_type == JOB_IMPORT and GameManager and GameManager.credits < total_cost:
		_fail_delivery("Credits insuffisants pour cette commande.")
		return false
	if job_type == JOB_EXPORT and (GameManager == null or not GameManager.has_resources({resource_id: safe_quantity})):
		_fail_delivery("Stock insuffisant pour exporter %s x%d." % [get_resource_label(resource_id), safe_quantity])
		return false

	if job_type == JOB_IMPORT and GameManager:
		GameManager.add_credits(-total_cost)

	var order: Dictionary = {
		"job_type": job_type,
		"job_label": _get_job_label(job_type),
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
	if not _prepare_job_for_dispatch(next_order):
		_try_start_next_delivery()
		return
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
	) + delivery_offset

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
	# ── Ajoute cette ligne pour la porte ──
	var door: AnimatedSprite2D = truck_instance.get_node_or_null("DoorSprite") as AnimatedSprite2D
	# ──────────────────────────────────────
	

	if bar:
		if unloading:
			bar.value = 0
			bar.max_value = 100
			bar.show()
			bar.z_index = 100
			var bar_tween: Tween = create_tween()
			bar_tween.tween_property(bar, "value", 100.0, unload_time)
		else:
			bar.hide()
			bar.value = 0
	
	if anim:
		if unloading:
			anim.play("default")
		else:
			anim.stop()
			anim.frame = 0
	
	# ── Contrôle de la porte ──
	if door:
		if unloading:
			door.play("open")
		else:
			door.play_backwards("open")
	# ──────────────────────────
# ─── MODIFIÉ : spawn des matériaux au point de livraison ───────────────────────
# Dans Projet/script/Livraison.gd


func _apply_delivery_payload(order: Dictionary) -> void:
	if not GameManager:
		return
	
	var job_type: String = String(order.get("job_type", JOB_IMPORT))
	var resource_id: String = String(order.get("resource_id", ""))
	var quantity: int = int(order.get("quantity", 0))
	
	# Chercher l'entrepôt le plus proche du point de livraison
	var best_entrepot = _find_nearest_entrepot(order.get("delivery_point", {}))
	
	if job_type == JOB_EXPORT:
		# Export : ressources déjà consommées dans _prepare_job_for_dispatch
		# On ajoute les crédits ET on valide les contrats
		GameManager.add_credits(float(order.get("total_cost", 0.0)))
		if ContractManager:
			ContractManager.try_fulfill_contracts(resource_id, quantity)
		return

	# Import : Stocker dans l'entrepôt le plus proche
	if best_entrepot and best_entrepot.has_method("deposit_input"):
		best_entrepot.deposit_input(resource_id, quantity)
	else:
		push_warning("Livraison: aucun entrepôt trouvé, ajout direct au stock.")
		GameManager.add_resource_stock({resource_id: quantity})

func _find_nearest_entrepot(delivery_point: Dictionary) -> Node:
	var entrepots = get_tree().get_nodes_in_group("entrepot")
	if entrepots.is_empty():
		return null
	if entrepots.size() == 1:
		return entrepots[0]
	# Trouver le plus proche du point de livraison
	var target_pos := Vector2(
		float(delivery_point.get("world_x", 0.0)),
		float(delivery_point.get("world_y", 0.0))
	)
	var nearest = entrepots[0]
	var min_dist := INF
	for e in entrepots:
		if not is_instance_valid(e):
			continue
		var dist := target_pos.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest

func _finish_delivery(order: Dictionary) -> void:
	_current_order.clear()
	_delivery_in_progress = false
	delivery_completed.emit(order.duplicate(true))
	delivery_state_changed.emit(false, {})
	_try_start_next_delivery()

func _fail_delivery(message: String) -> void:
	push_warning(message)
	delivery_failed.emit(message)
	

func _prepare_job_for_dispatch(order: Dictionary) -> bool:
	var job_type: String = String(order.get("job_type", JOB_IMPORT))
	if job_type != JOB_EXPORT:
		return true

	if GameManager == null:
		_fail_delivery("GameManager introuvable pour preparer l'export.")
		return false

	var resource_id: String = String(order.get("resource_id", ""))
	var quantity: int = int(order.get("quantity", 0))

	if resource_id.is_empty() or quantity <= 0:
		_fail_delivery("Export invalide: donnees de ressource manquantes.")
		return false

	var entrepot = _find_nearest_entrepot(order.get("delivery_point", {}))

	if entrepot and entrepot.has_method("give_resources"):
		if not entrepot.give_resources(resource_id, quantity):
			_fail_delivery("Stock insuffisant dans l'entrepot pour exporter %s x%d." % [get_resource_label(resource_id), quantity])
			return false
		return true

	if not GameManager.consume_resources({resource_id: quantity}):
		_fail_delivery("Stock insuffisant au depart du camion pour exporter %s x%d." % [get_resource_label(resource_id), quantity])
		return false

	return true

func _is_resource_available_for_job(resource_id: String, job_type: String) -> bool:
	var resource_entry: Dictionary = RESOURCE_CATALOG.get(resource_id, {})
	if job_type == JOB_EXPORT:
		return bool(resource_entry.get("can_export", false))
	return bool(resource_entry.get("can_import", false))

func _get_job_label(job_type: String) -> String:
	if job_type == JOB_EXPORT:
		return "Export"
	return "Import"

func _get_job_action_label(job_type: String) -> String:
	if job_type == JOB_EXPORT:
		return "export"
	return "import"

func _get_export_unit_value(resource_id: String) -> float:
	var resource_entry: Dictionary = RESOURCE_CATALOG.get(resource_id, {})
	var configured_value: float = float(resource_entry.get("export_unit_value", 0.0))
	if configured_value > 0.0:
		return configured_value
	var estimated_cost: float = _get_estimated_production_cost(resource_id)
	if estimated_cost <= 0.0:
		return 0.0
	return snappedf(estimated_cost * (1.0 + EXPORT_MARGIN_FACTOR), 0.01)

func _get_estimated_production_cost(resource_id: String, visited: Array[String] = []) -> float:
	if visited.has(resource_id):
		return 0.0

	var recipe: Dictionary = _find_recipe_for_output(resource_id)
	if recipe.is_empty():
		return float(RESOURCE_CATALOG.get(resource_id, {}).get("import_unit_cost", 0.0))

	var next_visited: Array[String] = visited.duplicate()
	next_visited.append(resource_id)
	var inputs: Dictionary = recipe.get("inputs", {})
	var total_input_cost: float = 0.0
	for input_id in inputs.keys():
		var quantity: float = float(inputs[input_id])
		total_input_cost += _get_estimated_production_cost(String(input_id), next_visited) * quantity

	var production_time: float = float(recipe.get("production_time", 0.0))
	var energy_delta: float = maxf(0.0, float(recipe.get("energy_delta", 0.0)))
	var energy_cost: float = (energy_delta * (production_time / 60.0)) * EXPORT_ENERGY_COST_PER_KW_MINUTE
	var time_cost: float = production_time * EXPORT_TIME_COST_PER_SECOND
	var output_quantity: float = maxf(1.0, float(recipe.get("outputs", {}).get(resource_id, 1.0)))
	return snappedf((total_input_cost + energy_cost + time_cost) / output_quantity, 0.01)

func _find_recipe_for_output(resource_id: String) -> Dictionary:
	for recipe_group in RecipeDatabase.recipes.values():
		for recipe_variant in recipe_group:
			var recipe: Dictionary = recipe_variant
			var outputs: Dictionary = recipe.get("outputs", {})
			if outputs.has(resource_id):
				return recipe
	return {}

func get_save_state() -> Dictionary:
	return {
		"pending_orders": _pending_orders.duplicate(true),
		"current_order": _current_order.duplicate(true) if _delivery_in_progress else {},
		"delivery_in_progress": _delivery_in_progress
	}
	var current_order_data: Variant = null
	if _delivery_in_progress and not _current_order.is_empty():
		current_order_data = _current_order.duplicate(true)
	return {
		"pending_orders": _pending_orders.duplicate(true),
		"current_order": current_order_data,
	}

func apply_save_state(data: Dictionary) -> void:
	_pending_orders.clear()
	_current_order.clear()
	_delivery_in_progress = false

	# Livraison qui était en cours au moment de la sauvegarde
	var current_order_data: Variant = data.get("current_order")
	if current_order_data is Dictionary and not current_order_data.is_empty():
		var job_type: String = String(current_order_data.get("job_type", JOB_IMPORT))
		if job_type == JOB_EXPORT:
			# Le stock était déjà consommé avant la sauvegarde → créditer directement
			if GameManager:
				GameManager.add_credits(float(current_order_data.get("total_cost", 0.0)))
		else:
			# Import : les crédits étaient déjà déduits → remettre en tête de file
			_pending_orders.append(current_order_data.duplicate(true))

	# Commandes en attente (non encore démarrées)
	var raw_pending: Variant = data.get("pending_orders", [])
	if raw_pending is Array:
		for order in raw_pending:
			if order is Dictionary:
				_pending_orders.append(order.duplicate(true))

	var saved_current: Variant = data.get("current_order", {})
	if saved_current is Dictionary and not saved_current.is_empty():
		_pending_orders.push_front(saved_current.duplicate(true))

	queue_changed.emit(_pending_orders.size())
	delivery_state_changed.emit(false, {})
	queue_changed.emit(_pending_orders.size())
	_try_start_next_delivery()
