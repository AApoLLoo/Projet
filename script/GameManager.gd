extends Node

const END_GAME_SCREEN_SCENE: PackedScene = preload("res://scene/end_game_screen.tscn")

const DEFAULT_RESOURCE_STOCK: Dictionary = {
	"charbon": 0,
	"gaz": 0,
	"matiere_brute": 0,
	"metal": 0,
	"piece_base": 0,
	"piece_avancee": 0,
}
const MAX_EXPORT_HISTORY_ENTRIES: int = 5

@export var credits_required_for_victory: int = 1000000
@export var victory_export_resource_id: String = "machine_ultime"
@export var credits_loss_threshold: float = -1.0

# Ressources globales (Maquette HUD)
var credits: float = 12500.0
var energy_usage: float = 0.0  # en kW (positif = consommation nette, négatif = production nette)
var co2_emissions: float = 0.0 # en g/min
const CO2_LIMIT: float = 30.0
var resource_stock: Dictionary = DEFAULT_RESOURCE_STOCK.duplicate(true)
var has_default_delivery_point: bool = false
var default_delivery_cell: Vector2i = Vector2i.ZERO
var default_delivery_position: Vector2 = Vector2.ZERO
var export_history: Array[Dictionary] = []
var _end_state: String = ""
var _end_screen: CanvasLayer = null

# Signaux pour mettre à jour l'UI automatiquement
signal resources_updated
signal stock_changed(stock_snapshot)
signal default_delivery_point_changed(has_point, cell_pos, world_pos)
signal export_history_changed(history)
signal end_state_changed(end_state, title, message)

func _ready() -> void:
	reset_end_state()
	# Synchroniser les totaux énergie/CO2 depuis l'EntityManager
	if EntityManager and not EntityManager.totals_changed.is_connected(_on_totals_changed):
		EntityManager.totals_changed.connect(_on_totals_changed)

func _on_totals_changed(energy_total: float, co2_total: float) -> void:
	energy_usage = energy_total
	co2_emissions = co2_total
	resources_updated.emit()

func apply_saved_state(saved_credits: float, saved_stock: Dictionary = {}, saved_delivery_point: Dictionary = {}, saved_export_history: Array = []) -> void:
	reset_end_state()
	credits = saved_credits
	_set_resource_stock_bulk(saved_stock)
	_restore_default_delivery_point(saved_delivery_point)
	export_history = _sanitize_export_history(saved_export_history)
	_emit_resource_signals(true)
	export_history_changed.emit(get_export_history())
	_check_credit_end_conditions()

func add_credits(amount: float, evaluate_end_conditions: bool = true) -> void:
	credits += amount
	resources_updated.emit()
	if evaluate_end_conditions:
		_check_credit_end_conditions()

func update_energy(amount: float) -> void:
	energy_usage += amount
	resources_updated.emit()

func add_construction_co2(amount: float) -> void:
	co2_emissions += amount
	resources_updated.emit()

func remove_construction_co2(amount: float) -> void:
	co2_emissions = maxf(0.0, co2_emissions - amount)
	resources_updated.emit()

func get_resource_stock(resource_id: String) -> int:
	return int(resource_stock.get(resource_id, 0))

func get_resource_stock_snapshot() -> Dictionary:
	var snapshot: Dictionary = DEFAULT_RESOURCE_STOCK.duplicate(true)
	for resource_id in resource_stock.keys():
		snapshot[resource_id] = max(0, int(resource_stock[resource_id]))
	return snapshot

func set_resource_stock(resource_id: String, amount: int, should_emit: bool = true) -> void:
	resource_stock[resource_id] = max(0, amount)
	_emit_resource_signals(should_emit)

func add_resource_stock(resources: Dictionary, should_emit: bool = true) -> void:
	for resource_id in resources.keys():
		var amount: int = int(resources[resource_id])
		if amount == 0:
			continue
		resource_stock[resource_id] = max(0, get_resource_stock(resource_id) + amount)
	_emit_resource_signals(should_emit)
	resources_updated.emit()

func has_resources(required_resources: Dictionary, multiplier: float = 1.0) -> bool:
	for resource_id in required_resources.keys():
		var required_amount: int = int(ceil(float(required_resources[resource_id]) * multiplier))
		if required_amount <= 0:
			continue
		if get_resource_stock(resource_id) < required_amount:
			return false
	return true

func consume_resources(required_resources: Dictionary, multiplier: float = 1.0) -> bool:
	if not has_resources(required_resources, multiplier):
		return false

	for resource_id in required_resources.keys():
		var required_amount: int = int(ceil(float(required_resources[resource_id]) * multiplier))
		if required_amount <= 0:
			continue
		resource_stock[resource_id] = max(0, get_resource_stock(resource_id) - required_amount)

	_emit_resource_signals(true)
	return true

func set_default_delivery_point(cell_pos: Vector2i, world_pos: Vector2, should_emit: bool = true) -> void:
	has_default_delivery_point = true
	default_delivery_cell = cell_pos
	default_delivery_position = world_pos
	if should_emit:
		default_delivery_point_changed.emit(true, default_delivery_cell, default_delivery_position)

func clear_default_delivery_point(should_emit: bool = true) -> void:
	has_default_delivery_point = false
	default_delivery_cell = Vector2i.ZERO
	default_delivery_position = Vector2.ZERO
	if should_emit:
		default_delivery_point_changed.emit(false, default_delivery_cell, default_delivery_position)

