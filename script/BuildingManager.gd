extends Node2D

# Correspondance entity_type → scène pour la restauration des sauvegardes
const _ENTITY_SCENES: Dictionary = {
	"turbine": preload("res://scene/turbine_2d.tscn"),
	"factory": preload("res://scene/factory.tscn")
}

@export var cell_size: int = 32 # En accord avec la taille des cellules de floor.gd
@export var buildings_node: Node2D # Nœud parent pour regrouper les usines placées

var factory_scene: PackedScene
var factory_cost: float = 0.0
var is_building: bool = false
var preview_sprite: Sprite2D
var occupied_cells: Dictionary = {} # maps Vector2i -> {"instance": Node2D, "cost": float}
# Signal émis quand l'état du dernier bâtiment change (disponible / non)
signal last_build_state_changed(available)
# Signal pour le mode destruction (on/off)
signal destroy_mode_changed(enabled)
# Signal émis quand l'utilisateur clique sur un bâtiment existant (null = clic dans le vide)
signal entity_selected(entity)

var is_destroying: bool = false

# Détection clic vs drag : position souris au moment du press
var _mouse_press_pos: Vector2 = Vector2.ZERO
const _CLICK_THRESHOLD: float = 5.0

# Informations sur le dernier bâtiment placé (cell_pos, instance, cost)
var _last_built: Dictionary = {}

func _ready() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.visible = false
	preview_sprite.z_index = 10 # Assure que le fantôme reste visible par-dessus le sol
	add_child(preview_sprite)

	# S'assurer que le preview est centré par rapport à sa position
	preview_sprite.centered = true

# --- MODIFICATION ICI : Ajout de frames_count ---
func start_building(scene: PackedScene, cost: float, texture: Texture2D, frames_count: int = 1) -> void:
	# Quitter le mode destruction si actif
	if is_destroying:
		stop_destroying()

	factory_scene = scene
	factory_cost = cost
	preview_sprite.texture = texture
	
	# --- NOUVEAU : Découpe l'image animée ---
	preview_sprite.hframes = frames_count
	preview_sprite.frame = 0 # Affiche seulement la première image
	# ----------------------------------------
	
	preview_sprite.visible = true
	is_building = true

	# Reset scale / modulate au cas où
	preview_sprite.scale = Vector2.ONE
	preview_sprite.modulate = Color(1,1,1,0.6)

func stop_building() -> void:
	is_building = false
	preview_sprite.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Gestion du mode destruction (prioritaire)
	if is_destroying:
		# Clic droit ou Echap pour annuler le mode destruction
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			stop_destroying()
			get_viewport().set_input_as_handled()
			return

		# Clic gauche pour détruire un bâtiment sous la souris
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_destroy_at_mouse()
			get_viewport().set_input_as_handled()
			return

	if not is_building:
		# ── Mode sélection : détecter les clics sur les bâtiments existants ──
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_press_pos = event.position
			else:
				# Release : vérifier si c'est un clic court (pas un drag caméra)
				var delta: float = (event as InputEventMouseButton).position.distance_to(_mouse_press_pos)
				if delta < _CLICK_THRESHOLD:
					_try_select_entity_at_mouse()
					get_viewport().set_input_as_handled()
			return

	# Clic droit ou Echap pour annuler la construction
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		stop_building()
		get_viewport().set_input_as_handled()
		
	# Clic gauche pour placer l'usine
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_building()
		print("JE POSE LE BATIMENT !")
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_building:
		_update_preview()

func _update_preview() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	# Alignement sur la grille (Grid snapping)
	var grid_x: int = int(floor(mouse_pos.x / cell_size))
	var grid_y: int = int(floor(mouse_pos.y / cell_size))
	
	# Centre le sprite sur la case (en présumant que l'origine du Sprite2D est centrée)
	var target_pos: Vector2 = Vector2(grid_x * cell_size + cell_size / 2.0, grid_y * cell_size + cell_size / 2.0)
	preview_sprite.global_position = target_pos
	
	var cell_pos: Vector2i = Vector2i(grid_x, grid_y)
	if _can_build(cell_pos):
		preview_sprite.modulate = Color(0, 1, 0, 0.6) # Vert semi-transparent si plaçable
	else:
		preview_sprite.modulate = Color(1, 0, 0, 0.6) # Rouge sinon

func _try_place_building() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var grid_x: int = int(floor(mouse_pos.x / cell_size))
	var grid_y: int = int(floor(mouse_pos.y / cell_size))
	var cell_pos: Vector2i = Vector2i(grid_x, grid_y)
	
	if _can_build(cell_pos):
		# Déduction des crédits grâce à la fonction existante
		GameManager.add_credits(-factory_cost)
		
		# Création de l'usine
		var factory_instance: Node2D = factory_scene.instantiate()
		# Ajoute en tant qu'enfant du nœud de bâtiments (si défini) avant de positionner
		if buildings_node:
			buildings_node.add_child(factory_instance)
		else:
			add_child(factory_instance)
		# Positionner l'instance au centre de la case en coordonnées globales
		factory_instance.global_position = preview_sprite.global_position
		_configure_instance_visuals(factory_instance)
			
		# Assigner la position grille et le coût à l'entité si elle hérite de Entity
		if factory_instance is Entity:
			factory_instance.cell_position = cell_pos
			factory_instance.build_cost = factory_cost

		# Enregistrement de la case comme étant occupée (après création de l'instance)
		occupied_cells[cell_pos] = {"instance": factory_instance, "cost": factory_cost}
		# Optionnel : décommentez la ligne suivante pour quitter le mode construction après un seul placement
		# stop_building()

		# --- NOUVEAU : Sauvegarde du dernier bâtiment placé pour permettre annulation/remboursement ---
		_last_built = {
			"cell_pos": cell_pos,
			"instance": factory_instance,
			"cost": factory_cost
		}
		last_build_state_changed.emit(true)
		# -----------------------------------------------------------------------------------------

