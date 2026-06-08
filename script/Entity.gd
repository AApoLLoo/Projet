extends Node2D
class_name Entity

const HITBOX_COLLISION_LAYER: int = 1 << 3

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

# Besoin en électricité (kW). 0.0 = pas de besoin (tapis, entrepôts, turbines).
# La turbine la plus proche doit produire au moins cette valeur pour que la machine fonctionne.
var electricity_need: float = 10.0

# Coût de construction (assigné par BuildingManager, utilisé pour la sauvegarde)
var build_cost: float = 0.0

# Si l'entité est en fonctionnement
var is_active: bool = false :
	set(value):
		is_active = value
		if not is_active:
			_production_timer = 0.0
		_refresh_runtime_state()

@export var is_broken: bool = false
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var wear_per_cycle: float = 0.35
@export var breakdown_threshold: float = 20.0
@export_range(0.0, 1.0, 0.01) var breakdown_chance_per_cycle: float = 0.08

var _production_timer: float = 0.0
var _hitbox_area: Area2D = null
var _production_bar: ProgressBar = null
# Limite de stockage par type d'objet
@export var max_input_stock: int = 50
@export var max_output_stock: int = 50
# ─── Signaux ─────────────────────────────────────────────────────────────────

# Émis quand l'entité est cliquée (non utilisé directement ici, géré par BuildingManager)
signal entity_clicked(entity: Entity)

# Émis quand une propriété change (recette, taux, actif/inactif)
signal entity_updated(entity: Entity)

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	#print("Entity _ready, cell_position = ", cell_position)
	entity_id = _generate_id()
	set_process(true)
	_production_bar = get_node_or_null("ProductionBar") as ProgressBar
	_update_production_bar()
	_ensure_hitbox()
	# La sous-classe appelle super._ready() puis définit entity_type et
	# charge ses recettes avant d'appeler _post_ready().
	_post_ready()

func _process(delta: float) -> void:
	_update_production_bar()
	if not _can_operate_now():
		return

	var cycle_duration: float = _get_cycle_duration()
	if cycle_duration <= 0.0:
		_update_production_bar()
		return

	_production_timer += delta
	while _production_timer >= cycle_duration:
		if not _run_production_cycle():
			_production_timer = 0.0
			break
		_production_timer -= cycle_duration
	_update_production_bar()

func _post_ready() -> void:
	# Charger la première recette disponible par défaut
	var available := RecipeDatabase.get_recipes(entity_type)
	if available.size() > 0:
		current_recipe = available[0]
	EntityManager.register_entity(self)

func get_hitbox_area() -> Area2D:
	if _hitbox_area == null or not is_instance_valid(_hitbox_area):
		_hitbox_area = get_node_or_null("HitboxArea") as Area2D
	return _hitbox_area

func _exit_tree() -> void:
	EntityManager.unregister_entity(entity_id, self)

func _ensure_hitbox() -> void:
	var hitbox_area: Area2D = get_hitbox_area()
	if hitbox_area == null:
		hitbox_area = Area2D.new()
		hitbox_area.name = "HitboxArea"
		hitbox_area.input_pickable = true
		hitbox_area.collision_layer = HITBOX_COLLISION_LAYER
		hitbox_area.collision_mask = 0
		add_child(hitbox_area)
		_hitbox_area = hitbox_area
	else:
		hitbox_area.input_pickable = true
		hitbox_area.collision_layer = HITBOX_COLLISION_LAYER
		hitbox_area.collision_mask = 0

	var collision_shape: CollisionShape2D = hitbox_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		hitbox_area.add_child(collision_shape)

	var shape_rect: Rect2 = _compute_hitbox_rect()
	var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		collision_shape.shape = rectangle_shape
	rectangle_shape.size = shape_rect.size
	hitbox_area.position = shape_rect.position + shape_rect.size * 0.5

func _compute_hitbox_rect() -> Rect2:
	var visual_node: Node = _find_visual_node_for_hitbox()
	if visual_node is Sprite2D:
		return _compute_sprite_hitbox_rect(visual_node as Sprite2D)
	if visual_node is AnimatedSprite2D:
		return _compute_animated_sprite_hitbox_rect(visual_node as AnimatedSprite2D)
	return Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0))

func _find_visual_node_for_hitbox() -> Node:
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

func _compute_sprite_hitbox_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0))
	var frame_width: float = sprite.texture.get_width() / maxf(1.0, float(sprite.hframes))
	var frame_height: float = sprite.texture.get_height() / maxf(1.0, float(sprite.vframes))
	var size: Vector2 = Vector2(frame_width, frame_height) * sprite.scale.abs()
	var top_left: Vector2 = sprite.position
	if sprite.centered:
		top_left -= size * 0.5
	return Rect2(top_left, size)

