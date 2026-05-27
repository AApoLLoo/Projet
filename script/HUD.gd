extends CanvasLayer

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel

@onready var btn_pause: Button = %BtnPause
@onready var btn_x1: Button = %BtnX1
@onready var btn_x2: Button = %BtnX2
@onready var btn_x4: Button = %BtnX4

# --- NOUVEAUX BOUTONS DE CONSTRUCTION ---
@onready var btn_toggle_build_menu: Button = %BtnToggleBuildMenu # Le bouton "Construction" principal
@onready var build_menu_container: VBoxContainer = %BuildMenuContainer # Le conteneur (menu déroulant)

@onready var btn_build_factory: Button = %BtnBuildFactory 
@onready var btn_build_belt: Button = %BtnBuildBelt       
@onready var btn_build_turbine: Button = %BtnBuildTurbine 

###BELT###
@onready var menu_belt: HBoxContainer = $Menu_Belt
@onready var curve_top: Button = $Menu_Belt/Curve_Top
@onready var curve_down: Button = $Menu_Belt/Curve_Down
@onready var curve_right: Button = $Menu_Belt/Curve_Right
@onready var curve_left: Button = $Menu_Belt/Curve_left
@onready var belt_droit: Button = $Menu_Belt/Belt_droit
@onready var belt_left: Button = $Menu_Belt/Belt_left

# --- DICTIONNAIRE MIS À JOUR ---
# --- DICTIONNAIRE MIS À JOUR AVEC DIRECTIONS ET VIRAGES ---
var buildings_data = {
	"factory": {
		"scene": preload("res://scene/factory.tscn"),
		"texture": preload("res://asset/IndustrialTile_14.png"),
		"cost": 200.0,
		"frames": 1
	},
	"turbine": {
		"scene": preload("res://scene/turbine_2d.tscn"),
		"texture": preload("res://asset/Turbine Animation base.png"),
		"cost": 500.0,
		"frames": 6
	},
	
	# --- TAPIS DROITS (Exemples de directions si vous séparez les scènes) ---
	"belt_right": {
		"scene": preload("res://scene/ASSET/belt/beltmid.tscn"), # À adapter si vous créez une scène par direction
		"texture": preload("res://asset/belt-midNO.png"),
		"cost": 50.0,
		"frames": 4
	},
	"belt_left": {
		"scene": preload("res://scene/ASSET/belt/beltleft.tscn"), 
		"texture": preload("res://asset/belt-mid.png"),
		"cost": 50.0,
		"frames": 4
	},
	
	# --- VIRAGES / COURBES (Curves 1 à 4 basées sur vos assets) ---
	"curve_top": {
		"scene": preload("res://scene/beltcurvetop.tscn"), # Votre scène existante !
		"texture": preload("res://asset/Curve_0001.png"),   # Texture correspondante
		"cost": 60.0,
		"frames": 4 # Mettez le nombre de frames d'animation si elles sont animées
	},
	"curve_down": {
		"scene": preload("res://scene/ASSET/belt/curvedown.tscn"), # À créer sur le modèle de beltcurvetop
		"texture": preload("res://asset/Curve_0002.png"),
		"cost": 60.0,
		"frames": 4
	},
	"curve_left": {
		"scene": preload("res://scene/ASSET/belt/curveright.tscn"),
		"texture": preload("res://asset/Curve_0003.png"),
		"cost": 60.0,
		"frames": 4
	},
	"curve_right": {
		"scene": preload("res://scene/ASSET/belt/curveright.tscn"),
		"texture": preload("res://asset/Curve_0004.png"),
		"cost": 60.0,
		"frames": 4
	}
}
@onready var minimap_camera: Camera2D = %MinimapCamera

func _ready() -> void:
	# On s'assure que le menu est caché au démarrage
	menu_belt.hide()
	
	# Connexion aux signaux du TimeManager
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	
	# --- CORRECTION 1 : Indentation corrigée ici ---
	
	
	# Exemple pour les tapis droits
	belt_droit.pressed.connect(func():
		print("Mode construction : Tapis Droit")
		_start_building_process("belt_right")
		menu_belt.hide()
	)
	belt_left.pressed.connect(func():
		print("Mode construction : Tapis Droit")
		_start_building_process("belt_left")
		menu_belt.hide()
	)
	# Exemple pour vos courbes (Curves)
	curve_top.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_top")
		menu_belt.hide()
	)
	curve_down.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_down")
		menu_belt.hide()
	)
	curve_right.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_right")
		menu_belt.hide()
	)
	curve_left.pressed.connect(func():
		print("Mode construction : Courbe Haut (Curve Top)")
		_start_building_process("curve_left")
		menu_belt.hide()
	)
	
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
	
	# Calculer manuellement l'heure pour la toute première frame
	var hour: int = int(TimeManager.current_time)
	var minute: int = int((TimeManager.current_time - hour) * 60)
	_update_time_display(hour, minute)

	# --- GESTION DU MENU DE CONSTRUCTION ---
	# 1. Cliquer sur "Construction" affiche ou masque le conteneur
	btn_toggle_build_menu.pressed.connect(func():
		build_menu_container.visible = not build_menu_container.visible
	)

	# 2. Les sous-boutons lancent la construction
	btn_build_factory.pressed.connect(func():
		print("Clic sur USINE !")
		_start_building_process("factory")
	)
	
	# --- CORRECTION 2 : Connexion directe et propre ---
	btn_build_belt.pressed.connect(_on_menu_belt_pressed)
	# --------------------------------------------------
	
	btn_build_turbine.pressed.connect(func():
		print("Clic sur TURBINE !")
		_start_building_process("turbine")
	)
# --- NOUVELLE FONCTION ---
func _start_building_process(building_type: String) -> void:
	var building_manager = get_tree().current_scene.find_child("BuildingManager", true, false)
	if building_manager:
		var data = buildings_data[building_type]
		building_manager.start_building(data["scene"], data["cost"], data["texture"], data.get("frames", 1))
		# Fermer le menu de construction après la sélection
		if build_menu_container:
			build_menu_container.visible = false

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
# --- NOUVELLE FONCTION POUR LE SOUS-MENU DES TAPIS ---
func _on_menu_belt_pressed() -> void:
	# Si le menu des tapis est visible, on le cache. Sinon, on l'affiche.
	if menu_belt.visible:
		menu_belt.hide()
	else:
		menu_belt.show()
