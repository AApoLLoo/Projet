extends Node

signal contract_arrived(contract: Dictionary)
signal contract_completed(contract: Dictionary)
signal contract_failed(contract: Dictionary)

# Templates de contrats : qty_min/max sont pour le jour 1, augmentent avec la difficulté
const CONTRACT_TEMPLATES: Array[Dictionary] = [
	{ "resource_id": "piece_base",    "label": "Pieces de base",    "qty_min": 3,  "qty_max": 8,  "bonus_factor": 1.3, "penalty": 200.0, "deadline_days": 2 },
	{ "resource_id": "piece_avancee", "label": "Pieces avancees",   "qty_min": 1,  "qty_max": 2,  "bonus_factor": 1.5, "penalty": 400.0, "deadline_days": 3 },
	{ "resource_id": "metal",         "label": "Metal",             "qty_min": 4,  "qty_max": 10, "bonus_factor": 1.2, "penalty": 150.0, "deadline_days": 2 },
]

var active_contracts: Array[Dictionary] = []
var _last_generated_day: int = -1
var _day_connected: bool = false
# Suivi du streak de contrats réussis consécutifs
var completed_streak: int = 0

func _ready() -> void:
	if TimeManager:
		if TimeManager.day_changed.is_connected(_on_new_day):
			TimeManager.day_changed.disconnect(_on_new_day)
		TimeManager.day_changed.connect(_on_new_day)
		_day_connected = true
	# Génère un contrat dès le démarrage (jour 1)
	await get_tree().process_frame
	var start_day: int = TimeManager.current_day if TimeManager else 1
	_generate_contract(start_day)

func _on_new_day(day: int) -> void:
	_check_expired_contracts(day)
	_generate_contract(day)

func _generate_contract(day: int) -> void:
	if day == _last_generated_day:
		return
	_last_generated_day = day

	# Chaque jour génère 1 à 2 contrats (1 seul au début, 2 à partir du jour 3)
	var contracts_per_day: int = 1 if day < 3 else 2
	var templates_to_use: Array = CONTRACT_TEMPLATES.duplicate()
	templates_to_use.shuffle()

	for i in range(mini(contracts_per_day, templates_to_use.size())):
		var template: Dictionary = templates_to_use[i]

		# Difficulté progressive : +15% par jour
		var difficulty: float = 1.0 + (day - 1) * 0.15

		var qty_min: int = int(ceil(float(template["qty_min"]) * difficulty))
		var qty_max: int = int(ceil(float(template["qty_max"]) * difficulty))
		var quantity: int = randi_range(qty_min, qty_max)

		var resource_id: String = String(template["resource_id"])
		# Prix unitaires par type de ressource
		var unit_value: float = _get_unit_value(resource_id)
		var reward: float = snappedf(unit_value * float(quantity) * float(template["bonus_factor"]), 1.0)

		# BUG FIX : le délai est correctement appliqué (n'expire plus le jour même)
		var deadline_days: int = int(template.get("deadline_days", 2))
		var contract: Dictionary = {
			"id": "contract_%d_%d" % [day, randi()],
			"day_issued": day,
			"day_deadline": day + deadline_days,
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

func _get_unit_value(resource_id: String) -> float:
	match resource_id:
		"piece_base":    return 180.0
		"piece_avancee": return 420.0
		"metal":         return 90.0
		_:               return 100.0

func try_fulfill_contracts(resource_id: String, amount: int) -> int:
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
	return amount - remaining

func _complete_contract(contract: Dictionary) -> void:
	contract["completed"] = true
	completed_streak += 1
	var streak_bonus: float = minf(float(completed_streak - 1) * 0.05, 0.50)
	var final_reward: float = float(contract["reward"]) * (1.0 + streak_bonus)
	if GameManager:
		GameManager.add_credits(final_reward)
	contract_completed.emit(contract.duplicate(true))
	# Retirer immédiatement le contrat terminé de la liste
	active_contracts = active_contracts.filter(func(c):
		return not bool(c["completed"])
	)
	# Génère immédiatement un contrat de remplacement
	var current_day: int = TimeManager.current_day if TimeManager else 1
	_generate_single_contract(current_day)

func _generate_single_contract(day: int) -> void:
	var templates_to_use: Array = CONTRACT_TEMPLATES.duplicate()
	templates_to_use.shuffle()
	# Éviter de générer un doublon d'une ressource déjà en contrat actif
	var active_ids: Array = active_contracts.map(func(c): return c["resource_id"])
	for template in templates_to_use:
		if active_ids.has(template["resource_id"]):
			continue
		var difficulty: float = 1.0 + (day - 1) * 0.15
		var qty_min: int = int(ceil(float(template["qty_min"]) * difficulty))
		var qty_max: int = int(ceil(float(template["qty_max"]) * difficulty))
		var quantity: int = randi_range(qty_min, qty_max)
		var resource_id: String = String(template["resource_id"])
		var unit_value: float = _get_unit_value(resource_id)
		var reward: float = snappedf(unit_value * float(quantity) * float(template["bonus_factor"]), 1.0)
		var deadline_days: int = int(template.get("deadline_days", 2))
		var contract: Dictionary = {
			"id": "contract_%d_%d" % [day, randi()],
			"day_issued": day,
			"day_deadline": day + deadline_days,
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
		return
	
func _check_expired_contracts(current_day: int) -> void:
	for contract in active_contracts:
		if bool(contract["completed"]) or bool(contract["failed"]):
			continue
		if int(contract["day_deadline"]) < current_day:
			contract["failed"] = true
			completed_streak = 0  # Reset du streak en cas d'échec
			if GameManager:
				GameManager.add_credits(-float(contract["penalty"]))
			contract_failed.emit(contract.duplicate(true))
	# Nettoyer les vieux contrats résolus
	active_contracts = active_contracts.filter(func(c):
		return not (bool(c["completed"]) or bool(c["failed"]))
	)

func reset() -> void:
	active_contracts.clear()
	_last_generated_day = -1
	completed_streak = 0

func start_new_game() -> void:
	active_contracts.clear()
	_last_generated_day = -1
	completed_streak = 0
	await get_tree().process_frame
	var start_day: int = TimeManager.current_day if TimeManager else 1
	_generate_contract(start_day)

func get_active_contracts() -> Array[Dictionary]:
	return active_contracts.duplicate(true)

func get_streak() -> int:
	return completed_streak
