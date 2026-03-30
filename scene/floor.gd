extends TileMapLayer

@export var cell_size: int = 32
@export var grid_width: int = 200  # Nombre de cases en largeur
@export var grid_height: int = 200 # Nombre de cases en hauteur
@export var line_color: Color = Color(1, 1, 1, 0.2) # Blanc semi-transparent

func _ready():
	# Demande à Godot de dessiner la grille au démarrage
	queue_redraw()
	
	# Lance la fonction pour remplir le sol de tuiles
	generate_floor()

func generate_floor():
	# D'après votre fichier level.tscn, l'ID de votre source d'image est 1
	var source_id = 1
	# Les coordonnées de votre tuile dans l'atlas (0,0 est la première image en haut à gauche)
	var atlas_coords = Vector2i(0, 0)
	
	# On boucle sur chaque colonne (x) et chaque ligne (y)
	for x in range(grid_width):
		for y in range(grid_height):
			# La fonction set_cell place la tuile aux coordonnées indiquées
			set_cell(Vector2i(x, y), source_id, atlas_coords)

func _draw():
	# Dessiner les lignes verticales
	for x in range(grid_width + 1):
		var start_point = Vector2(x * cell_size, 0)
		var end_point = Vector2(x * cell_size, grid_height * cell_size)
		draw_line(start_point, end_point, line_color, 1.0)

	# Dessiner les lignes horizontales
	for y in range(grid_height + 1):
		var start_point = Vector2(0, y * cell_size)
		var end_point = Vector2(grid_width * cell_size, y * cell_size)
		draw_line(start_point, end_point, line_color, 1.0)
