extends Node2D

const ENTITY_HITBOX_COLLISION_MASK: int = Entity.HITBOX_COLLISION_LAYER

# Correspondance entity_type → scène pour la restauration des sauvegardes
const _ENTITY_SCENES: Dictionary = {
	"turbine": preload("res://scene/turbine_2d.tscn"),
	"factory": preload("res://scene/factory.tscn"),
	"miner": preload("res://scene/miner.tscn"),
	"belt_right": preload("res://scene/ASSET/belt/beltmid.tscn"),
	"belt_left": preload("res://scene/ASSET/belt/beltleft.tscn"),
	"belt_west": preload("res://scene/ASSET/belt/beltleft.tscn"),
	"belt_east": preload("res://scene/ASSET/belt/belteast.tscn"),
	"belt_north": preload("res://scene/ASSET/belt/beltnorth.tscn"),
	"belt_south": preload("res://scene/ASSET/belt/beltsouth.tscn"),
	"merger": preload("res://scene/ASSET/belt/merger.tscn"),
	"splitter": preload("res://scene/ASSET/belt/splitter.tscn"),
	"curve_top": preload("res://scene/ASSET/beltcurvetop.tscn"),
	"curve_down": preload("res://scene/ASSET/belt/curvedown.tscn"),
	"curve_left": preload("res://scene/ASSET/belt/curveleft.tscn"),
	"curve_right": preload("res://scene/ASSET/belt/curveright.tscn"),
	"entrepot": preload("res://scene/entrepot.tscn"),
}

# --- MODIFICATION ICI : Ajout du lien vers le TileMap Isométrique ---
@onready var floor_tilemap: TileMapLayer = $"../TileMapLayer" # Si vous êtes sur Godot 4.2 ou moins, changez "TileMapLayer" en "TileMap"
# --------------------------------------------------------------------

@export var cell_size: int = 32 # Gardé au cas où, mais sera ignoré si floor_tilemap est assigné
@export var buildings_node: Node2D # Nœud parent pour regrouper les usines placées

var factory_scene: PackedScene
var factory_cost: float = 0.0
var _current_build_footprint_offsets: Array[Vector2i] = [Vector2i.ZERO]
var is_building: bool = false
var preview_sprite: Sprite2D
var occupied_cells: Dictionary = {} # maps Vector2i -> {"instance": Node2D, "cost": float}
# Signal émis quand l'état du dernier bâtiment change (disponible / non)
signal last_build_state_changed(available)
# Signal pour le mode destruction (on/off)
signal destroy_mode_changed(enabled)
# Signal émis quand l'utilisateur clique sur un bâtiment existant (null = clic dans le vide)
signal entity_selected(entity)
signal delivery_point_selected(cell_pos, world_pos)
signal delivery_point_hovered(cell_pos, world_pos)
signal delivery_point_selection_changed(enabled)
signal delivery_point_error(message: String)
signal entrepot_inspected(entrepot_instance)
var is_destroying: bool = false
var is_selecting_delivery_point: bool = false

# Détection clic vs drag : position souris au moment du press
var _mouse_press_pos: Vector2 = Vector2.ZERO
const _CLICK_THRESHOLD: float = 5.0

# Informations sur le dernier bâtiment placé (cell_pos, instance, cost)
var _last_built: Dictionary = {}
var _last_delivery_hover_cell: Vector2i = Vector2i(2147483647, 2147483647)

var is_moving: bool = false
var _moving_instance: Node2D = null
var _moving_origin_cell: Vector2i = Vector2i.ZERO
var _moving_cost: float = 0.0
var _moving_footprint: Array[Vector2i] = []

func _ready() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.visible = false
	preview_sprite.z_index = 10 # Assure que le fantôme reste visible par-dessus le sol
	add_child(preview_sprite)

	# S'assurer que le preview est centré par rapport à sa position
	preview_sprite.centered = true

# --- NOUVELLES FONCTIONS ISOMÉTRIQUES ---


const BUILDING_CELL_SIZE: int = 64

func get_grid_pos(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / float(BUILDING_CELL_SIZE))),
		int(floor(world_pos.y / float(BUILDING_CELL_SIZE)))
	)

func get_world_pos(cell_pos: Vector2i) -> Vector2:
	return Vector2(
		float(cell_pos.x) * BUILDING_CELL_SIZE + BUILDING_CELL_SIZE / 2.0,
		float(cell_pos.y) * BUILDING_CELL_SIZE + BUILDING_CELL_SIZE / 2.0
	)
	
