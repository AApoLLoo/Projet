extends Node2D

const MAIN_MENU_SCENE: String = "res://scene/main_menu.tscn"
const SETTINGS_SCENE: String = "res://scene/settings.tscn"

@export var floor_path: NodePath = NodePath("Floor")
@onready var _floor: TileMapLayer = get_node_or_null(floor_path) as TileMapLayer
@onready var _camera: Camera2D = $Camera2D

var _preview_mode: bool = false
var _is_paused: bool = false
# Bloque la sauvegarde automatique dans _exit_tree() quand on a déjà sauvegardé
# explicitement : à ce stade les entités ont quitté l'arbre et EntityManager est vide.
var _skip_exit_save: bool = false

var _pause_layer: CanvasLayer
var _pause_backdrop: ColorRect
var _pause_panel: PanelContainer
var _pause_message_dialog: AcceptDialog
var _save_dialog: ConfirmationDialog
var _save_slot_list: ItemList
var _save_name_input: LineEdit
var _save_dialog_slot_ids: Array[String] = []
var _save_dialog_slot_names: Array[String] = []
var _save_dialog_slot_labels: Array[String] = []

func set_preview_mode(enabled: bool) -> void:
	_preview_mode = enabled

func _ready() -> void:
	if _floor == null:
		var err_msg: String = "Floor node not found at path: %s" % floor_path
		push_error(err_msg)
		var dlg: AcceptDialog = AcceptDialog.new()
		dlg.title = "Erreur"
		dlg.dialog_text = err_msg
		get_tree().get_root().add_child(dlg)
		dlg.popup_centered()

	_apply_start_state()
	if _preview_mode:
		_disable_preview_interactions()
		return
		var hud = get_node_or_null("HUD")
		if hud:
			hud.visible = false

	_build_pause_ui()
	_spawn_boxes()
	TimeManager.is_time_running = true
	if has_node("DeliveryManager"):
		$DeliveryManager.start_delivery()
		
func _input(event: InputEvent) -> void:
	if _preview_mode:
		return

	if event.is_action_pressed("ui_cancel"):
		if _save_dialog != null and _save_dialog.visible:
			_save_dialog.hide()
			get_viewport().set_input_as_handled()
			return

		if _is_paused:
			_resume_game()
		else:
			_open_pause_menu()

		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _preview_mode:
		return

	if event.is_action_pressed("ui_cancel"):
		if _save_dialog != null and _save_dialog.visible:
			_save_dialog.hide()
			return

		if _is_paused:
			_resume_game()
		else:
			_open_pause_menu()

func _notification(what: int) -> void:
	if _preview_mode:
		return

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_current_state()

func _exit_tree() -> void:
	if _preview_mode:
		return

	TimeManager.is_time_running = false
	# Ne pas sauvegarder ici si on vient de sauvegarder explicitement :
	# à ce stade les entités ont déjà quitté l'arbre et EntityManager est vide,
	# ce qui écraserait la bonne sauvegarde avec un tableau vide.
	if not _skip_exit_save:
		_save_current_state()


func _apply_start_state() -> void:
	var start_state: Dictionary = SaveSystem.get_menu_preview_state() if _preview_mode else SaveSystem.get_level_start_state()
	if EntityManager and EntityManager.has_method("clear_entities"):
		EntityManager.clear_entities()

	var building_manager: Node = find_child("BuildingManager", true, false)
	if building_manager and building_manager.has_method("clear_runtime_state"):
		building_manager.call("clear_runtime_state")

	var floor_script: Object = _floor
	if floor_script and floor_script.has_method("apply_saved_state"):
		floor_script.call("apply_saved_state", start_state)

	var camera_script: Object = _camera
	if camera_script and camera_script.has_method("refresh_limits"):
		camera_script.call("refresh_limits")

	var camera_x: float = _to_float(start_state.get("camera_x"), 576.0)
	var camera_y: float = _to_float(start_state.get("camera_y"), 324.0)
	var camera_position: Vector2 = Vector2(camera_x, camera_y)
	if camera_script and camera_script.has_method("set_camera_world_position"):
		camera_script.call("set_camera_world_position", camera_position)
	else:
		_camera.global_position = camera_position
		
	TimeManager.current_day = start_state.get("game_day", 1)
	TimeManager.current_time = start_state.get("game_time", 8.0)
	
	if GameManager:
		GameManager.credits = start_state.get("credits", 12500.0)
		GameManager.resources_updated.emit()

	# Restaurer les entités sauvegardées (bâtiments avec leur état)
	var entities_data: Array = start_state.get("entities", [])
	if not entities_data.is_empty():
		if building_manager and building_manager.has_method("restore_entities"):
			var restored_count: Variant = building_manager.call("restore_entities", entities_data)
			if int(restored_count) != entities_data.size():
				push_warning("Restauration partielle des batiments: %d/%d" % [int(restored_count), entities_data.size()])
		else:
			push_warning("BuildingManager introuvable pendant la restauration des batiments.")

	# Forcer la mise à jour de l'UI
	var hour: int = int(TimeManager.current_time)
	var minute: int = int((TimeManager.current_time - hour) * 60)
	TimeManager.time_changed.emit(hour, minute)
	TimeManager.day_changed.emit(TimeManager.current_day)

