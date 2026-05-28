extends Node

# --- PARAMÈTRES DE LIVRAISON ---
# Glisse ta scène de camion (ex: camion.tscn) dans cette case dans l'inspecteur
@export var truck_scene: PackedScene 

# Points de passage en coordonnées globales (à ajuster dans l'inspecteur)
@export var spawn_position: Vector2 = Vector2(-200, 100) # Hors écran (départ)
@export var delivery_position: Vector2 = Vector2(400, 300) # Devant l'usine
@export var exit_position: Vector2 = Vector2(1000, 600) # Hors écran (sortie)

# Durées de l'animation en secondes
@export var drive_time: float = 3.0
@export var unload_time: float = 2.0

func _ready() -> void:
	# Optionnel : Pour tester automatiquement au lancement, décommente la ligne suivante
	# start_delivery()
	pass

# Fonction publique à appeler pour lancer une livraison
func start_delivery() -> void:
	if truck_scene == null:
		push_error("DeliveryManager: Aucune scène de camion n'est assignée dans l'inspecteur !")
		return

	# 1. Création et apparition du camion
	var truck_instance: Node2D = truck_scene.instantiate()
	add_child(truck_instance)
	truck_instance.global_position = spawn_position

	# 2. Création de la séquence d'animation (Tween)
	var tween: Tween = create_tween()

	# Étape A : Conduire jusqu'à la zone de livraison
	tween.tween_property(truck_instance, "global_position", delivery_position, drive_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# ... (code précédent)

	# Étape B : Le camion s'arrête et affiche la barre
	tween.tween_callback(func():
		# Utilise le chemin complet car 'loadingbar' est enfant de 'Truck'
		var bar = truck_instance.get_node_or_null("Truck/loadingbar")
		var anim = truck_instance.get_node_or_null("Truck") 
		
		if bar:
			bar.visible = true
			bar.show()
			bar.z_index = 100
		if anim:
			anim.play("default")
	)

	# ICI : AJOUTE CETTE LIGNE POUR FAIRE ATTENDRE LE TWEEN
	tween.tween_interval(unload_time)

	# Étape D : Livraison terminée -> On cache tout
	tween.tween_callback(func():
		var bar = truck_instance.get_node_or_null("Truck/loadingbar")
		var anim = truck_instance.get_node_or_null("Truck")
	
		if bar: bar.visible = false
		if anim: anim.stop()
		
		if GameManager:
			GameManager.add_credits(500)
	)
	
	# ... (code suivant)
	# Étape E : Repartir vers la sortie
	tween.tween_property(truck_instance, "global_position", exit_position, drive_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Étape F : Détruire le camion une fois l'animation terminée
	tween.tween_callback(func():
		print("Le camion quitte la carte.")
		truck_instance.queue_free()
	)
	pass