func start_building(scene: PackedScene, cost: float, texture: Texture2D, frames_count: int = 1, footprint_offsets: Array = [Vector2i.ZERO], preview_scale: Vector2 = Vector2.ONE) -> void:
	if is_selecting_delivery_point:
		stop_delivery_point_selection()

	# Quitter le mode destruction si actif
	if is_destroying:
		stop_destroying()

	factory_scene = scene
	factory_cost = cost
	_current_build_footprint_offsets = _normalize_footprint_offsets(footprint_offsets)
	preview_sprite.texture = texture
	preview_sprite.centered = true
	# Découpe l'image animée
	preview_sprite.hframes = frames_count
	preview_sprite.frame = 0 # Affiche seulement la première image
	
	preview_sprite.visible = true
	is_building = true

	# Reset scale / modulate au cas où
	preview_sprite.scale = preview_scale  # utilise la scale transmise par HUD (propre à chaque bâtiment)
	preview_sprite.modulate = Color(1,1,1,0.6)
	
func stop_building() -> void:
	is_building = false
	preview_sprite.visible = false
	_current_build_footprint_offsets = [Vector2i.ZERO]

func _input(event: InputEvent) -> void:
	if is_destroying:

		if get_viewport().gui_get_hovered_control() != null:
			return

		if event.is_action_pressed("ui_cancel"):
			stop_destroying()
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
			_try_destroy_at_mouse()
			get_viewport().set_input_as_handled()
			return
			
func _unhandled_input(event: InputEvent) -> void:
	if is_selecting_delivery_point:
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			stop_delivery_point_selection()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_delivery_point_at_mouse()
			get_viewport().set_input_as_handled()
			return

	# --- Mode déplacement actif ---
	if is_moving:
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			_cancel_moving()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place_moved_building()
			get_viewport().set_input_as_handled()
			return
		return

	# --- Ni construction ni déplacement ---
	if not is_building:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _try_pickup_conveyor_item_at_mouse():
				get_viewport().set_input_as_handled()
				return
			if _try_start_moving_at_mouse():
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_press_pos = event.position
			else:
				var delta: float = (event as InputEventMouseButton).position.distance_to(_mouse_press_pos)
				if delta < _CLICK_THRESHOLD:
					_try_select_entity_at_mouse()
					get_viewport().set_input_as_handled()
		return

	# --- Mode construction actif ---
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse_pos := get_global_mouse_position()
			var cell_pos := get_grid_pos(mouse_pos)
			if occupied_cells.has(cell_pos):
				var inst = occupied_cells[cell_pos].get("instance")
				if is_instance_valid(inst) and inst.is_in_group("entrepot"):
					entrepot_inspected.emit(inst)
					get_viewport().set_input_as_handled()
					return
		stop_building()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_building()
		get_viewport().set_input_as_handled()
		return
		
func _process(_delta: float) -> void:
	if is_selecting_delivery_point:
		_update_delivery_point_hover_preview()
	if is_building or is_moving:
		_update_preview()

func _update_delivery_point_hover_preview() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)
	
	if cell_pos == _last_delivery_hover_cell:
		return
	_last_delivery_hover_cell = cell_pos	
	
	# Feedback : Est-ce que la souris survole un entrepôt ?
	var is_hovering_entrepot = false
	if occupied_cells.has(cell_pos):
		var inst = occupied_cells[cell_pos].get("instance")
		if is_instance_valid(inst) and inst.is_in_group("entrepot"):
			is_hovering_entrepot = true
	
	# Vous pouvez ici changer la couleur de votre preview ou curseur
	# si is_hovering_entrepot est vrai
	delivery_point_hovered.emit(cell_pos, get_world_pos(cell_pos))

func _update_preview() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)
	var snap_pos: Vector2 = get_world_pos(cell_pos)
	preview_sprite.global_position = snap_pos

	var can_place: bool = false
	if is_moving:
		# Vérifie que toutes les cellules du footprint déplacé sont libres
		can_place = true
		for offset in _moving_footprint:
			if occupied_cells.has(cell_pos + offset):
				can_place = false
				break
	else:
		can_place = _can_build(cell_pos)

	if can_place:
		preview_sprite.modulate = Color(0, 1, 0, 0.6)
	else:
		preview_sprite.modulate = Color(1, 0, 0, 0.6)

