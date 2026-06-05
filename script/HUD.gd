extends CanvasLayer

signal order_delivery_preview_changed(point_state)

const ACTION_TOGGLE_ORDER_PANEL: StringName = &"hud_toggle_order_panel"
const ACTION_TOGGLE_SESSION_OVERVIEW: StringName = &"hud_toggle_session_overview"
const ACTION_TOGGLE_BUILD_MENU: StringName = &"hud_toggle_build_menu"
const ORDER_MODE_IMPORT: String = "import"
const ORDER_MODE_EXPORT: String = "export"

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var co2_label: Label = %CO2Label
@onready var top_hud_background: ColorRect = $MarginContainer/ColorRect
@onready var minimap_background: ColorRect = $MinimapContainer/ColorRect
@onready var minimap_surface: Control = %MinimapSurface
@onready var minimap_viewport: SubViewport = %SubViewport
@onready var resources_background: ColorRect = $ResourcesContainer/ColorRect
@onready var co2_background: ColorRect = $CO2Container/ColorRect
@onready var resources_caption: Label = $ResourcesContainer/MarginContainer/VBoxContainer/Caption
@onready var co2_caption: Label = $CO2Container/MarginContainer/VBoxContainer/Caption

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
@onready var contracts_label: Label = %ContractsLabel

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
@onready var btn_build_entrepot: Button = %BtnEntrepot 
@onready var btn_build_miner: Button = %BtnBuildMiner
###BELT###
@onready var menu_belt: HBoxContainer = $Menu_Belt
@onready var curve_top: Button = $Menu_Belt/Curve_Top
@onready var curve_down: Button = $Menu_Belt/Curve_Down
@onready var curve_right: Button = $Menu_Belt/Curve_Right
@onready var curve_left: Button = $Menu_Belt/Curve_left
@onready var belt_droit: Button = $Menu_Belt/Belt_droit
@onready var belt_left: Button = $Menu_Belt/Belt_left
@onready var belt_east: Button = $Menu_Belt/Belt_East
@onready var belt_south: Button = $Menu_Belt/Belt_South
@onready var belt_merger: Button = $Menu_Belt/Belt_Merger
@onready var belt_splitter: Button = $Menu_Belt/Belt_Splitter

@onready var orders_panel: PanelContainer = %OrdersPanel
@onready var orders_title_label: Label = $OrdersPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var btn_order_mode_import: Button = %BtnOrderModeImport
@onready var btn_order_mode_export: Button = %BtnOrderModeExport
@onready var order_resource_selector: OptionButton = %OrderResourceSelector
@onready var order_quantity_spinbox: SpinBox = %OrderQuantitySpinBox
@onready var order_unit_cost_label: Label = $OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/UnitCostLabel
@onready var order_unit_cost_value: Label = %OrderUnitCostValue
@onready var order_total_cost_label: Label = $OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/TotalCostLabel
@onready var order_total_cost_value: Label = %OrderTotalCostValue
@onready var estimated_cost_label: Label = %EstimatedCostLabel
@onready var estimated_cost_value: Label = %EstimatedCostValue
@onready var order_margin_label: Label = %MarginLabel
@onready var order_margin_value: Label = %OrderMarginValue
@onready var order_stock_value: Label = %OrderStockValue
@onready var default_delivery_point_value: Label = %DefaultDeliveryPointValue
@onready var order_delivery_point_value: Label = %OrderDeliveryPointValue
@onready var inventory_summary_label: Label = %InventorySummaryLabel
@onready var orders_status_label: Label = %OrdersStatusLabel
@onready var export_history_title: Label = %ExportHistoryTitle
@onready var export_history_label: Label = %ExportHistoryLabel
@onready var btn_choose_default_delivery_point: Button = %BtnChooseDefaultDeliveryPoint
@onready var btn_choose_order_delivery_point: Button = %BtnChooseOrderDeliveryPoint
@onready var btn_clear_order_delivery_point: Button = %BtnClearOrderDeliveryPoint
@onready var btn_submit_order: Button = %BtnSubmitOrder
var _warehouse_panel: PanelContainer = null
var _contract_just_failed: bool = false

