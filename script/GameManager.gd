extends Node

# Ressources globales (Maquette HUD)
var credits: float = 12500.0
var energy_usage: float = 0.0 # en kW
var co2_emissions: float = 0.0 # en tonnes

# Signaux pour mettre à jour l'UI automatiquement
signal resources_updated

func add_credits(amount: float):
	credits += amount
	resources_updated.emit()

func update_energy(amount: float):
	energy_usage += amount
	resources_updated.emit()
