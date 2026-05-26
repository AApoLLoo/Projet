extends Control

@onready var _gravity_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/GravitySlider
@onready var _gravity_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/GravityValue
@onready var _temp_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/TempSlider
@onready var _temp_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/TempValue
@onready var _friction_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/FrictionSlider
@onready var _friction_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/FrictionValue

@onready var _apply_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/ApplyButton
@onready var _reset_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/ResetButton
@onready var _back_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/BackButton
@onready var _message_dialog: AcceptDialog = $MessageDialog

var _active_settings: Dictionary = {}

func _ready() -> void:
    _active_settings = SettingsManager.get_settings()
    _update_ui_from_settings()

    _gravity_slider.value_changed.connect(_on_gravity_changed)
    _temp_slider.value_changed.connect(_on_temp_changed)
    _friction_slider.value_changed.connect(_on_friction_changed)

    _apply_button.pressed.connect(_on_apply_pressed)
    _reset_button.pressed.connect(_on_reset_pressed)
    _back_button.pressed.connect(_on_back_pressed)

func _update_ui_from_settings() -> void:
    _gravity_slider.value = SettingsManager._to_float(_active_settings.get("physics_gravity", 9.8), 9.8)
    _temp_slider.value = SettingsManager._to_float(_active_settings.get("physics_temperature", 20.0), 20.0)
    _friction_slider.value = SettingsManager._to_float(_active_settings.get("physics_friction", 1.0), 1.0)
    
    _on_gravity_changed(_gravity_slider.value)
    _on_temp_changed(_temp_slider.value)
    _on_friction_changed(_friction_slider.value)

func _on_gravity_changed(val: float) -> void:
    _gravity_value.text = String.num(val, 1) + " m/s²"

func _on_temp_changed(val: float) -> void:
    _temp_value.text = String.num(val, 1) + " °C"

func _on_friction_changed(val: float) -> void:
    _friction_value.text = String.num(val, 1)

func _on_apply_pressed() -> void:
    _active_settings["physics_gravity"] = _gravity_slider.value
    _active_settings["physics_temperature"] = _temp_slider.value
    _active_settings["physics_friction"] = _friction_slider.value
    
    SettingsManager.update_settings(_active_settings)
    _show_message("Parametres appliques avec succes.")

func _on_reset_pressed() -> void:
    SettingsManager.reset_to_defaults()
    _active_settings = SettingsManager.get_settings()
    _update_ui_from_settings()

func _on_back_pressed() -> void:
    var error: Error = get_tree().change_scene_to_file(SettingsManager.get_return_scene_path())
    if error != OK:
        push_error("Erreur retour: " + str(error))

func _show_message(text: String) -> void:
    _message_dialog.dialog_text = text
    _message_dialog.popup_centered()