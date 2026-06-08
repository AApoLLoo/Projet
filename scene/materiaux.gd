extends Area2D

var destination = ""
var quantity: int = 1
var temps_attente = 0
var etat = "en_attente"
var dragging = false
var offset = Vector2.ZERO
var _drag_origin: Vector2 = Vector2.ZERO

const FRAMES = {
	"charbon": 12,
	"gaz": 61,
	"matiere_brute": 35,
	"metal": 14,
	"piece_base": 45,
	"piece_avancee": 47,
}

func _ready():
	input_pickable = true
	add_to_group("ground_materials")
	_appliquer_apparence()
	_drag_origin = global_position
	z_index = max(z_index, 10)

func set_resource(resource_id: String, amount: int = 1) -> void:
	destination = resource_id
	quantity = max(1, amount)
	_appliquer_apparence()

func prepare_ground_spawn(world_position: Vector2) -> void:
	global_position = world_position
	_drag_origin = world_position
	dragging = false
	offset = Vector2.ZERO
	input_pickable = true
	z_index = max(z_index, 10)

func serialize() -> Dictionary:
	return {
		"resource_id": destination,
		"quantity": quantity,
		"world_x": global_position.x,
		"world_y": global_position.y,
	}

func deserialize(data: Dictionary) -> void:
	set_resource(String(data.get("resource_id", destination)), int(data.get("quantity", quantity)))
	prepare_ground_spawn(Vector2(float(data.get("world_x", global_position.x)), float(data.get("world_y", global_position.y))))

func _appliquer_apparence():
	if destination.is_empty():
		return
	var sprite = $Sprite2D
	if sprite and FRAMES.has(destination):
		sprite.frame = FRAMES[destination]

func _process(delta):
	temps_attente += delta
	if dragging:
		global_position = get_global_mouse_position() + offset

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var bm = get_tree().current_scene.get_node_or_null("BuildingManager")
			if bm and bool(bm.get("is_destroying")):
				return
			dragging = true

func _input(event):
	if dragging:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				dragging = false
				z_index = 0
				if not _try_drop_at_current_position():
					# Pas de cible valide : reste au sol là où on a lâché
					_drag_origin = global_position
					z_index = 0

# Appelé par ConveyorEntity.eject_carried_item() :
# place l'item directement en mode drag sous la souris.
func pickup_from_belt(world_position: Vector2) -> void:
	global_position = world_position
	_drag_origin = world_position
	z_index = 50
	input_pickable = true
	# Offset nul : le centre du sprite suit exactement la souris
	offset = Vector2.ZERO
	dragging = true

func _try_drop_at_current_position() -> bool:
	if destination.is_empty() or quantity <= 0:
		return false

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false

	var building_manager: Node = current_scene.get_node_or_null("BuildingManager")
	if building_manager == null or not building_manager.has_method("get_grid_pos"):
		return false

	var cell_pos_variant: Variant = building_manager.call("get_grid_pos", global_position)
	if not (cell_pos_variant is Vector2i):
		return false
	var target_cell: Vector2i = cell_pos_variant

	if GameManager != null and GameManager.has_default_delivery_point and GameManager.default_delivery_cell == target_cell:
		GameManager.add_resource_stock({destination: quantity})
		queue_free()
		return true

	var target_entity: Entity = EntityManager.get_entity_at_cell(target_cell)
	if target_entity == null:
		return false

	if target_entity is ConveyorEntity:
		var conveyor: ConveyorEntity = target_entity
		if conveyor.inject_manual_item(destination, quantity):
			queue_free()
			return true
		return false

	if not target_entity.can_accept_input(destination, quantity):
		return false
	if target_entity.deposit_input(destination, quantity) != quantity:
		return false
	# Afficher le panneau de l'entité après dépôt (comme l'entrepôt)
	var hud: Node = get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.has_method("open_entity_panel"):
		hud.open_entity_panel(target_entity)
	queue_free()
	return true
