extends Node2D

@export var colis_scene : PackedScene

var spawn_position = Vector2(0, 0)

func _ready():
	spawn_position = get_viewport_rect().size / 2
	spawn_loop()

func spawn_loop():
	while true:
		await get_tree().create_timer(2.0).timeout
		spawn_colis()

func spawn_colis():
	var colis = colis_scene.instantiate()
	colis.global_position = spawn_position
	
	get_parent().add_child(colis)
