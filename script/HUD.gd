extends CanvasLayer

signal order_delivery_preview_changed(point_state)

const ACTION_TOGGLE_ORDER_PANEL: StringName = &"hud_toggle_order_panel"
const ACTION_TOGGLE_SESSION_OVERVIEW: StringName = &"hud_toggle_session_overview"
const ACTION_TOGGLE_BUILD_MENU: StringName = &"hud_toggle_build_menu"

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var co2_label: Label = %CO2Label

@onready var session_overview_panel: PanelContainer = %SessionOverviewPanel
@onready var overview_day_value: Label = %OverviewDayValue
@onready var overview_time_value: Label = %OverviewTimeValue
@onready var overview_credits_value: Label = %OverviewCreditsValue
@onready var overview_machines_value: Label = %OverviewMachinesValue
@onready var overview_active_machines_value: Label = %OverviewActiveMachinesValue
@onready var overview_production_rate_value: Label = %OverviewProductionRateValue
@onready var overview_failures_value: Label = %OverviewFailuresValue
@onready var overview_co2_value: Label = %OverviewCO2Value
@onready var overview_electricity_value: Label = %OverviewElectricityValue

@onready var btn_pause: Button = %BtnPause
@onready var btn_x1: Button = %BtnX1
@onready var btn_x2: Button = %BtnX2
@onready var btn_x4: Button = %BtnX4
@onready var btn_toggle_orders: Button = %BtnToggleOrders
@onready var btn_toggle_session_overview: Button = %BtnToggleSessionOverview

# --- NOUVEAUX BOUTONS DE CONSTRUCTION ---
@onready var btn_toggle_build_menu: Button = %BtnToggleBuildMenu # Le bouton "Construction" principal
@onready var build_menu_container: VBoxContainer = %BuildMenuContainer # Le conteneur (menu déroulant)

@onready var btn_build_factory: Button = %BtnBuildFactory 
@onready var btn_build_belt: Button = %BtnBuildBelt       
@onready var btn_build_turbine: Button = %BtnBuildTurbine 

###BELT###
@onready var menu_belt: HBoxContainer = $Menu_Belt
@onready var curve_top: Button = $Menu_Belt/Curve_Top
@onready var curve_down: Button = $Menu_Belt/Curve_Down
@onready var curve_right: Button = $Menu_Belt/Curve_Right
@onready var curve_left: Button = $Menu_Belt/Curve_left
@onready var belt_droit: Button = $Menu_Belt/Belt_droit
@onready var belt_left: Button = $Menu_Belt/Belt_left

@onready var orders_panel: PanelContainer = %OrdersPanel
@onready var order_resource_selector: OptionButton = %OrderResourceSelector
@onready var order_quantity_spinbox: SpinBox = %OrderQuantitySpinBox
@onready var order_unit_cost_value: Label = %OrderUnitCostValue
@onready var order_total_cost_value: Label = %OrderTotalCostValue
@onready var order_stock_value: Label = %OrderStockValue
@onready var default_delivery_point_value: Label = %DefaultDeliveryPointValue
@onready var order_delivery_point_value: Label = %OrderDeliveryPointValue
@onready var inventory_summary_label: Label = %InventorySummaryLabel
@onready var orders_status_label: Label = %OrdersStatusLabel
@onready var btn_choose_default_delivery_point: Button = %BtnChooseDefaultDeliveryPoint
@onready var btn_choose_order_delivery_point: Button = %BtnChooseOrderDeliveryPoint
@onready var btn_clear_order_delivery_point: Button = %BtnClearOrderDeliveryPoint
@onready var btn_submit_order: Button = %BtnSubmitOrder

