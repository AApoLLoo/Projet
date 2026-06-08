extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
# Tutorial – révèle le HUD progressivement et guide le joueur étape par étape.
# ─────────────────────────────────────────────────────────────────────────────

signal tutorial_closed

# ── Référence au HUD ──────────────────────────────────────────────────────────
var _hud: CanvasLayer = null

# ── Nœuds HUD qu'on va masquer/révéler ───────────────────────────────────────
var _hud_groups: Dictionary = {}
var _extra_speed_nodes: Array = []

# ── Définition des étapes ────────────────────────────────────────────────────
const STEPS: Array[Dictionary] = [
	# ── 0 ── Bienvenue ───────────────────────────────────────────────────────
	{
		"tag": "Bienvenue",
		"title": "Bienvenue dans Factory Manager !",
		"body":
			"Tu hérites d'une usine à construire de zéro.\n\n" +
			"Ton objectif : bâtir une chaîne industrielle rentable en\n" +
			"• extrayant des ressources,\n" +
			"• les transformant en produits vendables,\n" +
			"• honorant des contrats pour empocher des crédits.\n\n" +
			"Tu démarres avec [b]12 500 €[/b]. Gère bien ton budget !",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": [],
		"highlight": "",
	},
	# ── 1 ── Déplacement ─────────────────────────────────────────────────────
	{
		"tag": "Navigation",
		"title": "Se déplacer sur la carte",
		"body":
			"[b]ZQSD[/b] (ou flèches) — déplacer la caméra\n" +
			"[b]Molette[/b] — zoomer / dézoomer\n\n" +
			"[b]Raccourcis utiles :[/b]\n" +
			"  [b]B[/b] — ouvrir/fermer le menu Construction\n" +
			"  [b]Tab[/b] — ouvrir/fermer les Commandes\n" +
			"  [b]I[/b] — Vue d'ensemble session\n" +
			"  [b]P[/b] — Pause / reprendre le temps\n" +
			"  [b]E[/b] — Sauvegarde rapide",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time"],
		"highlight": "",
	},
	# ── 2 ── Ouvrir le menu Construction ─────────────────────────────────────
	{
		"tag": "Étape 1 — Construction",
		"title": "Ouvre le menu Construction",
		"body":
			"Le bouton [b]Construction[/b] vient d'apparaître en haut.\n\n" +
			"Clique dessus (ou appuie sur [b]B[/b]) pour voir tous les\n" +
			"bâtiments disponibles.\n\n" +
			"[i]Objectif : ouvre le menu Construction.[/i]",
		"objective": "Ouvrir le menu Construction",
		"check": "build_menu_opened",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn"],
		"highlight": "build_btn",
	},
	# ── 3 ── Poser un Extracteur ─────────────────────────────────────────────
	{
		"tag": "Étape 2 — Extraction",
		"title": "Pose un Extracteur (300 €)",
		"body":
			"L'[b]Extracteur[/b] puise des ressources directement dans le sol.\n\n" +
			"Construction → [b]Extraction[/b] → clique sur la carte pour le placer.\n\n" +
			"Une fois posé, clique dessus pour choisir sa [b]recette[/b] :\n" +
			"  • Matière brute (3 s/cycle, 30 kW)\n" +
			"  • Charbon (5 s/cycle, 40 kW)\n" +
			"  • Métal brut (8 s/cycle, 50 kW)\n\n" +
			"💡 Les machines consomment de l'électricité — tu auras besoin d'une turbine !",
		"objective": "Poser au moins 1 Extracteur",
		"check": "has_miner",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu"],
		"highlight": "build_btn",
	},
	# ── 4 ── Poser une Turbine ───────────────────────────────────────────────
	{
		"tag": "Étape 3 — Énergie",
		"title": "Pose une Turbine (500 €)",
		"body":
			"Sans électricité, tes machines s'arrêtent.\n\n" +
			"Construction → [b]Energie[/b] → place la turbine sur la grille.\n\n" +
			"[b]3 recettes disponibles :[/b]\n" +
			"  • Turbine à vapeur — 100 kW gratuit (mais 5 g/min CO₂)\n" +
			"  • Turbine au charbon — 250 kW (consomme 1 charbon/2 s)\n" +
			"  • Turbine au gaz — 400 kW (consomme 1 gaz/2 s, moins polluant)\n\n" +
			"💡 La turbine à vapeur suffit pour débuter. Clique dessus après placement pour choisir.",
		"objective": "Poser au moins 1 Turbine",
		"check": "has_turbine",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu"],
		"highlight": "build_btn",
	},
	# ── 5 ── Poser une Usine ─────────────────────────────────────────────────
	{
		"tag": "Étape 4 — Production",
		"title": "Pose une Usine (200 €)",
		"body":
			"L'[b]Usine[/b] transforme des ressources en produits vendables.\n\n" +
			"Construction → [b]Production[/b] → place-la sur la grille.\n\n" +
			"Clique sur l'usine après placement pour sélectionner une recette.",
		"objective": "Poser au moins 1 Usine",
		"check": "has_factory",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu"],
		"highlight": "build_btn",
	},
	# ── 6 ── Connecter avec des tapis ────────────────────────────────────────
	{
		"tag": "Étape 5 — Convoyeurs",
		"title": "Relie tes bâtiments avec des tapis",
		"body":
			"Les [b]convoyeurs[/b] transportent les ressources de bâtiment en bâtiment.\n\n" +
			"Construction → [b]Convoyeurs[/b] → choisis une direction :\n" +
			"  • Tapis cardinaux : Nord, Sud, Est, Ouest\n" +
			"  • Virages : 4 courbes disponibles\n" +
			"Relie l'Extracteur → l'Usine avec au moins 3 tapis.\n\n" +
			"💡 La sortie d'un bâtiment alimente automatiquement l'entrée du suivant.",
		"objective": "Placer au moins 3 tapis",
		"check": "has_belts_3",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu"],
		"highlight": "build_btn",
	},
	# ── 7 ── Comprendre la grille d'énergie ──────────────────────────────────
	{
		"tag": "Étape 6 — Réseau électrique",
		"title": "Surveille ta consommation d'énergie",
		"body":
			"Chaque machine consomme des kW. Si la production est insuffisante,\n" +
			"les machines ralentissent ou s'arrêtent.\n\n" +
			"[b]Voir la zone couverte :[/b]\n" +
			"Construction → [b]Zone électricité[/b] (bouton toggle)\n\n" +
			"[b]Règle générale :[/b]\n" +
			"  1 Turbine vapeur (100 kW) couvre :\n" +
			"  → 3 Extracteurs (30 kW chacun)\n" +
			"  → ou 2 Usines basiques (50 kW chacune)\n\n" +
			"Le panneau CO₂ (coin bas droite) apparaîtra bientôt — surveille\n" +
			"ton impact environnemental pour éviter les pénalités de fin de partie.",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu", "resources"],
		"highlight": "resources",
	},
	# ── 8 ── Poser un entrepôt ───────────────────────────────────────────────
	{
		"tag": "Étape 7 — Entrepôt",
		"title": "Pose un Entrepôt (1 000 €)",
		"body":
			"L'[b]Entrepôt[/b] est obligatoire pour importer et exporter des marchandises.\n\n" +
			"Construction → [b]Entrepôt[/b] → place-le sur la grille.\n\n" +
			"Il sert de point de dépôt pour :\n" +
			"  • Les ressources importées par camion\n" +
			"  • Les produits finis à expédier\n\n" +
			"💡 Clique sur un entrepôt placé pour voir son stock et le gérer.",
		"objective": "Poser au moins 1 Entrepôt",
		"check": "has_entrepot",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "build_menu", "resources"],
		"highlight": "build_btn",
	},
	# ── 9 ── Importer des ressources ─────────────────────────────────────────
	{
		"tag": "Étape 8 — Import",
		"title": "Importe des ressources",
		"body":
			"Tu peux acheter des ressources directement par camion.\n\n" +
			"[b]Commandes[/b] (ou [b]Tab[/b]) → onglet [b]Import[/b] :\n" +
			"  • Choisis une ressource dans la liste\n" +
			"  • Ajuste la quantité\n" +
			"  • Définis un point de livraison sur la carte\n" +
			"  • Clique [b]Commander[/b]\n\n" +
			"[b]Tarifs d'import :[/b]\n" +
			"  • Charbon : 45 €/u | Gaz : 70 €/u\n" +
			"  • Matière brute : 55 €/u | Métal : 95 €/u\n\n" +
			"Le camion arrive automatiquement et décharge à la destination choisie.",
		"objective": "Lancer une commande d'import",
		"check": "has_imported",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn"],
		"highlight": "orders_btn",
	},
	# ── 10 ── Exporter pour gagner de l'argent ───────────────────────────────
	{
		"tag": "Étape 9 — Export",
		"title": "Exporte ta production pour gagner des crédits",
		"body":
			"La vente de produits finis est ta principale source de revenus.\n\n" +
			"[b]Commandes[/b] → onglet [b]Export[/b] :\n" +
			"  • Sélectionne le produit à vendre\n" +
			"  • Fixe la quantité (vérifie ton stock)\n" +
			"  • Valide — le camion vient chercher la marchandise\n\n" +
			"[b]Valeurs d'export :[/b]\n" +
			"  • Gaz raffiné : 165 €/u | Pièce de base : 180 €/u\n" +
			"  • Métal : 90 €/u | Pièce avancée : 420 €/u\n\n" +
			"💡 Le panneau affiche aussi la marge nette après coûts de production.",
		"objective": "Lancer un export",
		"check": "has_exported",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn"],
		"highlight": "orders_btn",
	},
	# ── 11 ── Contrats ───────────────────────────────────────────────────────
	{
		"tag": "Étape 10 — Contrats",
		"title": "Honore les contrats pour des bonus",
		"body":
			"Chaque jour, des [b]contrats[/b] arrivent automatiquement (max 2 actifs).\n" +
			"Ils demandent une quantité précise avant une [b]deadline[/b].\n\n" +
			"[b]Si tu livres à temps :[/b] récompense + bonus de streak (5% par contrat enchaîné, jusqu'à +50%)\n" +
			"[b]Si tu rates :[/b] pénalité financière déduite immédiatement\n\n" +
			"[b]Contrats possibles :[/b]\n" +
			"  • Gaz raffiné : 2–5 unités, deadline 2 jours\n" +
			"  • Pièce de base : 3–8 unités, deadline 2 jours\n" +
			"  • Pièce avancée : 1–2 unités, deadline 3 jours\n\n" +
			"Les contrats actifs s'affichent en haut de l'écran.",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn"],
		"highlight": "",
	},
	# ── 12 ── Usure et pannes ────────────────────────────────────────────────
	{
		"tag": "Étape 11 — Maintenance",
		"title": "Gère l'usure de tes machines",
		"body":
			"Chaque cycle de production use tes machines ([b]-0,35 PV[/b] par cycle).\n\n" +
			"En dessous de [b]20 PV[/b] de santé, une machine peut tomber en panne\n" +
			"avec 8% de chance par cycle — elle s'arrête alors complètement.\n\n" +
			"[b]Pour réparer :[/b] clique sur la machine → bouton Réparer\n" +
			"(nécessite un [b]repair_kit[/b] dans ton stock)\n\n" +
			"💡 Tu peux importer des repair_kits via le menu Commandes.\n" +
			"Surveille la santé de tes machines pour éviter les interruptions de production.",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn"],
		"highlight": "",
	},
	# ── 13 ── Mode destruction et déplacement ────────────────────────────────
	{
		"tag": "Étape 12 — Gestion avancée",
		"title": "Détruire et déplacer des bâtiments",
		"body":
			"Tu peux reorganiser ta factory à tout moment.\n\n" +
			"[b]Mode Destruction[/b] :\n" +
			"Construction → [b]Mode destruction[/b] (toggle)\n" +
			"Clic gauche sur un bâtiment pour le supprimer et récupérer une partie du coût.\n\n" +
			"[b]Déplacer un bâtiment :[/b]\n" +
			"Maintiens le clic gauche sur un bâtiment placé → glisse-le vers sa nouvelle case.\n\n" +
			"💡 La grille est grande (1000×1000 cases). Utilise la [b]minimap[/b] en bas à droite\n" +
			"pour naviguer et cliquer directement pour te téléporter.",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn", "overview_btn"],
		"highlight": "minimap",
	},
	# ── 14 ── Vue d'ensemble et victoire ─────────────────────────────────────
	{
		"tag": "Étape 13 — Objectif final",
		"title": "Vue d'ensemble et condition de victoire",
		"body":
			"Le bouton [b]I[/b] (Vue d'ensemble) résume ta session en temps réel :\n" +
			"machines actives, taux de production, consommation électrique, CO₂…\n\n" +
			"[b]Conditions de fin de partie :[/b]\n" +
			"  🏆 [b]Victoire[/b] — Atteins 1 000 000 € de crédits\n" +
			"  💀 [b]Défaite[/b] — Tu tombes à 0 € (ou en dessous du seuil)\n\n" +
			"[b]Stratégie recommandée :[/b]\n" +
			"  1. Matière brute → Pièce de base → Export (rentable dès le départ)\n" +
			"  2. Ajoute des turbines au charbon/gaz pour booster la production\n" +
			"  3. Enchaîne les contrats pour les bonus de streak\n" +
			"  4. Passe aux Pièces avancées (420 €/u) pour la ligne droite vers la victoire\n\n" +
			"Bonne chance !",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "orders_btn", "overview_btn", "minimap", "resources", "co2", "build_menu"],
		"highlight": "",
	},
	# ── 15 ── Fin ────────────────────────────────────────────────────────────
	{
		"tag": "Terminé !",
		"title": "Tu es prêt à jouer 🎉",
		"body":
			"Tu maîtrises maintenant toutes les bases :\n\n" +
			"✓ Extraire → Transformer → Vendre\n" +
			"✓ Gérer l'énergie (turbines)\n" +
			"✓ Connecter avec des convoyeurs\n" +
			"✓ Importer / Exporter par camion\n" +
			"✓ Honorer les contrats\n" +
			"✓ Gérer l'usure et les pannes\n\n" +
			"Tout le HUD est maintenant débloqué.\n" +
			"Construis ta fortune — le million t'attend !",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "orders_btn", "overview_btn", "minimap", "resources", "co2", "build_menu"],
		"highlight": "",
	},
]

