extends Entity
class_name TurbineEntity

# ─────────────────────────────────────────────────────────────────────────────
# TurbineEntity – Entité turbine.
# Gère l'animation (AnimatedSprite2D) en fonction de is_active.
# ─────────────────────────────────────────────────────────────────────────────

@onready var _anim_sprite: AnimatedSprite2D = _find_anim_sprite()
@onready var _white_puff_vfx: WhitePuffVfx = _find_white_puff_vfx()

func _ready() -> void:
	entity_type = "turbine"
	super._ready()
	
	# Force l'activation dès le spawn
	is_active = true 
	
	#EntityManager.register_entity(self)
	# Le scan se fera via le BuildingManager lors de la pose

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
	# Rayon 2 pour couvrir le 5x5
	for x in range(-2, 3):
		for y in range(-2, 3):
			if x == 0 and y == 0: continue
			
			var neighbor_pos = cell_position + Vector2i(x, y)
			var entity = EntityManager.get_entity_at_cell(neighbor_pos)
			
			if entity != null:
				var type = entity.get("entity_type")
				# On vérifie si c'est un tapis
				if type != null and "belt" in str(type):
					print("   >>> OUI ! Convoyeur détecté en ", neighbor_pos, ". Activation : ", is_active)
					if entity.has_method("set_powered"):
						entity.set_powered(is_active)
