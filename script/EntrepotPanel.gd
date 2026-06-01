# EntrepotPanel.gd
extends PanelContainer

@onready var title_label = $VBoxContainer/TitleLabel
@onready var stock_label = $VBoxContainer/StockLabel
@onready var incoming_label = $VBoxContainer/IncomingLabel

func setup(entrepot_instance):
	title_label.text = "Entrepôt"
	# Supposons que l'entrepôt a une fonction get_stock() ou accès direct au stock
	var stock = GameManager.get_resource_stock() # Ou une méthode spécifique de l'entrepôt
	stock_label.text = "Stock : " + str(stock)
	
	# Pour la livraison :
	# Il faudrait idéalement que l'entrepôt sache quelle livraison l'a pour cible
	incoming_label.text = "Livraison en attente : Aucune"
	show()
