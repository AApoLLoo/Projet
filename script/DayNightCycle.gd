extends CanvasModulate

@export var day_night_gradient: Gradient
@export var use_gradient: bool = false

@export_range(0.0, 24.0, 0.1) var sunrise_start_hour: float = 5.0
@export_range(0.0, 24.0, 0.1) var sunrise_peak_hour: float = 6.5
@export_range(0.0, 24.0, 0.1) var day_start_hour: float = 8.0
@export_range(0.0, 24.0, 0.1) var sunset_start_hour: float = 18.0
@export_range(0.0, 24.0, 0.1) var sunset_peak_hour: float = 19.0
@export_range(0.0, 24.0, 0.1) var night_start_hour: float = 20.5

@export var night_color: Color = Color(0.42, 0.47, 0.62, 1.0)
@export var sunrise_color: Color = Color(0.86, 0.76, 0.70, 1.0)
@export var day_color: Color = Color(1.0, 0.98, 0.96, 1.0)
@export var sunset_color: Color = Color(0.78, 0.68, 0.74, 1.0)

func _ready() -> void:
	if use_gradient and not day_night_gradient:
		push_warning("Aucun Gradient assigné pour le cycle Jour/Nuit !")
	_update_ambient_color()

func _process(_delta: float) -> void:
	_update_ambient_color()

func _update_ambient_color() -> void:
	if use_gradient and day_night_gradient:
		color = day_night_gradient.sample(TimeManager.get_time_ratio())
		return

	color = _sample_ambient_color(TimeManager.current_time)

func _sample_ambient_color(hour: float) -> Color:
	if hour < sunrise_start_hour or hour >= night_start_hour:
		return night_color
	if hour < sunrise_peak_hour:
		return night_color.lerp(sunrise_color, _smoothstep_range(sunrise_start_hour, sunrise_peak_hour, hour))
	if hour < day_start_hour:
		return sunrise_color.lerp(day_color, _smoothstep_range(sunrise_peak_hour, day_start_hour, hour))
	if hour < sunset_start_hour:
		return day_color
	if hour < sunset_peak_hour:
		return day_color.lerp(sunset_color, _smoothstep_range(sunset_start_hour, sunset_peak_hour, hour))
	if hour < night_start_hour:
		return sunset_color.lerp(night_color, _smoothstep_range(sunset_peak_hour, night_start_hour, hour))
	return night_color

func _smoothstep_range(start_value: float, end_value: float, value: float) -> float:
	if is_equal_approx(start_value, end_value):
		return 1.0
	var t: float = clampf((value - start_value) / (end_value - start_value), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
