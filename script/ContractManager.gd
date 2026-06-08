extends Node

signal contract_arrived(contract: Dictionary)
signal contract_progressed(contract: Dictionary)
signal contract_completed(contract: Dictionary)
signal contract_failed(contract: Dictionary)

const CONTRACT_RULE_OVERRIDES: Dictionary = {
	"gaz_raffine": { "qty_min": 2, "qty_max": 5, "bonus_factor": 1.25, "penalty": 220.0, "deadline_days": 2 },
	"piece_base": { "qty_min": 3, "qty_max": 8, "bonus_factor": 1.3, "penalty": 200.0, "deadline_days": 2 },
	"piece_avancee": { "qty_min": 1, "qty_max": 2, "bonus_factor": 1.5, "penalty": 400.0, "deadline_days": 3 },
}
const CONTRACT_EXCLUDED_RESOURCE_IDS: Array[String] = [
	"gaz",
]

var active_contracts: Array[Dictionary] = []
var _last_generated_day: int = -1
var _day_connected: bool = false
# Suivi du streak de contrats réussis consécutifs
var completed_streak: int = 0
var failed_streak: int = 0

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
	var slots_available: int = 2 - active_contracts.size()
	if slots_available <= 0:
		return
	var contracts_per_day: int = mini(1 if day < 3 else 2, slots_available)
	var templates_to_use: Array = _build_contract_templates()
	if templates_to_use.is_empty():
		return
	templates_to_use.shuffle()

	for i in range(mini(contracts_per_day, templates_to_use.size())):
		var template: Dictionary = templates_to_use[i]
		_create_and_emit_contract(day, template)

func _get_unit_value(resource_id: String) -> float:
	match resource_id:
		"gaz_raffine":   return 165.0
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
		if delivered_now > 0:
			contract_progressed.emit(contract.duplicate(true))
		remaining -= delivered_now
		if int(contract["delivered"]) >= int(contract["quantity"]):
			_complete_contract(contract)
		if remaining <= 0:
			break
	return amount - remaining

func _complete_contract(contract: Dictionary) -> void:
	contract["completed"] = true
	failed_streak = 0
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
	if active_contracts.size() >= 2:
		return
	var templates_to_use: Array = _build_contract_templates()
	if templates_to_use.is_empty():
		return
	templates_to_use.shuffle()
	# Éviter de générer un doublon d'une ressource déjà en contrat actif
	var active_ids: Array = active_contracts.map(func(c): return c["resource_id"])
	for template in templates_to_use:
		if active_ids.has(template["resource_id"]):
			continue
		_create_and_emit_contract(day, template)
		return

func _create_and_emit_contract(day: int, template: Dictionary) -> void:
	var difficulty: float = 1.0 + (day - 1) * 0.15
	var qty_min: int = int(ceil(float(template.get("qty_min", 1)) * difficulty))
	var qty_max: int = int(ceil(float(template.get("qty_max", qty_min)) * difficulty))
	var quantity: int = randi_range(qty_min, max(qty_min, qty_max))
	var resource_id: String = String(template.get("resource_id", ""))
	var unit_value: float = _get_unit_value(resource_id)
	var reward: float = snappedf(unit_value * float(quantity) * float(template.get("bonus_factor", 1.2)), 1.0)
	var deadline_days: int = int(template.get("deadline_days", 2))
	var contract: Dictionary = {
		"id": "contract_%d_%d" % [day, randi()],
		"day_issued": day,
		"day_deadline": day + deadline_days,
		"resource_id": resource_id,
		"resource_label": String(template.get("label", resource_id)),
		"quantity": quantity,
		"delivered": 0,
		"reward": reward,
		"penalty": float(template.get("penalty", 100.0)),
		"completed": false,
		"failed": false,
	}
	active_contracts.append(contract)
	contract_arrived.emit(contract.duplicate(true))

func _build_contract_templates() -> Array:
	var templates: Array = []
	for resource_id in _get_contract_eligible_resource_ids():
		var template: Dictionary = {
			"resource_id": resource_id,
			"label": _format_resource_label(resource_id),
		}
		var overrides: Dictionary = CONTRACT_RULE_OVERRIDES.get(resource_id, {})
		if overrides.is_empty():
			template.merge(_build_default_contract_rule(resource_id), true)
		else:
			template.merge(overrides, true)
		templates.append(template)
	return templates

