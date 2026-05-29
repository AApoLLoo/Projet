extends Node

# Ressources globales (Maquette HUD)
var credits: float = 12500.0
var energy_usage: float = 0.0  # en kW (positif = consommation nette, négatif = production nette)
var co2_emissions: float = 0.0 # en g/min
var construction_co2: float = 0.0
var machine_co2_emissions: float = 0.0

# Signaux pour mettre à jour l'UI automatiquement
signal resources_updated

func _ready() -> void:
	# Synchroniser les totaux énergie/CO2 depuis l'EntityManager
	EntityManager.totals_changed.connect(_on_totals_changed)

func _on_totals_changed(energy_total: float, co2_total: float) -> void:
	energy_usage = energy_total
	machine_co2_emissions = co2_total
	_update_total_co2()
	resources_updated.emit()
	


func add_credits(amount: float):
	credits += amount
	resources_updated.emit()

func update_energy(amount: float):
	energy_usage += amount
	resources_updated.emit()

func add_construction_co2(amount: float) -> void:
	construction_co2 += amount
	_update_total_co2()
	resources_updated.emit()
	
func remove_construction_co2(amount: float) -> void:
	construction_co2 -= amount
	if construction_co2 < 0.0:
		construction_co2 = 0.0
	_update_total_co2()
	resources_updated.emit()

func _update_total_co2() -> void:
	co2_emissions = machine_co2_emissions + construction_co2