func _try_place_building() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)
	var snap_pos: Vector2 = get_world_pos(cell_pos)
	if _can_build(cell_pos):
		GameManager.add_credits(-factory_cost)
		var factory_instance: Node2D = factory_scene.instantiate()
		
		if factory_instance is Entity:
			factory_instance.cell_position = cell_pos
			factory_instance.build_cost = factory_cost
		

		if buildings_node:
			buildings_node.add_child(factory_instance)
		else:
			add_child(factory_instance)
		# 4. Positionnement visuel : centrer les sprites D'ABORD, puis positionner
		_configure_instance_visuals(factory_instance)
		factory_instance.global_position = get_world_pos(cell_pos)
			
		# 5. Enregistrement des cellules
		var occupied_by_build: Array[Vector2i] = _get_occupied_cells_for_build(cell_pos, _current_build_footprint_offsets)
		_register_occupied_cells(factory_instance, occupied_by_build, cell_pos, factory_cost)

		# 6. Sauvegarde
		_last_built = {
			"cell_pos": cell_pos,
			"occupied_cells": occupied_by_build.duplicate(),
			"instance": factory_instance,
			"cost": factory_cost,
			"co2_cost": factory_instance.get("build_co2_cost") if factory_instance else 0.0,
		}
		last_build_state_changed.emit(true)
		
		# --- ICI : On appelle la fonction de rafraîchissement ---
		# Comme on est dans _try_place_building, cell_pos est connu !
		_refresh_turbines_around(cell_pos)
func _can_build(cell_pos: Vector2i) -> bool:
	for occupied_cell in _get_occupied_cells_for_build(cell_pos, _current_build_footprint_offsets):
		if occupied_cells.has(occupied_cell):
			return false
	# 2. Vérification des fonds disponibles
	if GameManager.credits < factory_cost:
		return false
	return true

func has_last_build() -> bool:
	return _last_built.size() > 0

func undo_last_build() -> void:
	if not has_last_build():
		return

	var inst = _last_built.get("instance")
	var occupied_for_build: Array = _last_built.get("occupied_cells", [])
	var cost: float = float(str(_last_built.get("cost", 0.0)))
	var co2_cost: float = float(str(_last_built.get("co2_cost", 0.0)))

	if is_instance_valid(inst):
		inst.queue_free()

	_clear_occupied_cells_for_instance(inst, occupied_for_build)

	# Remboursement de 50% du coût crédits
	GameManager.add_credits(cost * 0.5)
	# Remboursement de la totalité du CO2 de construction
	if co2_cost > 0.0:
		GameManager.remove_construction_co2(co2_cost)

	_last_built.clear()
	last_build_state_changed.emit(false)


func start_destroying() -> void:
	# Passe en mode destruction; conserve le mode jusqu'à annulation
	if is_selecting_delivery_point:
		stop_delivery_point_selection()
	is_destroying = true
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

func start_delivery_point_selection() -> void:
	if is_building:
		stop_building()
	if is_destroying:
		stop_destroying()
	is_selecting_delivery_point = true
	_last_delivery_hover_cell = Vector2i(2147483647, 2147483647)
	entity_selected.emit(null)
	delivery_point_selection_changed.emit(true)

func stop_delivery_point_selection() -> void:
	is_selecting_delivery_point = false
	_last_delivery_hover_cell = Vector2i(2147483647, 2147483647)
	delivery_point_selection_changed.emit(false)

func is_delivery_point_selection_active() -> bool:
	return is_selecting_delivery_point

func _select_delivery_point_at_mouse() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)

	# Cherche un entrepôt sur la cellule cliquée
	var entrepot_inst = null
	if occupied_cells.has(cell_pos):
		var data = occupied_cells[cell_pos]
		var inst = data.get("instance")
		if is_instance_valid(inst) and inst.is_in_group("entrepot"):
			entrepot_inst = inst

	if entrepot_inst == null:
		delivery_point_error.emit("⚠ Aucun entrepôt à cet endroit.")
		return

	if entrepot_inst != null:
		# Snapper le point au centre exact de l'entrepôt, peu importe où on clique
		var snap_pos: Vector2 = entrepot_inst.global_position
		var snap_cell: Vector2i = get_grid_pos(snap_pos)
		delivery_point_selected.emit(snap_cell, snap_pos)
		stop_delivery_point_selection()
	else:
		delivery_point_error.emit("⚠ Aucun entrepôt sur la carte ! Pose d'abord un entrepôt.")