# ── Nœuds UI du panneau tutoriel ─────────────────────────────────────────────
var _overlay: ColorRect
var _panel: PanelContainer
var _tag_label: Label
var _title_label: Label
var _body_label: RichTextLabel
var _objective_panel: PanelContainer
var _objective_label: Label
var _check_icon: Label
var _next_btn: Button
var _skip_btn: Button
var _step_counter: Label
var _progress_bar: ProgressBar

# ── Highlight overlay sur élément HUD ────────────────────────────────────────
var _highlight_rect: ColorRect = null

# ── État ──────────────────────────────────────────────────────────────────────
var _current_step: int = 0
var _next_callable: Callable = Callable()
var _import_submitted: bool = false
var _export_submitted: bool = false
var _build_menu_was_opened: bool = false
var _building_manager: Node = null
var _delivery_manager: Node = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	await get_tree().process_frame
	layer = 10
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_find_hud()
	_bind_managers()
	_bind_build_menu_signal()
	_go_to(0)

# ─────────────────────────────────────────────────────────────────────────────
func _find_hud() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	_hud = null

	for child in scene.get_children():
		if child is CanvasLayer and child.name == "HUD":
			_hud = child
			break
	if _hud == null:
		_hud = scene.find_child("HUD", true, false)
	if _hud == null:
		push_warning("Tutorial: HUD non trouvé, skip HUD binding")
		return
	var orders_panel := _hud.get_node_or_null("OrdersPanel")
	if orders_panel:
		orders_panel.hide()

	var contracts_banner := _hud.get_node_or_null()
	if contracts_banner:
		contracts_banner.hide()
		if orders_panel:
			orders_panel.hide()
	var hbox_path: String = "MarginContainer/MarginContainer/VBoxContainer/HBoxContainer"

	_hud_groups = {
		"day_time":     _hud.get_node_or_null("MarginContainer/MarginContainer/VBoxContainer/DayLabel"),
		"speed_btns":   _hud.get_node_or_null(hbox_path + "/BtnPause"),
		"build_btn":    _hud.get_node_or_null(hbox_path + "/BtnToggleBuildMenu"),
		"orders_btn":   _hud.get_node_or_null(hbox_path + "/BtnToggleOrders"),
		"overview_btn": _hud.get_node_or_null(hbox_path + "/BtnToggleSessionOverview"),
		"minimap":      _hud.get_node_or_null("MinimapContainer"),
		"resources":    _hud.get_node_or_null("ResourcesContainer"),
		"co2":          _hud.get_node_or_null("CO2Container"),
		"build_menu":   _hud.get_node_or_null("BuildMenuContainer"),
		"orders_panel": _hud.get_node_or_null("OrdersPanel"),
	}

	_extra_speed_nodes = [
		_hud.get_node_or_null(hbox_path + "/BtnX1"),
		_hud.get_node_or_null(hbox_path + "/BtnX2"),
		_hud.get_node_or_null(hbox_path + "/BtnX4"),
		_hud.get_node_or_null("MarginContainer/MarginContainer/VBoxContainer/TimeLabel"),
	]

	for key in _hud_groups:
		if _hud_groups[key] == null:
			push_warning("Tutorial: nœud HUD introuvable pour la clé '%s'" % key)

	_hide_all_hud()

