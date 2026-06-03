extends Entity
class_name MinerEntity

# ─────────────────────────────────────────────────────────────────────────────
# MinerEntity – Bâtiment d'extraction de ressources brutes.
# Produit automatiquement des ressources dans son output_buffer.
# Un tapis placé en sortie récupère ces ressources et les achemine.
# ─────────────────────────────────────────────────────────────────────────────

@onready var _anim_sprite: AnimatedSprite2D = _find_anim_sprite()

func _ready() -> void:
	entity_type = "miner"
	super._ready()
	# Le mineur démarre automatiquement dès le placement
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

func _find_anim_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null

func get_status_text() -> String:
	if not is_active:
		return "Arret"
	if current_recipe.is_empty():
		return "Aucune ressource"
	if not _has_output_capacity_for_recipe():
		return "Buffer plein"
	return "Extraction"