# --- DICTIONNAIRE MIS À JOUR ---
# --- DICTIONNAIRE MIS À JOUR AVEC DIRECTIONS ET VIRAGES ---
var buildings_data = {
	"factory": {
	"scene": preload("res://scene/factory.tscn"),
	"texture": preload("res://asset/usine.png"),
	"cost": 200.0,
	"frames": 1,
	"preview_scale": Vector2(0.4, 0.4),
	"footprint_offsets": [Vector2i.ZERO]
},
	"turbine": {
		"scene": preload("res://scene/turbine_2d.tscn"),
		"texture": preload("res://asset/Turbine Animation base.png"),
		"cost": 500.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO, Vector2i(1, 0)]
	},
	
	# --- TAPIS DROITS ---
	"belt_right": {
		"scene": preload("res://scene/ASSET/belt/beltmid.tscn"),
		"texture": preload("res://asset/convoyer/conveyer belt all-0001.png"),
		"texture_region": Rect2(0, 0, 32, 32),
		"cost": 50.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"belt_left": {
		"scene": preload("res://scene/ASSET/belt/beltleft.tscn"),
		"texture": preload("res://asset/convoyer/conveyer belt all-0001.png"),
		"texture_region": Rect2(0, 128, 32, 32),
		"cost": 50.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	
	# --- TAPIS CARDINAUX SUPPLEMENTAIRES ---
	"belt_east": {
		"scene": preload("res://scene/ASSET/belt/belteast.tscn"),
		"texture": preload("res://asset/convoyer/conveyer belt all-0001.png"),
		"texture_region": Rect2(0, 32, 32, 32),
		"cost": 50.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"belt_south": {
		"scene": preload("res://scene/ASSET/belt/beltsouth.tscn"),
		"texture": preload("res://asset/convoyer/conveyer belt all-0001.png"),
		"texture_region": Rect2(0, 64, 32, 32),
		"cost": 50.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	# --- MERGEUR / SPLITTER ---
	"merger": {
		"scene": preload("res://scene/ASSET/belt/merger.tscn"),
		"texture": preload("res://asset/convoyer/combiner.png"),
		"texture_region": Rect2(0, 64, 64, 64),
		"cost": 80.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"splitter": {
		"scene": preload("res://scene/ASSET/belt/splitter.tscn"),
		"texture": preload("res://asset/convoyer/combiner.png"),
		"texture_region": Rect2(0, 0, 64, 64),
		"cost": 80.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	# --- VIRAGES / COURBES ---
	# curves.png : 64x128, 2 frames x 4 lignes (row0=top, row1=right, row2=down, row3=left)
	"curve_top": {
		"scene": preload("res://scene/ASSET/beltcurvetop.tscn"),
		"texture": preload("res://asset/convoyer/curves.png"),
		"texture_region": Rect2(0, 0, 32, 32),
		"cost": 60.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"curve_down": {
		"scene": preload("res://scene/ASSET/belt/curvedown.tscn"),
		"texture": preload("res://asset/convoyer/curves.png"),
		"texture_region": Rect2(0, 64, 32, 32),
		"cost": 60.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"curve_left": {
		"scene": preload("res://scene/ASSET/belt/curveleft.tscn"),
		"texture": preload("res://asset/convoyer/curves.png"),
		"texture_region": Rect2(0, 96, 32, 32),
		"cost": 60.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"curve_right": {
		"scene": preload("res://scene/ASSET/belt/curveright.tscn"),
		"texture": preload("res://asset/convoyer/curves.png"),
		"texture_region": Rect2(0, 32, 32, 32),
		"cost": 60.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"entrepot":{
		"scene": preload("res://scene/entrepot.tscn"),
		"texture": preload("res://asset/image-removebg-preview.png"),
		"cost": 1000.0,
		"frames": 1,
		"footprint_offsets": [Vector2i.ZERO]
	},
	"miner": {
		"scene": preload("res://scene/miner.tscn"),
		"texture": preload("res://asset/Miner/miner-one/north-east/mining-animation.png"),
		"cost": 300.0,
		"frames": 8,
		"footprint_offsets": [Vector2i.ZERO]
	}
}
@onready var minimap_camera: Camera2D = %MinimapCamera
@onready var minimap_overlay: Control = %MinimapOverlay

const ENTITY_PANEL_SCENE := preload("res://scene/entity_panel.tscn")
const MINIMAP_FACTORY_COLOR: Color = Color(0.95, 0.71, 0.28, 0.96)
const MINIMAP_TURBINE_COLOR: Color = Color(0.4, 0.88, 0.52, 0.96)
const MINIMAP_CONVEYOR_COLOR: Color = Color(0.88, 0.9, 0.93, 0.82)
const MINIMAP_DELIVERY_COLOR: Color = Color(1.0, 0.82, 0.24, 1.0)
const MINIMAP_ORDER_TARGET_COLOR: Color = Color(0.35, 0.9, 1.0, 1.0)
var _entity_panel: PanelContainer = null
var _building_manager: Node = null
var _delivery_manager: Node = null
var _pending_order_delivery_point: Dictionary = {}
var _delivery_selection_context: String = ""
var _orderable_resources: Array[Dictionary] = []
var _is_delivery_point_selection_active: bool = false
var _order_mode: String = ORDER_MODE_IMPORT
var _minimap_world_rect: Rect2 = Rect2()
var _minimap_viewport_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	btn_build_entrepot.pressed.connect(func():
		_start_building_process("entrepot")
	)
	_ensure_input_actions()
	_style_hud()
	build_menu_container.offset_top = -350.0
	build_menu_container.offset_bottom = -40.0
	if session_overview_panel:
		session_overview_panel.hide()
	if ContractManager:
		if ContractManager.contract_arrived.is_connected(_on_contract_arrived):
			ContractManager.contract_arrived.disconnect(_on_contract_arrived)
		if ContractManager.contract_completed.is_connected(_on_contract_completed):
			ContractManager.contract_completed.disconnect(_on_contract_completed)
		if ContractManager.contract_failed.is_connected(_on_contract_failed):
			ContractManager.contract_failed.disconnect(_on_contract_failed)
		ContractManager.contract_arrived.connect(_on_contract_arrived)
		ContractManager.contract_completed.connect(_on_contract_completed)
		ContractManager.contract_failed.connect(_on_contract_failed)
	if orders_panel:
		orders_panel.hide()

	# On s'assure que le menu est caché au démarrage
	if menu_belt:
		menu_belt.hide()
	
	# Connexion aux signaux du TimeManager
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	
	# Exemple pour les tapis droits
	if belt_droit:
		belt_droit.pressed.connect(func():
			_start_building_process("belt_right")
			menu_belt.hide()
		)
	if belt_left:
		belt_left.pressed.connect(func():
			_start_building_process("belt_left")
			menu_belt.hide()
		)
	# Exemple pour vos courbes (Curves)
	if curve_top:
		curve_top.pressed.connect(func():
			_start_building_process("curve_top")
			menu_belt.hide()
		)
	if curve_down:
		curve_down.pressed.connect(func():
			_start_building_process("curve_down")
			menu_belt.hide()
		)
	if curve_right:
		curve_right.pressed.connect(func():
			_start_building_process("curve_right")
			menu_belt.hide()
		)
	if curve_left:
		curve_left.pressed.connect(func():
			_start_building_process("curve_left")
			menu_belt.hide()
		)
	if belt_east:
		belt_east.pressed.connect(func():
			_start_building_process("belt_east")
			menu_belt.hide()
		)
	if belt_south:
		belt_south.pressed.connect(func():
			_start_building_process("belt_south")
			menu_belt.hide()
		)
	if belt_merger:
		belt_merger.pressed.connect(func():
			_start_building_process("merger")
			menu_belt.hide()
		)
	if belt_splitter:
		belt_splitter.pressed.connect(func():
			_start_building_process("splitter")
			menu_belt.hide()
		)

	if GameManager:
		GameManager.resources_updated.connect(_on_resources_updated)
		if GameManager.has_signal("default_delivery_point_changed"):
			GameManager.default_delivery_point_changed.connect(_on_default_delivery_point_changed)
		if GameManager.has_signal("export_history_changed"):
			GameManager.export_history_changed.connect(_on_export_history_changed)
		_update_money_display()
		_update_co2_display()

	# --- PANNEAU ENTITÉ ---
	_entity_panel = ENTITY_PANEL_SCENE.instantiate()
	add_child(_entity_panel)
	_warehouse_panel = preload("res://scene/entrepot_panel.tscn").instantiate()
	add_child(_warehouse_panel)
	
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

	# --- CORRECTION CRITIQUE : _bind_runtime_managers() AVANT les connexions qui en dépendent ---
	_bind_runtime_managers()
	_setup_minimap()
	_setup_order_panel()

	# --- GESTION DU MENU DE CONSTRUCTION ---
	# 1. Cliquer sur "Construction" affiche ou masque le conteneur
	btn_toggle_orders.pressed.connect(_toggle_orders_panel)
	btn_toggle_session_overview.pressed.connect(_toggle_session_overview)
	btn_toggle_build_menu.pressed.connect(_toggle_build_menu)

	# 2. Les sous-boutons lancent la construction
	btn_build_factory.pressed.connect(func():
		_start_building_process("factory")
	)
	
	btn_build_belt.pressed.connect(_on_menu_belt_pressed)
	
	btn_build_turbine.pressed.connect(func():
		_start_building_process("turbine")
	)

	btn_build_miner.pressed.connect(func():
		_start_building_process("miner")
	)

	_style_button(btn_build_belt, Color.html("#3D6F8E"))
	_style_button(btn_build_turbine, Color.html("#4F8F5B"))
	_style_button(btn_build_factory, Color.html("#A66A3F"))
	_style_button(btn_build_miner, Color.html("#D4A017"))
	
	btn_build_belt.custom_minimum_size = Vector2(200.0, 32.0)
	btn_build_turbine.custom_minimum_size = Vector2(200.0, 32.0)
	btn_build_factory.custom_minimum_size = Vector2(200.0, 32.0)
	btn_build_miner.custom_minimum_size = Vector2(200.0, 32.0)
	_update_build_button_prices()
	btn_build_entrepot.custom_minimum_size = Vector2(200.0, 32.0)
	_style_button(btn_build_entrepot, Color.html("#69558C"))

	# --- BOUTON D'ANNULATION DU DERNIER BATIMENT (créé dynamiquement) ---
	var undo_button: Button = Button.new()
	undo_button.name = "BtnUndoBuild"
	undo_button.text = "Annuler (50%)"
	undo_button.custom_minimum_size = Vector2(200.0, 32.0)
	_style_button(undo_button, Color.html("#8A6D2E"))
	undo_button.visible = false
	if build_menu_container:
		build_menu_container.add_child(undo_button)
	else:
		add_child(undo_button)

	# Connexion du clic
	undo_button.pressed.connect(_on_undo_build_pressed)

	# Connexion au BuildingManager pour synchroniser la visibilité
	# NOTE : _building_manager est maintenant disponible car _bind_runtime_managers() a été appelé plus haut
	if _building_manager:
		if _building_manager.has_signal("last_build_state_changed"):
			_building_manager.last_build_state_changed.connect(func(available):
				undo_button.visible = available
			)
		undo_button.visible = _building_manager.has_method("has_last_build") and _building_manager.has_last_build()

		# --- BOUTON MODE DESTRUCTION (toggle) ---
		var destroy_button: Button = Button.new()
		destroy_button.name = "BtnDestroyMode"
		destroy_button.text = "Mode destruction"
		destroy_button.custom_minimum_size = Vector2(200.0, 32.0)
		_style_button(destroy_button, Color.html("#8A3A3A"))
		destroy_button.toggle_mode = true
		destroy_button.set_pressed(false)
		if build_menu_container:
			build_menu_container.add_child(destroy_button)
		else:
			add_child(destroy_button)

		destroy_button.toggled.connect(func(pressed):
			var bm = get_tree().current_scene.find_child("BuildingManager", true, false)
			if bm:
				if pressed and bm.has_method("start_destroying"):
					bm.start_destroying()
				elif not pressed and bm.has_method("stop_destroying"):
					bm.stop_destroying()
		)

		if _building_manager.has_signal("destroy_mode_changed"):
			_building_manager.destroy_mode_changed.connect(func(enabled):
				destroy_button.set_pressed(enabled)
			)
		destroy_button.set_pressed(_building_manager.is_destroying)

	# --- BOUTON AFFICHAGE ZONE ÉLECTRIQUE ---
	var elec_overlay_button: Button = Button.new()
	elec_overlay_button.name = "BtnElectricityOverlay"
	elec_overlay_button.text = "Zone électricité"
	elec_overlay_button.custom_minimum_size = Vector2(200.0, 32.0)
	elec_overlay_button.toggle_mode = true
	elec_overlay_button.set_pressed(false)
	_style_button(elec_overlay_button, Color.html("#2A6B4A"))
	if build_menu_container:
		build_menu_container.add_child(elec_overlay_button)
	else:
		add_child(elec_overlay_button)
	elec_overlay_button.toggled.connect(func(_pressed: bool):
		var level: Node = get_tree().current_scene
		if level and level.has_method("toggle_electricity_overlay"):
			level.toggle_electricity_overlay()
	)

	_update_contracts_display()

	
func _on_contract_arrived(contract: Dictionary) -> void:
	_update_contracts_display()
	var msg := "📦 Nouveau contrat : %s x%d\n+%.0f€ si livré avant J-%d" % [
	String(contract.get("resource_label", "?")),
	int(contract.get("quantity", 0)),
	float(contract.get("reward", 0.0)),
	int(contract.get("day_deadline", 0)) - int(contract.get("day_issued", 0))
]
	if _contract_just_failed:
		await get_tree().create_timer(4.8).timeout
		_contract_just_failed = false
	_show_hint_toast(msg)

func _on_contract_completed(contract: Dictionary) -> void:
	_update_contracts_display()
	var streak: int = ContractManager.completed_streak if ContractManager else 0
	var streak_bonus_pct: int = int(minf(float(streak - 1) * 5.0, 50.0))
	var msg: String = "✓ Contrat rempli ! +%.0f €" % float(contract["reward"])
	if streak_bonus_pct > 0:
		msg += " (🔥 Streak +%d%%)" % streak_bonus_pct
	_show_hint_toast(msg)

func _on_contract_failed(contract: Dictionary) -> void:
	_update_contracts_display()
	_contract_just_failed = true
	_show_hint_toast("✗ Contrat échoué : vous perdez %.0f €" % float(contract["penalty"]))
	
func _show_hint_toast(message: String) -> void:
	var toast := PanelContainer.new()
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.offset_left = -280.0
	toast.offset_right = 280.0
	toast.offset_top = 40.0
	toast.offset_bottom = 80.0
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.ACCENT_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	toast.add_theme_stylebox_override("panel", style)
	add_child(toast)
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UITheme.INK_DARK)
	toast.add_child(label)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.8)
	tween.tween_callback(toast.queue_free)
	
func _style_hud() -> void:
	UITheme.style_label(day_label, "caption")
	UITheme.style_label(time_label, "metric")
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.style_label(resources_caption, "caption")
	UITheme.style_label(co2_caption, "caption")
	UITheme.style_label(money_label, "metric")
	UITheme.style_label(co2_label, "body")
	UITheme.style_label(contracts_label, "caption")
	UITheme.style_label(contracts_label, "caption")
	contracts_label.add_theme_color_override("font_color", UITheme.INK_DARK)
	contracts_label.add_theme_font_size_override("font_size", 16)
	resources_background.color = UITheme.SURFACE_GLASS
	co2_background.color = UITheme.SURFACE_GLASS
	top_hud_background.color = UITheme.SURFACE_GLASS
	minimap_background.color = UITheme.SURFACE_GLASS
	for button in [btn_pause, btn_x1, btn_x2, btn_x4]:
		UITheme.style_button(button, Color("#E9EEF1"), UITheme.INK_DARK, false, true)
	for button in [btn_toggle_build_menu, btn_toggle_orders, btn_toggle_session_overview]:
		UITheme.style_button(button, UITheme.ACCENT_GOLD, UITheme.INK_DARK, true, true)
	for button in [btn_build_belt, btn_build_turbine, btn_build_factory]:
		button.custom_minimum_size = Vector2(200.0, 32.0)
	for button in [curve_top, curve_down, curve_right, curve_left, belt_droit, belt_left, belt_east, belt_south]:
		UITheme.style_button(button, Color("#E9EEF1"), UITheme.INK_DARK, false, true)
	for button in [belt_merger, belt_splitter]:
		UITheme.style_button(button, Color("#6E8A9E"), UITheme.INK_DARK, false, true)
	UITheme.style_card(orders_panel, false, true)
	UITheme.style_card(session_overview_panel, false, true)
	_style_order_panels()
	_build_shortcut_bar()

func _build_shortcut_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "ShortcutBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -32.0
	bar.offset_bottom = -20.0
	
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UITheme.SURFACE_GLASS
	bar_style.bg_color.a = 0.82
	bar_style.content_margin_left = 0.0
	bar_style.content_margin_right = 0.0
	bar_style.content_margin_top = 2.0
	bar_style.content_margin_bottom = 2.0
	bar.add_theme_stylebox_override("panel", bar_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	bar.add_child(hbox)

	var shortcuts: Array = [
		["Échap", "Menu Pause"],
		["B", "Construction"],
		["Tab", "Logistique"],
		["I", "Vue usine"],
		["P", "Pause temps"],
		["E", "Sauvegarde rapide"],
	]

	for i in shortcuts.size():
		if i > 0:
			var sep := Label.new()
			sep.text = "·"
			sep.add_theme_font_size_override("font_size", 16)
			sep.add_theme_color_override("font_color", UITheme.BORDER_STRONG)
			hbox.add_child(sep)

		var entry: Array = shortcuts[i]

		var key_panel := PanelContainer.new()
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = UITheme.SURFACE_DARK
		key_style.border_color = UITheme.ACCENT_GOLD
		key_style.border_width_left = 1
		key_style.border_width_top = 1
		key_style.border_width_right = 1
		key_style.border_width_bottom = 2
		key_style.corner_radius_top_left = 5
		key_style.corner_radius_top_right = 5
		key_style.corner_radius_bottom_left = 5
		key_style.corner_radius_bottom_right = 5
		key_style.content_margin_left = 6.0
		key_style.content_margin_right = 6.0
		key_style.content_margin_top = 2.0
		key_style.content_margin_bottom = 2.0
		key_panel.add_theme_stylebox_override("panel", key_style)
		hbox.add_child(key_panel)

		var key_label := Label.new()
		key_label.text = entry[0]
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.add_theme_color_override("font_color", UITheme.ACCENT_GOLD)
		key_panel.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = entry[1]
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", UITheme.INK_MUTED)
		hbox.add_child(desc_label)

	add_child(bar)
	
		
func _style_order_panels() -> void:
	for button in [
		btn_order_mode_import,
		btn_order_mode_export,
		btn_choose_default_delivery_point,
		btn_choose_order_delivery_point,
		btn_clear_order_delivery_point,
		btn_submit_order
	]:
		UITheme.style_button(button, UITheme.ACCENT_TEAL if button == btn_submit_order else Color("#E9EEF1"), UITheme.TEXT_LIGHT if button == btn_submit_order else UITheme.INK_DARK, false, true)
	UITheme.style_option_button(order_resource_selector)
	UITheme.style_spin_box(order_quantity_spinbox)
	for label in [
		orders_title_label,
		$OrdersPanel/MarginContainer/VBoxContainer/TitleLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/TitleLabel
	]:
		UITheme.style_label(label, "section")
	for label in [
		order_unit_cost_label,
		order_total_cost_label,
		estimated_cost_label,
		order_margin_label,
		inventory_summary_label,
		orders_status_label,
		export_history_title,
		export_history_label,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/HintLabel
	]:
		UITheme.style_label(label, "caption")
	for label in [
		order_unit_cost_value,
		order_total_cost_value,
		estimated_cost_value,
		order_margin_value,
		order_stock_value,
		default_delivery_point_value,
		order_delivery_point_value,
		overview_day_value,
		overview_time_value,
		overview_credits_value,
		overview_machines_value,
		overview_active_machines_value,
		overview_production_rate_value,
		overview_failures_value,
		overview_co2_value,
		overview_electricity_value
	]:
		UITheme.style_label(label, "body")
	for label in [
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/DayLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/TimeLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/CreditsLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/MachinesLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/ActiveMachinesLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/ProductionRateLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/FailuresLabel,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/CO2Label,
		$SessionOverviewPanel/MarginContainer/VBoxContainer/InfoGrid/ElectricityLabel,
		$OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/ResourceLabel,
		$OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/QuantityLabel,
		$OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/StockLabel,
		$OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/DefaultDeliveryPointLabel,
		$OrdersPanel/MarginContainer/VBoxContainer/OrderGrid/OrderDeliveryPointLabel
	]:
		UITheme.style_label(label, "small")

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return
		if key_event.is_action_pressed(ACTION_TOGGLE_ORDER_PANEL):
			_toggle_orders_panel()
			get_viewport().set_input_as_handled()
		elif key_event.is_action_pressed(ACTION_TOGGLE_BUILD_MENU):
			_toggle_build_menu()
			get_viewport().set_input_as_handled()
		elif key_event.is_action_pressed(ACTION_TOGGLE_SESSION_OVERVIEW):
			_toggle_session_overview()
			get_viewport().set_input_as_handled()
		elif key_event.is_action_pressed(&"hud_toggle_pause"):
			var new_speed: float = 0.0 if TimeManager.time_speed > 0.0 else 1.0
			TimeManager.time_speed = new_speed
			get_viewport().set_input_as_handled()
		elif key_event.is_action_pressed(&"hud_quick_save"):
			var level: Node = get_tree().current_scene
			if level and level.has_method("quick_save"):
				level.quick_save()
				_show_quick_save_toast()
			get_viewport().set_input_as_handled()

func _show_quick_save_toast() -> void:
	_show_toast("✓ Partie sauvegardée")

func _show_toast(message: String, border_color: Color = UITheme.BORDER_STRONG) -> void:
	if message.is_empty():
		return
	var toast := PanelContainer.new()
	toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast.offset_left = -220.0
	toast.offset_top = -360.0
	toast.offset_right = -10.0
	toast.offset_bottom = -320.0
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.SURFACE_SOFT
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	toast.add_theme_stylebox_override("panel", style)
	add_child(toast)

	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UITheme.INK_DARK)
	toast.add_child(label)

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)

func _update_contracts_display() -> void:
	if not ContractManager or contracts_label == null:
		return
	var contracts: Array[Dictionary] = ContractManager.get_active_contracts()
	if contracts.is_empty():
		contracts_label.text = ""
		contracts_label.hide()
		return
	contracts_label.show()
	contracts_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var parts: PackedStringArray = []
	var current_day: int = TimeManager.current_day if TimeManager else 1
	for c in contracts:
		var delivered := int(c["delivered"])
		var contract_quantity := int(c["quantity"])
		var label := String(c["resource_label"])
		var days_left: int = int(c["day_deadline"]) - current_day
		var reward := int(float(c["reward"]))
		var day_str: String = "⚠ URGENT" if days_left <= 0 else ("J-%d" % days_left)
		parts.append("📦 %s : %d/%d [%s | +%d€]" % [label, delivered, contract_quantity, day_str, reward])
	var streak_text: String = ""
	if ContractManager.completed_streak > 1:
		streak_text = " 🔥x%d" % ContractManager.completed_streak
	contracts_label.text = "Contrats :  " + "   |   ".join(parts) + streak_text
	
func _start_building_process(building_type: String) -> void:
	var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if building_manager:
		var data = buildings_data[building_type]
		var preview_tex: Texture2D = data["texture"]
		if data.has("texture_region"):
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = data["texture"]
			atlas_tex.region = data["texture_region"]
			preview_tex = atlas_tex
		building_manager.start_building(
			data["scene"],
			data["cost"],
			preview_tex,
			1,
			data.get("footprint_offsets", [Vector2i.ZERO]),
			data.get("preview_scale", Vector2.ONE)
		)
		# Masquer les panneaux entité quand on entre en mode construction
		if _entity_panel:
			_entity_panel.hide()
		if _warehouse_panel:
			_warehouse_panel.hide()

# --- CORRECTION : aiguillage correct entre les deux panneaux ---
func open_entity_panel(entity: Entity) -> void:
	_on_entity_selected(entity)

func _on_entity_selected(entity) -> void:
	if entity == null:
		if _entity_panel: _entity_panel.hide()
		if _warehouse_panel: _warehouse_panel.hide()
		return

	if entity is WarehouseEntity:
		# C'est un entrepôt : on cache l'entity panel et on ouvre le warehouse panel
		if _entity_panel: _entity_panel.hide()
		if _warehouse_panel: _warehouse_panel.setup(entity)
	elif entity is Entity:
		# C'est une usine/turbine/tapis : on cache le warehouse panel et on ouvre l'entity panel
		if _warehouse_panel: _warehouse_panel.hide()
		if _entity_panel: _entity_panel.setup(entity)

func _process(_delta: float) -> void:
	_update_minimap()

func _setup_minimap() -> void:
	if minimap_viewport:
		minimap_viewport.world_2d = get_viewport().world_2d
		minimap_viewport.transparent_bg = true
		minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera:
		minimap_camera.enabled = true
	if minimap_overlay and minimap_overlay.has_signal("navigate_requested") and not minimap_overlay.navigate_requested.is_connected(_on_minimap_navigate_requested):
		minimap_overlay.navigate_requested.connect(_on_minimap_navigate_requested)
	_sync_minimap_viewport_size()

func _update_minimap() -> void:
	if minimap_overlay == null:
		return

	var main_camera: Camera2D = _get_main_camera()
	var world_rect: Rect2 = _get_minimap_world_rect()
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0 or main_camera == null:
		if minimap_overlay.has_method("clear_state"):
			minimap_overlay.call("clear_state")
		return

	_sync_minimap_viewport_size()
	_sync_minimap_camera(world_rect)
	var camera_rect: Rect2 = _get_camera_visible_rect(main_camera)
	var markers: Array[Dictionary] = _build_minimap_markers()
	if minimap_overlay.has_method("update_state"):
		minimap_overlay.call("update_state", world_rect, camera_rect, markers)

func _get_main_camera() -> Camera2D:
	var current_camera: Camera2D = get_viewport().get_camera_2d()
	if current_camera == minimap_camera:
		return null
	return current_camera

func _get_minimap_world_rect() -> Rect2:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return _minimap_world_rect

	var floor_node: Node = current_scene.find_child("Floor", true, false)
	if floor_node and floor_node.has_method("get_loaded_chunk_world_bounds"):
		var chunk_world_rect_variant: Variant = floor_node.call("get_loaded_chunk_world_bounds")
		if chunk_world_rect_variant is Rect2:
			var chunk_world_rect: Rect2 = chunk_world_rect_variant
			if chunk_world_rect.size.x > 0.0 and chunk_world_rect.size.y > 0.0:
				_minimap_world_rect = chunk_world_rect
				return _minimap_world_rect
	if _minimap_world_rect.size.x > 0.0 and _minimap_world_rect.size.y > 0.0:
		return _minimap_world_rect
	if floor_node and floor_node.has_method("get_world_bounds"):
		_minimap_world_rect = floor_node.call("get_world_bounds")
		return _minimap_world_rect
	if floor_node and floor_node.has_method("get_generation_state"):
		var generation_state: Dictionary = floor_node.call("get_generation_state")
		var cell_size_value: float = float(generation_state.get("cell_size", 32))
		var grid_width_value: float = float(generation_state.get("grid_width", 0))
		var grid_height_value: float = float(generation_state.get("grid_height", 0))
		_minimap_world_rect = Rect2(Vector2.ZERO, Vector2(grid_width_value * cell_size_value, grid_height_value * cell_size_value))
	return _minimap_world_rect

func _sync_minimap_viewport_size() -> void:
	if minimap_viewport == null or minimap_surface == null:
		return
	var surface_size: Vector2 = minimap_surface.size
	var next_size: Vector2i = Vector2i(
		maxi(1, int(round(surface_size.x))),
		maxi(1, int(round(surface_size.y)))
	)
	if next_size == _minimap_viewport_size:
		return
	_minimap_viewport_size = next_size
	minimap_viewport.size = next_size

func _sync_minimap_camera(world_rect: Rect2) -> void:
	if minimap_camera == null or minimap_viewport == null:
		return
	minimap_camera.enabled = true
	minimap_camera.global_position = world_rect.get_center()
	var viewport_size: Vector2i = minimap_viewport.size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var zoom_x: float = float(viewport_size.x) / maxf(world_rect.size.x, 1.0)
	var zoom_y: float = float(viewport_size.y) / maxf(world_rect.size.y, 1.0)
	var target_zoom: float = maxf(minf(zoom_x, zoom_y) * 0.9, 0.0001)
	minimap_camera.zoom = Vector2(target_zoom, target_zoom)

func _get_camera_visible_rect(main_camera: Camera2D) -> Rect2:
	if main_camera.has_method("get_visible_world_rect"):
		return main_camera.call("get_visible_world_rect")
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var visible_size: Vector2 = Vector2(
		viewport_size.x / maxf(main_camera.zoom.x, 0.001),
		viewport_size.y / maxf(main_camera.zoom.y, 0.001)
	)
	return Rect2(main_camera.global_position - visible_size * 0.5, visible_size)

func _build_minimap_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if EntityManager:
		for entity_variant in EntityManager.entities.values():
			var entity: Entity = entity_variant as Entity
			if entity == null or not is_instance_valid(entity):
				continue
			markers.append({
				"position": entity.global_position,
				"color": _get_minimap_entity_color(entity.entity_type),
				"radius": _get_minimap_entity_radius(entity.entity_type)
			})
	if GameManager and GameManager.has_method("get_default_delivery_point_state"):
		var default_point: Dictionary = GameManager.get_default_delivery_point_state()
		if bool(default_point.get("has_point", false)):
			markers.append({
				"position": Vector2(float(default_point.get("world_x", 0.0)), float(default_point.get("world_y", 0.0))),
				"color": MINIMAP_DELIVERY_COLOR,
				"radius": 4.0
			})
	if bool(_pending_order_delivery_point.get("has_point", false)):
		markers.append({
			"position": Vector2(float(_pending_order_delivery_point.get("world_x", 0.0)), float(_pending_order_delivery_point.get("world_y", 0.0))),
			"color": MINIMAP_ORDER_TARGET_COLOR,
			"radius": 4.0
		})
	return markers

func _get_minimap_entity_color(entity_type: String) -> Color:
	if entity_type == "factory":
		return MINIMAP_FACTORY_COLOR
	if entity_type == "turbine":
		return MINIMAP_TURBINE_COLOR
	return MINIMAP_CONVEYOR_COLOR

func _get_minimap_entity_radius(entity_type: String) -> float:
	if entity_type == "factory":
		return 3.4
	if entity_type == "turbine":
		return 3.0
	return 2.1

func _on_minimap_navigate_requested(world_position: Vector2) -> void:
	if _is_minimap_navigation_blocked():
		return
	var main_camera: Camera2D = _get_main_camera()
	if main_camera == null:
		return
	if main_camera.has_method("set_camera_world_position"):
		main_camera.call("set_camera_world_position", world_position)
	else:
		main_camera.global_position = world_position

func _is_minimap_navigation_blocked() -> bool:
	if _building_manager == null:
		return false
	if _building_manager.has_method("is_delivery_point_selection_active") and bool(_building_manager.call("is_delivery_point_selection_active")):
		return true
	if bool(_building_manager.get("is_building")):
		return true
	if bool(_building_manager.get("is_destroying")):
		return true
	return false

func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)
	_update_session_overview()

func _on_day_changed(day: int) -> void:
	_update_day_display(day)
	_update_session_overview()
	_update_contracts_display() 

func _update_time_display(hour: int, minute: int) -> void:
	time_label.text = "%02d:%02d" % [hour, minute]

func _update_day_display(day: int) -> void:
	day_label.text = "Jour %d" % day

func _on_resources_updated() -> void:
	_update_money_display()
	_update_co2_display()
	_update_session_overview()
	_update_order_panel()
	_update_contracts_display()

func _update_money_display() -> void:
	if money_label and GameManager:
		money_label.text = _format_money_value(GameManager.credits)

func _update_co2_display() -> void:
	if co2_label and GameManager:
		co2_label.text = _format_rate_value(GameManager.co2_emissions, "g/min CO2")

func _close_all_panels() -> void:
	if session_overview_panel and session_overview_panel.visible:
		session_overview_panel.hide()
	if orders_panel and orders_panel.visible:
		orders_panel.hide()
	if build_menu_container and build_menu_container.visible:
		if _building_manager:
			_building_manager.stop_building()
		build_menu_container.hide()
		menu_belt.hide()  

func _toggle_session_overview() -> void:
	if session_overview_panel == null:
		return
	var will_open: bool = not session_overview_panel.visible
	_close_all_panels()
	if will_open:
		_update_session_overview()
		session_overview_panel.show()

func _toggle_orders_panel() -> void:
	if orders_panel == null:
		return
	var will_open: bool = not orders_panel.visible
	_close_all_panels()
	if will_open:
		_update_order_panel()
		orders_panel.show()

func _toggle_build_menu() -> void:
	if build_menu_container == null:
		return
	var will_open: bool = not build_menu_container.visible
	_close_all_panels()
	if will_open:
		build_menu_container.show()
	else:
		menu_belt.hide()  
	
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

	if _building_manager:
		if _building_manager.has_signal("delivery_point_selected") and not _building_manager.delivery_point_selected.is_connected(_on_delivery_point_selected):
			_building_manager.delivery_point_selected.connect(_on_delivery_point_selected)
		if _building_manager.has_signal("delivery_point_error") and not _building_manager.delivery_point_error.is_connected(_on_delivery_point_error):
			_building_manager.delivery_point_error.connect(_on_delivery_point_error)
		if _building_manager.has_signal("delivery_point_selection_changed") and not _building_manager.delivery_point_selection_changed.is_connected(_on_delivery_point_selection_changed):
			_building_manager.delivery_point_selection_changed.connect(_on_delivery_point_selection_changed)
		# --- CORRECTION CRITIQUE : connexion du signal entity_selected ici, après que _building_manager est défini ---
		if _building_manager.has_signal("entity_selected") and not _building_manager.entity_selected.is_connected(_on_entity_selected):
			_building_manager.entity_selected.connect(_on_entity_selected)

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

	order_resource_selector.item_selected.connect(_on_order_resource_selected)
	order_quantity_spinbox.value_changed.connect(_on_order_quantity_changed)
	btn_order_mode_import.pressed.connect(func(): _set_order_mode(ORDER_MODE_IMPORT))
	btn_order_mode_export.pressed.connect(func(): _set_order_mode(ORDER_MODE_EXPORT))
	btn_choose_default_delivery_point.pressed.connect(_on_choose_default_delivery_point_pressed)
	btn_choose_order_delivery_point.pressed.connect(_on_choose_order_delivery_point_pressed)
	btn_clear_order_delivery_point.pressed.connect(_on_clear_order_delivery_point_pressed)
	btn_submit_order.pressed.connect(_on_submit_order_pressed)
	_refresh_orderable_resources()
	_update_export_history_display()
	_update_order_panel()

func _update_order_panel() -> void:
	if orders_panel == null:
		return

	var resource_id: String = _get_selected_resource_id()
	var selected_quantity: int = maxi(1, int(order_quantity_spinbox.value)) if order_quantity_spinbox else 1
	var unit_cost: float = 0.0
	if _delivery_manager and _delivery_manager.has_method("get_unit_cost"):
		unit_cost = _delivery_manager.get_unit_cost(resource_id, _order_mode)
	orders_title_label.text = "Import de ressources" if _order_mode == ORDER_MODE_IMPORT else "Contrats d'export"
	order_unit_cost_label.text = "Prix unitaire" if _order_mode == ORDER_MODE_IMPORT else "Valeur unitaire"
	order_total_cost_label.text = "Cout total" if _order_mode == ORDER_MODE_IMPORT else "Gain total"
	estimated_cost_label.visible = _order_mode == ORDER_MODE_EXPORT
	estimated_cost_value.visible = _order_mode == ORDER_MODE_EXPORT
	order_margin_label.visible = _order_mode == ORDER_MODE_EXPORT
	order_margin_value.visible = _order_mode == ORDER_MODE_EXPORT
	export_history_title.visible = _order_mode == ORDER_MODE_EXPORT
	export_history_label.visible = _order_mode == ORDER_MODE_EXPORT
	btn_submit_order.text = "Commander" if _order_mode == ORDER_MODE_IMPORT else "Exporter"
	btn_order_mode_import.disabled = _order_mode == ORDER_MODE_IMPORT
	btn_order_mode_export.disabled = _order_mode == ORDER_MODE_EXPORT
	order_unit_cost_value.text = _format_money_value(unit_cost)
	order_total_cost_value.text = _format_money_value(unit_cost * float(selected_quantity))
	if _order_mode == ORDER_MODE_EXPORT:
		estimated_cost_value.text = _format_estimated_cost_value(resource_id)
		order_margin_value.text = _format_margin_value(resource_id)
	order_stock_value.text = str(GameManager.get_resource_stock(resource_id)) if GameManager else "0"
	default_delivery_point_value.text = _format_delivery_point_label(GameManager.get_default_delivery_point_state() if GameManager else {})
	order_delivery_point_value.text = _format_effective_delivery_choice()
	inventory_summary_label.text = _build_inventory_summary()
	btn_submit_order.disabled = _is_delivery_point_selection_active or resource_id.is_empty()
	btn_choose_default_delivery_point.disabled = _is_delivery_point_selection_active and _delivery_selection_context != "default"
	btn_choose_order_delivery_point.disabled = _is_delivery_point_selection_active and _delivery_selection_context != "order"
	btn_clear_order_delivery_point.disabled = _is_delivery_point_selection_active
	if _is_delivery_point_selection_active:
		orders_status_label.text = "Selection active: clique sur la carte, ou ESC / clic droit pour annuler."
	elif orders_status_label.text.is_empty():
		orders_status_label.text = "Aucun trajet en cours."

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
		return "Aucune ressource disponible pour l'export" if _order_mode == ORDER_MODE_EXPORT else "Aucune ressource disponible pour l'import"
	if _order_mode == ORDER_MODE_EXPORT:
		return "Produits vendables | " + " | ".join(parts)
	return " | ".join(parts)

func _format_margin_value(resource_id: String) -> String:
	if resource_id.is_empty() or _delivery_manager == null:
		return "N/A"
	if not _delivery_manager.has_method("get_margin_value") or not _delivery_manager.has_method("get_margin_percent"):
		return "N/A"
	var margin_value: float = float(_delivery_manager.get_margin_value(resource_id))
	var margin_percent: float = float(_delivery_manager.get_margin_percent(resource_id)) * 100.0
	return "%s (%s%%)" % [_format_money_value(margin_value), String.num(margin_percent, 0)]

func _format_estimated_cost_value(resource_id: String) -> String:
	if resource_id.is_empty() or _delivery_manager == null:
		return "N/A"
	if not _delivery_manager.has_method("get_estimated_production_cost"):
		return "N/A"
	return _format_money_value(float(_delivery_manager.get_estimated_production_cost(resource_id)))

func _set_order_mode(order_mode: String) -> void:
	if order_mode != ORDER_MODE_IMPORT and order_mode != ORDER_MODE_EXPORT:
		return
	if _order_mode == order_mode:
		return
	_order_mode = order_mode
	_refresh_orderable_resources()
	orders_status_label.text = "Mode import actif." if _order_mode == ORDER_MODE_IMPORT else "Mode export actif."
	_update_export_history_display()
	_update_order_panel()

func _on_delivery_point_error(message: String) -> void:
	_show_hint_toast(message)
	orders_status_label.text = message
	
func _refresh_orderable_resources() -> void:
	if order_resource_selector == null:
		return
	order_resource_selector.clear()
	_orderable_resources.clear()
	if _delivery_manager and _delivery_manager.has_method("get_orderable_resources"):
		_orderable_resources = _delivery_manager.get_orderable_resources(_order_mode)
	for index in _orderable_resources.size():
		var resource_entry: Dictionary = _orderable_resources[index]
		order_resource_selector.add_item(String(resource_entry.get("label", "Ressource")), index)
		order_resource_selector.set_item_metadata(index, String(resource_entry.get("id", "")))
	if order_resource_selector.item_count > 0:
		order_resource_selector.select(0)

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
	orders_panel.hide()

func _on_choose_order_delivery_point_pressed() -> void:
	if _building_manager == null or not _building_manager.has_method("start_delivery_point_selection"):
		orders_status_label.text = "Selection de point indisponible."
		return
	_delivery_selection_context = "order"
	orders_status_label.text = "Clique sur la carte pour definir la destination de cette commande." if _order_mode == ORDER_MODE_IMPORT else "Clique sur la carte pour definir la destination de cet export."
	_building_manager.start_delivery_point_selection()
	orders_panel.hide()

func _on_clear_order_delivery_point_pressed() -> void:
	_pending_order_delivery_point.clear()
	order_delivery_preview_changed.emit({})
	orders_status_label.text = "La commande utilisera le point par defaut."
	_update_order_panel()

func _on_submit_order_pressed() -> void:
	if _delivery_manager == null:
		orders_status_label.text = "DeliveryManager introuvable."
		return
	var resource_id: String = _get_selected_resource_id()
	if resource_id.is_empty():
		orders_status_label.text = "Choisis une ressource a traiter."
		return
	if GameManager and not GameManager.has_default_delivery_point and not bool(_pending_order_delivery_point.get("has_point", false)):
		_show_hint_toast("⚠ Définis un point de livraison avant de commander")
		return
	var requested_quantity: int = maxi(1, int(order_quantity_spinbox.value))
	var custom_point: Dictionary = _pending_order_delivery_point if bool(_pending_order_delivery_point.get("has_point", false)) else {}
	var submit_succeeded: bool = false
	if _order_mode == ORDER_MODE_EXPORT and _delivery_manager.has_method("submit_export"):
		submit_succeeded = _delivery_manager.submit_export(resource_id, requested_quantity, custom_point)
	elif _order_mode == ORDER_MODE_IMPORT and _delivery_manager.has_method("submit_order"):
		submit_succeeded = _delivery_manager.submit_order(resource_id, requested_quantity, custom_point)
	if submit_succeeded:
		_pending_order_delivery_point.clear()
		order_delivery_preview_changed.emit({})
		orders_status_label.text = "Commande envoyee. Le camion arrive des que possible." if _order_mode == ORDER_MODE_IMPORT else "Contrat d'export lance. Paiement a l'arrivee du camion."
		_update_order_panel()
		orders_panel.hide() 

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
			orders_status_label.text = "Destination de commande prete." if _order_mode == ORDER_MODE_IMPORT else "Destination d'export prete."
		_:
			orders_status_label.text = "Point de livraison selectionne."
	_delivery_selection_context = ""
	orders_panel.show()
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
	orders_status_label.text = "%s en file: %s x%d" % [order.get("job_label", "Trajet"), order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _on_delivery_started(order: Dictionary) -> void:
	orders_status_label.text = "%s en cours: %s x%d" % [order.get("job_label", "Trajet"), order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _on_delivery_completed(order: Dictionary) -> void:
	if String(order.get("job_type", ORDER_MODE_IMPORT)) == ORDER_MODE_EXPORT:
		if GameManager:
			GameManager.record_export_gain(
				String(order.get("resource_id", "")),
				String(order.get("resource_label", "Ressource")),
				int(order.get("quantity", 0)),
				float(order.get("total_cost", 0.0))
			)
		orders_status_label.text = "Export termine: %s x%d, gain %s" % [
			order.get("resource_label", "Ressource"),
			int(order.get("quantity", 0)),
			_format_money_value(float(order.get("total_cost", 0.0)))
		]
	else:
		orders_status_label.text = "Import termine: %s x%d" % [order.get("resource_label", "Ressource"), int(order.get("quantity", 0))]
	_update_order_panel()

func _update_export_history_display() -> void:
	if export_history_label == null:
		return
	if GameManager == null:
		export_history_label.text = "Historique indisponible."
		return
	var history_entries: Array[Dictionary] = GameManager.get_export_history()
	if history_entries.is_empty():
		export_history_label.text = "Aucun export termine."
		return
	var lines: PackedStringArray = []
	for history_entry in history_entries:
		lines.append(
			"J%d %02d:%02d - %s x%d -> %s" % [
				int(history_entry.get("day", 1)),
				int(history_entry.get("hour", 0)),
				int(history_entry.get("minute", 0)),
				history_entry.get("resource_label", "Ressource"),
				int(history_entry.get("quantity", 0)),
				_format_money_value(float(history_entry.get("total_value", 0.0)))
			]
		)
	export_history_label.text = "\n".join(lines)

func _on_export_history_changed(_history: Array) -> void:
	_update_export_history_display()

func _on_delivery_failed(message: String) -> void:
	orders_status_label.text = message
	_update_order_panel()

func _on_delivery_queue_changed(queue_size: int) -> void:
	if queue_size > 0:
		btn_toggle_orders.text = "Commandes [%d]" % queue_size
	else:
		btn_toggle_orders.text = "Commandes"

func _update_build_button_prices() -> void:
	_set_build_button_price(btn_build_belt, "Convoyeurs", "belt_right")
	_set_build_button_price(btn_build_turbine, "Energie", "turbine")
	_set_build_button_price(btn_build_factory, "Production", "factory")
	_set_build_button_price(btn_build_entrepot, "Entrepot", "entrepot")
	_set_build_button_price(btn_build_miner, "Extraction", "miner")

func _set_build_button_price(button: Button, label: String, building_id: String) -> void:
	if button == null:
		return
	var building_data: Dictionary = buildings_data.get(building_id, {})
	var cost: float = float(building_data.get("cost", 0.0))
	button.text = "%s - %s" % [label, _format_money_value(cost)]

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
	_ensure_action_with_keys(ACTION_TOGGLE_BUILD_MENU, [KEY_B])
	_ensure_action_with_keys(&"hud_quick_save", [KEY_E])        
	_ensure_action_with_keys(&"hud_toggle_pause", [KEY_P])

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

func _on_menu_belt_pressed() -> void:
	if menu_belt.visible:
		menu_belt.hide()
	else:
		menu_belt.show()

func _on_undo_build_pressed() -> void:
	var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if building_manager and building_manager.has_method("undo_last_build"):
		building_manager.undo_last_build()

func _style_button(button: Button, base_color: Color, text_color: Color = Color.WHITE) -> void:
	UITheme.style_button(button, base_color, text_color, false, true)
