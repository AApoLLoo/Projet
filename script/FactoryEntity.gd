extends Entity
class_name FactoryEntity

# ─────────────────────────────────────────────────────────────────────────────
# FactoryEntity – Entité usine.
# Point d'extension pour la logique spécifique aux usines (animations, etc.)
# ─────────────────────────────────────────────────────────────────────────────

@onready var _white_puff_vfx: WhitePuffVfx = _find_white_puff_vfx()

func _ready() -> void:
	entity_type = "factory"
	super._ready()

func _on_active_changed(active: bool) -> void:
	if _white_puff_vfx == null:
		_white_puff_vfx = _find_white_puff_vfx()
	if _white_puff_vfx != null:
		_white_puff_vfx.set_emitting(active)

func _find_white_puff_vfx() -> WhitePuffVfx:
	for child in get_children():
		if child is WhitePuffVfx:
			return child
	return null
