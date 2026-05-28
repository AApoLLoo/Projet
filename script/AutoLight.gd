extends PointLight2D

@export var turn_on_hour: float = 19.0 # S'allume à 19h00
@export var turn_off_hour: float = 7.0 # S'éteint à 07h00
@export_range(0.1, 6.0, 0.1) var fade_duration_hours: float = 1.5
@export_range(0.0, 8.0, 0.05) var max_energy: float = 1.2

func _process(_delta: float) -> void:
	var intensity: float = _get_light_intensity(TimeManager.current_time)
	enabled = intensity > 0.01
	energy = max_energy * intensity

func _get_light_intensity(current_hour: float) -> float:
	var intensity: float = 0.0

	if turn_on_hour > turn_off_hour:
		if current_hour >= turn_on_hour:
			intensity = 1.0
			if current_hour < turn_on_hour + fade_duration_hours:
				intensity = _smoothstep((current_hour - turn_on_hour) / fade_duration_hours)
		elif current_hour < turn_off_hour:
			intensity = 1.0
			if current_hour > turn_off_hour - fade_duration_hours:
				intensity = _smoothstep((turn_off_hour - current_hour) / fade_duration_hours)
	else:
		if current_hour >= turn_on_hour and current_hour < turn_off_hour:
			intensity = 1.0
			if current_hour < turn_on_hour + fade_duration_hours:
				intensity = _smoothstep((current_hour - turn_on_hour) / fade_duration_hours)
			if current_hour > turn_off_hour - fade_duration_hours:
				intensity = minf(intensity, _smoothstep((turn_off_hour - current_hour) / fade_duration_hours))

	return clampf(intensity, 0.0, 1.0)

func _smoothstep(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
