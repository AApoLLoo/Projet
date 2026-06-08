extends Control

const LEVEL_SCENE: String = "res://scene/level.tscn"
const SETTINGS_SCENE: String = "res://scene/settings.tscn"
const ACHIEVEMENTS_SCENE: String = "res://scene/achivements.tscn"

@onready var _bottom_left_label: Label = $BottomLeftPanel/BottomLeftMargin/BottomLeftLabel
@onready var _menu_card: PanelContainer = $MenuBounds/CenterContainer/ContentStack/MenuCard
@onready var _menu_description_label: Label = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/MenuDescriptionLabel
@onready var _menu_title: Label = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/MenuTitle
@onready var _menu_footnote: Label = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/MenuFootnote
@onready var _start_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/StartButton
@onready var _load_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/LoadButton
@onready var _lab_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/LabButton
@onready var _tutorial_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/TutorialButton
@onready var _settings_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/SettingsButton
@onready var _achievements_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/AchievementsButton
@onready var _quit_button: Button = $MenuBounds/CenterContainer/ContentStack/MenuCard/MarginContainer/MenuButtons/QuitButton
@onready var _left_panel: PanelContainer = $BottomLeftPanel
@onready var _right_panel: PanelContainer = $BottomRightPanel
@onready var _message_dialog: AcceptDialog = $MessageDialog

var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _load_dialog: ConfirmationDialog
var _load_slot_list: ItemList
var _load_slot_ids: Array[String] = []
var _menu_descriptions: Dictionary = {}

func _ready() -> void:
	UITheme.style_screen(self)
	_update_physics_panel()
	_setup_load_dialog()
	resized.connect(_on_menu_resized)
	_style_buttons()
	_style_panels()
	_style_text()
	_menu_title.text = "FACTORY MANAGER"
	_menu_title.add_theme_font_size_override("font_size", 42)
	_menu_title.add_theme_color_override("font_color", UITheme.INK_DARK)
	_configure_menu_descriptions()
	_update_responsive_layout()
	_connect_actions()
	_menu_description_label.custom_minimum_size = Vector2(0, 105)
	_menu_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for btn in [_start_button, _load_button, _lab_button, _tutorial_button,
				_settings_button, _achievements_button, _quit_button]:
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _style_buttons() -> void:
	_apply_button_style(_start_button,        Color("#4FA39A"), UITheme.TEXT_LIGHT)  # teal
	_apply_button_style(_load_button,         Color("#6E95C4"), UITheme.TEXT_LIGHT)  # bleu
	_apply_button_style(_lab_button,          Color("#8B7EC8"), UITheme.TEXT_LIGHT)  # violet
	_apply_button_style(_tutorial_button, Color("#E8A87C"), UITheme.TEXT_LIGHT)  # orange doux	
	_apply_button_style(_settings_button,     Color("#7AAB8A"), UITheme.TEXT_LIGHT)  # vert sauge
	_apply_button_style(_achievements_button, Color("#C4956E"), UITheme.TEXT_LIGHT)  # brun chaud
	_apply_button_style(_quit_button,         Color("#C86B57"), UITheme.TEXT_LIGHT)  # rouge
	
func _update_physics_panel() -> void:
	if _bottom_left_label:
		var settings: Dictionary = SettingsManager.get_settings()
		var g: float = SettingsManager._to_float(settings.get("physics_gravity", 9.8), 9.8)
		var t: float = SettingsManager._to_float(settings.get("physics_temperature", 20.0), 20.0)
		var f: float = SettingsManager._to_float(settings.get("physics_friction", 1.0), 1.0)
		_bottom_left_label.text = "Univers actif\nGravite %.1f m/s²\nTemperature %.1f °C\nFrottement %.1f" % [g, t, f]

func _style_panels() -> void:
	UITheme.style_card(_menu_card, false, true, 0.68)
	UITheme.style_card(_left_panel, false, true, 0.6)
	UITheme.style_card(_right_panel, true, true, 0.58)

