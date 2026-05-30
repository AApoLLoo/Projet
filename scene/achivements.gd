extends Control

const MAIN_MENU_SCENE: String = "res://scene/main_menu.tscn"

@onready var _root_panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _production_card: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/ProductionCard
@onready var _energy_card: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/EnergyCard
@onready var _logistics_card: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/LogisticsCard
@onready var _eyebrow_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Eyebrow
@onready var _title_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Title
@onready var _subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Subtitle
@onready var _production_status: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/ProductionCard/MarginContainer/Content/Status
@onready var _energy_status: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/EnergyCard/MarginContainer/Content/Status
@onready var _logistics_status: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Cards/LogisticsCard/MarginContainer/Content/Status
@onready var _summary_label: Label = %SummaryLabel
@onready var _back_button: Button = %BackButton

func _ready() -> void:
	_style_screen()
	_refresh_summary()
	_back_button.pressed.connect(_return_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()

func _style_screen() -> void:
	UITheme.style_screen(self)
	UITheme.style_card(_root_panel, false, true)
	UITheme.style_card(_production_card, false, false)
	UITheme.style_card(_energy_card, false, false)
	UITheme.style_card(_logistics_card, false, false)
	UITheme.style_button(_back_button, UITheme.ACCENT_TEAL, UITheme.TEXT_LIGHT)
	UITheme.style_label(_eyebrow_label, "caption")
	UITheme.style_label(_title_label, "title")
	UITheme.style_label(_subtitle_label, "body")
	UITheme.style_label(_summary_label, "caption")
	for label in [
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/ProductionCard/MarginContainer/Content/Title,
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/EnergyCard/MarginContainer/Content/Title,
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/LogisticsCard/MarginContainer/Content/Title
	]:
		UITheme.style_label(label, "section")
	for label in [
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/ProductionCard/MarginContainer/Content/Description,
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/EnergyCard/MarginContainer/Content/Description,
		$CenterContainer/PanelContainer/MarginContainer/Content/Cards/LogisticsCard/MarginContainer/Content/Description
	]:
		UITheme.style_label(label, "body")
	for label in [_production_status, _energy_status, _logistics_status]:
		UITheme.style_label(label, "caption")

func _refresh_summary() -> void:
	var save_slots: Array[Dictionary] = SaveSystem.get_save_slots(true)
	var saves_with_data: int = 0
	for slot_variant in save_slots:
		var slot: Dictionary = slot_variant
		if bool(slot.get("has_data", false)):
			saves_with_data += 1

	if saves_with_data > 0:
		_production_status.text = "Progression detectee sur %d sauvegarde(s)" % saves_with_data
		_logistics_status.text = "Import/export disponible pour tes prochaines lignes"
		_summary_label.text = "Le prototype detecte deja de la progression. Les succes complets pourront s'accrocher a ces saves existantes."
	else:
		_production_status.text = "En attente d'une premiere session"
		_logistics_status.text = "Commence une partie pour ouvrir la progression logistique"
		_summary_label.text = "Les achievements detailles arriveront avec la boucle de progression complete. Pour l'instant, cet ecran sert de hub de progression lisible."

func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)