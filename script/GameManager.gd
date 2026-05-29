extends Node

# Ressources globales (Maquette HUD)
var credits: float = 12500.0
var energy_usage: float = 0.0  # en kW (positif = consommation nette, négatif = production nette)
var co2_emissions: float = 0.0 # en g/min

# Signaux pour mettre à jour l'UI automatiquement
signal resources_updated

func _ready() -> void:
	# Synchroniser les totaux énergie/CO2 depuis l'EntityManager
	EntityManager.totals_changed.connect(_on_totals_changed)

func _on_totals_changed(energy_total: float, co2_total: float) -> void:
	energy_usage = energy_total
	co2_emissions = co2_total
	resources_updated.emit()
	


func add_credits(amount: float):
	credits += amount
	resources_updated.emit()

func update_energy(amount: float):
	energy_usage += amount
	resources_updated.emit()
