extends PanelContainer

@onready var title_label: Label       = %TitleLabel
@onready var inventory_list: ItemList = %InventoryList
@onready var status_label: Label      = %StatusLabel
@onready var close_btn: Button        = %CloseBtn

var current_warehouse: WarehouseEntity = null
var _signal_connected: bool = false

func _ready() -> void:
	_style_panel()

	inventory_list.item_clicked.connect(_on_item_clicked)

	close_btn.pressed.connect(_on_close)

	if GameManager:
		GameManager.resources_updated.connect(_on_resources_updated)

	hide()

func _style_panel() -> void:
	UITheme.style_card(self, false, true)
	UITheme.style_button(close_btn, UITheme.ACCENT_RED, UITheme.TEXT_LIGHT, false, true)
	UITheme.style_label(title_label, "section")
	UITheme.style_item_list(inventory_list)
	UITheme.style_label($MarginContainer/VBoxContainer/StockLabel, "caption")
	UITheme.style_label(status_label, "body")

func setup(warehouse: WarehouseEntity) -> void:
	if current_warehouse != null and _signal_connected:
		if current_warehouse.entity_updated.is_connected(_refresh_ui):
			current_warehouse.entity_updated.disconnect(_refresh_ui)
		_signal_connected = false

	current_warehouse = warehouse

	if current_warehouse == null:
		hide()
		return

	current_warehouse.entity_updated.connect(_refresh_ui)
	_signal_connected = true
	title_label.text = "Entrepôt"
	_refresh_ui()
	show()

func _on_close() -> void:
	if current_warehouse != null and _signal_connected:
		if current_warehouse.entity_updated.is_connected(_refresh_ui):
			current_warehouse.entity_updated.disconnect(_refresh_ui)
		_signal_connected = false
	current_warehouse = null
	hide()

func _on_resources_updated() -> void:
	_refresh_ui()

func _refresh_ui(_ignored = null) -> void:
	if not current_warehouse:
		return

	inventory_list.clear()

	# Utilise le stock LOCAL de cet entrepôt (pas le stock global)
	var stock: Dictionary = current_warehouse.get_inventory_snapshot() if current_warehouse.has_method("get_inventory_snapshot") else {}
	var has_any: bool = false

	for resource_id in stock.keys():
		var amount: int = int(stock[resource_id])
		if amount <= 0:
			continue
		has_any = true
		var idx: int = inventory_list.add_item(
			"📦  %s  —  %d\n      (clic pour extraire)" % [_resource_label(resource_id), amount]
		)
		inventory_list.set_item_metadata(idx, resource_id)

func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var resource_id: String = String(inventory_list.get_item_metadata(index))
	if resource_id.is_empty():
		return
	if not current_warehouse or current_warehouse.get_local_stock(resource_id) <= 0:
		status_label.text = "Plus de %s en stock." % _resource_label(resource_id)
		return

	# Retire 1 du stock LOCAL de cet entrepôt
	current_warehouse.give_resources(resource_id, 1)

	# Instancie le matériau réel et démarre le drag immédiatement
	var mat_scene: PackedScene = preload("res://scene/Materiaux.tscn")
	var mat = mat_scene.instantiate()
	mat.set_resource(resource_id, 1)
	# On définit _drag_origin à la position de spawn AVANT d'activer le drag
	# comme ça si on lâche au sol, il reste là où on lâche et ne disparaît pas
	get_tree().current_scene.add_child(mat)
	mat.global_position = get_global_mouse_position()
	mat._drag_origin = mat.global_position
	mat.dragging = true
	mat.offset = Vector2.ZERO
	mat.z_index = 100

	status_label.text = "Drag and Drop les matériaux."

func _resource_label(resource_id: String) -> String:
	match resource_id:
		"charbon":       return "Charbon"
		"gaz":           return "Gaz"
		"matiere_brute": return "Matière brute"
		"metal":         return "Métal"
		"piece_base":    return "Pièce de base"
		"piece_avancee": return "Pièce avancée"
		_:               return resource_id.capitalize()