# --- DICTIONNAIRE MIS À JOUR ---
# --- DICTIONNAIRE MIS À JOUR AVEC DIRECTIONS ET VIRAGES ---
var buildings_data = {
	"factory": {
		"scene": preload("res://scene/factory.tscn"),
		"texture": preload("res://asset/IndustrialTile_14.png"),
		"cost": 200.0,
		"frames": 1
	},
	"turbine": {
		"scene": preload("res://scene/turbine_2d.tscn"),
		"texture": preload("res://asset/Turbine Animation base.png"),
		"cost": 500.0,
		"frames": 6
	},
	
	# --- TAPIS DROITS (Exemples de directions si vous séparez les scènes) ---
	"belt_right": {
		"scene": preload("res://scene/ASSET/belt/beltmid.tscn"), # À adapter si vous créez une scène par direction
		"texture": preload("res://asset/belt-midNO.png"),
		"cost": 50.0,
		"frames": 4
	},
	"belt_left": {
		"scene": preload("res://scene/ASSET/belt/beltleft.tscn"), 
		"texture": preload("res://asset/belt-mid.png"),
		"cost": 50.0,
		"frames": 4
	},
	
	# --- VIRAGES / COURBES (Curves 1 à 4 basées sur vos assets) ---
	"curve_top": {
		"scene": preload("res://scene/ASSET/beltcurvetop.tscn"), # Votre scène existante !
		"texture": preload("res://asset/Curve_0001.png"),   # Texture correspondante
		"cost": 60.0,
		"frames": 4 # Mettez le nombre de frames d'animation si elles sont animées
	},
	"curve_down": {
		"scene": preload("res://scene/ASSET/belt/curvedown.tscn"), # À créer sur le modèle de beltcurvetop
		"texture": preload("res://asset/Curve_0002.png"),
		"cost": 60.0,
		"frames": 4
	},
	"curve_left": {
		"scene": preload("res://scene/ASSET/belt/curveright.tscn"),
		"texture": preload("res://asset/Curve_0003.png"),
		"cost": 60.0,
		"frames": 4
	},
	"curve_right": {
		"scene": preload("res://scene/ASSET/belt/curveright.tscn"),
		"texture": preload("res://asset/Curve_0004.png"),
		"cost": 60.0,
		"frames": 4
	}
}
@onready var minimap_camera: Camera2D = %MinimapCamera

const ENTITY_PANEL_SCENE := preload("res://scene/entity_panel.tscn")
var _entity_panel: PanelContainer = null
var _building_manager: Node = null
var _delivery_manager: Node = null
var _pending_order_delivery_point: Dictionary = {}
var _delivery_selection_context: String = ""
var _orderable_resources: Array[Dictionary] = []
var _is_delivery_point_selection_active: bool = false

