extends Entity

@export var co2_absorption_per_minute: float = 2.0
@export var arbre_variant: String = "vert" # "vert", "vertF", "rouge", "blanc"

@onready var sprite_vert_f: Sprite2D = $ArbreSpriteVertF
@onready var sprite_vert: Sprite2D = $ArbreSpriteVert
@onready var sprite_rouge: Sprite2D = $ArbreSpriteRouge
@onready var sprite_blanc: Sprite2D = $ArbreSpriteBlanc

func _ready() -> void:
	entity_type = "arbre"
	is_active = true
	electricity_need = 0.0
	_apply_variant()
	super._ready()

func _apply_variant() -> void:
	if sprite_vert_f: sprite_vert_f.hide()
	if sprite_vert:   sprite_vert.hide()
	if sprite_rouge:  sprite_rouge.hide()
	if sprite_blanc:  sprite_blanc.hide()
	
	match arbre_variant:
		"vertF":  if sprite_vert_f: sprite_vert_f.show()
		"vert":   if sprite_vert:   sprite_vert.show()
		"rouge":  if sprite_rouge:  sprite_rouge.show()
		"blanc":  if sprite_blanc:  sprite_blanc.show()
		_:        if sprite_vert:   sprite_vert.show()

func get_co2_rate() -> float:
	return -co2_absorption_per_minute

func get_energy_delta() -> float:
	return 0.0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["co2_absorption_per_minute"] = co2_absorption_per_minute
	data["arbre_variant"] = arbre_variant
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	co2_absorption_per_minute = float(data.get("co2_absorption_per_minute", 2.0))
	arbre_variant = data.get("arbre_variant", "vert")
	_apply_variant()
