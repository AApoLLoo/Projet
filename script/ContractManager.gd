extends Node

signal contract_arrived(contract: Dictionary)
signal contract_completed(contract: Dictionary)
signal contract_failed(contract: Dictionary)

const CONTRACT_TEMPLATES: Array[Dictionary] = [
	{ "resource_id": "piece_base",    "label": "Pieces de base",   "qty_min": 3,  "qty_max": 8,  "bonus_factor": 1.3, "penalty": 200.0 },
	{ "resource_id": "piece_avancee", "label": "Pieces avancees",  "qty_min": 1,  "qty_max": 2,  "bonus_factor": 1.5, "penalty": 400.0 },
]

var active_contracts: Array[Dictionary] = []
var _day_connected: bool = false

func _ready() -> void:
	if TimeManager:
		if TimeManager.day_changed.is_connected(_on_new_day):
			TimeManager.day_changed.disconnect(_on_new_day)
		TimeManager.day_changed.connect(_on_new_day)
		_day_connected = true

func _on_new_day(day: int) -> void:
	_check_expired_contracts(day)
	_generate_contract(day)

func _generate_contract(day: int) -> void:
	for template in CONTRACT_TEMPLATES:
		# Multiplicateur qui augmente avec les jours
		var difficulty: float = 1.0 + (day - 1) * 0.15  # +15% par jour
		
		var qty_min: int = int(ceil(template["qty_min"] * difficulty))
		var qty_max: int = int(ceil(template["qty_max"] * difficulty))
		var quantity: int = randi_range(qty_min, qty_max)
		
		var resource_id: String = String(template["resource_id"])
		var unit_value: float = 180.0 if resource_id == "piece_base" else 420.0
		var reward: float = snappedf(unit_value * float(quantity) * float(template["bonus_factor"]), 1.0)
		var contract: Dictionary = {
			"id": "contract_%d_%d" % [day, randi()],
			"day_issued": day,
			"day_deadline": day,
			"resource_id": resource_id,
			"resource_label": String(template["label"]),
			"quantity": quantity,
			"delivered": 0,
			"reward": reward,
			"penalty": float(template["penalty"]),
			"completed": false,
			"failed": false,
		}
		active_contracts.append(contract)
		contract_arrived.emit(contract.duplicate(true))

func try_fulfill_contracts(resource_id: String, amount: int) -> int:
	# Appelé quand des ressources entrent dans le stock global
	var remaining: int = amount
	for contract in active_contracts:
		if String(contract["resource_id"]) != resource_id:
			continue
		if bool(contract["completed"]) or bool(contract["failed"]):
			continue
		var needed: int = int(contract["quantity"]) - int(contract["delivered"])
		var delivered_now: int = mini(needed, remaining)
		contract["delivered"] = int(contract["delivered"]) + delivered_now
		remaining -= delivered_now
		if int(contract["delivered"]) >= int(contract["quantity"]):
			_complete_contract(contract)
		if remaining <= 0:
			break
	return amount - remaining   # quantité utilisée pour les contrats

func _complete_contract(contract: Dictionary) -> void:
	contract["completed"] = true
	if GameManager:
		GameManager.add_credits(float(contract["reward"]))
	contract_completed.emit(contract.duplicate(true))

func _check_expired_contracts(current_day: int) -> void:
	for contract in active_contracts:
		if bool(contract["completed"]) or bool(contract["failed"]):
			continue
		if int(contract["day_deadline"]) < current_day:
			contract["failed"] = true
			if GameManager:
				GameManager.add_credits(-float(contract["penalty"]))
			contract_failed.emit(contract.duplicate(true))
	# Nettoyer les vieux contrats résolus
	active_contracts = active_contracts.filter(func(c): 
		return not (bool(c["completed"]) or bool(c["failed"]))
	)

func reset() -> void:
	active_contracts.clear()
	
func get_active_contracts() -> Array[Dictionary]:
	return active_contracts.duplicate(true)