func _ready() -> void:
	_ensure_input_actions()
	if session_overview_panel:
		session_overview_panel.hide()
	if orders_panel:
		orders_panel.hide()

	# On s'assure que le menu est caché au démarrage
	menu_belt.hide()
	
	# Connexion aux signaux du TimeManager
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	
	# --- CORRECTION 1 : Indentation corrigée ici ---
	
	
	# Exemple pour les tapis droits
	belt_droit.pressed.connect(func():
		print("Mode construction : Tapis Droit")
		_start_building_process("belt_right")
		menu_belt.hide()
	)
	belt_left.pressed.connect(func():
		print("Mode construction : Tapis Droit")
		_start_building_process("belt_left")
		menu_belt.hide()
	)
	# Exemple pour vos courbes (Curves)
	curve_top.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_top")
		menu_belt.hide()
	)
	curve_down.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_down")
		menu_belt.hide()
	)
	curve_right.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_right")
		menu_belt.hide()
	)
	curve_left.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_left")
		menu_belt.hide()
	)
	
	if GameManager:
		GameManager.resources_updated.connect(_on_resources_updated)
		if GameManager.has_signal("default_delivery_point_changed"):
			GameManager.default_delivery_point_changed.connect(_on_default_delivery_point_changed)
		_update_money_display()
		_update_co2_display()

	# --- PANNEAU ENTITÉ ---
	_entity_panel = ENTITY_PANEL_SCENE.instantiate()
	add_child(_entity_panel)
	
	# Boutons de contrôle du temps
	btn_pause.pressed.connect(func(): TimeManager.time_speed = 0.0)
	btn_x1.pressed.connect(func(): TimeManager.time_speed = 1.0)
	btn_x2.pressed.connect(func(): TimeManager.time_speed = 2.0)
	btn_x4.pressed.connect(func(): TimeManager.time_speed = 4.0)
	
	# Initialisation avec les valeurs actuelles au lancement
	_update_day_display(TimeManager.current_day)
	
	# Calculer manuellement l'heure pour la toute première frame
	var hour: int = int(TimeManager.current_time)
	var minute: int = int((TimeManager.current_time - hour) * 60)
	_update_time_display(hour, minute)
	_update_session_overview()
	_bind_runtime_managers()
	_setup_order_panel()

	# --- GESTION DU MENU DE CONSTRUCTION ---
	# 1. Cliquer sur "Construction" affiche ou masque le conteneur
	btn_toggle_orders.pressed.connect(_toggle_orders_panel)
	btn_toggle_session_overview.pressed.connect(_toggle_session_overview)
	btn_toggle_build_menu.pressed.connect(_toggle_build_menu)

	# 2. Les sous-boutons lancent la construction
	btn_build_factory.pressed.connect(func():
		print("Clic sur USINE !")
		_start_building_process("factory")
	)
	
	# --- CORRECTION 2 : Connexion directe et propre ---
	btn_build_belt.pressed.connect(_on_menu_belt_pressed)
	# --------------------------------------------------
	
	btn_build_turbine.pressed.connect(func():
		print("Clic sur TURBINE !")
		_start_building_process("turbine")
	)

	_style_button(btn_build_belt, Color.html("#3D6F8E"))
	_style_button(btn_build_turbine, Color.html("#4F8F5B"))
	_style_button(btn_build_factory, Color.html("#A66A3F"))

	# --- BOUTON D'ANNULATION DU DERNIER BATIMENT (créé dynamiquement) ---
	var undo_button: Button = Button.new()
	undo_button.name = "BtnUndoBuild"
	undo_button.text = "Annuler dernier bâtiment (50%)"
	_style_button(undo_button, Color.html("#8A6D2E"))
	undo_button.visible = false
	# Positionnement simple : en bas du menu de construction si présent, sinon en haut à gauche
	if build_menu_container:
		build_menu_container.add_child(undo_button)
	else:
		add_child(undo_button)

	# Connexion du clic
	undo_button.pressed.connect(_on_undo_build_pressed)

	# Connexion au BuildingManager pour synchroniser la visibilité
	if _building_manager:
		# Si le BuildingManager offre un signal, on l'écoute
		if _building_manager.has_signal("last_build_state_changed"):
			_building_manager.last_build_state_changed.connect(func(available):
				undo_button.visible = available
			)
		# Set initial visibility si nécessaire
		undo_button.visible = _building_manager.has_method("has_last_build") and _building_manager.has_last_build()

		# Connecter la sélection d'entité
		if _building_manager.has_signal("entity_selected") and not _building_manager.entity_selected.is_connected(_on_entity_selected):
			_building_manager.entity_selected.connect(_on_entity_selected)

		# --- BOUTON MODE DESTRUCTION (toggle) ---
		var destroy_button: Button = Button.new()
		destroy_button.name = "BtnDestroyMode"
		destroy_button.text = "Mode destruction"
		_style_button(destroy_button, Color.html("#8A3A3A"))
		destroy_button.toggle_mode = true
		destroy_button.set_pressed(false)
		if build_menu_container:
			build_menu_container.add_child(destroy_button)
		else:
			add_child(destroy_button)

		# Quand l'utilisateur bascule le bouton, on demande au BuildingManager de démarrer/arrêter
		destroy_button.toggled.connect(func(pressed):
			var bm = get_tree().current_scene.find_child("BuildingManager", true, false)
			if bm:
				if pressed and bm.has_method("start_destroying"):
					bm.start_destroying()
				elif not pressed and bm.has_method("stop_destroying"):
					bm.stop_destroying()
		)

		# Synchroniser l'état du bouton avec le BuildingManager
		if _building_manager and _building_manager.has_signal("destroy_mode_changed"):
			_building_manager.destroy_mode_changed.connect(func(enabled):
				destroy_button.set_pressed(enabled)
			)
		if _building_manager:
			destroy_button.set_pressed(_building_manager.is_destroying)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.is_action_pressed(ACTION_TOGGLE_ORDER_PANEL):
			_toggle_orders_panel()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.is_action_pressed(ACTION_TOGGLE_BUILD_MENU):
			_toggle_build_menu()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.is_action_pressed(ACTION_TOGGLE_SESSION_OVERVIEW):
			_toggle_session_overview()
			get_viewport().set_input_as_handled()

