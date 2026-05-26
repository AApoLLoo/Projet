extends Node2D

@export var cell_size: int = 32 # En accord avec la taille des cellules de floor.gd
@export var buildings_node: Node2D # Nœud parent pour regrouper les usines placées

var factory_scene: PackedScene
var factory_cost: float = 0.0
var is_building: bool = false
var preview_sprite: Sprite2D
var occupied_cells: Dictionary = {} # Garde en mémoire les cases utilisées

func _ready() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.visible = false
	preview_sprite.z_index = 10 # Assure que le fantôme reste visible par-dessus le sol
	add_child(preview_sprite)

	# S'assurer que le preview est centré par rapport à sa position
	preview_sprite.centered = true

# --- MODIFICATION ICI : Ajout de frames_count ---
func start_building(scene: PackedScene, cost: float, texture: Texture2D, frames_count: int = 1) -> void:
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
	if not is_building:
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
		
		# Enregistrement de la case comme étant occupée
		occupied_cells[cell_pos] = true
		
		# Création de l'usine
		var factory_instance: Node2D = factory_scene.instantiate()
		# Ajoute en tant qu'enfant du nœud de bâtiments (si défini) avant de positionner
		if buildings_node:
			buildings_node.add_child(factory_instance)
		else:
			add_child(factory_instance)
		# Positionner l'instance au centre de la case en coordonnées globales
		factory_instance.global_position = preview_sprite.global_position
		# Assurer une visibilité complète et ordre d'affichage
		if factory_instance.has_method("set_z_index"):
			factory_instance.z_index = preview_sprite.z_index - 1
		# Forcer les sprites enfants à être centrés (évite les découpes causées par un pivot en haut-gauche)
		for child in factory_instance.get_children():
			if child is Sprite2D:
				child.centered = true
				child.region_enabled = false
			elif child is AnimatedSprite2D:
				child.centered = true
			
		# Optionnel : décommentez la ligne suivante pour quitter le mode construction après un seul placement
		# stop_building()

func _can_build(cell_pos: Vector2i) -> bool:
	# 1. Vérification si une usine est déjà présente
	if occupied_cells.has(cell_pos):
		return false
	# 2. Vérification des fonds disponibles
	if GameManager.credits < factory_cost:
		return false
	return true
