extends PanelContainer

# ─────────────────────────────────────────────────────────────────────────────
# EntityPanel – Panneau de configuration d'une entité.
# Affiché quand l'utilisateur clique sur un bâtiment en mode sélection.
# ─────────────────────────────────────────────────────────────────────────────

@onready var entity_name_label: Label       = %EntityNameLabel
@onready var recipe_selector: OptionButton  = %RecipeSelector
@onready var input_list: ItemList           = %InputList
@onready var output_list: ItemList          = %OutputList
@onready var rate_slider: HSlider           = %RateSlider
@onready var rate_label: Label              = %RateLabel
@onready var energy_label: Label            = %EnergyLabel
@onready var co2_label: Label               = %Co2Label
@onready var active_toggle: CheckButton     = %ActiveToggle
@onready var close_btn: Button              = %CloseBtn

var current_entity: Entity = null

# Connexions temporaires à l'entité précédente (pour nettoyage)
var _entity_signal_connected: bool = false

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	recipe_selector.item_selected.connect(_on_recipe_selected)
	rate_slider.value_changed.connect(_on_rate_changed)
	active_toggle.toggled.connect(_on_active_toggled)
	hide()

# ─── API publique ─────────────────────────────────────────────────────────────

func setup(entity: Entity) -> void:
	# Déconnecter l'ancienne entité si nécessaire
	if current_entity != null and _entity_signal_connected:
		if current_entity.entity_updated.is_connected(_on_entity_updated):
			current_entity.entity_updated.disconnect(_on_entity_updated)
		_entity_signal_connected = false

	current_entity = entity

	if current_entity == null:
		hide()
		return

	# Nom de l'entité
	entity_name_label.text = _display_name(entity.entity_type)

	# Peupler le sélecteur de recettes
	recipe_selector.clear()
	var recipes := RecipeDatabase.get_recipes(entity.entity_type)
	for i in recipes.size():
		recipe_selector.add_item(recipes[i]["name"], i)
		# Pré-sélectionner la recette courante
		if recipes[i]["id"] == entity.current_recipe.get("id", ""):
			recipe_selector.select(i)

	# Taux de production
	rate_slider.set_block_signals(true)
	rate_slider.value = entity.production_rate
	rate_slider.set_block_signals(false)
	rate_label.text = "%d%%" % roundi(entity.production_rate * 100.0)

	# Toggle Actif
	active_toggle.set_block_signals(true)
	active_toggle.button_pressed = entity.is_active
	active_toggle.set_block_signals(false)

	# Détails recette et stats
	_refresh_recipe_details()
	_refresh_stats()

	# Connecter le signal de mise à jour
	entity.entity_updated.connect(_on_entity_updated)
	_entity_signal_connected = true

	show()

# ─── Callbacks UI ─────────────────────────────────────────────────────────────

func _on_close() -> void:
	if current_entity != null and _entity_signal_connected:
		if current_entity.entity_updated.is_connected(_on_entity_updated):
			current_entity.entity_updated.disconnect(_on_entity_updated)
		_entity_signal_connected = false
	current_entity = null
	hide()

func _on_recipe_selected(index: int) -> void:
	if current_entity == null:
		return
	var recipes := RecipeDatabase.get_recipes(current_entity.entity_type)
	if index >= 0 and index < recipes.size():
		current_entity.set_recipe(recipes[index])
		_refresh_recipe_details()

func _on_rate_changed(value: float) -> void:
	if current_entity == null:
		return
	rate_label.text = "%d%%" % roundi(value * 100.0)
	current_entity.set_production_rate(value)

func _on_active_toggled(pressed: bool) -> void:
	if current_entity == null:
		return
	current_entity.is_active = pressed

func _on_entity_updated(_entity: Entity) -> void:
	_refresh_stats()

# ─── Rafraîchissement ─────────────────────────────────────────────────────────

func _refresh_recipe_details() -> void:
	if current_entity == null:
		return
	var recipe := current_entity.current_recipe

	input_list.clear()
	if recipe.is_empty():
		input_list.add_item("—")
	else:
		var inputs: Dictionary = recipe.get("inputs", {})
		if inputs.is_empty():
			input_list.add_item("(aucune)")
		else:
			for item in inputs:
				input_list.add_item("%s ×%d" % [item, inputs[item]])

	output_list.clear()
	if recipe.is_empty():
		output_list.add_item("—")
	else:
		var outputs: Dictionary = recipe.get("outputs", {})
		if outputs.is_empty():
			output_list.add_item("(aucune)")
		else:
			for item in outputs:
				output_list.add_item("%s ×%d" % [item, outputs[item]])

func _refresh_stats() -> void:
	if current_entity == null:
		return
	var energy := current_entity.get_energy_delta()
	var co2 := current_entity.get_co2_rate()

	# Énergie : négatif = production, positif = consommation
	if energy < 0.0:
		energy_label.text = "%.0f kW produits" % absf(energy)
		energy_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	elif energy > 0.0:
		energy_label.text = "%.0f kW consommés" % energy
		energy_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.2))
	else:
		energy_label.text = "0 kW"
		energy_label.remove_theme_color_override("font_color")

	co2_label.text = "%.1f g/min" % co2
	if co2 > 10.0:
		co2_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		co2_label.remove_theme_color_override("font_color")

# ─── Utilitaire ───────────────────────────────────────────────────────────────

func _display_name(entity_type: String) -> String:
	match entity_type:
		"turbine":  return "Turbine"
		"factory":  return "Usine"
		_:          return entity_type.capitalize()
