extends PanelContainer

# Assurez-vous que les noms dans l'éditeur correspondent à ces "%"
@onready var title_label: Label = %TitleLabel
@onready var inventory_list: ItemList = %InventoryList
@onready var status_label: Label = %StatusLabel

var current_warehouse: WarehouseEntity = null

func _ready() -> void:
	hide()

func setup(warehouse: WarehouseEntity) -> void:
	# 1. Nettoyage
	if current_warehouse and current_warehouse.entity_updated.is_connected(_refresh_ui):
		current_warehouse.entity_updated.disconnect(_refresh_ui)

	current_warehouse = warehouse
	
	# 2. Connexion
	current_warehouse.entity_updated.connect(_refresh_ui)
	
	# 3. Affichage initial
	_refresh_ui()
	show()

func _refresh_ui(_entity: Entity = null) -> void:
	# 1. Debug : On regarde si la fonction est bien lancée
	print("Refresh UI appelé !")
	
	if not current_warehouse:
		print("Erreur : current_warehouse est null !")
		return # La fonction s'arrête ici si l'entrepôt n'est pas défini
	
	print("Affichage des données pour : ", current_warehouse)
	
	# ... reste de votre code ...
	
	# 2. Forcez la visibilité (des fois le parent cache le panneau)	
	self.show()
	
func _on_close() -> void:
	if current_warehouse and current_warehouse.entity_updated.is_connected(_refresh_ui):
		current_warehouse.entity_updated.disconnect(_refresh_ui)
	current_warehouse = null
	hide()