func _try_destroy_at_mouse() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	# --- MODIFICATION ICI : Calcul de position isométrique ---
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)
	# ---------------------------------------------------------

	if not occupied_cells.has(cell_pos):
		return

	var data = occupied_cells[cell_pos]
	var inst = data.get("instance")
	var cost = float(data.get("cost", 0.0))
	var co2_cost = float(data.get("co2_cost", 0.0))

	if is_instance_valid(inst):
		inst.queue_free()

	_clear_occupied_cells_for_instance(inst)

	# Remboursement de 50%
	GameManager.add_credits(cost * 0.5)
	GameManager.remove_construction_co2(co2_cost)

	# Si on avait enregistré ce bâtiment comme dernier construit, on le nettoie
	if _last_built.size() > 0 and _last_built.get("instance") == inst:
		_last_built.clear()
		last_build_state_changed.emit(false)
	_refresh_turbines_around(cell_pos)
	_refresh_conveyors_around(cell_pos)

	# Fermer le panneau entité si c'est elle qui vient d'être détruite
	entity_selected.emit(null)

func _try_select_entity_at_mouse() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var hitbox_entity: Entity = _find_entity_from_hitbox(mouse_pos)
	if hitbox_entity != null:
		entity_selected.emit(hitbox_entity)
		return
	
	# --- MODIFICATION ICI : Calcul de position isométrique ---
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)
	# ---------------------------------------------------------

	if not occupied_cells.has(cell_pos):
		# Clic dans le vide : désélectionner
		entity_selected.emit(null)
		return

	var inst = occupied_cells[cell_pos].get("instance")
	if is_instance_valid(inst) and inst is Entity:
		entity_selected.emit(inst)
	else:
		entity_selected.emit(null)

func _find_entity_from_hitbox(world_pos: Vector2) -> Entity:
	var world_2d: World2D = get_world_2d()
	if world_2d == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = ENTITY_HITBOX_COLLISION_MASK
	var hits: Array[Dictionary] = world_2d.direct_space_state.intersect_point(query, 8)
	for hit in hits:
		var collider: Variant = hit.get("collider")
		if collider is Area2D:
			var parent: Node = (collider as Area2D).get_parent()
			if parent is Entity:
				return parent
	return null

func _try_pickup_conveyor_item_at_mouse() -> bool:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell_pos: Vector2i = get_grid_pos(mouse_pos)

	if not occupied_cells.has(cell_pos):
		return false

	var inst: Variant = occupied_cells[cell_pos].get("instance")
	if not is_instance_valid(inst) or not (inst is ConveyorEntity):
		return false

	var conveyor: ConveyorEntity = inst
	return conveyor.eject_carried_item()

# ─────────────────────────────────────────────────────────────────────────────
# Restauration des entités depuis une sauvegarde
# Appelé par level.gd lors du chargement d'une partie.
# ─────────────────────────────────────────────────────────────────────────────

func clear_runtime_state() -> void:
	occupied_cells.clear()
	_last_built.clear()
	is_selecting_delivery_point = false
	_last_delivery_hover_cell = Vector2i(2147483647, 2147483647)
	last_build_state_changed.emit(false)
	entity_selected.emit(null)
	delivery_point_selection_changed.emit(false)

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
	var footprint_offsets: Array[Vector2i] = _get_default_footprint_offsets(entity_type)
	var occupied_for_build: Array[Vector2i] = _get_occupied_cells_for_build(cell_pos, footprint_offsets)

	for occupied_cell in occupied_for_build:
		if occupied_cells.has(occupied_cell):
			push_warning("Case deja occupee pendant la restauration: %s" % occupied_cell)
			return 0

	var scene: PackedScene = _ENTITY_SCENES[entity_type]
	var instance: Node2D = scene.instantiate()

	# ── Définir cell_position AVANT add_child pour que register_entity() l'ait ──
	if instance is Entity:
		instance.cell_position = cell_pos
		instance.build_cost = float(data.get("build_cost", 0.0))

	if buildings_node:
		buildings_node.add_child(instance)
	else:
		add_child(instance)

	instance.global_position = get_world_pos(cell_pos)

	var cost: float = float(data.get("build_cost", 0.0))
	_register_occupied_cells(instance, occupied_for_build, cell_pos, cost)

	if instance is Entity:
		_configure_instance_visuals(instance)
		instance.deserialize(data)
		return 1

	push_warning("La scene restauree n'herite pas de Entity: %s" % entity_type)
	return 0

