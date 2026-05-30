extends Area2D

var destination = ""
var temps_attente = 0
var etat = "en_attente"
var dragging = false
var offset = Vector2.ZERO

const FRAMES = {
	"charbon": 12,
	"gaz": 61,
	"matiere_brute": 35,
	"metal": 14,
	"piece_base": 45,
	"piece_avancee": 47,
}

func _ready():
	input_pickable = true
	_appliquer_apparence()

func _appliquer_apparence():
	if destination.is_empty():
		return
	var sprite = $Sprite2D
	if sprite and FRAMES.has(destination):
		sprite.frame = FRAMES[destination]

func _process(delta):
	temps_attente += delta
	if dragging:
		global_position = get_global_mouse_position() + offset

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging = true
			offset = global_position - get_global_mouse_position()
			z_index = 100

func _input(event):
	if dragging:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				dragging = false
				z_index = 0
