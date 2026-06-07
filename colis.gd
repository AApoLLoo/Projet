extends Area2D

var destination = ""
var temps_attente = 0
var etat = "en_attente"

var dragging = false
var offset = Vector2.ZERO


func _ready():
	input_pickable = true


func _process(delta):
	temps_attente += delta

	if dragging:
		global_position = get_global_mouse_position() + offset


func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var bm = get_tree().current_scene.get_node_or_null("BuildingManager")
			if bm and bool(bm.get("is_destroying")):
				return
			dragging = true


func _input(event):
	if dragging:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				dragging = false
				z_index = 0
