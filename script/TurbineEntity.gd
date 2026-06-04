extends Entity
class_name TurbineEntity

# ─────────────────────────────────────────────────────────────────────────────
# TurbineEntity – Entité turbine.
# Gère l'animation (AnimatedSprite2D) en fonction de is_active.
# ─────────────────────────────────────────────────────────────────────────────

# kW produits par cette turbine dans sa zone
var electricity_output: float = 100.0
# Rayon (en cellules) de la zone d'alimentation électrique
var zone_radius: int = 20

@onready var _anim_sprite: AnimatedSprite2D = _find_anim_sprite()
@onready var _white_puff_vfx: WhitePuffVfx = _find_white_puff_vfx()

func _ready() -> void:
	entity_type = "turbine"
	# Les turbines produisent de l'électricité, elles n'en consomment pas
	electricity_need = 0.0
	super._ready()
	# Démarre automatiquement à la pose ; désactivé si restauré depuis une sauvegarde
	if not is_active:
		is_active = true

func _on_active_changed(active: bool) -> void:
	if _anim_sprite == null:
		_anim_sprite = _find_anim_sprite()
	if _anim_sprite != null:
		if active:
			_anim_sprite.play()
		else:
			_anim_sprite.stop()
			_anim_sprite.frame = 0
	if _white_puff_vfx == null:
		_white_puff_vfx = _find_white_puff_vfx()
	if _white_puff_vfx != null:
		_white_puff_vfx.set_emitting(active)

# Cherche l'AnimatedSprite2D parmi les enfants (fonctionne même si le nom change)
func _find_anim_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null

func _find_white_puff_vfx() -> WhitePuffVfx:
	for child in get_children():
		if child is WhitePuffVfx:
			return child
	return null
# Dans TurbineEntity.gd
func _on_active_toggled(value: bool):
	is_active = value
	update_neighbors()

func update_neighbors():
	var rayon = zone_radius
	
	for x in range(-rayon, rayon + 1):
		for y in range(-rayon, rayon + 1):
			if x == 0 and y == 0:
				continue
			
			# Vérifie la distance réelle (pas juste le carré)
			if Vector2(x, y).length() > float(rayon):
				continue
			
			var pos_a_verifier = cell_position + Vector2i(x, y)
			var ent = EntityManager.get_entity_at_cell(pos_a_verifier)
			
			if ent != null:
				var type = str(ent.get("entity_type"))
				if "belt" in type:
					if ent.has_method("set_powered"):
						ent.set_powered(is_active)
