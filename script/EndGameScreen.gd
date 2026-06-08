extends CanvasLayer

const LEVEL_SCENE: String = "res://scene/level.tscn"
const MAIN_MENU_SCENE: String = "res://scene/main_menu.tscn"

@onready var _panel: PanelContainer = $Root/CenterContainer/Panel
@onready var _eyebrow_label: Label = $Root/CenterContainer/Panel/MarginContainer/Content/Eyebrow
@onready var _title_label: Label = $Root/CenterContainer/Panel/MarginContainer/Content/Title
@onready var _message_label: Label = $Root/CenterContainer/Panel/MarginContainer/Content/Message
@onready var _summary_label: Label = $Root/CenterContainer/Panel/MarginContainer/Content/Summary
@onready var _restart_button: Button = $Root/CenterContainer/Panel/MarginContainer/Content/Actions/RestartButton
@onready var _menu_button: Button = $Root/CenterContainer/Panel/MarginContainer/Content/Actions/MenuButton

var _is_victory: bool = true
var _title_text: String = "Victoire !"
var _message_text: String = "Objectif atteint."
var _summary_text: String = ""

func configure(is_victory: bool, title: String, message: String, summary: String = "") -> void:
	_is_victory = is_victory
	_title_text = title
	_message_text = message
	_summary_text = summary
	if is_node_ready():
		_apply_content()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	_apply_theme()
	_apply_content()
	_restart_button.pressed.connect(_restart_game)
	_menu_button.pressed.connect(_return_to_menu)

func _apply_theme() -> void:
	UITheme.style_screen($Root)
	UITheme.style_card(_panel, true, true, 0.94)
	UITheme.style_label(_eyebrow_label, "caption", true)
	UITheme.style_label(_title_label, "title", true)
	UITheme.style_label(_message_label, "body", true)
	UITheme.style_label(_summary_label, "caption", true)
	var primary_color: Color = UITheme.ACCENT_GOLD if _is_victory else UITheme.ACCENT_RED
	UITheme.style_button(_restart_button, primary_color, UITheme.TEXT_LIGHT)
	UITheme.style_button(_menu_button, UITheme.ACCENT_SKY, UITheme.TEXT_LIGHT, true)

func _apply_content() -> void:
	_eyebrow_label.text = "Simulation completee" if _is_victory else "Simulation interrompue"
	_title_label.text = _title_text
	_message_label.text = _message_text
	_summary_label.text = _summary_text
	_restart_button.text = "Recommencer"
	_menu_button.text = "Menu principal"

func _restart_game() -> void:
	if GameManager and GameManager.has_method("reset_end_state"):
		GameManager.reset_end_state()
	if SaveSystem and SaveSystem.has_method("request_new_game"):
		SaveSystem.request_new_game()
	get_tree().change_scene_to_file(LEVEL_SCENE)

func _return_to_menu() -> void:
	if GameManager and GameManager.has_method("reset_end_state"):
		GameManager.reset_end_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)