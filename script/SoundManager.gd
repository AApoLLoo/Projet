extends Node

const UI_SOUNDS: Dictionary = {
	"click": preload("res://asset/UI/audio/click1.ogg"),
	"hover": preload("res://asset/UI/audio/rollover1.ogg"),
	"switch": preload("res://asset/UI/audio/switch1.ogg"),
}
const SFX_BUS_NAME: String = "SFX"
const PLAYER_POOL_SIZE: int = 6
const META_HOVER_CONNECTED: StringName = &"sound_manager_hover_connected"
const META_PRESS_CONNECTED: StringName = &"sound_manager_press_connected"
const META_TOGGLE_CONNECTED: StringName = &"sound_manager_toggle_connected"
const META_OPTION_CONNECTED: StringName = &"sound_manager_option_connected"
const META_SLIDER_CONNECTED: StringName = &"sound_manager_slider_connected"

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0

func _ready() -> void:
	_ensure_sfx_bus()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_player_pool()
	if get_tree() != null and not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	_register_existing_controls(get_tree().root)

func play_sfx(name: String) -> void:
	var stream: AudioStream = UI_SOUNDS.get(name)
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_player_index]
	_player_index = (_player_index + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.play()

func register_ui_sfx(root: Node) -> void:
	_register_existing_controls(root)

func _create_player_pool() -> void:
	for _i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS_NAME
		add_child(player)
		_players.append(player)

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) != -1:
		return
	var bus_count: int = AudioServer.get_bus_count()
	AudioServer.add_bus(bus_count)
	AudioServer.set_bus_name(bus_count, SFX_BUS_NAME)
	AudioServer.set_bus_send(bus_count, "Master")

func _on_tree_node_added(node: Node) -> void:
	_register_control(node)

func _register_existing_controls(root: Node) -> void:
	if root == null:
		return
	_register_control(root)
	for child in root.get_children():
		_register_existing_controls(child)

func _register_control(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_register_button(node as BaseButton)
	if node is OptionButton:
		_register_option_button(node as OptionButton)
	if node is Slider:
		_register_slider(node as Slider)

func _register_button(button: BaseButton) -> void:
	if button == null:
		return
	if not button.has_meta(META_HOVER_CONNECTED):
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_focused.bind(button))
		button.set_meta(META_HOVER_CONNECTED, true)
	if button is CheckBox or button is CheckButton or button.toggle_mode:
		if not button.has_meta(META_TOGGLE_CONNECTED):
			button.toggled.connect(_on_button_toggled)
			button.set_meta(META_TOGGLE_CONNECTED, true)
		return
	if not button.has_meta(META_PRESS_CONNECTED):
		button.pressed.connect(_on_button_pressed)
		button.set_meta(META_PRESS_CONNECTED, true)

func _register_option_button(option_button: OptionButton) -> void:
	if option_button == null or option_button.has_meta(META_OPTION_CONNECTED):
		return
	option_button.item_selected.connect(_on_option_selected)
	option_button.set_meta(META_OPTION_CONNECTED, true)

func _register_slider(slider: Slider) -> void:
	if slider == null or slider.has_meta(META_SLIDER_CONNECTED):
		return
	slider.drag_ended.connect(_on_slider_drag_ended)
	slider.set_meta(META_SLIDER_CONNECTED, true)

func _on_button_hovered(_button: BaseButton) -> void:
	play_sfx("hover")

func _on_button_focused(_button: BaseButton) -> void:
	play_sfx("hover")

func _on_button_pressed() -> void:
	play_sfx("click")

func _on_button_toggled(_pressed: bool) -> void:
	play_sfx("switch")

func _on_option_selected(_index: int) -> void:
	play_sfx("switch")

func _on_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		play_sfx("switch")
