extends Node

# Signaux pour mettre à jour l'UI ou déclencher des événements
signal time_changed(hour: int, minute: int)
signal day_changed(day: int)

@export var time_multiplier: float = 60.0 # 1 sec réelle = 60 sec en jeu (1 minute)
var current_time: float = 8.0 # On commence à 8h00 du matin
var current_day: int = 1
var is_time_running: bool = false # Le temps est arrêté par défaut (ex: dans les menus)
var time_speed: float = 1.0 # Vitesse du temps (0.0 = pause, 1.0 = normal, 2.0 = rapide, etc.)

func _process(delta: float) -> void:
	if not is_time_running or time_speed <= 0.0:
		return
		
	# Convertir le delta en heures in-game
	current_time += (delta * time_multiplier * time_speed) / 3600.0
	current_time += (delta * time_multiplier) / 3600.0
	
	# Gestion du changement de jour
	if current_time >= 24.0:
		current_time -= 24.0
		current_day += 1
		day_changed.emit(current_day)
	
	# Calcul pour l'interface utilisateur
	var hour: int = int(current_time)
	var minute: int = int((current_time - hour) * 60)
	time_changed.emit(hour, minute)

# Retourne une valeur entre 0.0 et 1.0 pour interpoler les couleurs
func get_time_ratio() -> float:
	return current_time / 24.0