extends Entity 
class_name WarehouseEntity

var inventory: Dictionary = {} 

# NE PAS REDÉCLARER LE SIGNAL ICI, IL EST DÉJÀ DANS ENTITY
# signal entity_updated(entity)  <-- SUPPRIME CETTE LIGNE

func _ready():
	add_to_group("entrepot")

func add_resource(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	
	# Tu utilises directement le signal hérité de Entity
	entity_updated.emit(self)
