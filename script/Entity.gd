extends Node2D
class_name Entity

# ─────────────────────────────────────────────────────────────────────────────
# Entity – Classe de base pour tous les bâtiments interactifs.
# Étendre cette classe dans TurbineEntity.gd, FactoryEntity.gd, etc.
# ─────────────────────────────────────────────────────────────────────────────

# Identifiant unique généré à la création
var entity_id: String = ""

# Type de bâtiment, défini par la sous-classe dans _ready()
var entity_type: String = "unknown"

# Position sur la grille (assignée par BuildingManager après placement)
var cell_position: Vector2i = Vector2i.ZERO

# Buffers logistiques locaux
var input_buffer: Dictionary = {}
var output_buffer: Dictionary = {}
var input_buffer_capacity: int = 32
var output_buffer_capacity: int = 32

# Recette actuellement sélectionnée (dict de RecipeDatabase)
var current_recipe: Dictionary = {}

# Taux de production : 0.0 (arrêt) → 1.0 (100%)
var production_rate: float = 1.0

# Coût de construction (assigné par BuildingManager, utilisé pour la sauvegarde)
var build_cost: float = 0.0

# Si l'entité est en fonctionnement
var is_active: bool = false :
	set(value):
		is_active = value
		if not is_active:
			_production_timer = 0.0
		_on_active_changed(value)
		entity_updated.emit(self)
		EntityManager.recalculate_totals()

var _production_timer: float = 0.0

# ─── Signaux ─────────────────────────────────────────────────────────────────

# Émis quand l'entité est cliquée (non utilisé directement ici, géré par BuildingManager)
signal entity_clicked(entity: Entity)

# Émis quand une propriété change (recette, taux, actif/inactif)
signal entity_updated(entity: Entity)

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	entity_id = _generate_id()
	set_process(true)
	# La sous-classe appelle super._ready() puis définit entity_type et
	# charge ses recettes avant d'appeler _post_ready().
	_post_ready()

func _process(delta: float) -> void:
	if not _can_operate_now():
		return

	var cycle_duration: float = _get_cycle_duration()
	if cycle_duration <= 0.0:
		return

	_production_timer += delta
	while _production_timer >= cycle_duration:
		if not _run_production_cycle():
			_production_timer = 0.0
			break
		_production_timer -= cycle_duration

func _post_ready() -> void:
	# Charger la première recette disponible par défaut
	var available := RecipeDatabase.get_recipes(entity_type)
	if available.size() > 0:
		current_recipe = available[0]
	EntityManager.register_entity(self)

func _exit_tree() -> void:
	EntityManager.unregister_entity(entity_id, self)

# ─── Propriétés calculées ────────────────────────────────────────────────────

# kW effectif : recipe.energy_delta × taux × (1 si actif, 0 sinon)
func get_energy_delta() -> float:
	if not _can_operate_now():
		return 0.0
	return current_recipe.get("energy_delta", 0.0) * production_rate

# g/min effectif
func get_co2_rate() -> float:
	if not _can_operate_now():
		return 0.0
	return current_recipe.get("co2_rate", 0.0) * production_rate

# ─── Méthodes publiques ──────────────────────────────────────────────────────

func set_recipe(recipe: Dictionary) -> void:
	current_recipe = recipe
	_production_timer = 0.0
	entity_updated.emit(self)
	EntityManager.recalculate_totals()

func set_production_rate(rate: float) -> void:
	production_rate = clampf(rate, 0.0, 1.0)
	_production_timer = 0.0
	entity_updated.emit(self)
	EntityManager.recalculate_totals()

# Retourne un dict résumé des stats courantes
func get_stats() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"recipe_id": current_recipe.get("id", ""),
		"production_rate": production_rate,
		"is_active": is_active,
		"energy_delta": get_energy_delta(),
		"co2_rate": get_co2_rate(),
		"cell_position": cell_position,
		"status_text": get_status_text()
	}

func get_status_text() -> String:
	if not is_active:
		return "Arret"
	if current_recipe.is_empty():
		return "Aucune recette"
	if not _has_output_capacity_for_recipe():
		return "Sortie bloquee"
	var inputs: Dictionary = current_recipe.get("inputs", {})
	if not inputs.is_empty() and not _has_required_inputs():
		return "En attente de ressources"
	return "Operationnel"

func get_input_buffer_snapshot() -> Dictionary:
	return input_buffer.duplicate(true)

func get_output_buffer_snapshot() -> Dictionary:
	return output_buffer.duplicate(true)

func get_total_buffer_load(buffer_name: String) -> int:
	match buffer_name:
		"input":
			return _get_buffer_load(input_buffer)
		"output":
			return _get_buffer_load(output_buffer)
		_:
			return 0

func get_buffer_amount(buffer_name: String, resource_id: String) -> int:
	match buffer_name:
		"input":
			return int(input_buffer.get(resource_id, 0))
		"output":
			return int(output_buffer.get(resource_id, 0))
		_:
			return 0

