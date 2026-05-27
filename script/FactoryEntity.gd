extends Entity
class_name FactoryEntity

# ─────────────────────────────────────────────────────────────────────────────
# FactoryEntity – Entité usine.
# Point d'extension pour la logique spécifique aux usines (animations, etc.)
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	entity_type = "factory"
	super._ready()

func _on_active_changed(_active: bool) -> void:
	# Pas d'animation dans factory.tscn pour l'instant.
	# Ajouter ici la logique si une AnimatedSprite2D est ajoutée à la scène.
	pass
