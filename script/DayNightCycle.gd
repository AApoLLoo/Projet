extends CanvasModulate

@export var day_night_gradient: Gradient

func _ready() -> void:
	if not day_night_gradient:
		push_warning("Aucun Gradient assigné pour le cycle Jour/Nuit !")

func _process(_delta: float) -> void:
	if day_night_gradient:
		# get_time_ratio() the ratio between 0.0 and 1.0 representing the 24h cycle
		var ratio = TimeManager.get_time_ratio()
		
		# Sample the gradient based on the time of the day
		color = day_night_gradient.sample(ratio)
