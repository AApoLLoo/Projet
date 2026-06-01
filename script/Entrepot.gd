# Entrepot.gd
extends Node2D # Ou Node2D, selon votre structure

func _ready():
	add_to_group("entrepot") # Permet de le trouver facilement via get_tree()

func receive_resources(resource_id: String, quantity: int):
	# Appel vers GameManager pour mettre à jour le stock global
	GameManager.add_resource_stock({resource_id: quantity})
	print("Entrepôt : %d de %s reçu." % [quantity, resource_id])

func give_resources(resource_id: String, quantity: int) -> bool:
	# Vérifie si le stock est suffisant dans le GameManager
	if GameManager.has_resources({resource_id: quantity}):
		GameManager.consume_resources({resource_id: quantity})
		return true
	return false
