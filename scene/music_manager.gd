extends Node

@onready var player: AudioStreamPlayer = $AudioStreamPlayer

func play_music(stream: AudioStream) -> void:
	if player.stream == stream and player.playing:
		return  # déjà en train de jouer, on ne recoupe pas
	player.stream = stream
	player.play()

func stop_music() -> void:
	player.stop()