func _hide_all_hud() -> void:
	for key in _hud_groups:
		var node: Node = _hud_groups[key]
		if node and node is CanvasItem:
			(node as CanvasItem).hide()
	for node in _extra_speed_nodes:
		if node and node is CanvasItem:
			(node as CanvasItem).hide()

func _apply_reveals(step: Dictionary) -> void:
	if _hud == null:
		return
	var reveals: Array = step.get("reveals", [])

	_hide_all_hud()

	for key in reveals:
		var node: Node = _hud_groups.get(key)
		if node and node is CanvasItem:
			(node as CanvasItem).show()
		if key == "speed_btns":
			for extra in _extra_speed_nodes:
				if extra and extra is CanvasItem:
					(extra as CanvasItem).show()

	_clear_highlight()
	var highlight_key: String = step.get("highlight", "")
	if not highlight_key.is_empty():
		var target: Node = _hud_groups.get(highlight_key)
		if target and target is Control:
			_show_highlight(target as Control)

# ─────────────────────────────────────────────────────────────────────────────
func _show_highlight(target: Control) -> void:
	if _highlight_rect == null:
		_highlight_rect = ColorRect.new()
		_highlight_rect.name = "TutorialHighlight"
		_highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_highlight_rect.z_index = 5
		add_child(_highlight_rect)

	_highlight_rect.color = Color(1.0, 0.85, 0.2, 0.18)

	var rect: Rect2 = target.get_global_rect()
	_highlight_rect.set_anchor_and_offset(SIDE_LEFT,   0, rect.position.x - 4)
	_highlight_rect.set_anchor_and_offset(SIDE_TOP,    0, rect.position.y - 4)
	_highlight_rect.set_anchor_and_offset(SIDE_RIGHT,  0, rect.position.x + rect.size.x + 4)
	_highlight_rect.set_anchor_and_offset(SIDE_BOTTOM, 0, rect.position.y + rect.size.y + 4)
	_highlight_rect.show()

