extends PointLight2D

@export var turn_on_hour: float = 19.0 # S'allume à 19h00
@export var turn_off_hour: float = 7.0 # S'éteint à 07h00

func _process(_delta: float) -> void:
	var current_hour = TimeManager.current_time
	
	# Gère les lumières qui doivent rester allumées en traversant le minuit (ex: 19h à 7h)
	if turn_on_hour > turn_off_hour:
		enabled = current_hour >= turn_on_hour or current_hour < turn_off_hour
	else:
		enabled = current_hour >= turn_on_hour and current_hour < turn_off_hour
