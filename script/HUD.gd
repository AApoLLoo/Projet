extends CanvasLayer

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel

@onready var btn_pause: Button = %BtnPause
@onready var btn_x1: Button = %BtnX1
@onready var btn_x2: Button = %BtnX2
@onready var btn_x4: Button = %BtnX4

@onready var minimap_camera: Camera2D = %MinimapCamera

func _ready() -> void:
	# Connexion aux signaux du TimeManager
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	
	# Boutons de contrôle du temps
	btn_pause.pressed.connect(func(): TimeManager.time_speed = 0.0)
	btn_x1.pressed.connect(func(): TimeManager.time_speed = 1.0)
	btn_x2.pressed.connect(func(): TimeManager.time_speed = 2.0)
	btn_x4.pressed.connect(func(): TimeManager.time_speed = 4.0)
	
	# Initialisation avec les valeurs actuelles au lancement
	_update_day_display(TimeManager.current_day)
	
	# Calculer manuellement l'heure pour la toute première frame (avant le premier signal Emit)
	var hour: int = int(TimeManager.current_time)
	var minute: int = int((TimeManager.current_time - hour) * 60)
	_update_time_display(hour, minute)

func _process(_delta: float) -> void:
	# Synchroniser la caméra de la minimap avec la caméra principale
	var main_camera = get_viewport().get_camera_2d()
	if main_camera and is_instance_valid(main_camera):
		minimap_camera.global_position = main_camera.global_position

func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)

func _on_day_changed(day: int) -> void:
	_update_day_display(day)

func _update_time_display(hour: int, minute: int) -> void:
	# Formatage avec des zéros (ex: 08:05)
	time_label.text = "%02d:%02d" % [hour, minute]

func _update_day_display(day: int) -> void:
	day_label.text = "Jour %d" % day
