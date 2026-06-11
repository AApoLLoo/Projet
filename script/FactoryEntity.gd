extends Entity
class_name FactoryEntity

const FACTORY_MAX_STOCK_PER_RESOURCE: int = 16

# ─────────────────────────────────────────────────────────────────────────────
# FactoryEntity – Entité usine.
# Point d'extension pour la logique spécifique aux usines (animations, etc.)
# ─────────────────────────────────────────────────────────────────────────────

@onready var _white_puff_vfx: WhitePuffVfx = _find_white_puff_vfx()
@onready var _black_smoke_vfx: BlackSmokeVfx = _find_black_smoke_vfx()
@onready var _main_sprite: Sprite2D = _find_main_sprite()

func _ready() -> void:
	entity_type = "factory"
	max_input_stock = FACTORY_MAX_STOCK_PER_RESOURCE
	max_output_stock = FACTORY_MAX_STOCK_PER_RESOURCE
	super._ready()
	# Démarre automatiquement à la pose ; désactivé si restauré depuis une sauvegarde
	if not is_active:
		is_active = true

func _on_active_changed(active: bool) -> void:
	if _white_puff_vfx == null:
		_white_puff_vfx = _find_white_puff_vfx()
	if _white_puff_vfx != null:
		_white_puff_vfx.set_emitting(active)

func _on_broken_changed(broken: bool) -> void:
	if _black_smoke_vfx == null:
		_black_smoke_vfx = _find_black_smoke_vfx()
	if _black_smoke_vfx != null:
		_black_smoke_vfx.set_emitting(broken)
	if _main_sprite == null:
		_main_sprite = _find_main_sprite()
	if _main_sprite != null:
		_main_sprite.modulate = Color(0.62, 0.62, 0.62) if broken else Color.WHITE

func _find_white_puff_vfx() -> WhitePuffVfx:
	for child in get_children():
		if child is WhitePuffVfx:
			return child
	return null

func _find_black_smoke_vfx() -> BlackSmokeVfx:
	for child in get_children():
		if child is BlackSmokeVfx:
			return child
	return null

func _find_main_sprite() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null