# --- NOUVELLE FONCTION ---
func _start_building_process(building_type: String) -> void:
	var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if building_manager:
		var data = buildings_data[building_type]
		building_manager.start_building(data["scene"], data["cost"], data["texture"], data.get("frames", 1))
		# Fermer le menu de construction après la sélection
		if build_menu_container:
			build_menu_container.visible = false
		# Masquer le panneau entité quand on entre en mode construction
		if _entity_panel:
			_entity_panel.hide()

func _on_entity_selected(entity) -> void:
	if _entity_panel == null:
		return
	if entity == null:
		_entity_panel.hide()
	else:
		_entity_panel.setup(entity)

func _process(_delta: float) -> void:
	# Synchroniser la caméra de la minimap avec la caméra principale
	var main_camera = get_viewport().get_camera_2d()
	if main_camera and is_instance_valid(main_camera):
		minimap_camera.global_position = main_camera.global_position

func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)
	_update_session_overview()

func _on_day_changed(day: int) -> void:
	_update_day_display(day)
	_update_session_overview()

func _update_time_display(hour: int, minute: int) -> void:
	# Formatage avec des zéros (ex: 08:05)
	time_label.text = "%02d:%02d" % [hour, minute]

func _update_day_display(day: int) -> void:
	day_label.text = "Jour %d" % day

func _on_resources_updated() -> void:
	_update_money_display()
	_update_co2_display()
	_update_session_overview()
	_update_order_panel()

func _update_money_display() -> void:
	if money_label and GameManager:
		money_label.text = _format_money_value(GameManager.credits)

func _update_co2_display() -> void:
	if co2_label and GameManager:
		co2_label.text = _format_rate_value(GameManager.co2_emissions, "g/min CO2")

func _toggle_session_overview() -> void:
	if session_overview_panel == null:
		return

	if not session_overview_panel.visible:
		_update_session_overview()

	session_overview_panel.visible = not session_overview_panel.visible

func _toggle_orders_panel() -> void:
	if orders_panel == null:
		return
	_update_order_panel()
	orders_panel.visible = not orders_panel.visible

func _toggle_build_menu() -> void:
	if build_menu_container == null:
		return
	build_menu_container.visible = not build_menu_container.visible

func _update_session_overview() -> void:
	if session_overview_panel == null:
		return

	overview_day_value.text = "Jour %d" % TimeManager.current_day
	var hour: int = int(TimeManager.current_time)
	var minute: int = int((TimeManager.current_time - hour) * 60)
	overview_time_value.text = "%02d:%02d" % [hour, minute]

	if GameManager:
		overview_credits_value.text = _format_money_value(GameManager.credits)
		overview_co2_value.text = _format_rate_value(GameManager.co2_emissions, "g/min")
		overview_electricity_value.text = _format_energy_value(GameManager.energy_usage)
	else:
		overview_credits_value.text = "N/A"
		overview_co2_value.text = "Placeholder"
		overview_electricity_value.text = "Placeholder"

	var machine_count: int = 0
	var active_machine_count: int = 0
	var production_rate_total: float = 0.0
	if EntityManager:
		for entity_variant in EntityManager.entities.values():
			var entity: Entity = entity_variant as Entity
			if entity == null or not is_instance_valid(entity):
				continue
			machine_count += 1
			if entity.is_active:
				active_machine_count += 1
			production_rate_total += entity.production_rate

	overview_machines_value.text = str(machine_count)
	overview_active_machines_value.text = "%d / %d" % [active_machine_count, machine_count]
	if machine_count > 0:
		overview_production_rate_value.text = "%.0f%%" % [production_rate_total / float(machine_count) * 100.0]
	else:
		overview_production_rate_value.text = "0%"
	overview_failures_value.text = "A venir (placeholder)"

