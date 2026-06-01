# EntrepotPanel.gd
extends PanelContainer

# Assurez-vous que ces chemins correspondent à vos noms de nœuds réels dans la scène
@onready var title_label = $VBoxContainer/TitleLabel 
@onready var stock_label = $VBoxContainer/StockLabel
@onready var status_label = $VBoxContainer/StatusLabel

func setup(entrepot_instance):
	# Met à jour le titre
	title_label.text = "Entrepôt"
	
	# Récupère les infos depuis l'instance
	# ATTENTION : Entrepot.gd doit avoir accès à ses données
	stock_label.text = "Stock : En attente..." 
	status_label.text = "État : Opérationnel"
	
	# Si vous voulez afficher des données dynamiques plus tard, 
	# vous pourrez appeler des fonctions de entrepot_instance ici.
