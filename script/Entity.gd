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
		_on_active_changed(value)
		entity_updated.emit(self)
		EntityManager.recalculate_totals()

# ─── Signaux ─────────────────────────────────────────────────────────────────

# Émis quand l'entité est cliquée (non utilisé directement ici, géré par BuildingManager)
signal entity_clicked(entity: Entity)

# Émis quand une propriété change (recette, taux, actif/inactif)
signal entity_updated(entity: Entity)

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	entity_id = _generate_id()
	# La sous-classe appelle super._ready() puis définit entity_type et
	# charge ses recettes avant d'appeler _post_ready().
	_post_ready()

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
	if not is_active or current_recipe.is_empty():
		return 0.0
	return current_recipe.get("energy_delta", 0.0) * production_rate

# g/min effectif
func get_co2_rate() -> float:
	if not is_active or current_recipe.is_empty():
		return 0.0
	return current_recipe.get("co2_rate", 0.0) * production_rate

# ─── Méthodes publiques ──────────────────────────────────────────────────────

func set_recipe(recipe: Dictionary) -> void:
	current_recipe = recipe
	entity_updated.emit(self)
	EntityManager.recalculate_totals()

func set_production_rate(rate: float) -> void:
	production_rate = clampf(rate, 0.0, 1.0)
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
		"cell_position": cell_position
	}

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
		"build_cost": build_cost
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
	# is_active en dernier pour déclencher le setter une seule fois
	is_active = data.get("is_active", false)

# ─── À surcharger dans les sous-classes ──────────────────────────────────────

# Appelé quand is_active change (ex: jouer/arrêter une animation)
func _on_active_changed(_active: bool) -> void:
	pass

# ─── Interne ─────────────────────────────────────────────────────────────────

static func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]