func _clear_highlight() -> void:
	if _highlight_rect:
		_highlight_rect.hide()

# ─────────────────────────────────────────────────────────────────────────────
func _bind_managers() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	_building_manager = scene.find_child("BuildingManager", true, false)
	_delivery_manager = scene.find_child("DeliveryManager", true, false)

	if _delivery_manager:
		_delivery_manager.set("contracts_enabled", false) # 🔥 AJOUT IMPORTANT

		if _delivery_manager.has_signal("order_submitted"):
			_delivery_manager.order_submitted.connect(_on_order_submitted)

		if _delivery_manager.has_signal("delivery_completed"):
			_delivery_manager.delivery_completed.connect(_on_delivery_completed)

func _bind_build_menu_signal() -> void:
	if _hud == null:
		return
	var hbox_path: String = "MarginContainer/MarginContainer/VBoxContainer/HBoxContainer"
	var btn: Button = _hud.get_node_or_null(hbox_path + "/BtnToggleBuildMenu")
	if btn == null:
		push_warning("Tutorial: BtnToggleBuildMenu introuvable, signal build_menu non connecté")
		return
	if not btn.pressed.is_connected(_on_build_menu_toggled):
		btn.pressed.connect(_on_build_menu_toggled)

func _on_build_menu_toggled() -> void:
	_build_menu_was_opened = true
	_try_auto_advance()

