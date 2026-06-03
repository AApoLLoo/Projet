extends Entity
class_name WarehouseEntity

var inventory: Dictionary = {}

func _ready() -> void:
	entity_type = "entrepot"
	add_to_group("entrepot")
	super._ready()

func add_resource(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	
	# Tu utilises directement le signal hérité de Entity
	entity_updated.emit(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["inventory"] = inventory.duplicate(true)
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	var saved_inventory: Variant = data.get("inventory", {})
	if saved_inventory is Dictionary:
		inventory = saved_inventory.duplicate(true)
	else:
		inventory = {}
	add_to_group("entrepot")
