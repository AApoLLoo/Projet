extends Node2D
class_name ElectricityOverlay

# ─────────────────────────────────────────────────────────────────────────────
# ElectricityOverlay – Affiche les zones d'électricité des turbines en surimpression
# sur le monde. Doit être enfant direct de la scène Level (position 0,0).
# Activé / désactivé via show() / hide() depuis le HUD.
# ─────────────────────────────────────────────────────────────────────────────

# Couleur de remplissage de la zone (vert électrique translucide)
const FILL_COLOR_ACTIVE   := Color(0.25, 1.0, 0.45, 0.10)
const FILL_COLOR_INACTIVE := Color(0.6,  0.6,  0.6,  0.06)
# Couleur du contour
const OUTLINE_COLOR_ACTIVE   := Color(0.35, 1.0, 0.55, 0.75)
const OUTLINE_COLOR_INACTIVE := Color(0.55, 0.55, 0.55, 0.45)
const OUTLINE_WIDTH := 2.0
# Nombre de segments pour l'approximation du cercle isométrique
const SEGMENTS := 48

# Référence au BuildingManager pour les conversions grille ↔ monde
var _building_manager: Node = null
# Vecteurs de base de la grille isométrique (calculés une fois)
var _basis_x := Vector2.ZERO
var _basis_y := Vector2.ZERO
var _basis_computed := false

func _ready() -> void:
	z_index = 100
	hide()  # Caché par défaut
	_find_building_manager()
	# Se redessiner quand les entités changent (turbine ajoutée / supprimée)
	if EntityManager and not EntityManager.totals_changed.is_connected(_on_entities_changed):
		EntityManager.totals_changed.connect(_on_entities_changed)

func _on_entities_changed(_energy: float, _co2: float) -> void:
	if visible:
		queue_redraw()

func _find_building_manager() -> void:
	_building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if _building_manager:
		_compute_basis()

func _compute_basis() -> void:
	if _building_manager == null:
		return
	# Les deux vecteurs de base de la transformation isométrique grille → monde
	var origin: Vector2 = _building_manager.call("get_world_pos", Vector2i(0, 0))
	var px: Vector2 = _building_manager.call("get_world_pos", Vector2i(1, 0))
	var py: Vector2 = _building_manager.call("get_world_pos", Vector2i(0, 1))
	_basis_x = px - origin
	_basis_y = py - origin
	_basis_computed = true

func _draw() -> void:
	if not visible:
		return
	if not _basis_computed:
		_find_building_manager()
		if not _basis_computed:
			return

	if EntityManager == null:
		return

	for entity_variant in EntityManager.entities.values():
		var entity: Entity = entity_variant as Entity
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.entity_type != "turbine":
			continue

		var radius: int = int(entity.get("zone_radius")) if entity.get("zone_radius") != null else 20
		var center: Vector2 = entity.global_position
		var is_active: bool = entity.is_active

		# Génère le polygone — cercle dans l'espace grille projeté en monde isométrique
		var points := PackedVector2Array()
		points.resize(SEGMENTS)
		for i in SEGMENTS:
			var angle := TAU * float(i) / float(SEGMENTS)
			var dx := cos(angle) * float(radius)
			var dy := sin(angle) * float(radius)
			points[i] = center + _basis_x * dx + _basis_y * dy

		# Remplissage
		var fill_color := FILL_COLOR_ACTIVE if is_active else FILL_COLOR_INACTIVE
		draw_colored_polygon(points, fill_color)

		# Contour fermé
		var outline_color := OUTLINE_COLOR_ACTIVE if is_active else OUTLINE_COLOR_INACTIVE
		var outline_pts := PackedVector2Array(points)
		outline_pts.append(outline_pts[0])
		draw_polyline(outline_pts, outline_color, OUTLINE_WIDTH, true)

		# Petit indicateur central (cercle de 6px autour de la turbine)
		draw_circle(center, 6.0, outline_color)