func _connect_actions() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_lab_button.pressed.connect(_on_lab_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_achievements_button.pressed.connect(_on_achievements_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _apply_button_style(button: Button, base_color: Color, text_color: Color) -> void:
	UITheme.style_button(button, base_color, text_color)

func _style_text() -> void:
	UITheme.style_label(_menu_description_label, "body")
	UITheme.style_label(_menu_title, "section")
	UITheme.style_label(_menu_footnote, "caption")
	UITheme.style_label(_bottom_left_label, "small")
	UITheme.style_label(_right_panel.get_node("BottomRightMargin/BottomRightLabel"), "small", true)

func _configure_menu_descriptions() -> void:
	_menu_descriptions = {
		_start_button: "Demarre une nouvelle ligne de production, ou reprend automatiquement la derniere sauvegarde disponible.",
		_load_button: "Choisis un slot precis et repars depuis un point de progression recent.",
		_lab_button: "Passe dans le laboratoire pour regler les parametres de simulation avant de jouer.",
		_tutorial_button: "Accede au futur parcours guide pour prendre en main les bases de l'automatisation.",
		_settings_button: "Ajuste l'affichage, l'audio et les options de confort depuis un ecran unifie.",
		_achievements_button: "Consulte les objectifs de progression et ce qui reste a debloquer.",
		_quit_button: "Ferme le jeu proprement apres avoir sauvegarde ta progression."
	}
	for button_variant in _menu_descriptions.keys():
		var button: Button = button_variant
		button.mouse_entered.connect(func() -> void: _set_menu_description(button))
	_set_menu_description(_start_button)

func _set_menu_description(button: Button) -> void:
	if button == null:
		return
	_menu_description_label.text = _menu_descriptions.get(button, "")

# APRÈS
func _on_start_pressed() -> void:
	SaveSystem.request_new_game()
	_change_scene(LEVEL_SCENE)

func _on_load_pressed() -> void:
	_open_load_dialog()

func _on_lab_pressed() -> void:
	SettingsManager.set_return_target("res://scene/main_menu.tscn")
	var error: Error = get_tree().change_scene_to_file("res://scene/lab_editor.tscn")
	if error != OK:
		_show_message("Impossible d'ouvrir le Lab: " + str(error))

func _on_tutorial_pressed() -> void:
	_show_message("Le tutoriel interactif arrive bientot.")

func _on_settings_pressed() -> void:
	SettingsManager.set_return_target("res://scene/main_menu.tscn")
	_change_scene(SETTINGS_SCENE)

func _on_achievements_pressed() -> void:
	_change_scene(ACHIEVEMENTS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _change_scene(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_show_message("Impossible d'ouvrir la scene : %s" % scene_path)

func _show_message(message: String) -> void:
	_message_dialog.dialog_text = message
	_message_dialog.popup_centered()

func _setup_map_preview() -> void:
	_preview_container = SubViewportContainer.new()
	_preview_container.name = "MapPreviewContainer"
	_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.layout_mode = 1
	_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _preview_container != null:
		_preview_container.anchor_right = 1.0
		_preview_container.anchor_bottom = 1.0
	_preview_container.stretch = true
	_preview_container.stretch_shrink = 1
	add_child(_preview_container)
	move_child(_preview_container, 0)

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "MapPreviewViewport"
	_preview_viewport.transparent_bg = false
	_preview_viewport.disable_3d = true
	_preview_viewport.handle_input_locally = false
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)
	_spawn_preview_level_scene()
	_resize_preview_viewport()

func _on_menu_resized() -> void:
	_resize_preview_viewport()
	_update_responsive_layout()

func _update_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact_layout: bool = viewport_size.x < 1180.0 or viewport_size.y < 760.0
	var tiny_layout: bool = viewport_size.x < 940.0 or viewport_size.y < 620.0
	var button_width: float = 300.0
	if viewport_size.x < 1280.0:
		button_width = 272.0
	if viewport_size.x < 1080.0:
		button_width = 244.0
	if viewport_size.x < 940.0:
		button_width = 216.0
	for button in [_start_button, _load_button, _lab_button, _tutorial_button, _settings_button, _achievements_button, _quit_button]:
		button.custom_minimum_size = Vector2(button_width, 50.0 if compact_layout else 54.0)
	_menu_card.custom_minimum_size = Vector2(button_width + 44.0, 0.0)
	_left_panel.visible = not tiny_layout
	_right_panel.visible = not tiny_layout
	if compact_layout:
		_left_panel.offset_right = 280.0
		_right_panel.offset_left = -280.0
	else:
		_left_panel.offset_right = 324.0
		_right_panel.offset_left = -324.0

func _resize_preview_viewport() -> void:
	if _preview_viewport == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var viewport_width: int = max(1, int(viewport_size.x))
	var viewport_height: int = max(1, int(viewport_size.y))
	_preview_viewport.size = Vector2i(viewport_width, viewport_height)

func _setup_load_dialog() -> void:
	_load_dialog = ConfirmationDialog.new()
	_load_dialog.title = "Charger une partie"
	_load_dialog.ok_button_text = "Charger"
	_load_dialog.confirmed.connect(_on_load_dialog_confirmed)
	_load_dialog.custom_action.connect(_on_load_dialog_custom_action)
	_load_dialog.add_button("Ouvrir le dossier", true, &"open_save_folder")
	_load_dialog.add_button("Supprimer", true, &"delete_slot")
	add_child(_load_dialog)

	var dialog_margin: MarginContainer = MarginContainer.new()
	dialog_margin.add_theme_constant_override("margin_left", 14)
	dialog_margin.add_theme_constant_override("margin_top", 14)
	dialog_margin.add_theme_constant_override("margin_right", 14)
	dialog_margin.add_theme_constant_override("margin_bottom", 14)
	_load_dialog.add_child(dialog_margin)

	var dialog_vbox: VBoxContainer = VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 8)
	dialog_margin.add_child(dialog_vbox)

	var title_label: Label = Label.new()
	title_label.text = "Choisis un slot a charger :"
	dialog_vbox.add_child(title_label)

	_load_slot_list = ItemList.new()
	_load_slot_list.custom_minimum_size = Vector2(390.0, 230.0)
	_load_slot_list.select_mode = ItemList.SELECT_SINGLE
	dialog_vbox.add_child(_load_slot_list)
	_style_load_dialog()

func _style_load_dialog() -> void:
	if _load_dialog == null:
		return
	if _load_slot_list:
		UITheme.style_item_list(_load_slot_list)
	var ok_button: Button = _load_dialog.get_ok_button()
	if ok_button:
		UITheme.style_button(ok_button, UITheme.ACCENT_TEAL, UITheme.TEXT_LIGHT, false, true)
	var cancel_button: Button = _load_dialog.get_cancel_button()
	if cancel_button:
		UITheme.style_button(cancel_button, Color("#E9EEF1"), UITheme.INK_DARK, false, true)

func _open_load_dialog() -> void:
	_populate_load_slots()
	_load_dialog.popup_centered(Vector2i(470, 340))

func _populate_load_slots() -> void:
	_load_slot_list.clear()
	_load_slot_ids.clear()

	var slots: Array[Dictionary] = SaveSystem.get_save_slots(true)
	var active_slot: String = SaveSystem.get_active_slot_id()
	var slot_index: int = 0

	for slot_variant in slots:
		var slot: Dictionary = slot_variant
		var slot_id: String = _variant_to_string(slot.get("slot_id"), "slot_1")
		var slot_label: String = _variant_to_string(slot.get("label"), slot_id)
		var has_data: bool = _to_bool(slot.get("has_data"), false)
		var saved_at_unix: int = _to_int(slot.get("saved_at_unix"), 0)
		var save_name: String = _variant_to_string(slot.get("save_name"), slot_label)

		var item_text: String = "%s - Nouvelle partie" % slot_label
		if has_data:
			var display_name: String = save_name if not save_name.is_empty() else slot_label
			item_text = "%s - %s (%s)" % [slot_label, display_name, _format_saved_time(saved_at_unix)]
		elif SaveSystem.is_new_slot_id(slot_id):
			item_text = "%s" % slot_label

		_load_slot_list.add_item(item_text)
		_load_slot_ids.append(slot_id)
		if slot_id == active_slot:
			_load_slot_list.select(slot_index)
		slot_index += 1

	if _load_slot_list.get_item_count() > 0 and _load_slot_list.get_selected_items().is_empty():
		_load_slot_list.select(0)

func _on_load_dialog_confirmed() -> void:
	var selected_indices: PackedInt32Array = _load_slot_list.get_selected_items()
	if selected_indices.is_empty():
		_show_message("Choisis un slot a charger.")
		return

	var selected_index: int = selected_indices[0]
	if selected_index < 0 or selected_index >= _load_slot_ids.size():
		_show_message("Slot invalide.")
		return

	var selected_slot: String = _load_slot_ids[selected_index]
	if SaveSystem.is_new_slot_id(selected_slot):
		SaveSystem.request_new_game()
	else:
		SaveSystem.request_load_game(selected_slot)
	_change_scene(LEVEL_SCENE)

func _on_load_dialog_custom_action(action: StringName) -> void:
	if action == &"open_save_folder":
		if SaveSystem.open_save_directory():
			return
		_show_message("Impossible d'ouvrir le dossier des sauvegardes.")
		return

	if action != &"delete_slot":
		return

	var selected_indices: PackedInt32Array = _load_slot_list.get_selected_items()
	if selected_indices.is_empty():
		_show_message("Choisis un slot a supprimer.")
		return

	var selected_index: int = selected_indices[0]
	if selected_index < 0 or selected_index >= _load_slot_ids.size():
		_show_message("Slot invalide.")
		return

	var selected_slot: String = _load_slot_ids[selected_index]
	if SaveSystem.is_new_slot_id(selected_slot):
		_show_message("Ce slot est un emplacement de creation.")
		return

	var deleted: bool = SaveSystem.delete_slot(selected_slot)
	if not deleted:
		_show_message("Impossible de supprimer %s." % selected_slot)
		return

	_show_message("Sauvegarde supprimee: %s." % selected_slot)
	_populate_load_slots()
	_spawn_preview_level_scene()

func _spawn_preview_level_scene() -> void:
	if _preview_viewport == null:
		return

	for child in _preview_viewport.get_children():
		child.queue_free()

	var level_scene_resource: Resource = load(LEVEL_SCENE)
	if not (level_scene_resource is PackedScene):
		return

	var level_scene: PackedScene = level_scene_resource
	var level_instance: Node = level_scene.instantiate()
	if level_instance and level_instance.has_method("set_preview_mode"):
		level_instance.call("set_preview_mode", true)

	# Ensure HUD is hidden in the preview instance so it doesn't appear behind the menu
	if level_instance:
		var hud_node: Node = null
		if level_instance.has_node("HUD"):
			hud_node = level_instance.get_node("HUD")
		else:
			hud_node = level_instance.find_node("HUD", true, false)
		if hud_node != null:
			if hud_node.has_method("hide"):
				hud_node.hide()
			elif hud_node is CanvasLayer or hud_node is Control:
				hud_node.visible = false
	if level_instance:
		_preview_viewport.add_child(level_instance)

func _format_saved_time(saved_at_unix: int) -> String:
	if saved_at_unix <= 0:
		return "Jamais sauvegarde"
	var date_text: String = Time.get_datetime_string_from_unix_time(saved_at_unix, true)
	return date_text.replace("T", " ")

func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback

func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return bool(value)
	return fallback

func _variant_to_string(value: Variant, fallback: String) -> String:
	if value is String:
		return value
	return fallback
