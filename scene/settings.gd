extends Control

const MAIN_MENU_SCENE: String = "res://scene/main_menu.tscn"
const LEVEL_SCENE: String = "res://scene/level.tscn"

@onready var _root_panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _display_card: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard
@onready var _audio_card: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard
@onready var _eyebrow_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Eyebrow
@onready var _title_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Title
@onready var _subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Header/Subtitle
@onready var _display_hint_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/DisplayHint
@onready var _footer_label: Label = $CenterContainer/PanelContainer/MarginContainer/Content/FooterLabel
@onready var _resolution_option: OptionButton = $CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/ResolutionOption
@onready var _fullscreen_check: CheckBox = $CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/FullscreenCheck
@onready var _master_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/SfxRow/SfxSlider
@onready var _master_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MasterRow/MasterValue
@onready var _music_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MusicRow/MusicValue
@onready var _sfx_value: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/SfxRow/SfxValue
@onready var _apply_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/ApplyButton
@onready var _reset_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/ResetButton
@onready var _back_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Buttons/BackButton
@onready var _message_dialog: AcceptDialog = $MessageDialog

var _window_controls_supported: bool = true

func _ready() -> void:
	_style_screen()
	_populate_resolution_options()
	_load_from_settings_manager()
	_configure_window_controls_state()
	_connect_signals()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_previous_scene()

func _populate_resolution_options() -> void:
	_resolution_option.clear()
	var resolutions: Array[Vector2i] = SettingsManager.get_resolution_options()
	for resolution in resolutions:
		_resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])

func _load_from_settings_manager() -> void:
	var settings: Dictionary = SettingsManager.get_settings()
	var max_index: int = max(0, _resolution_option.get_item_count() - 1)
	var resolution_index: int = clampi(_to_int(settings.get("resolution_index"), 0), 0, max_index)
	_resolution_option.select(resolution_index)
	_fullscreen_check.button_pressed = _to_bool(settings.get("fullscreen"), false)
	_master_slider.value = _to_float(settings.get("master_volume"), 80.0)
	_music_slider.value = _to_float(settings.get("music_volume"), 80.0)
	_sfx_slider.value = _to_float(settings.get("sfx_volume"), 80.0)
	_update_volume_labels()

func _connect_signals() -> void:
	_master_slider.value_changed.connect(_on_volume_slider_changed)
	_music_slider.value_changed.connect(_on_volume_slider_changed)
	_sfx_slider.value_changed.connect(_on_volume_slider_changed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(_on_back_pressed)

func _on_volume_slider_changed(_value: float) -> void:
	_update_volume_labels()

func _update_volume_labels() -> void:
	_master_value.text = "%d%%" % int(round(_master_slider.value))
	_music_value.text = "%d%%" % int(round(_music_slider.value))
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value))

func _on_apply_pressed() -> void:
	var settings: Dictionary = {}
	settings["resolution_index"] = _resolution_option.selected
	settings["fullscreen"] = _fullscreen_check.button_pressed
	settings["master_volume"] = _master_slider.value
	settings["music_volume"] = _music_slider.value
	settings["sfx_volume"] = _sfx_slider.value
	SettingsManager.update_settings(settings)
	if _window_controls_supported:
		_message_dialog.dialog_text = "Parametres appliques."
	else:
		_message_dialog.dialog_text = "Parametres appliques. Les options fenetre sont desactivees en mode integre."
	_message_dialog.popup_centered()

func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_from_settings_manager()
	_message_dialog.dialog_text = "Parametres reinitialises."
	_message_dialog.popup_centered()

func _on_back_pressed() -> void:
	_return_to_previous_scene()

func _return_to_previous_scene() -> void:
	var target_scene: String = SettingsManager.get_return_scene_path()
	var target_slot: String = SettingsManager.get_return_slot_id()
	if target_scene == LEVEL_SCENE:
		SaveSystem.request_load_game(target_slot)
	elif target_scene.is_empty():
		target_scene = MAIN_MENU_SCENE

	var error: Error = get_tree().change_scene_to_file(target_scene)
	if error != OK:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _configure_window_controls_state() -> void:
	_window_controls_supported = SettingsManager.supports_window_controls()
	_resolution_option.disabled = not _window_controls_supported
	_fullscreen_check.disabled = not _window_controls_supported
	if _window_controls_supported:
		_resolution_option.tooltip_text = ""
		_fullscreen_check.tooltip_text = ""
		_display_hint_label.text = "Choisis la resolution et le mode d'affichage qui conviennent a ton poste."
	else:
		var hint: String = "Indisponible en fenetre integree de l'editeur."
		_resolution_option.tooltip_text = hint
		_fullscreen_check.tooltip_text = hint
		_display_hint_label.text = "Les controles de fenetre sont bloques dans la vue integree de l'editeur. Lance le jeu dans une vraie fenetre pour les modifier."

func _style_screen() -> void:
	UITheme.style_screen(self)
	UITheme.style_card(_root_panel, false, true)
	UITheme.style_card(_display_card, false, false)
	UITheme.style_card(_audio_card, false, false)
	UITheme.style_option_button(_resolution_option)
	UITheme.style_toggle(_fullscreen_check, UITheme.ACCENT_GOLD)
	UITheme.style_slider(_master_slider, UITheme.ACCENT_TEAL)
	UITheme.style_slider(_music_slider, UITheme.ACCENT_SKY)
	UITheme.style_slider(_sfx_slider, UITheme.ACCENT_GOLD)
	UITheme.style_button(_apply_button, UITheme.ACCENT_TEAL, UITheme.TEXT_LIGHT)
	UITheme.style_button(_reset_button, Color("#E9EEF1"), UITheme.INK_DARK)
	UITheme.style_button(_back_button, UITheme.ACCENT_RED, UITheme.TEXT_LIGHT)
	UITheme.style_label(_eyebrow_label, "caption")
	UITheme.style_label(_title_label, "title")
	UITheme.style_label(_subtitle_label, "body")
	UITheme.style_label(_display_hint_label, "caption")
	UITheme.style_label(_footer_label, "caption")
	for label in [
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/DisplayTitle,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/AudioTitle
	]:
		UITheme.style_label(label, "section")
	for label in [
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/DisplaySubtitle,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/AudioSubtitle,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/DisplayCard/MarginContainer/Content/ResolutionLabel,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MasterLabel,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/MusicLabel,
		$CenterContainer/PanelContainer/MarginContainer/Content/Body/AudioCard/MarginContainer/Content/SfxLabel,
		_master_value,
		_music_value,
		_sfx_value
	]:
		UITheme.style_label(label, "body")
	var dialog_ok_button: Button = _message_dialog.get_ok_button()
	if dialog_ok_button:
		UITheme.style_button(dialog_ok_button, UITheme.ACCENT_TEAL, UITheme.TEXT_LIGHT, false, true)

func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback

func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return float(value)
	if value is int:
		return float(value)
	return fallback

func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return bool(value)
	return fallback