func _disable_preview_interactions() -> void:
	set_process_unhandled_input(false)
	_set_gameplay_enabled(false)

func _set_gameplay_enabled(enabled: bool) -> void:
	if _camera != null:
		_camera.set_process(enabled)
		_camera.set_process_input(enabled)
		_camera.set_process_unhandled_input(enabled)

	if _floor != null:
		_floor.set_process(enabled)

func _build_pause_ui() -> void:
	if _preview_mode:
		_disable_preview_interactions()
		var hud = get_node_or_null("HUD")
		if hud:
			hud.visible = false
		return

	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseUI"
	add_child(_pause_layer)

	_pause_backdrop = ColorRect.new()
	_pause_backdrop.name = "PauseBackdrop"
	_pause_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_backdrop.anchor_right = 1.0
	_pause_backdrop.anchor_bottom = 1.0
	_pause_backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	_pause_backdrop.visible = false
	_pause_layer.add_child(_pause_backdrop)

	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -180.0
	_pause_panel.offset_top = -180.0
	_pause_panel.offset_right = 180.0
	_pause_panel.offset_bottom = 180.0
	_pause_panel.visible = false
	_pause_backdrop.add_child(_pause_panel)

	var pause_margin: MarginContainer = MarginContainer.new()
	pause_margin.add_theme_constant_override("margin_left", 20)
	pause_margin.add_theme_constant_override("margin_top", 20)
	pause_margin.add_theme_constant_override("margin_right", 20)
	pause_margin.add_theme_constant_override("margin_bottom", 20)
	_pause_panel.add_child(pause_margin)

	var pause_vbox: VBoxContainer = VBoxContainer.new()
	pause_vbox.add_theme_constant_override("separation", 10)
	pause_margin.add_child(pause_vbox)

	var title_label: Label = Label.new()
	title_label.text = "PAUSE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	pause_vbox.add_child(title_label)

	var resume_button: Button = Button.new()
	resume_button.text = "Reprendre"
	resume_button.custom_minimum_size = Vector2(240.0, 44.0)
	resume_button.pressed.connect(_resume_game)
	pause_vbox.add_child(resume_button)

	var save_button: Button = Button.new()
	save_button.text = "Enregistrer"
	save_button.custom_minimum_size = Vector2(240.0, 44.0)
	save_button.pressed.connect(_on_pause_save_pressed)
	pause_vbox.add_child(save_button)

	var settings_button: Button = Button.new()
	settings_button.text = "Parametres"
	settings_button.custom_minimum_size = Vector2(240.0, 44.0)
	settings_button.pressed.connect(_on_pause_settings_pressed)
	pause_vbox.add_child(settings_button)

	var menu_button: Button = Button.new()
	menu_button.text = "Retour a l'accueil"
	menu_button.custom_minimum_size = Vector2(240.0, 44.0)
	menu_button.pressed.connect(_save_and_return_to_menu)
	pause_vbox.add_child(menu_button)

	_pause_message_dialog = AcceptDialog.new()
	_pause_message_dialog.title = "Information"
	_pause_layer.add_child(_pause_message_dialog)

	_save_dialog = ConfirmationDialog.new()
	_save_dialog.title = "Enregistrer dans un slot"
	_save_dialog.ok_button_text = "Enregistrer"
	_save_dialog.confirmed.connect(_on_save_dialog_confirmed)
	_save_dialog.custom_action.connect(_on_save_dialog_custom_action)
	_save_dialog.add_button("Supprimer", true, &"delete_slot")
	_pause_layer.add_child(_save_dialog)

	var save_dialog_margin: MarginContainer = MarginContainer.new()
	save_dialog_margin.add_theme_constant_override("margin_left", 14)
	save_dialog_margin.add_theme_constant_override("margin_top", 14)
	save_dialog_margin.add_theme_constant_override("margin_right", 14)
	save_dialog_margin.add_theme_constant_override("margin_bottom", 14)
	_save_dialog.add_child(save_dialog_margin)

	var save_dialog_vbox: VBoxContainer = VBoxContainer.new()
	save_dialog_vbox.add_theme_constant_override("separation", 8)
	save_dialog_margin.add_child(save_dialog_vbox)

	var save_dialog_label: Label = Label.new()
	save_dialog_label.text = "Choisir un slot de sauvegarde :"
	save_dialog_vbox.add_child(save_dialog_label)

	_save_slot_list = ItemList.new()
	_save_slot_list.custom_minimum_size = Vector2(380.0, 220.0)
	_save_slot_list.select_mode = ItemList.SELECT_SINGLE
	_save_slot_list.item_selected.connect(_on_save_slot_selected)
	save_dialog_vbox.add_child(_save_slot_list)

	var save_name_label: Label = Label.new()
	save_name_label.text = "Nom de sauvegarde :"
	save_dialog_vbox.add_child(save_name_label)

	_save_name_input = LineEdit.new()
	_save_name_input.placeholder_text = "Ex: Usine principale"
	save_dialog_vbox.add_child(_save_name_input)