func _refresh_conveyors_around(pos: Vector2i) -> void:
	var rayon := 12
	for x in range(-rayon, rayon + 1):
		for y in range(-rayon, rayon + 1):
			var check_pos := pos + Vector2i(x, y)
			var ent := EntityManager.get_entity_at_cell(check_pos)
			if ent != null and ent is ConveyorEntity:
				(ent as ConveyorEntity).refresh_power_state()
				
func _configure_instance_visuals(instance: Node2D) -> void:
	instance.z_index = preview_sprite.z_index - 1
	_center_sprites_recursive(instance)

func _center_sprites_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			child.centered = true
			child.position = Vector2.ZERO
			child.offset = Vector2.ZERO
		elif child is AnimatedSprite2D:
			child.centered = true
			child.position = Vector2.ZERO
			child.offset = Vector2.ZERO
		_center_sprites_recursive(child)

func _normalize_footprint_offsets(footprint_offsets: Array) -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	for footprint_offset in footprint_offsets:
		if footprint_offset is Vector2i:
			normalized.append(footprint_offset)
	if normalized.is_empty():
		normalized.append(Vector2i.ZERO)
	return normalized

func _get_occupied_cells_for_build(anchor_cell: Vector2i, footprint_offsets: Array[Vector2i]) -> Array[Vector2i]:
	var occupied_for_build: Array[Vector2i] = []
	for footprint_offset in footprint_offsets:
		occupied_for_build.append(anchor_cell + footprint_offset)
	return occupied_for_build

func _register_occupied_cells(instance: Node2D, occupied_for_build: Array[Vector2i], anchor_cell: Vector2i, cost: float) -> void:
	for occupied_cell in occupied_for_build:
		occupied_cells[occupied_cell] = {
			"instance": instance,
			"cost": cost,
			"anchor_cell": anchor_cell,
			"occupied_cells": occupied_for_build.duplicate(),
		}

func _clear_occupied_cells_for_instance(instance: Variant, occupied_for_build: Array = []) -> void:
	if not is_instance_valid(instance):
		return
	if occupied_for_build is Array and not occupied_for_build.is_empty():
		for occupied_cell_variant in occupied_for_build:
			if occupied_cell_variant is Vector2i and occupied_cells.get(occupied_cell_variant, {}).get("instance") == instance:
				occupied_cells.erase(occupied_cell_variant)
		return
	var cells_to_clear: Array[Vector2i] = []
	for occupied_cell in occupied_cells.keys():
		var cell_data: Dictionary = occupied_cells.get(occupied_cell, {})
		if cell_data.get("instance") == instance:
			cells_to_clear.append(occupied_cell)
	for occupied_cell in cells_to_clear:
		occupied_cells.erase(occupied_cell)

func _get_default_footprint_offsets(entity_type: String) -> Array[Vector2i]:
	match entity_type:
		"turbine":
			return [Vector2i.ZERO, Vector2i(1, 0)]
		_:
			return [Vector2i.ZERO]
func _refresh_turbines_around(pos: Vector2i):
	# Même rayon que la zone de turbine pour que les turbines proches rescannent leurs voisins
	var rayon = 20
	
	for x in range(-rayon, rayon + 1):
		for y in range(-rayon, rayon + 1):
			var check_pos = pos + Vector2i(x, y)
			var ent = EntityManager.get_entity_at_cell(check_pos)
			
			# Si on trouve une turbine dans cette zone, on la force à rescanner
			if ent != null and ent.entity_type == "turbine":
				ent.update_neighbors()
# Table des directions par type de belt
const CONVEYOR_DIRECTIONS: Dictionary = {
	"belt_right":  { "input": Vector2i(-1,  0), "output": Vector2i( 1,  0) },
	"belt_left":   { "input": Vector2i( 1,  0), "output": Vector2i(-1,  0) },
	"belt_east":   { "input": Vector2i( 0, -1), "output": Vector2i( 0,  1) },
	"belt_south":  { "input": Vector2i( 0, -1), "output": Vector2i( 0,  1) },
	"curve_top":   { "input": Vector2i( 0,  1), "output": Vector2i( 1,  0) },
	"curve_down":  { "input": Vector2i(-1,  0), "output": Vector2i( 0,  1) },
	"curve_left":  { "input": Vector2i( 0, -1), "output": Vector2i(-1,  0) },
	"curve_right": { "input": Vector2i( 1,  0), "output": Vector2i( 0, -1) },
	"merger":      { "input": Vector2i(-1,  0), "output": Vector2i( 1,  0) },
	"splitter":    { "input": Vector2i(-1,  0), "output": Vector2i( 1,  0) },
}

