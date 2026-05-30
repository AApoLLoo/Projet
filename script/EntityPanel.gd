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
@onready var status_label: Label            = %StatusLabel
@onready var active_toggle: CheckButton     = %ActiveToggle
@onready var close_btn: Button              = %CloseBtn

var current_entity: Entity = null

# Connexions temporaires à l'entité précédente (pour nettoyage)
var _entity_signal_connected: bool = false

func _ready() -> void:
	_style_panel()
	close_btn.pressed.connect(_on_close)
	recipe_selector.item_selected.connect(_on_recipe_selected)
	rate_slider.value_changed.connect(_on_rate_changed)
	active_toggle.toggled.connect(_on_active_toggled)
	if GameManager:
		GameManager.resources_updated.connect(_on_game_resources_updated)
	hide()

func _style_panel() -> void:
	UITheme.style_card(self, false, true)
	UITheme.style_option_button(recipe_selector)
	UITheme.style_item_list(input_list)
	UITheme.style_item_list(output_list)
	UITheme.style_slider(rate_slider, UITheme.ACCENT_SKY)
	UITheme.style_toggle(active_toggle, UITheme.ACCENT_TEAL)
	UITheme.style_button(close_btn, UITheme.ACCENT_RED, UITheme.TEXT_LIGHT, false, true)
	UITheme.style_label(entity_name_label, "section")
	for label in [
		$MarginContainer/VBoxContainer/RecipeLabel,
		$MarginContainer/VBoxContainer/RateLabel_Title,
		$MarginContainer/VBoxContainer/RecipeDetailsBox/InputBox/InputLabel,
		$MarginContainer/VBoxContainer/RecipeDetailsBox/OutputBox/OutputLabel,
		$MarginContainer/VBoxContainer/StatsBox/EnergyBox/EnergyTitle,
		$MarginContainer/VBoxContainer/StatsBox/Co2Box/Co2Title
	]:
		UITheme.style_label(label, "caption")
	for label in [rate_label, energy_label, co2_label, status_label]:
		UITheme.style_label(label, "body")

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
				var buffered_amount: int = current_entity.get_buffer_amount("input", String(item))
				input_list.add_item("%s ×%d (buffer %d)" % [item, inputs[item], buffered_amount])

	output_list.clear()
	if recipe.is_empty():
		output_list.add_item("—")
	else:
		var outputs: Dictionary = recipe.get("outputs", {})
		if outputs.is_empty():
			output_list.add_item("(aucune)")
		else:
			for item in outputs:
				if String(item) == "energie":
					output_list.add_item("%s ×%d" % [item, outputs[item]])
					continue
				var buffered_amount: int = current_entity.get_buffer_amount("output", String(item))
				output_list.add_item("%s ×%d (sortie %d)" % [item, outputs[item], buffered_amount])

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

	status_label.text = current_entity.get_status_text()
	if current_entity.get_status_text() == "Operationnel":
		status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	elif current_entity.get_status_text() == "En attente de ressources":
		status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	else:
		status_label.remove_theme_color_override("font_color")

func _on_game_resources_updated() -> void:
	if current_entity == null:
		return
	_refresh_recipe_details()
	_refresh_stats()

# ─── Utilitaire ───────────────────────────────────────────────────────────────

func _display_name(entity_type: String) -> String:
	match entity_type:
		"turbine":  return "Turbine"
		"factory":  return "Usine"
		"belt_right": return "Convoyeur droite"
		"belt_left": return "Convoyeur gauche"
		"curve_top": return "Convoyeur courbe haut"
		"curve_down": return "Convoyeur courbe bas"
		"curve_left": return "Convoyeur courbe gauche"
		"curve_right": return "Convoyeur courbe droite"
		_:          return entity_type.capitalize()