func _open_pause_menu() -> void:
	_is_paused = true
	TimeManager.is_time_running = false
	_set_gameplay_enabled(false)
	if _pause_backdrop != null:
		_pause_backdrop.visible = true
	if _pause_panel != null:
		_pause_panel.visible = true

func _resume_game() -> void:
	_is_paused = false
	TimeManager.is_time_running = true
	_set_gameplay_enabled(true)
	if _pause_panel != null:
		_pause_panel.visible = false
	if _pause_backdrop != null:
		_pause_backdrop.visible = false

func _on_pause_save_pressed() -> void:
	_populate_save_slots()
	_save_dialog.popup_centered(Vector2i(460, 330))

func _on_pause_settings_pressed() -> void:
	_save_current_state()
	var active_slot: String = SaveSystem.get_active_slot_id()
	SettingsManager.set_return_target("res://scene/level.tscn", active_slot)
	SaveSystem.request_load_game(active_slot)
	var error: Error = get_tree().change_scene_to_file(SETTINGS_SCENE)
	if error != OK:
		_is_paused = true
		_show_pause_message("Impossible d'ouvrir les parametres.")

func _on_save_dialog_confirmed() -> void:
	var selected_indices: PackedInt32Array = _save_slot_list.get_selected_items()
	if selected_indices.is_empty():
		_show_pause_message("Choisis un slot avant d'enregistrer.")
		return

	var selected_index: int = selected_indices[0]
	if selected_index < 0 or selected_index >= _save_dialog_slot_ids.size():
		_show_pause_message("Slot invalide.")
		return

	var selected_slot: String = _save_dialog_slot_ids[selected_index]
	var floor_state: Dictionary = _collect_floor_state()
	var camera_position: Vector2 = _collect_camera_position()
	var save_name: String = ""
	if _save_name_input != null:
		save_name = _save_name_input.text.strip_edges()
	var saved_slot: String = SaveSystem.save_level_state_to_slot(selected_slot, camera_position, floor_state, save_name)
	_populate_save_slots()
	_show_pause_message("Partie enregistree dans %s." % _display_label_for_slot(saved_slot))

func _populate_save_slots() -> void:
	_save_slot_list.clear()
	_save_dialog_slot_ids.clear()
	_save_dialog_slot_names.clear()
	_save_dialog_slot_labels.clear()

	var slots: Array[Dictionary] = SaveSystem.get_save_slots(true)
	var active_slot: String = SaveSystem.get_active_slot_id()
	var slot_index: int = 0

	for slot_variant in slots:
		var slot: Dictionary = slot_variant
		var slot_id: String = _variant_to_string(slot.get("slot_id"), "slot_1")
		var label: String = _variant_to_string(slot.get("label"), slot_id)
		var has_data: bool = _to_bool(slot.get("has_data"), false)
		var saved_at_unix: int = _to_int(slot.get("saved_at_unix"), 0)
		var save_name: String = _variant_to_string(slot.get("save_name"), label)
		if not has_data:
			save_name = ""

		var item_text: String = "%s - Vide" % label
		if has_data:
			var display_name: String = save_name if not save_name.is_empty() else label
			item_text = "%s - %s (%s)" % [label, display_name, _format_saved_time(saved_at_unix)]
		elif SaveSystem.is_new_slot_id(slot_id):
			item_text = "%s" % label

		_save_slot_list.add_item(item_text)
		_save_dialog_slot_ids.append(slot_id)
		_save_dialog_slot_names.append(save_name)
		_save_dialog_slot_labels.append(label)
		if slot_id == active_slot:
			_save_slot_list.select(slot_index)
		slot_index += 1

	if _save_slot_list.get_item_count() > 0 and _save_slot_list.get_selected_items().is_empty():
		_save_slot_list.select(0)
	_on_sync_save_name_input_with_selection()

