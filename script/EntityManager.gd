extends Node

# ─────────────────────────────────────────────────────────────────────────────
# EntityManager – Autoload
# Registre de toutes les entités actives en jeu.
# Recalcule les totaux énergie / CO2 et notifie GameManager.
# ─────────────────────────────────────────────────────────────────────────────

var entities: Dictionary = {}       # entity_id → Entity
var _cell_index: Dictionary = {}    # Vector2i → Entity
var global_power_capacity: float = 0.0
var global_power_demand: float = 0.0
var power_satisfaction: float = 1.0 # 1.0 = 100% de puissance, 0.5 = 50% de puissance
const CARDINAL_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

signal totals_changed(energy_total: float, co2_total: float)

# ─── API ─────────────────────────────────────────────────────────────────────

func register_entity(entity: Entity) -> void:
	entities[entity.entity_id] = entity
	_cell_index[entity.cell_position] = entity
	recalculate_totals()

func update_entity_cell(entity: Entity, old_pos: Vector2i, new_pos: Vector2i) -> void:
	if _cell_index.get(old_pos) == entity:
		_cell_index.erase(old_pos)
	_cell_index[new_pos] = entity

func get_entity_at_cell(cell_pos: Vector2i) -> Entity:
	var entity = _cell_index.get(cell_pos, null)
	if entity != null and not is_instance_valid(entity):
		_cell_index.erase(cell_pos)
		return null
	return entity

func unregister_entity(entity_id: String, expected_entity: Entity = null) -> void:
	if expected_entity != null:
		var registered_entity: Variant = entities.get(entity_id)
		if registered_entity != null and registered_entity != expected_entity:
			return
		# Nettoyer le cell_index pour cette entité
		if is_instance_valid(expected_entity):
			var cell = expected_entity.cell_position
			if _cell_index.get(cell) == expected_entity:
				_cell_index.erase(cell)
		else:
			# Entité déjà libérée : balayage défensif
			var stale_cells: Array = []
			for cell in _cell_index.keys():
				if not is_instance_valid(_cell_index[cell]):
					stale_cells.append(cell)
			for cell in stale_cells:
				_cell_index.erase(cell)
	else:
		var entity = entities.get(entity_id)
		if entity != null and is_instance_valid(entity):
			var cell = entity.cell_position
			if _cell_index.get(cell) == entity:
				_cell_index.erase(cell)
	entities.erase(entity_id)
	recalculate_totals()

func clear_entities() -> void:
	entities.clear()
	_cell_index.clear()
	recalculate_totals()

func recalculate_totals() -> void:
	var energy_total: float = 0.0
	var co2_total: float = 0.0
	global_power_capacity = 0.0
	global_power_demand = 0.0
	var stale: Array = []
	
	for id in entities:
		var entity = entities[id]
		if not is_instance_valid(entity):
			stale.append(id)
			continue
			
		# Calcul Capacité vs Demande (On regarde si la machine est allumée)
		if entity.is_operational():
			if entity.entity_type == "turbine":
				global_power_capacity += entity.get("electricity_output") if entity.get("electricity_output") != null else 100.0
			elif entity.get("electricity_need") != null and entity.electricity_need > 0.0:
				global_power_demand += entity.electricity_need

		energy_total += entity.get_energy_delta()
		co2_total += entity.get_co2_rate()
		
	for id in stale:
		entities.erase(id)
		
	# Calcul du ratio de satisfaction électrique (bridé à 1.0 maximum)
	if global_power_demand > 0.0:
		power_satisfaction = minf(1.0, global_power_capacity / global_power_demand)
	else:
		power_satisfaction = 1.0
		
	totals_changed.emit(energy_total, co2_total)

func get_entities_of_type(entity_type: String) -> Array:
	var result: Array = []
	for entity in entities.values():
		if is_instance_valid(entity) and entity.entity_type == entity_type:
			result.append(entity)
	return result

func count() -> int:
	return entities.size()

func get_adjacent_entities(cell_pos: Vector2i) -> Array:
	var neighbors: Array = []
	for offset in CARDINAL_NEIGHBOR_OFFSETS:
		var neighbor: Entity = get_entity_at_cell(cell_pos + offset)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors

func get_electricity_at_cell(cell_pos: Vector2i) -> float:
	var total: float = 0.0
	for entity in entities.values():
		if not is_instance_valid(entity):
			continue
		if entity.entity_type != "turbine" or not entity.is_operational():
			continue
		var radius: int = entity.get("zone_radius") if entity.get("zone_radius") != null else 20
		var dist: float = Vector2(cell_pos - entity.cell_position).length()
		if dist <= float(radius):
			total += float(entity.get("electricity_output") if entity.get("electricity_output") != null else 100.0)
	return total