func _get_contract_eligible_resource_ids() -> Array[String]:
	var eligible_resources: Array[String] = []
	var mineable_resources: Array[String] = _get_mineable_resource_ids()
	for recipe_group_id in RecipeDatabase.recipes.keys():
		if String(recipe_group_id) == "miner":
			continue
		var recipe_group: Variant = RecipeDatabase.recipes[recipe_group_id]
		if not (recipe_group is Array):
			continue
		for recipe_variant in recipe_group:
			if not (recipe_variant is Dictionary):
				continue
			var recipe: Dictionary = recipe_variant
			var outputs: Dictionary = recipe.get("outputs", {})
			for output_variant in outputs.keys():
				var resource_id: String = String(output_variant)
				if resource_id.is_empty() or resource_id == "energie":
					continue
				if CONTRACT_EXCLUDED_RESOURCE_IDS.has(resource_id):
					continue
				if mineable_resources.has(resource_id) or eligible_resources.has(resource_id):
					continue
				eligible_resources.append(resource_id)
	return eligible_resources

func _get_mineable_resource_ids() -> Array[String]:
	var mineable_resources: Array[String] = []
	for recipe_variant in RecipeDatabase.get_recipes("miner"):
		if not (recipe_variant is Dictionary):
			continue
		var recipe: Dictionary = recipe_variant
		var outputs: Dictionary = recipe.get("outputs", {})
		for output_variant in outputs.keys():
			var resource_id: String = String(output_variant)
			if resource_id.is_empty() or mineable_resources.has(resource_id):
				continue
			mineable_resources.append(resource_id)
	return mineable_resources

func _build_default_contract_rule(resource_id: String) -> Dictionary:
	var unit_value: float = _get_unit_value(resource_id)
	var qty_min: int = clampi(int(round(240.0 / maxf(unit_value, 1.0))), 1, 8)
	var qty_max: int = max(qty_min + 1, qty_min * 2)
	var deadline_days: int = 2 if unit_value < 200.0 else 3
	var bonus_factor: float = 1.15
	if unit_value >= 180.0:
		bonus_factor = 1.3
	if unit_value >= 320.0:
		bonus_factor = 1.45
	return {
		"qty_min": qty_min,
		"qty_max": qty_max,
		"bonus_factor": bonus_factor,
		"penalty": snappedf(unit_value * float(qty_min) * 0.75, 10.0),
		"deadline_days": deadline_days,
	}

func _format_resource_label(resource_id: String) -> String:
	var words: PackedStringArray = resource_id.split("_")
	for index in range(words.size()):
		var word: String = words[index]
		if word.is_empty():
			continue
		words[index] = word.substr(0, 1).to_upper() + word.substr(1)
	return " ".join(words)
	
func _check_expired_contracts(current_day: int) -> void:
	for contract in active_contracts:
		if bool(contract["completed"]) or bool(contract["failed"]):
			continue
		if int(contract["day_deadline"]) < current_day:
			contract["failed"] = true
			completed_streak = 0  # Reset du streak en cas d'échec
			failed_streak += 1
			if GameManager:
				GameManager.add_credits(-float(contract["penalty"]))
				if failed_streak >= 2:
					GameManager.trigger_defeat("Deux contrats ont echoue d'affilee.")
			contract_failed.emit(contract.duplicate(true))
	# Nettoyer les vieux contrats résolus
	active_contracts = active_contracts.filter(func(c):
		return not (bool(c["completed"]) or bool(c["failed"]))
	)

func reset() -> void:
	active_contracts.clear()
	_last_generated_day = -1
	completed_streak = 0
	failed_streak = 0

func start_new_game() -> void:
	active_contracts.clear()
	_last_generated_day = -1
	completed_streak = 0
	failed_streak = 0
	await get_tree().process_frame
	var start_day: int = TimeManager.current_day if TimeManager else 1
	_generate_contract(start_day)

func get_save_state() -> Dictionary:
	return {
		"active_contracts": active_contracts.duplicate(true),
		"completed_streak": completed_streak,
		"failed_streak": failed_streak,
		"last_generated_day": _last_generated_day,
	}

func apply_save_state(data: Dictionary) -> void:
	active_contracts.clear()
	completed_streak = int(data.get("completed_streak", 0))
	failed_streak = int(data.get("failed_streak", 0))
	_last_generated_day = int(data.get("last_generated_day", -1))
	var raw_contracts: Variant = data.get("active_contracts", [])
	if raw_contracts is Array:
		for c in raw_contracts:
			if c is Dictionary:
				active_contracts.append(c.duplicate(true))

func get_active_contracts() -> Array[Dictionary]:
	return active_contracts.duplicate(true)

func get_streak() -> int:
	return completed_streak
