extends Node

const DEFAULT_RESOURCE_STOCK: Dictionary = {
	"charbon": 0,
	"gaz": 0,
	"matiere_brute": 0,
	"metal": 0,
	"piece_base": 0,
	"piece_avancee": 0,
}

# Ressources globales (Maquette HUD)
var credits: float = 12500.0
var energy_usage: float = 0.0  # en kW (positif = consommation nette, négatif = production nette)
var co2_emissions: float = 0.0 # en g/min
var resource_stock: Dictionary = DEFAULT_RESOURCE_STOCK.duplicate(true)
var has_default_delivery_point: bool = false
var default_delivery_cell: Vector2i = Vector2i.ZERO
var default_delivery_position: Vector2 = Vector2.ZERO

# Signaux pour mettre à jour l'UI automatiquement
signal resources_updated
signal stock_changed(stock_snapshot)
signal default_delivery_point_changed(has_point, cell_pos, world_pos)

func _ready() -> void:
	# Synchroniser les totaux énergie/CO2 depuis l'EntityManager
	if EntityManager and not EntityManager.totals_changed.is_connected(_on_totals_changed):
		EntityManager.totals_changed.connect(_on_totals_changed)

func _on_totals_changed(energy_total: float, co2_total: float) -> void:
	energy_usage = energy_total
	co2_emissions = co2_total
	resources_updated.emit()

func apply_saved_state(saved_credits: float, saved_stock: Dictionary = {}, saved_delivery_point: Dictionary = {}) -> void:
	credits = saved_credits
	_set_resource_stock_bulk(saved_stock)
	_restore_default_delivery_point(saved_delivery_point)
	_emit_resource_signals(true)

func add_credits(amount: float) -> void:
	credits += amount
	resources_updated.emit()

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

func _emit_resource_signals(include_stock_signal: bool) -> void:
	resources_updated.emit()
	if include_stock_signal:
		stock_changed.emit(get_resource_stock_snapshot())
	if EntityManager:
		EntityManager.recalculate_totals()