func _bind_runtime_managers() -> void:
	_building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	_delivery_manager = get_tree().current_scene.find_child("DeliveryManager", true, false)

	if _building_manager and _building_manager.has_signal("delivery_point_selected") and not _building_manager.delivery_point_selected.is_connected(_on_delivery_point_selected):
		_building_manager.delivery_point_selected.connect(_on_delivery_point_selected)
	if _building_manager and _building_manager.has_signal("delivery_point_selection_changed") and not _building_manager.delivery_point_selection_changed.is_connected(_on_delivery_point_selection_changed):
		_building_manager.delivery_point_selection_changed.connect(_on_delivery_point_selection_changed)
	if _delivery_manager:
		if _delivery_manager.has_signal("order_submitted") and not _delivery_manager.order_submitted.is_connected(_on_order_submitted):
			_delivery_manager.order_submitted.connect(_on_order_submitted)
		if _delivery_manager.has_signal("delivery_started") and not _delivery_manager.delivery_started.is_connected(_on_delivery_started):
			_delivery_manager.delivery_started.connect(_on_delivery_started)
		if _delivery_manager.has_signal("delivery_completed") and not _delivery_manager.delivery_completed.is_connected(_on_delivery_completed):
			_delivery_manager.delivery_completed.connect(_on_delivery_completed)
		if _delivery_manager.has_signal("delivery_failed") and not _delivery_manager.delivery_failed.is_connected(_on_delivery_failed):
			_delivery_manager.delivery_failed.connect(_on_delivery_failed)
		if _delivery_manager.has_signal("queue_changed") and not _delivery_manager.queue_changed.is_connected(_on_delivery_queue_changed):
			_delivery_manager.queue_changed.connect(_on_delivery_queue_changed)

func _setup_order_panel() -> void:
	if orders_panel == null or order_resource_selector == null or order_quantity_spinbox == null:
		return

	order_resource_selector.clear()
	_orderable_resources.clear()
	if _delivery_manager and _delivery_manager.has_method("get_orderable_resources"):
		_orderable_resources = _delivery_manager.get_orderable_resources()
	for index in _orderable_resources.size():
		var resource_entry: Dictionary = _orderable_resources[index]
		order_resource_selector.add_item(String(resource_entry.get("label", "Ressource")), index)
		order_resource_selector.set_item_metadata(index, String(resource_entry.get("id", "")))
	if order_resource_selector.item_count > 0:
		order_resource_selector.select(0)

	order_resource_selector.item_selected.connect(_on_order_resource_selected)
	order_quantity_spinbox.value_changed.connect(_on_order_quantity_changed)
	btn_choose_default_delivery_point.pressed.connect(_on_choose_default_delivery_point_pressed)
	btn_choose_order_delivery_point.pressed.connect(_on_choose_order_delivery_point_pressed)
	btn_clear_order_delivery_point.pressed.connect(_on_clear_order_delivery_point_pressed)
	btn_submit_order.pressed.connect(_on_submit_order_pressed)
	_update_order_panel()

func _update_order_panel() -> void:
	if orders_panel == null:
		return

	var resource_id: String = _get_selected_resource_id()
	var quantity: int = maxi(1, int(order_quantity_spinbox.value)) if order_quantity_spinbox else 1
	var unit_cost: float = 0.0
	if _delivery_manager and _delivery_manager.has_method("get_unit_cost"):
		unit_cost = _delivery_manager.get_unit_cost(resource_id)
	order_unit_cost_value.text = _format_money_value(unit_cost)
	order_total_cost_value.text = _format_money_value(unit_cost * float(quantity))
	order_stock_value.text = str(GameManager.get_resource_stock(resource_id)) if GameManager else "0"
	default_delivery_point_value.text = _format_delivery_point_label(GameManager.get_default_delivery_point_state() if GameManager else {})
	order_delivery_point_value.text = _format_effective_delivery_choice()
	inventory_summary_label.text = _build_inventory_summary()
	btn_submit_order.disabled = _is_delivery_point_selection_active
	btn_choose_default_delivery_point.disabled = _is_delivery_point_selection_active and _delivery_selection_context != "default"
	btn_choose_order_delivery_point.disabled = _is_delivery_point_selection_active and _delivery_selection_context != "order"
	btn_clear_order_delivery_point.disabled = _is_delivery_point_selection_active
	if _is_delivery_point_selection_active:
		orders_status_label.text = "Selection active: clique sur la carte, ou ESC / clic droit pour annuler."
	elif orders_status_label.text.is_empty():
		orders_status_label.text = "Aucune commande en cours."