func _compute_animated_sprite_hitbox_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null or sprite.sprite_frames == null:
		return Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0))
	var animation_name: StringName = sprite.animation if not sprite.animation.is_empty() else &"default"
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if texture == null:
		return Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0))
	var size: Vector2 = texture.get_size() * sprite.scale.abs()
	var top_left: Vector2 = sprite.position
	if sprite.centered:
		top_left -= size * 0.5
	return Rect2(top_left, size)

# ─── Propriétés calculées ────────────────────────────────────────────────────

# kW effectif, influencé linéairement par la gravité et la température
func get_energy_delta() -> float:
	if not _can_operate_now():
		return 0.0
	var base_energy: float = current_recipe.get("energy_delta", 0.0) * production_rate
	var settings: Dictionary = SettingsManager.get_settings()
	# Gravité : 0.1→30.0 → factor linéaire 0.5 (légère) à 2.0 (forte)
	var gravity: float = SettingsManager._to_float(settings.get("physics_gravity", 9.8), 9.8)
	var gravity_t: float = (gravity - 0.1) / (30.0 - 0.1)
	var gravity_factor: float = lerpf(0.5, 2.0, gravity_t)
	# Température : -50→150 → factor linéaire 2.0 (froid, chauffage) à 0.5 (chaud)
	var temperature: float = SettingsManager._to_float(settings.get("physics_temperature", 20.0), 20.0)
	var temp_t: float = (temperature - (-50.0)) / (150.0 - (-50.0))
	var temp_factor: float = lerpf(2.0, 0.5, temp_t)
	return base_energy * gravity_factor * temp_factor

# g/min effectif, influencé linéairement par la température
func get_co2_rate() -> float:
	if not _can_operate_now():
		return 0.0
	var base_co2: float = current_recipe.get("co2_rate", 0.0) * production_rate
	var settings: Dictionary = SettingsManager.get_settings()
	# Température : -50→150, défaut 20 → factor linéaire 0.5 (froid) à 2.0 (chaud)
	var temperature: float = SettingsManager._to_float(settings.get("physics_temperature", 20.0), 20.0)
	var temp_t: float = (temperature - (-50.0)) / (150.0 - (-50.0))
	var temp_factor: float = lerpf(0.5, 2.0, temp_t)
	return base_co2 * temp_factor

# ─── Méthodes publiques ──────────────────────────────────────────────────────

func set_recipe(recipe: Dictionary) -> void:
	current_recipe = recipe
	_production_timer = 0.0
	_update_production_bar()
	entity_updated.emit(self)
	EntityManager.recalculate_totals()

func set_production_rate(rate: float) -> void:
	production_rate = clampf(rate, 0.0, 1.0)
	_production_timer = 0.0
	_update_production_bar()
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
		"is_broken": is_broken,
		"health": health,
		"energy_delta": get_energy_delta(),
		"co2_rate": get_co2_rate(),
		"cell_position": cell_position,
		"status_text": get_status_text()
	}

func get_health_percent() -> int:
	if max_health <= 0.0:
		return 0
	return clampi(roundi((health / max_health) * 100.0), 0, 100)

func get_status_text() -> String:
	if not is_active:
		return "Arret"
	if is_broken:
		return "En panne - Reparer"
	if current_recipe.is_empty():
		return "Aucune recette"
	# Vérifications Électriques
	if electricity_need > 0.0:
		if EntityManager.get_electricity_at_cell(cell_position) == 0.0:
			return "Pas d'electricite (hors zone)"
		if EntityManager.power_satisfaction < 1.0:
			return "Reseau sature (" + str(int(EntityManager.power_satisfaction * 100)) + "%)"
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
	if get_buffer_amount("input", resource_id) + amount > max_input_stock:
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

func can_repair() -> bool:
	return is_broken and GameManager != null and GameManager.has_resources({"repair_kit": 1})

func is_operational() -> bool:
	return is_active and not is_broken

func repair_machine() -> bool:
	if not can_repair():
		return false
	if not GameManager.consume_resources({"repair_kit": 1}):
		return false
	is_broken = false
	health = max_health
	_refresh_runtime_state()
	return true

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
		"is_broken": is_broken,
		"health": health,
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
	max_health = maxf(1.0, float(data.get("max_health", max_health)))
	health = clampf(float(data.get("health", max_health)), 0.0, max_health)
	is_broken = bool(data.get("is_broken", false))
	# is_active en dernier pour déclencher le setter une seule fois
	is_active = data.get("is_active", false)

# ─── À surcharger dans les sous-classes ──────────────────────────────────────