func _on_save_slot_selected(_index: int) -> void:
	_on_sync_save_name_input_with_selection()

func _on_sync_save_name_input_with_selection() -> void:
	if _save_name_input == null:
		return

	var selected_indices: PackedInt32Array = _save_slot_list.get_selected_items()
	if selected_indices.is_empty():
		_save_name_input.text = ""
		return

	var selected_index: int = selected_indices[0]
	if selected_index < 0 or selected_index >= _save_dialog_slot_names.size():
		_save_name_input.text = ""
		return

	_save_name_input.text = _save_dialog_slot_names[selected_index]

func _on_save_dialog_custom_action(action: StringName) -> void:
	if action != &"delete_slot":
		return

	var selected_indices: PackedInt32Array = _save_slot_list.get_selected_items()
	if selected_indices.is_empty():
		_show_pause_message("Choisis un slot a supprimer.")
		return

	var selected_index: int = selected_indices[0]
	if selected_index < 0 or selected_index >= _save_dialog_slot_ids.size():
		_show_pause_message("Slot invalide.")
		return

	var selected_slot: String = _save_dialog_slot_ids[selected_index]
	if SaveSystem.is_new_slot_id(selected_slot):
		_show_pause_message("Ce slot est un emplacement de creation.")
		return

	var deleted: bool = SaveSystem.delete_slot(selected_slot)
	if not deleted:
		_show_pause_message("Impossible de supprimer %s." % _display_label_for_slot(selected_slot))
		return

	_show_pause_message("Sauvegarde supprimee: %s." % _display_label_for_slot(selected_slot))
	_populate_save_slots()

func _format_saved_time(saved_at_unix: int) -> String:
	if saved_at_unix <= 0:
		return "Jamais sauvegarde"
	var date_text: String = Time.get_datetime_string_from_unix_time(saved_at_unix, true)
	return date_text.replace("T", " ")

func _display_label_for_slot(slot_id: String) -> String:
	for index in range(_save_dialog_slot_ids.size()):
		if _save_dialog_slot_ids[index] == slot_id:
			if index >= 0 and index < _save_dialog_slot_labels.size():
				return _save_dialog_slot_labels[index]
			return slot_id

	if SaveSystem.is_new_slot_id(slot_id):
		return "Nouveau slot"
	return slot_id

func _save_and_return_to_menu() -> void:
	_save_current_state()
	_is_paused = false
	var error: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Impossible d'ouvrir la scene menu.")

func _save_current_state() -> void:
	if _floor == null or _camera == null:
		return

	var floor_state: Dictionary = _collect_floor_state()
	var camera_position: Vector2 = _collect_camera_position()
	SaveSystem.save_level_state(camera_position, floor_state)
	# Marquer que la sauvegarde est faite : _exit_tree() ne l'écrasera pas
	# avec un EntityManager déjà vidé par la sortie des nœuds enfants.
	_skip_exit_save = true

func _collect_floor_state() -> Dictionary:
	var floor_state: Dictionary = {}
	var floor_script: Object = _floor
	if floor_script and floor_script.has_method("get_generation_state"):
		var state_result: Variant = floor_script.call("get_generation_state")
		floor_state = _to_dictionary(state_result)
	return floor_state

func _collect_camera_position() -> Vector2:
	var camera_position: Vector2 = _camera.global_position if _camera else Vector2.ZERO
	var camera_script: Object = _camera
	if camera_script and camera_script.has_method("get_camera_world_position"):
		var position_result: Variant = camera_script.call("get_camera_world_position")
		camera_position = _to_vector2(position_result, camera_position)
	return camera_position

func _show_pause_message(message: String) -> void:
	if _pause_message_dialog == null:
		return
	_pause_message_dialog.dialog_text = message
	_pause_message_dialog.popup_centered()

func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return float(value)
	if value is int:
		return float(value)
	return fallback

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

func _to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}

func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return fallback

func _spawn_boxes() -> void:
	if _preview_mode:
		return
	var box_scene: PackedScene = load("res://scene/box.tscn")
	if box_scene == null:
		push_error("Impossible de charger res://scene/box.tscn")
		return
	var spawn_positions: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(4, 2),
	]
	for cell in spawn_positions:
		var box: Node2D = box_scene.instantiate()
		add_child(box)
		box.global_position = Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
		