func _build_inventory_summary() -> String:
	if not GameManager:
		return "Stock indisponible"
	var parts: PackedStringArray = []
	for resource_entry in _orderable_resources:
		var resource_id: String = String(resource_entry.get("id", ""))
		if resource_id.is_empty():
			continue
		parts.append("%s: %d" % [resource_entry.get("label", resource_id), GameManager.get_resource_stock(resource_id)])
	if parts.is_empty():
		return "Stock vide"
	return " | ".join(parts)

func _get_selected_resource_id() -> String:
	if order_resource_selector == null or order_resource_selector.item_count == 0:
		return ""
	var selected_index: int = order_resource_selector.selected
	if selected_index < 0:
		selected_index = 0
	return String(order_resource_selector.get_item_metadata(selected_index))

func _format_delivery_point_label(point_state: Dictionary) -> String:
	if not bool(point_state.get("has_point", false)):
		return "Aucun"
	return "Case (%d, %d)" % [int(point_state.get("cell_x", 0)), int(point_state.get("cell_y", 0))]

func _format_effective_delivery_choice() -> String:
	if _is_delivery_point_selection_active and _delivery_selection_context == "order":
		return "Choix specifique en cours..."
	if bool(_pending_order_delivery_point.get("has_point", false)):
		return "Specifique: %s" % _format_delivery_point_label(_pending_order_delivery_point)
	var default_point: Dictionary = GameManager.get_default_delivery_point_state() if GameManager else {}
	if bool(default_point.get("has_point", false)):
		return "Par defaut: %s" % _format_delivery_point_label(default_point)
	if _is_delivery_point_selection_active and _delivery_selection_context == "default":
		return "Choix du point par defaut en cours..."
	return "Aucun point disponible"

func _make_delivery_point_state(cell_pos: Vector2i, world_pos: Vector2) -> Dictionary:
	return {
		"has_point": true,
		"cell_x": cell_pos.x,
		"cell_y": cell_pos.y,
		"world_x": world_pos.x,
		"world_y": world_pos.y,
	}

func _on_order_resource_selected(_index: int) -> void:
	_update_order_panel()

func _on_order_quantity_changed(_value: float) -> void:
	_update_order_panel()

func _on_choose_default_delivery_point_pressed() -> void:
	if _building_manager == null or not _building_manager.has_method("start_delivery_point_selection"):
		orders_status_label.text = "Selection de point indisponible."
		return
	_delivery_selection_context = "default"
	orders_status_label.text = "Clique sur la carte pour definir le point de livraison par defaut."
	_building_manager.start_delivery_point_selection()

func _on_choose_order_delivery_point_pressed() -> void:
	if _building_manager == null or not _building_manager.has_method("start_delivery_point_selection"):
		orders_status_label.text = "Selection de point indisponible."
		return
	_delivery_selection_context = "order"
	orders_status_label.text = "Clique sur la carte pour definir la destination de cette commande."
	_building_manager.start_delivery_point_selection()

func _on_clear_order_delivery_point_pressed() -> void:
	_pending_order_delivery_point.clear()
	order_delivery_preview_changed.emit({})
	orders_status_label.text = "La commande utilisera le point par defaut."
	_update_order_panel()

func _on_submit_order_pressed() -> void:
	if _delivery_manager == null or not _delivery_manager.has_method("submit_order"):
		orders_status_label.text = "DeliveryManager introuvable."
		return
	var resource_id: String = _get_selected_resource_id()
	if resource_id.is_empty():
		orders_status_label.text = "Choisis une ressource a commander."
		return
	var quantity: int = maxi(1, int(order_quantity_spinbox.value))
	var custom_point: Dictionary = _pending_order_delivery_point if bool(_pending_order_delivery_point.get("has_point", false)) else {}
	if _delivery_manager.submit_order(resource_id, quantity, custom_point):
		_pending_order_delivery_point.clear()
		order_delivery_preview_changed.emit({})
		orders_status_label.text = "Commande envoyee. Le camion arrive des que possible."
		_update_order_panel()