# Appelé quand is_active change (ex: jouer/arrêter une animation)
func _on_active_changed(_active: bool) -> void:
	pass

func _on_broken_changed(_broken: bool) -> void:
	pass

func _can_operate_now() -> bool:
	if not is_active or is_broken or current_recipe.is_empty() or production_rate <= 0.0:
		return false
	if not _has_output_capacity_for_recipe():
		return false
	# Vérifier que la zone a suffisamment d'électricité pour faire fonctionner ce bâtiment
	if electricity_need > 0.0:
		var available: float = EntityManager.get_electricity_at_cell(cell_position)
		if available < electricity_need:
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
	var settings: Dictionary = SettingsManager.get_settings()
	# Gravité : 0.1→30.0, défaut 9.8 → factor linéaire 0.5 (rapide) à 2.0 (lent)
	var gravity: float = SettingsManager._to_float(settings.get("physics_gravity", 9.8), 9.8)
	var gravity_t: float = (gravity - 0.1) / (30.0 - 0.1)
	var gravity_factor: float = lerpf(0.5, 2.0, gravity_t)
	# Friction : 0.0→5.0, défaut 1.0 → factor linéaire 0.5 (glissant) à 2.0 (résistant)
	var friction: float = SettingsManager._to_float(settings.get("physics_friction", 1.0), 1.0)
	var friction_t: float = friction / 5.0
	var friction_factor: float = lerpf(0.5, 2.0, friction_t)
	var adjusted_duration: float = base_duration * gravity_factor * friction_factor
	var actual_rate = maxf(production_rate * EntityManager.power_satisfaction, 0.01)
	return adjusted_duration / actual_rate

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

	_apply_wear_after_cycle()
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
		if get_buffer_amount("output", resource_key) + amount > max_output_stock:
			return false
		if _get_buffer_load(output_buffer) + amount > output_buffer_capacity:
			return false
		output_buffer[resource_key] = get_buffer_amount("output", resource_key) + amount
	return true

func _has_output_capacity_for_recipe() -> bool:
	if current_recipe.is_empty():
		return false
		
	var outputs: Dictionary = current_recipe.get("outputs", {})
	for item_id in outputs:
		if item_id == "energie":
			continue
		var resource_id: String = String(item_id)
		var current_amount: int = get_buffer_amount("output", resource_id)
		var amount_produced: int = int(outputs[item_id])
		
		# Limite atteinte
		if current_amount + amount_produced > max_output_stock:
			return false
		if _get_buffer_load(output_buffer) + amount_produced > output_buffer_capacity:
			return false
	return true

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

func _refresh_runtime_state() -> void:
	if not is_active:
		_production_timer = 0.0
	_on_active_changed(is_active and not is_broken)
	_on_broken_changed(is_broken)
	_update_production_bar()
	entity_updated.emit(self)
	EntityManager.recalculate_totals()

func _apply_wear_after_cycle() -> void:
	if is_broken:
		return
	health = clampf(health - wear_per_cycle, 0.0, max_health)
	if health <= 0.0:
		_set_broken(true)
		return
	if health > breakdown_threshold:
		return
	if randf() < breakdown_chance_per_cycle:
		_set_broken(true)

func _set_broken(value: bool) -> void:
	if is_broken == value:
		return
	is_broken = value
	if is_broken:
		_production_timer = 0.0
	_refresh_runtime_state()

func _update_production_bar() -> void:
	if _production_bar == null:
		return
	var should_show: bool = is_active and not current_recipe.is_empty()
	_production_bar.visible = should_show
	if not should_show:
		_production_bar.value = 0.0
		return
	var cycle_duration: float = _get_cycle_duration()
	var progress_percent: float = 0.0
	if cycle_duration > 0.0:
		progress_percent = clampf((_production_timer / cycle_duration) * 100.0, 0.0, 100.0)
	_production_bar.value = progress_percent
	if is_broken:
		_production_bar.modulate = Color(0.95, 0.3, 0.3)
	elif _can_operate_now():
		_production_bar.modulate = Color(0.32, 1.0, 0.55)
	else:
		_production_bar.modulate = Color(0.95, 0.76, 0.22)

# Vérifie si l'entité peut recevoir cet objet spécifique

func can_accept_item(item_id: String) -> bool:
	if current_recipe.is_empty():
		return false
		
	# 1. Vérifier si l'objet fait bien partie des ingrédients de la recette
	var inputs: Dictionary = current_recipe.get("inputs", {})
	if not inputs.has(item_id):
		return false
		
	# 2. Vérifier si la limite de stock est atteinte
	return can_accept_input(item_id, 1)
# ─── Interne ─────────────────────────────────────────────────────────────────

static func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]
