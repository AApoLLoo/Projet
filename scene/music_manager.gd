extends Node

@onready var player: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var tracks: Array[AudioStream] = []

var _shuffled: Array[AudioStream] = []
var _current_index: int = 0
var _paused: bool = false
var _playback_position: float = 0.0

func _ready() -> void:
	player.finished.connect(_on_track_finished)
	_shuffle_and_play()

func _shuffle_and_play() -> void:
	if tracks.is_empty():
		return
	_shuffled = tracks.duplicate()
	_shuffled.shuffle()
	_current_index = 0
	_play_current()

func _play_current() -> void:
	if _shuffled.is_empty():
		return
	player.stream = _shuffled[_current_index]
	player.play()
	_paused = false
	_playback_position = 0.0

func _on_track_finished() -> void:
	if _paused:
		return
	_current_index = (_current_index + 1) % _shuffled.size()
	if _current_index == 0:
		_shuffled.shuffle()
	_play_current()

func next_track() -> void:
	if _shuffled.is_empty():
		return
	_paused = false
	_playback_position = 0.0
	_current_index = (_current_index + 1) % _shuffled.size()
	_play_current()

func toggle_pause() -> void:
	if _shuffled.is_empty():
		return
	if _paused:
		player.play(_playback_position)
		_paused = false
	else:
		_playback_position = player.get_playback_position()
		player.stop()
		_paused = true

func is_paused() -> bool:
	return _paused

func get_current_track_name() -> String:
	if player.stream == null:
		return ""
	return player.stream.resource_path.get_file().get_basename()