func _setup_moving_preview_from_instance(instance: Node2D) -> void:
	var visual_node: Node = _find_first_visual_node(instance)

	preview_sprite.texture = null
	preview_sprite.region_enabled = false
	preview_sprite.hframes = 1
	preview_sprite.vframes = 1
	preview_sprite.frame = 0
	preview_sprite.centered = true

	if visual_node is Sprite2D:
		var sprite := visual_node as Sprite2D

		preview_sprite.texture = sprite.texture
		preview_sprite.hframes = sprite.hframes
		preview_sprite.vframes = sprite.vframes
		preview_sprite.frame = sprite.frame
		preview_sprite.region_enabled = sprite.region_enabled
		preview_sprite.region_rect = sprite.region_rect
		preview_sprite.scale = sprite.global_scale

	elif visual_node is AnimatedSprite2D:
		var animated_sprite := visual_node as AnimatedSprite2D

		if animated_sprite.sprite_frames:
			var animation_name: StringName = animated_sprite.animation
			var frame_texture: Texture2D = animated_sprite.sprite_frames.get_frame_texture(animation_name, animated_sprite.frame)

			preview_sprite.texture = frame_texture
			preview_sprite.scale = animated_sprite.global_scale

	preview_sprite.modulate = Color(1, 1, 1, 0.6)
	
func _find_first_visual_node(node: Node) -> Node:
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child

		var nested_visual: Node = _find_first_visual_node(child)
		if nested_visual != null:
			return nested_visual

	return null
	
func _try_start_moving_at_mouse() -> bool:
	var mouse_pos := get_global_mouse_position()
	var cell_pos := get_grid_pos(mouse_pos)
	if not occupied_cells.has(cell_pos):
		return false
	var data = occupied_cells[cell_pos]
	var inst = data.get("instance")
	if not is_instance_valid(inst):
		return false
	
	# Trouve toutes les cellules occupées par ce bâtiment
	var all_cells: Array[Vector2i] = []
	for c in occupied_cells:
		if occupied_cells[c].get("instance") == inst:
			all_cells.append(c)
	var anchor: Vector2i = all_cells[0] if all_cells.size() > 0 else cell_pos
	var footprint: Array[Vector2i] = []
	for c in all_cells:
		footprint.append(c - anchor)
	# Retire toutes les cellules de la grille
	for c in all_cells:
		occupied_cells.erase(c)
	_moving_instance = inst
	_moving_origin_cell = anchor
	_moving_cost = float(data.get("cost", 0.0))
	_moving_footprint = footprint
	_setup_moving_preview_from_instance(inst)
	preview_sprite.visible = true
	is_moving = true
	inst.hide()
	return true

func _try_place_moved_building() -> void:
	if not is_instance_valid(_moving_instance):
		_stop_moving()
		return
	var mouse_pos := get_global_mouse_position()
	var cell_pos := get_grid_pos(mouse_pos)
	for offset in _moving_footprint:
		var target = cell_pos + offset
		if occupied_cells.has(target):
			return
	_moving_instance.global_position = get_world_pos(cell_pos)
	_moving_instance.show()
	if _moving_instance.get("cell_position") != null:
		_moving_instance.cell_position = cell_pos
	var new_cells: Array[Vector2i] = []
	for offset in _moving_footprint:
		new_cells.append(cell_pos + offset)
	_register_occupied_cells(_moving_instance, new_cells, cell_pos, _moving_cost)
	_stop_moving()

func _cancel_moving() -> void:
	if not is_instance_valid(_moving_instance):
		_stop_moving()
		return
	_moving_instance.global_position = get_world_pos(_moving_origin_cell)
	_moving_instance.show()
	if _moving_instance.get("cell_position") != null:
		_moving_instance.cell_position = _moving_origin_cell
	var restored_cells: Array[Vector2i] = []
	for offset in _moving_footprint:
		restored_cells.append(_moving_origin_cell + offset)
	_register_occupied_cells(_moving_instance, restored_cells, _moving_origin_cell, _moving_cost)
	_stop_moving()

func _stop_moving() -> void:
	is_moving = false
	_moving_instance = null
	preview_sprite.visible = false
	preview_sprite.modulate = Color(1, 1, 1, 0.6)
	_moving_footprint = []
