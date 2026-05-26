extends Control

const LEVEL_SCENE: String = "res://scene/level.tscn"
const SETTINGS_SCENE: String = "res://scene/settings.tscn"
const ACHIEVEMENTS_SCENE: String = "res://scene/achivements.tscn"

@onready var _bottom_left_label: Label = $BottomLeftPanel/BottomLeftMargin/BottomLeftLabel
@onready var _start_button: Button = $MenuButtons/StartButton
@onready var _load_button: Button = $MenuButtons/LoadButton
@onready var _lab_button: Button = $MenuButtons/LabButton
@onready var _tutorial_button: Button = $MenuButtons/TutorialButton
@onready var _settings_button: Button = $MenuButtons/SettingsButton
@onready var _achievements_button: Button = $MenuButtons/AchievementsButton
@onready var _quit_button: Button = $MenuButtons/QuitButton
@onready var _left_panel: PanelContainer = $BottomLeftPanel
@onready var _right_panel: PanelContainer = $BottomRightPanel
@onready var _message_dialog: AcceptDialog = $MessageDialog

var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _load_dialog: ConfirmationDialog
var _load_slot_list: ItemList
var _load_slot_ids: Array[String] = []

func _ready() -> void:
	_update_physics_panel()
	_setup_map_preview()
	_setup_load_dialog()
	resized.connect(_on_menu_resized)
	_style_buttons()
	_style_info_panels()
	_connect_actions()

func _style_buttons() -> void:
	_apply_button_style(_start_button, Color(0.41, 0.72, 0.53), Color(0.95, 0.98, 0.96))
	_apply_button_style(_load_button, Color(0.75, 0.79, 0.85), Color(0.08, 0.11, 0.17))
	_apply_button_style(_lab_button, Color(0.44, 0.64, 0.86), Color(0.06, 0.12, 0.23))
	_apply_button_style(_tutorial_button, Color(0.93, 0.79, 0.38), Color(0.15, 0.12, 0.06))
	_apply_button_style(_settings_button, Color(0.94, 0.95, 0.96), Color(0.08, 0.11, 0.17))
	_apply_button_style(_achievements_button, Color(0.94, 0.95, 0.96), Color(0.08, 0.11, 0.17))
	_apply_button_style(_quit_button, Color(0.94, 0.95, 0.96), Color(0.08, 0.11, 0.17))

func _update_physics_panel() -> void:
	if _bottom_left_label:
		var settings: Dictionary = SettingsManager.get_settings()
		var g: float = SettingsManager._to_float(settings.get("physics_gravity", 9.8), 9.8)
		var t: float = SettingsManager._to_float(settings.get("physics_temperature", 20.0), 20.0)
		var f: float = SettingsManager._to_float(settings.get("physics_friction", 1.0), 1.0)
		_bottom_left_label.text = "CURRENT ACTIVE UNIVERSE RULE:\nPhysique Modifiee :\nGravite: %.1f m/s²\nTemp: %.1f °C\nFrottement: %.1f" % [g, t, f]

func _style_info_panels() -> void:
	_left_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_right_panel.add_theme_stylebox_override("panel", _make_panel_style())

func _connect_actions() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_lab_button.pressed.connect(_on_lab_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_achievements_button.pressed.connect(_on_achievements_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _apply_button_style(button: Button, base_color: Color, text_color: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(base_color, base_color.darkened(0.28)))
	button.add_theme_stylebox_override("hover", _make_button_style(base_color.lightened(0.08), base_color.darkened(0.25)))
	button.add_theme_stylebox_override("pressed", _make_button_style(base_color.darkened(0.08), base_color.darkened(0.35)))
	button.add_theme_stylebox_override("focus", _make_button_style(base_color.lightened(0.12), base_color.darkened(0.2)))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE

func _make_button_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 3
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.97, 0.99, 0.9)
	style.border_color = Color(0.73, 0.79, 0.88, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	return style

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
		SaveSystem.request_load_game("")
	else:
		SaveSystem.request_load_game(selected_slot)
	_change_scene(LEVEL_SCENE)

func _on_load_dialog_custom_action(action: StringName) -> void:
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