func get_default_delivery_point_state() -> Dictionary:
	return {
		"has_point": has_default_delivery_point,
		"cell_x": default_delivery_cell.x,
		"cell_y": default_delivery_cell.y,
		"world_x": default_delivery_position.x,
		"world_y": default_delivery_position.y,
	}

func get_export_history() -> Array[Dictionary]:
	return export_history.duplicate(true)

func complete_export(resource_id: String, resource_label: String, quantity: int, total_value: float) -> void:
	add_credits(total_value, false)
	record_export_gain(resource_id, resource_label, quantity, total_value)
	if _end_state.is_empty() and not victory_export_resource_id.is_empty() and resource_id == victory_export_resource_id and quantity > 0:
		_trigger_victory("Machine ultime exportee !")
	if _end_state.is_empty():
		_check_credit_end_conditions()

func record_export_gain(resource_id: String, resource_label: String, quantity: int, total_value: float) -> void:
	var hour: int = 0
	var minute: int = 0
	if TimeManager:
		hour = int(TimeManager.current_time)
		minute = int((TimeManager.current_time - hour) * 60)
	var history_entry: Dictionary = {
		"resource_id": resource_id,
		"resource_label": resource_label,
		"quantity": quantity,
		"total_value": total_value,
		"day": TimeManager.current_day if TimeManager else 1,
		"hour": hour,
		"minute": minute,
	}
	export_history.push_front(history_entry)
	while export_history.size() > MAX_EXPORT_HISTORY_ENTRIES:
		export_history.pop_back()
	export_history_changed.emit(get_export_history())

func has_ended() -> bool:
	return not _end_state.is_empty()

func get_end_state() -> String:
	return _end_state

func reset_end_state() -> void:
	_end_state = ""
	if _end_screen != null and is_instance_valid(_end_screen):
		_end_screen.queue_free()
	_end_screen = null
	if get_tree() != null:
		get_tree().paused = false

func trigger_defeat(message: String = "Banqueroute.") -> void:
	_trigger_end_state("defeat", "Defaite", message)

func _check_credit_end_conditions() -> void:
	if has_ended():
		return
	if credits >= float(credits_required_for_victory):
		_trigger_victory("Objectif financier atteint !")
		return
	if credits <= credits_loss_threshold:
		trigger_defeat("L'entreprise est en banqueroute.")

func _trigger_victory(message: String) -> void:
	_trigger_end_state("victory", "Victoire !", message)

func _trigger_end_state(end_state: String, title: String, message: String) -> void:
	if has_ended():
		return
	_end_state = end_state
	if TimeManager:
		TimeManager.is_time_running = false
	_show_end_screen(end_state == "victory", title, message)
	if get_tree() != null:
		get_tree().paused = true
	end_state_changed.emit(end_state, title, message)

func _show_end_screen(is_victory: bool, title: String, message: String) -> void:
	if END_GAME_SCREEN_SCENE == null or get_tree() == null:
		return
	if _end_screen != null and is_instance_valid(_end_screen):
		_end_screen.queue_free()
	var screen_instance: Node = END_GAME_SCREEN_SCENE.instantiate()
	if screen_instance == null:
		return
	if screen_instance is CanvasLayer:
		_end_screen = screen_instance as CanvasLayer
	else:
		_end_screen = null
	if screen_instance.has_method("configure"):
		screen_instance.call("configure", is_victory, title, message, _build_end_summary())
	get_tree().root.add_child(screen_instance)

func _build_end_summary() -> String:
	var day_text: String = "Jour %d" % (TimeManager.current_day if TimeManager else 1)
	return "%s | Credits: %.0f" % [day_text, credits]

func _set_resource_stock_bulk(saved_stock: Dictionary) -> void:
	resource_stock = DEFAULT_RESOURCE_STOCK.duplicate(true)
	for resource_id in saved_stock.keys():
		resource_stock[resource_id] = max(0, int(saved_stock[resource_id]))

func _restore_default_delivery_point(saved_delivery_point: Dictionary) -> void:
	if bool(saved_delivery_point.get("has_point", false)):
		set_default_delivery_point(
			Vector2i(int(saved_delivery_point.get("cell_x", 0)), int(saved_delivery_point.get("cell_y", 0))),
			Vector2(float(saved_delivery_point.get("world_x", 0.0)), float(saved_delivery_point.get("world_y", 0.0))),
			false
		)
	else:
		clear_default_delivery_point(false)

func _sanitize_export_history(raw_history: Array) -> Array[Dictionary]:
	var sanitized_history: Array[Dictionary] = []
	for entry_variant in raw_history:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		sanitized_history.append({
			"resource_id": String(entry.get("resource_id", "")),
			"resource_label": String(entry.get("resource_label", "Ressource")),
			"quantity": int(entry.get("quantity", 0)),
			"total_value": float(entry.get("total_value", 0.0)),
			"day": int(entry.get("day", 1)),
			"hour": int(entry.get("hour", 0)),
			"minute": int(entry.get("minute", 0)),
		})
		if sanitized_history.size() >= MAX_EXPORT_HISTORY_ENTRIES:
			break
	return sanitized_history

func _emit_resource_signals(include_stock_signal: bool) -> void:
	resources_updated.emit()
	if include_stock_signal:
		stock_changed.emit(get_resource_stock_snapshot())
	if EntityManager:
		EntityManager.recalculate_totals()

func apply_co2_penalty() -> float:
	var excess: float = co2_emissions - CO2_LIMIT
	if excess <= 0.0:
		return 0.0
	var penalty: float = excess * 50.0  # 50€ par g/min de dépassement
	add_credits(-penalty)
	return penalty
