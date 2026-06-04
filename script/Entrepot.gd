extends Entity
class_name WarehouseEntity

# Stock LOCAL de cet entrepôt (isolé des autres entrepôts)
var inventory: Dictionary = {}

func _ready():
	add_to_group("entrepot")
	entity_type = "entrepot"
	super._ready()

# Quand un tapis dépose une ressource : ajout au stock LOCAL de cet entrepôt uniquement
func deposit_input(resource_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	inventory[resource_id] = inventory.get(resource_id, 0) + amount
	# On met aussi à jour le stock global pour que le HUD et les machines y aient accès
	GameManager.add_resource_stock({resource_id: amount})
	entity_updated.emit(self)
	return amount

func can_accept_input(resource_id: String, amount: int = 1) -> bool:
	return amount > 0

# Donner des ressources depuis cet entrepôt (pour les exports)
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
	var local_stock: int = inventory.get(resource_id, 0)
	if local_stock < amount:
		return false
	inventory[resource_id] = max(0, local_stock - amount)
	GameManager.consume_resources({resource_id: amount})
	entity_updated.emit(self)
	return true

func get_local_stock(resource_id: String) -> int:
	return inventory.get(resource_id, 0)

func get_inventory_snapshot() -> Dictionary:
	return inventory.duplicate()

func add_resource(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	entity_updated.emit(self)

# Sérialisation / désérialisation pour la sauvegarde
func serialize() -> Dictionary:
	var data: Dictionary = super.serialize() if super.has_method("serialize") else {}
	data["warehouse_inventory"] = inventory.duplicate()
	return data

func deserialize(data: Dictionary) -> void:
	if super.has_method("deserialize"):
		super.deserialize(data)
	var saved_inv: Dictionary = data.get("warehouse_inventory", {})
	for k in saved_inv.keys():
		inventory[k] = int(saved_inv[k])
