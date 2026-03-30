extends Control


func _ready():
	# S'assure que la souris est bien visible dans le menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- BOUTONS PRINCIPAUX ---

func _on_btn_start_pressed():
	# Lance la scène du jeu !
	get_tree().change_scene_to_file("res://scene/level.tscn")

func _on_btn_quit_pressed():
	# Ferme le jeu
	get_tree().quit()
