extends Node2D

const CELL_SIZE: int = 32

@export var direction: Vector2 = Vector2.RIGHT

# La cellule occupée par CE segment de tapis (remplie automatiquement à la pose)
var cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	add_to_group("belt")
	# Calcule automatiquement sa propre cellule depuis sa position dans le monde
	cell = Vector2i(
		int(floor(global_position.x / CELL_SIZE)),
		int(floor(global_position.y / CELL_SIZE))
	)

func get_cell() -> Vector2i:
	return cell

func get_direction() -> Vector2:
	return direction
