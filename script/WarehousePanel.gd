extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var inventory_list: ItemList = %InventoryList
@onready var status_label: Label = %StatusLabel

var current_warehouse: WarehouseEntity = null

func _ready() -> void:
	# 1. Appliquer le thème dès le démarrage
	UITheme.style_card(self, true, true) # Style le panneau
	UITheme.style_item_list(inventory_list) # Style la liste
	
	hide()

func setup(warehouse: WarehouseEntity) -> void:
	# Gestion de la connexion du signal (sécurisée)
	if current_warehouse and current_warehouse.entity_updated.is_connected(_refresh_ui):
		current_warehouse.entity_updated.disconnect(_refresh_ui)

	current_warehouse = warehouse
	current_warehouse.entity_updated.connect(_refresh_ui)
	
	_refresh_ui()
	show()

func _refresh_ui(_entity: Entity = null) -> void:
	if not current_warehouse:
		return

	inventory_list.clear()
	
	# On accède directement à l'inventaire de l'entrepôt
	var items = current_warehouse.inventory 
	
	for item_name in items:
		var quantity = items[item_name]
		# Ajout à l'UI
		inventory_list.add_item("%s : %d" % [item_name, quantity])

func _on_close() -> void:
	if current_warehouse and current_warehouse.entity_updated.is_connected(_refresh_ui):
		current_warehouse.entity_updated.disconnect(_refresh_ui)
	current_warehouse = null
	hide()
