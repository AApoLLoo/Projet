extends Node

# ─────────────────────────────────────────────────────────────────────────────
# RecipeDatabase – Autoload
# Registre central de toutes les recettes par type de bâtiment.
#
# Structure d'une recette :
#   id              : String  – identifiant unique
#   name            : String  – nom affiché
#   inputs          : Dict    – { "item_name": quantité }  (vide si aucun)
#   outputs         : Dict    – { "item_name": quantité }  (vide si aucun)
#   production_time : float   – secondes par cycle (non simulé pour l'instant)
#   energy_delta    : float   – kW (négatif = produit de l'énergie, positif = consomme)
#   co2_rate        : float   – g/min d'émissions
# ─────────────────────────────────────────────────────────────────────────────

var recipes: Dictionary = {
	"turbine": [
		{
			"id": "turbine_vapeur",
			"name": "Turbine à vapeur",
			"inputs": {},
			"outputs": { "energie": 100 },
			"production_time": 1.0,
			"energy_delta": -100.0,   # produit 100 kW
			"co2_rate": 5.0
		},
		{
			"id": "turbine_charbon",
			"name": "Turbine au charbon",
			"inputs": { "charbon": 1 },
			"outputs": { "energie": 250 },
			"production_time": 2.0,
			"energy_delta": -250.0,   # produit 250 kW
			"co2_rate": 18.0
		},
		{
			"id": "turbine_gaz",
			"name": "Turbine au gaz",
			"inputs": { "gaz": 1 },
			"outputs": { "energie": 400 },
			"production_time": 2.0,
			"energy_delta": -400.0,   # produit 400 kW
			"co2_rate": 12.0
		}
	],
	"factory": [
		{
			"id": "piece_basique",
			"name": "Pièce basique",
			"inputs": { "matiere_brute": 2 },
			"outputs": { "piece_base": 1 },
			"production_time": 5.0,
			"energy_delta": 50.0,     # consomme 50 kW
			"co2_rate": 2.0
		},
		{
			"id": "fonte_metal",
			"name": "Fonte de métal",
			"inputs": { "charbon": 1, "matiere_brute": 3 },
			"outputs": { "metal": 2 },
			"production_time": 8.0,
			"energy_delta": 80.0,
			"co2_rate": 6.0
		},
		{
			"id": "raffinage_gaz",
			"name": "Raffinage de gaz",
			"inputs": { "matiere_brute": 4 },
			"outputs": { "gaz": 2 },
			"production_time": 12.0,
			"energy_delta": 60.0,
			"co2_rate": 3.0
		},
		{
			"id": "purification_gaz",
			"name": "Purification de gaz",
			"inputs": { "gaz": 2 },
			"outputs": { "gaz_raffine": 1 },
			"production_time": 10.0,
			"energy_delta": 75.0,
			"co2_rate": 2.5
		},
		{
			"id": "charbon_compresse",
			"name": "Charbon compressé",
			"inputs": { "charbon": 3 },
			"outputs": { "charbon": 4 },
			"production_time": 6.0,
			"energy_delta": 30.0,
			"co2_rate": 1.5
		},
		{
			"id": "piece_avancee",
			"name": "Pièce avancée",
			"inputs": { "piece_base": 2, "metal": 1 },
			"outputs": { "piece_avancee": 1 },
			"production_time": 10.0,
			"energy_delta": 120.0,    # consomme 120 kW
			"co2_rate": 5.0
		}
	],
	"miner": [
		{
			"id": "extract_matiere_brute",
			"name": "Extraction de matière brute",
			"inputs": {},
			"outputs": { "matiere_brute": 1 },
			"production_time": 3.0,
			"energy_delta": 30.0,
			"co2_rate": 1.0
		},
		{
			"id": "extract_charbon",
			"name": "Extraction de charbon",
			"inputs": {},
			"outputs": { "charbon": 1 },
			"production_time": 5.0,
			"energy_delta": 40.0,
			"co2_rate": 3.0
		},
		{
			"id": "extract_metal",
			"name": "Extraction de métal brut",
			"inputs": {},
			"outputs": { "metal": 1 },
			"production_time": 8.0,
			"energy_delta": 50.0,
			"co2_rate": 2.0
		}
	]
}

# Retourne les recettes disponibles pour un type de bâtiment.
# Retourne un tableau vide si aucune recette n'est définie.
func get_recipes(entity_type: String) -> Array:
	return recipes.get(entity_type, [])

# Retourne une recette par son id (recherche dans tous les types).
func get_recipe_by_id(recipe_id: String) -> Dictionary:
	for type_recipes in recipes.values():
		for recipe in type_recipes:
			if recipe["id"] == recipe_id:
				return recipe
	return {}
