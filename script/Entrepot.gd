extends Entity
class_name WarehouseEntity

var inventory: Dictionary = {}

func _ready():
	add_to_group("entrepot")
	entity_type = "entrepot"
	super._ready()

# Surcharge : quand un tapis dépose une ressource, on l'envoie direct au stock global
func deposit_input(resource_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	# On n'utilise pas le buffer interne — on envoie directement au GameManager
	# ce qui déclenche automatiquement try_fulfill_contracts()
	GameManager.add_resource_stock({resource_id: amount})
	inventory[resource_id] = inventory.get(resource_id, 0) + amount
	entity_updated.emit(self)
	return amount

func can_accept_input(resource_id: String, amount: int = 1) -> bool:
	# L'entrepôt accepte tout
	return amount > 0

func give_resources(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	if int(inventory.get(resource_id, 0)) < amount:
		return false

	if GameManager.get_resource_stock(resource_id) < amount:
		return false

	GameManager.consume_resources({resource_id: amount})

	inventory[resource_id] = int(inventory.get(resource_id, 0)) - amount
	if int(inventory.get(resource_id, 0)) <= 0:
		inventory.erase(resource_id)

	entity_updated.emit(self)
	return true

func add_resource(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	entity_updated.emit(self)