func _on_delivery_point_selected(cell_pos: Vector2i, world_pos: Vector2) -> void:
	var point_state: Dictionary = _make_delivery_point_state(cell_pos, world_pos)
	match _delivery_selection_context:
		"default":
			if GameManager:
				GameManager.set_default_delivery_point(cell_pos, world_pos)
			orders_status_label.text = "Point de livraison par defaut mis a jour."
		"order":
			_pending_order_delivery_point = point_state
			order_delivery_preview_changed.emit(_pending_order_delivery_point.duplicate(true))
			orders_status_label.text = "Destination de commande prete."
		_:
			orders_status_label.text = "Point de livraison selectionne."
	_delivery_selection_context = ""
	_update_order_panel()

func _on_delivery_point_selection_changed(enabled: bool) -> void:
	_is_delivery_point_selection_active = enabled
	if not enabled and not _delivery_selection_context.is_empty():
		_delivery_selection_context = ""
		orders_status_label.text = "Selection annulee."
	_update_order_panel()

func _on_default_delivery_point_changed(_has_point: bool, _cell_pos: Vector2i, _world_pos: Vector2) -> void:
	_update_order_panel()

func _on_order_submitted(order: Dictionary) -> void:
	orders_status_label.text = "Commande en file: %s x%d" % [order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _on_delivery_started(order: Dictionary) -> void:
	orders_status_label.text = "Livraison en cours: %s x%d" % [order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _on_delivery_completed(order: Dictionary) -> void:
	orders_status_label.text = "Livraison terminee: %s x%d" % [order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _on_delivery_failed(message: String) -> void:
	orders_status_label.text = message
	_update_order_panel()

func _on_delivery_queue_changed(queue_size: int) -> void:
	if queue_size > 0:
		btn_toggle_orders.text = "Commandes [%d]" % queue_size
	else:
		btn_toggle_orders.text = "Commandes"

func _format_money_value(amount: float) -> String:
	var formatted_money: String = String.num(amount, 2)
	if formatted_money.ends_with(".00"):
		formatted_money = formatted_money.trim_suffix(".00")

	var parts: PackedStringArray = formatted_money.split(".")
	var int_part: String = parts[0]
	var result: String = ""
	var count: int = 0
	for i in range(int_part.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = int_part[i] + result
		count += 1

	if parts.size() > 1:
		result += "." + parts[1]

	return result + " €"

func _format_rate_value(value: float, unit: String) -> String:
	return "%s %s" % [String.num(value, 1), unit]

func _format_energy_value(value: float) -> String:
	if is_zero_approx(value):
		return "0.0 kW"
	if value < 0.0:
		return "%s kW production" % String.num(absf(value), 1)
	return "%s kW consommation" % String.num(value, 1)

func _ensure_input_actions() -> void:
	_ensure_action_with_keys(ACTION_TOGGLE_ORDER_PANEL, [KEY_TAB])
	_ensure_action_with_keys(ACTION_TOGGLE_SESSION_OVERVIEW, [KEY_I])
	_ensure_action_with_keys(ACTION_TOGGLE_BUILD_MENU, [KEY_Q])

func _ensure_action_with_keys(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for keycode in keycodes:
		if _has_physical_key(existing_events, keycode):
			continue
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, input_event)

func _has_physical_key(events: Array[InputEvent], keycode: int) -> bool:
	for input_event in events:
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event
			if key_event.physical_keycode == keycode:
				return true
	return false

# --- NOUVELLE FONCTION POUR LE SOUS-MENU DES TAPIS ---
func _on_menu_belt_pressed() -> void:
	# Si le menu des tapis est visible, on le cache. Sinon, on l'affiche.
	if menu_belt.visible:
		menu_belt.hide()
	else:
		menu_belt.show()


func _on_undo_build_pressed() -> void:
	var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if building_manager and building_manager.has_method("undo_last_build"):
		building_manager.undo_last_build()
	else:
		print("Annulation impossible : BuildingManager introuvable ou méthode manquante")

func _style_button(button: Button, base_color: Color, text_color: Color = Color.WHITE) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(base_color))
	button.add_theme_stylebox_override("hover", _make_button_style(base_color.lightened(0.15)))
	button.add_theme_stylebox_override("pressed", _make_button_style(base_color.darkened(0.15)))

	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