func _on_close_pressed():
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	
func _on_order_submitted(order: Dictionary) -> void:
	var job_type: String = String(order.get("job_type", ""))
	if job_type == "import":
		_import_submitted = true
	elif job_type == "export":
		_export_submitted = true
	_try_auto_advance()

func _on_delivery_completed(order: Dictionary) -> void:
	var job_type: String = String(order.get("job_type", ""))
	if job_type == "export":
		_export_submitted = true
	_try_auto_advance()

# ─────────────────────────────────────────────────────────────────────────────
func _check_step(check_id: String) -> bool:
	if check_id.is_empty():
		return true

	match check_id:
		"build_menu_opened":
			return _build_menu_was_opened

		"has_miner":
			var em = _get_autoload("EntityManager")
			if em:
				return em.get_entities_of_type("miner").size() >= 1
			return false

		"has_factory":
			var em = _get_autoload("EntityManager")
			if em:
				return em.get_entities_of_type("factory").size() >= 1
			return false

		"has_turbine":
			var em = _get_autoload("EntityManager")
			if em:
				return em.get_entities_of_type("turbine").size() >= 1
			return false

		"has_entrepot":
			var em = _get_autoload("EntityManager")
			if em:
				return em.get_entities_of_type("entrepot").size() >= 1
			return false

		"has_belts_3":
			if _building_manager == null:
				return false
			return _building_manager.get_belt_count() >= 3

		"has_imported":
			return _import_submitted

		"has_exported":
			return _export_submitted

		"has_produced_item":
			return true

	return false

