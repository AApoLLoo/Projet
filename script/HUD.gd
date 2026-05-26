extends CanvasLayer

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel

@onready var btn_pause: Button = %BtnPause
@onready var btn_x1: Button = %BtnX1
@onready var btn_x2: Button = %BtnX2
@onready var btn_x4: Button = %BtnX4
@onready var btn_build_factory: Button = %BtnBuildFactory 

var factory_scene = preload("res://scene/factory.tscn")
var factory_texture = preload("res://asset/IndustrialTile_14.png")
@onready var minimap_camera: Camera2D = %MinimapCamera

func _ready() -> void:
	# Connexion aux signaux du TimeManager
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	
	if GameManager:
		GameManager.resources_updated.connect(_on_resources_updated)
		_update_money_display()
	
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

	# Bouton Construction 
	btn_build_factory.pressed.connect(func():
		var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
		if building_manager:
			building_manager.start_building(factory_scene, 1000.0, factory_texture)
	)

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

func _on_resources_updated() -> void:
	_update_money_display()

func _update_money_display() -> void:
	if money_label and GameManager:
		var formatted_money: String = String.num(GameManager.credits, 2)
		if formatted_money.ends_with(".00"):
			formatted_money = formatted_money.trim_suffix(".00")
		
		# Ajouter des espaces pour les milliers (séparateur de milliers simple)
		var parts: PackedStringArray = formatted_money.split(".")
		var int_part: String = parts[0]
		var result: String = ""
		var count: int = 0
		for i in range(int_part.length() - 1, -1, -1):
			if count > 0 and count % 3 == 0:
				result = " " + result
			result = int_part[i] + result
			count += 1
			
		if parts.size() > 1:
			result += "." + parts[1]
			
		money_label.text = result + " €"