func can_accept_input(resource_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not _expects_input_resource(resource_id):
		return false
	return _get_buffer_load(input_buffer) + amount <= input_buffer_capacity

func deposit_input(resource_id: String, amount: int = 1) -> int:
	if not can_accept_input(resource_id, amount):
		return 0
	input_buffer[resource_id] = get_buffer_amount("input", resource_id) + amount
	_emit_logistics_update()
	return amount

func has_output_resource(resource_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	return get_buffer_amount("output", resource_id) >= amount

func withdraw_output(resource_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var available: int = min(amount, get_buffer_amount("output", resource_id))
	if available <= 0:
		return 0
	output_buffer[resource_id] = get_buffer_amount("output", resource_id) - available
	_cleanup_buffer(output_buffer, resource_id)
	_emit_logistics_update()
	return available

# Sérialisation pour la sauvegarde future
func serialize() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"cell_x": cell_position.x,
		"cell_y": cell_position.y,
		"recipe_id": current_recipe.get("id", ""),
		"production_rate": production_rate,
		"is_active": is_active,
		"build_cost": build_cost,
		"input_buffer": get_input_buffer_snapshot(),
		"output_buffer": get_output_buffer_snapshot(),
	}

# Restauration depuis une sauvegarde
func deserialize(data: Dictionary) -> void:
	var old_id := entity_id
	entity_id = data.get("entity_id", entity_id)
	# Si l'ID a changé (restauration depuis sauvegarde), mettre à jour l'entrée dans EntityManager
	# pour que _exit_tree() désenregistre correctement la bonne clé.
	if old_id != entity_id and EntityManager.entities.has(old_id):
		EntityManager.entities.erase(old_id)
		EntityManager.entities[entity_id] = self
	cell_position = Vector2i(data.get("cell_x", 0), data.get("cell_y", 0))
	production_rate = data.get("production_rate", 1.0)
	var rid: String = data.get("recipe_id", "")
	if rid != "":
		var r := RecipeDatabase.get_recipe_by_id(rid)
		if not r.is_empty():
			current_recipe = r
	var restored_input_buffer: Variant = data.get("input_buffer", {})
	input_buffer = _sanitize_buffer(restored_input_buffer if restored_input_buffer is Dictionary else {})
	var restored_output_buffer: Variant = data.get("output_buffer", {})
	output_buffer = _sanitize_buffer(restored_output_buffer if restored_output_buffer is Dictionary else {})
	# is_active en dernier pour déclencher le setter une seule fois
	is_active = data.get("is_active", false)

# ─── À surcharger dans les sous-classes ──────────────────────────────────────

# Appelé quand is_active change (ex: jouer/arrêter une animation)
func _on_active_changed(_active: bool) -> void:
	pass

func _can_operate_now() -> bool:
	if not is_active or current_recipe.is_empty() or production_rate <= 0.0:
		return false
	if not _has_output_capacity_for_recipe():
		return false
	var inputs: Dictionary = current_recipe.get("inputs", {})
	if inputs.is_empty():
		return true
	return _has_required_inputs()

func _has_required_inputs() -> bool:
	var inputs: Dictionary = current_recipe.get("inputs", {})
	for resource_id in inputs.keys():
		if get_buffer_amount("input", String(resource_id)) < int(inputs[resource_id]):
			return false
	return true

func _get_cycle_duration() -> float:
	if current_recipe.is_empty():
		return 0.0
	var base_duration: float = maxf(0.1, float(current_recipe.get("production_time", 1.0)))
	return base_duration / maxf(production_rate, 0.01)

func _run_production_cycle() -> bool:
	var inputs: Dictionary = current_recipe.get("inputs", {})
	if not inputs.is_empty():
		if not _consume_input_buffer(inputs):
			entity_updated.emit(self)
			EntityManager.recalculate_totals()
			return false

	var outputs: Dictionary = current_recipe.get("outputs", {})
	if not _store_cycle_outputs(outputs):
		_restore_consumed_inputs(inputs)
		entity_updated.emit(self)
		EntityManager.recalculate_totals()
		return false

	entity_updated.emit(self)
	EntityManager.recalculate_totals()
	return true

func _consume_input_buffer(required_resources: Dictionary) -> bool:
	if not _has_required_inputs():
		return false
	for resource_id in required_resources.keys():
		var resource_key: String = String(resource_id)
		input_buffer[resource_key] = get_buffer_amount("input", resource_key) - int(required_resources[resource_id])
		_cleanup_buffer(input_buffer, resource_key)
	return true

func _restore_consumed_inputs(required_resources: Dictionary) -> void:
	for resource_id in required_resources.keys():
		var resource_key: String = String(resource_id)
		input_buffer[resource_key] = get_buffer_amount("input", resource_key) + int(required_resources[resource_id])

func _store_cycle_outputs(outputs: Dictionary) -> bool:
	for resource_id in outputs.keys():
		if resource_id == "energie":
			continue
		var resource_key: String = String(resource_id)
		var amount: int = int(outputs[resource_id])
		if amount <= 0:
			continue
		if _get_buffer_load(output_buffer) + amount > output_buffer_capacity:
			return false
		output_buffer[resource_key] = get_buffer_amount("output", resource_key) + amount
	return true

func _has_output_capacity_for_recipe() -> bool:
	var outputs: Dictionary = current_recipe.get("outputs", {})
	if outputs.is_empty():
		return true
	var projected_load: int = _get_buffer_load(output_buffer)
	for resource_id in outputs.keys():
		if resource_id == "energie":
			continue
		projected_load += int(outputs[resource_id])
	return projected_load <= output_buffer_capacity

func _expects_input_resource(resource_id: String) -> bool:
	var inputs: Dictionary = current_recipe.get("inputs", {})
	return inputs.has(resource_id)

func _get_buffer_load(buffer: Dictionary) -> int:
	var total: int = 0
	for amount in buffer.values():
		total += int(amount)
	return total

func _cleanup_buffer(buffer: Dictionary, resource_id: String) -> void:
	if int(buffer.get(resource_id, 0)) <= 0:
		buffer.erase(resource_id)

func _sanitize_buffer(buffer_data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for resource_id in buffer_data.keys():
		var amount: int = max(0, int(buffer_data[resource_id]))
		if amount > 0:
			sanitized[String(resource_id)] = amount
	return sanitized

func _emit_logistics_update() -> void:
	entity_updated.emit(self)

# ─── Interne ─────────────────────────────────────────────────────────────────

static func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]