func _get_autoload(name: String) -> Node:
	return get_tree().root.get_node_or_null(name)

# ─────────────────────────────────────────────────────────────────────────────
var _poll_timer: float = 0.0

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer < 0.5:
		return
	_poll_timer = 0.0
	_try_auto_advance()

func _try_auto_advance() -> void:
	if _current_step >= STEPS.size():
		return
	var step: Dictionary = STEPS[_current_step]
	if bool(step.get("skip", false)):
		_update_check_icon(true)
		return
	var done: bool = _check_step(String(step.get("check", "")))
	_update_check_icon(done)
	if done:
		_next_btn.disabled = false

# ─────────────────────────────────────────────────────────────────────────────
func _go_to(index: int) -> void:
	if index == 9:
		if _delivery_manager:
			_delivery_manager.set("contracts_enabled", true)
	if index < 0 or index >= STEPS.size():
		return
	_current_step = index
	var step: Dictionary = STEPS[index]
	var is_skip: bool = bool(step.get("skip", false))
	var is_last: bool = (index == STEPS.size() - 1)

	_tag_label.text = String(step.get("tag", "")).to_upper()
	_title_label.text = step["title"]
	_body_label.text = step["body"]
	_progress_bar.value = float(index + 1)
	_step_counter.text = "%d / %d" % [index + 1, STEPS.size()]

	var objective_text: String = String(step.get("objective", ""))
	if objective_text.is_empty():
		_objective_panel.hide()
	else:
		_objective_label.text = objective_text
		_objective_panel.show()

	_apply_reveals(step)

	if _next_callable.is_valid() and _next_btn.pressed.is_connected(_next_callable):
		_next_btn.pressed.disconnect(_next_callable)

	if is_last:
		_next_btn.text = "Terminer"
		_next_callable = Callable(self, "_close")
		UITheme.style_button(_next_btn, UITheme.ACCENT_TEAL, UITheme.TEXT_LIGHT, false, true)
		_next_btn.disabled = false
	else:
		_next_btn.text = "Suivant →"
		_next_callable = func() -> void: _go_to(_current_step + 1)
		UITheme.style_button(_next_btn, UITheme.ACCENT_GOLD, UITheme.INK_DARK, false, true)
		_next_btn.disabled = not is_skip

	_next_btn.pressed.connect(_next_callable)
	_skip_btn.visible = not is_skip and not is_last
	_update_check_icon(is_skip or _check_step(String(step.get("check", ""))))
	if not is_skip and not is_last:
		_try_auto_advance()

func _update_check_icon(done: bool) -> void:
	if done:
		_check_icon.text = "✓  Objectif atteint !"
		_check_icon.add_theme_color_override("font_color", Color("#1D9E75"))
		_next_btn.disabled = false
	else:
		_check_icon.text = "En attente..."
		_check_icon.add_theme_color_override("font_color", UITheme.INK_MUTED)

# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "TutorialPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400.0
	_panel.offset_right = -20.0
	_panel.offset_top = -560.0
	_panel.offset_bottom = -80.0
	_panel.custom_minimum_size = Vector2(380.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.style_card(_panel, false, true, 0.96)
	add_child(_panel)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	# En-tête
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var header_left := VBoxContainer.new()
	header_left.add_theme_constant_override("separation", 2)
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_left)

	_tag_label = Label.new()
	_tag_label.add_theme_font_size_override("font_size", 10)
	_tag_label.add_theme_color_override("font_color", UITheme.ACCENT_GOLD)
	header_left.add_child(_tag_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", UITheme.INK_DARK)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_left.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(28.0, 28.0)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.add_theme_color_override("font_color", UITheme.INK_MUTED)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Barre de progression
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = float(STEPS.size())
	_progress_bar.value = 1.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 4.0)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = UITheme.BORDER_SOFT
	pb_bg.corner_radius_top_left = 2; pb_bg.corner_radius_top_right = 2
	pb_bg.corner_radius_bottom_left = 2; pb_bg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = UITheme.ACCENT_GOLD
	pb_fill.corner_radius_top_left = 2; pb_fill.corner_radius_top_right = 2
	pb_fill.corner_radius_bottom_left = 2; pb_fill.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	vbox.add_child(_progress_bar)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", UITheme.BORDER_SOFT)
	vbox.add_child(sep)

	# Corps (BBCode activé pour [b] et [i])
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("normal_font_size", 13)
	_body_label.add_theme_color_override("default_color", UITheme.INK_MUTED)
	_body_label.custom_minimum_size = Vector2(0.0, 80.0)
	vbox.add_child(_body_label)

	# Encadré objectif
	_objective_panel = PanelContainer.new()
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color("#E1F5EE")
	obj_style.border_color = Color("#1D9E75")
	obj_style.border_width_left = 4
	obj_style.corner_radius_top_left = 6; obj_style.corner_radius_top_right = 6
	obj_style.corner_radius_bottom_left = 6; obj_style.corner_radius_bottom_right = 6
	obj_style.content_margin_left = 12.0; obj_style.content_margin_right = 12.0
	obj_style.content_margin_top = 8.0; obj_style.content_margin_bottom = 8.0
	_objective_panel.add_theme_stylebox_override("panel", obj_style)
	vbox.add_child(_objective_panel)

	var obj_vbox := VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 4)
	_objective_panel.add_child(obj_vbox)

	var obj_title := Label.new()
	obj_title.text = "OBJECTIF"
	obj_title.add_theme_font_size_override("font_size", 10)
	obj_title.add_theme_color_override("font_color", Color("#0F6E56"))
	obj_vbox.add_child(obj_title)

	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 13)
	_objective_label.add_theme_color_override("font_color", Color("#04342C"))
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_vbox.add_child(_objective_label)

	_check_icon = Label.new()
	_check_icon.add_theme_font_size_override("font_size", 12)
	_check_icon.add_theme_color_override("font_color", UITheme.INK_MUTED)
	obj_vbox.add_child(_check_icon)

	# Navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	vbox.add_child(nav)

	_step_counter = Label.new()
	_step_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_counter.add_theme_font_size_override("font_size", 12)
	_step_counter.add_theme_color_override("font_color", UITheme.INK_MUTED)
	nav.add_child(_step_counter)

	_skip_btn = Button.new()
	_skip_btn.text = "Passer"
	_skip_btn.custom_minimum_size = Vector2(80.0, 34.0)
	UITheme.style_button(_skip_btn, UITheme.BORDER_SOFT, UITheme.INK_MUTED, false, true)
	_skip_btn.pressed.connect(func() -> void: _go_to(_current_step + 1))
	nav.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.text = "Suivant →"
	_next_btn.custom_minimum_size = Vector2(130.0, 34.0)
	UITheme.style_button(_next_btn, UITheme.ACCENT_GOLD, UITheme.INK_DARK, false, true)
	nav.add_child(_next_btn)

# ─────────────────────────────────────────────────────────────────────────────
func _close() -> void:
	SaveSystem.tutorial_mode = false
	if _hud:
		for key in _hud_groups:
			var node: Node = _hud_groups[key]
			if node and node is CanvasItem:
				(node as CanvasItem).show()
		for node in _extra_speed_nodes:
			if node and node is CanvasItem:
				(node as CanvasItem).show()

	_clear_highlight()

	if _delivery_manager:
		if _delivery_manager.has_signal("order_submitted") and _delivery_manager.order_submitted.is_connected(_on_order_submitted):
			_delivery_manager.order_submitted.disconnect(_on_order_submitted)
		if _delivery_manager.has_signal("delivery_completed") and _delivery_manager.delivery_completed.is_connected(_on_delivery_completed):
			_delivery_manager.delivery_completed.disconnect(_on_delivery_completed)
	tutorial_closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_action_pressed("build_menu"):
		_build_menu_was_opened = true
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