func _can_build(cell_pos: Vector2i) -> bool:
	# 1. Vérification si une usine est déjà présente
	if occupied_cells.has(cell_pos):
		return false
	# 2. Vérification des fonds disponibles
	if GameManager.credits < factory_cost:
		return false
	return true


func has_last_build() -> bool:
	return _last_built.size() > 0


func undo_last_build() -> void:
	# Annule le dernier bâtiment placé et rembourse la moitié du coût
	if not has_last_build():
		return

	var inst = _last_built.get("instance")
	var cell = _last_built.get("cell_pos")
	var cost = float(_last_built.get("cost", 0.0))

	if is_instance_valid(inst):
		inst.queue_free()

	if cell:
		occupied_cells.erase(cell)

	# Remboursement de 50%
	GameManager.add_credits(cost * 0.5)

	_last_built.clear()
	last_build_state_changed.emit(false)


func start_destroying() -> void:
	# Passe en mode destruction; conserve le mode jusqu'à annulation
	is_destroying = true
	# S'assurer de quitter le mode construction si actif
	if is_building:
		stop_building()
	destroy_mode_changed.emit(true)


func stop_destroying() -> void:
	is_destroying = false
	destroy_mode_changed.emit(false)


func toggle_destroying() -> void:
	if is_destroying:
		stop_destroying()
	else:
		start_destroying()


func _try_destroy_at_mouse() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var grid_x: int = int(floor(mouse_pos.x / cell_size))
	var grid_y: int = int(floor(mouse_pos.y / cell_size))
	var cell_pos: Vector2i = Vector2i(grid_x, grid_y)

	if not occupied_cells.has(cell_pos):
		return

	var data = occupied_cells[cell_pos]
	var inst = data.get("instance")
	var cost = float(data.get("cost", 0.0))

	if is_instance_valid(inst):
		inst.queue_free()

	occupied_cells.erase(cell_pos)

	# Remboursement de 50%
	GameManager.add_credits(cost * 0.5)

	# Si on avait enregistré ce bâtiment comme dernier construit, on le nettoie
	if _last_built.size() > 0 and _last_built.get("cell_pos") == cell_pos:
		_last_built.clear()
		last_build_state_changed.emit(false)
	# Fermer le panneau entité si c'est elle qui vient d'être détruite
	entity_selected.emit(null)

func _try_select_entity_at_mouse() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var grid_x: int = int(floor(mouse_pos.x / cell_size))
	var grid_y: int = int(floor(mouse_pos.y / cell_size))
	var cell_pos: Vector2i = Vector2i(grid_x, grid_y)

	if not occupied_cells.has(cell_pos):
		# Clic dans le vide : désélectionner
		entity_selected.emit(null)
		return

	var inst = occupied_cells[cell_pos].get("instance")
	if is_instance_valid(inst) and inst is Entity:
		entity_selected.emit(inst)
	else:
		entity_selected.emit(null)

# ─────────────────────────────────────────────────────────────────────────────
# Restauration des entités depuis une sauvegarde
# Appelé par level.gd lors du chargement d'une partie.
# ─────────────────────────────────────────────────────────────────────────────

func clear_runtime_state() -> void:
	occupied_cells.clear()
	_last_built.clear()
	last_build_state_changed.emit(false)
	entity_selected.emit(null)

func restore_entities(entities_data: Array) -> int:
	clear_runtime_state()
	var restored_count: int = 0
	for data in entities_data:
		if data is Dictionary:
			restored_count += _restore_single_entity(data)
	return restored_count

func _restore_single_entity(data: Dictionary) -> int:
	var entity_type: String = data.get("entity_type", "")
	if not _ENTITY_SCENES.has(entity_type):
		push_warning("Type d'entite inconnu ignore pendant la restauration: %s" % entity_type)
		return 0

	var cell_x: int = int(data.get("cell_x", 0))
	var cell_y: int = int(data.get("cell_y", 0))
	var cell_pos := Vector2i(cell_x, cell_y)

	# Ne pas écraser une case déjà occupée
	if occupied_cells.has(cell_pos):
		push_warning("Case deja occupee pendant la restauration: %s" % cell_pos)
		return 0

	var scene: PackedScene = _ENTITY_SCENES[entity_type]
	var instance: Node2D = scene.instantiate()

	if buildings_node:
		buildings_node.add_child(instance)
	else:
		add_child(instance)

	instance.global_position = Vector2(
		cell_pos.x * cell_size + cell_size / 2.0,
		cell_pos.y * cell_size + cell_size / 2.0
	)

	var cost: float = float(data.get("build_cost", 0.0))
	occupied_cells[cell_pos] = {"instance": instance, "cost": cost}

	# Restaurer l'état de l'entité (recette, taux, actif…)
	if instance is Entity:
		instance.cell_position = cell_pos
		instance.build_cost = cost
		_configure_instance_visuals(instance)
		instance.deserialize(data)
		return 1

	push_warning("La scene restauree n'herite pas de Entity: %s" % entity_type)
	return 0

func _configure_instance_visuals(instance: Node2D) -> void:
	instance.z_index = preview_sprite.z_index - 1
	for child in instance.get_children():
		if child is Sprite2D:
			child.centered = true
			child.region_enabled = false
		elif child is AnimatedSprite2D:
			child.centered = true
