extends Node

# ─────────────────────────────────────────────────────────────────────────────
# EntityManager – Autoload
# Registre de toutes les entités actives en jeu.
# Recalcule les totaux énergie / CO2 et notifie GameManager.
# ─────────────────────────────────────────────────────────────────────────────

# Dictionnaire entity_id -> Entity
var entities: Dictionary = {}
const CARDINAL_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

# Émis quand les totaux changent
# energy_total : kW net (négatif = production nette, positif = consommation nette)
# co2_total    : g/min total
signal totals_changed(energy_total: float, co2_total: float)

# ─── API ─────────────────────────────────────────────────────────────────────

func register_entity(entity: Entity) -> void:
	print("EntityManager : Enregistrement de ", entity.entity_type, " à ", entity.cell_position)
	entities[entity.entity_id] = entity
	recalculate_totals()

func unregister_entity(entity_id: String, expected_entity: Entity = null) -> void:
	if expected_entity != null:
		var registered_entity: Variant = entities.get(entity_id)
		if registered_entity != null and registered_entity != expected_entity:
			return
	entities.erase(entity_id)
	recalculate_totals()

func clear_entities() -> void:
	entities.clear()
	recalculate_totals()

# Somme toutes les contributions énergie et CO2 des entités actives.
func recalculate_totals() -> void:
	var energy_total: float = 0.0
	var co2_total: float = 0.0
	var stale: Array = []
	for id in entities:
		var entity = entities[id]
		if not is_instance_valid(entity):
			stale.append(id)
			continue
		energy_total += entity.get_energy_delta()
		co2_total += entity.get_co2_rate()
	# Nettoyer les références périmées
	for id in stale:
		entities.erase(id)
	totals_changed.emit(energy_total, co2_total)

# Retourne toutes les entités d'un type donné
func get_entities_of_type(entity_type: String) -> Array:
	var result: Array = []
	for entity in entities.values():
		if entity.entity_type == entity_type:
			result.append(entity)
	return result

# Retourne le nombre total d'entités enregistrées
func count() -> int:
	return entities.size()

func get_entity_at_cell(cell_pos: Vector2i) -> Entity:
	for id in entities:
		var entity = entities[id]
		
		if not is_instance_valid(entity):
			continue
			
		# DEBUG TRÈS PRÉCIS
		if entity.cell_position == cell_pos:
			return entity # Succès !
		else:
			# On vérifie si par hasard ce n'est pas un problème de Vector2 vs Vector2i
			# (Si les valeurs sont identiques mais le type diffère, le == peut échouer)
			if Vector2i(entity.cell_position) == cell_pos:
				# Si ça rentre ici, c'est que ton objet a une position qui ressemble à un Vector2
				# alors qu'il devrait être un Vector2i
				print("DEBUG : Position correspondante trouvée mais type différent. Entité : ", entity.cell_position, " Cherché : ", cell_pos)
				return entity
	
	return null

func get_adjacent_entities(cell_pos: Vector2i) -> Array:
	var neighbors: Array = []
	for offset in CARDINAL_NEIGHBOR_OFFSETS:
		var neighbor: Entity = get_entity_at_cell(cell_pos + offset)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors
