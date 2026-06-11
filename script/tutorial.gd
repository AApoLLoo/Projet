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
			"Ton objectif est de produire, transformer et vendre des ressources afin de développer une industrie rentable.\n\n" +
			"Tu démarres avec [b]3 000 €[/b]. Gère bien ton budget !",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["day_time","resources"],
		"highlight": "",
	},
	{
		"tag": "Étape 1 — Construction",
		"title": "Ouvre le menu Construction",
		"body":
			"Le bouton [b]Construction[/b] vient d'apparaître en haut.\n\n" +
			"Clique dessus (ou appuie sur [b]B[/b]) pour voir tous les bâtiments disponibles.",
		"objective": "Ouvrir le menu Construction",
		"check": "build_menu_opened",
		"skip": false,
		"reveals": ["speed_btns", "day_time","resources", "build_btn"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 2 — Extraction",
		"title": "Pose un Extracteur (300 €)",
		"body":
			"L'Extracteur récupère des ressources directement dans le sol.\n\n" +
			"Construction → Extraction → place-le sur la carte.\n\n" +
			"Clique ensuite dessus pour choisir la ressource à produire.\n\n",
		"objective": "Poser au moins 1 Extracteur",
		"check": "has_miner",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 3 — Énergie",
		"title": "Pose une Turbine (500 €)",
		"body":
			"Les turbines produisent l'électricité nécessaire à ton usine.\n\n" +
			"Construction → Énergie → place une turbine.\n\n"+
			"Le bouton 'zone électricité' sert à voir quelles machines la turbine alimente\n\n"+
			"💡 Une turbine suffit pour démarrer ton activité.",
		"objective": "Poser au moins 1 Turbine",
		"check": "has_turbine",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 4 — Production",
		"title": "Pose une Usine (200 €)",
		"body":
			"L'Usine transforme les ressources en produits vendables.\n\n" +
			"Construction → Production → place-la sur la grille.\n\n" +
			"Clique sur l'usine après placement pour sélectionner une recette.",
		"objective": "Poser au moins 1 Usine",
		"check": "has_factory",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 5 — Convoyeurs",
		"title": "Relie tes bâtiments",
		"body":
			"Les convoyeurs transportent automatiquement les ressources.\n\n" +
			"Relie ton Extracteur à ton Usine avec quelques tapis.\n\n" +
			"💡 Les ressources avancent automatiquement d'un bâtiment à l'autre.",
		"objective": "Placer au moins 3 tapis",
		"check": "has_belts_3",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn","resources", "build_menu"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 6 — Utilisation des Batiments",
		"title": "Surveille la santé de tes bâtiments",
		"body":
			"Toutes les machines actives consomment une partie de leur santé.\n\n" +
			"Si elles sont fonctionnent pendant trop longtemps, elle cassent.\n\n" +
			"Tu peux commander un kit de reparation (voir plus tard), ou simplement remplacer la machine cassée.\n\n"+
			"Appuie sur le bouton 'mode destruction' pour supprimer un ou plusieurs bâtiments.",

		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu"],
		"highlight": "resources",
	},

	{
		"tag": "Étape 7 — Environnement",
		"title": "Les arbres réduisent le CO₂",
		"body":
			"Plus le nombre de machines actives est élevé, plus ton impact carbone est fort.\n\n" +
			"Attention, il y a une limite à ne pas dépasser !.\n\n" +
			"Mais les arbres absorbent une partie de la pollution générée par ton usine.\n\n" +
			"Chaque arbre réduit le CO₂ produit par tes bâtiments.\n\n" +
			"💡 Plus ton usine devient grande, plus les arbres deviennent utiles.",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu","co2"],
		"highlight": "resources",
	},

	{
		"tag": "Étape 8 — Entrepôt",
		"title": "Pose un Entrepôt (1 000 €)",
		"body":
			"L'Entrepôt sert à stocker les ressources et les produits.\n\n" +
			"Il est nécessaire pour les opérations d'import et d'export.\n\n" +
			"💡 Clique sur un entrepôt pour consulter son stock.",
		"objective": "Poser au moins 1 Entrepôt",
		"check": "has_entrepot",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources","build_menu", "co2"],
		"highlight": "build_btn",
	},

	{
		"tag": "Étape 9 — Import",
		"title": "Importer des ressources",
		"body":
			"Tu peux acheter des ressources directement depuis le menu Commandes.\n\n" +
			"Onglet Import → choisis une ressource → indique une quantité → commande.\n\n" +
			"Le camion livrera automatiquement les marchandises.",
		"objective": "Lancer une commande d'import",
		"check": "has_imported",
		"skip": false,
		"reveals": ["speed_btns", "day_time", "build_btn",  "minimap","resources", "orders_btn", "co2"],
		"highlight": "orders_btn",
	},

	{
		"tag": "Étape 10 — Contrats",
		"title": "Remplis des contrats",
		"body":
			"Des contrats apparaissent régulièrement.\n\n" +
			"Produis et exporte (dans logistique) les marchandises demandées avant la date limite.\n\n" +
			"Les contrats rapportent des bonus importants et accélèrent ta progression.\n\n"+
			"Mais attention ! Si tu ne les remplis pas dans les temps, tu auras une pénalité et tu perdras de l'argent...",

		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "resources", "minimap", "orders_btn", "co2", "contracts"],
		"highlight": "",
	},

	{
		"tag": "Étape 11 — Objectif final",
		"title": "Développe ton empire industriel",
		"body":
			"Ton objectif est de construire une usine toujours plus rentable.\n\n" +
			"Produis, transforme, exporte et remplis des contrats pour gagner de l'argent.\n\n" +
			"🏆 [b]Victoire[/b] : atteindre 1 000 000 €\n" +
			"💀 [b]Défaite[/b] : ne plus avoir assez d'argent pour continuer.\n\n" +
			"Bonne chance !",
		"objective": "",
		"check": "",
		"skip": true,
		"reveals": ["speed_btns", "day_time", "build_btn", "orders_btn", "overview_btn", "minimap", "resources", "co2", "build_menu", "contracts"],
		"highlight": "",
	},

	{
	"tag": "Terminé !",
	"title": "Tu es prêt à jouer 🎉",
	"body":
		"Tu maîtrises maintenant les bases :\n\n" +
		"✓ Extraire\n" +
		"✓ Produire\n" +
		"✓ Transporter\n" +
		"✓ Gérer l'énergie\n" +
		"✓ Importer et exporter\n" +
		"✓ Réduire le CO₂ grâce aux arbres\n\n" +
		"[b]Maintenant commence une partie de zéro pour voir si tu as compris ![/b]",  # ← remplace la fin
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

# ── État ──────────────────────────────────────────────────────────────────────
var _current_step: int = 0
var _next_callable: Callable = Callable()
var _import_submitted: bool = false
var _export_submitted: bool = false
var _build_menu_was_opened: bool = false
var _building_manager: Node = null
var _delivery_manager: Node = null
var _drag_active: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

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
	
	# Réinitialiser les ressources pour le tuto
	var gm = _get_autoload("GameManager")
	if gm:
		gm.credits = 3000.0
		gm.resources_updated.emit()
	
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

	var contracts_banner := _hud.get_node_or_null(
	    "MarginContainer/MarginContainer/VBoxContainer/ContractsLabel"
	)

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
			"contracts":       _hud.get_node_or_null("MarginContainer/MarginContainer/VBoxContainer/ContractsLabel"),

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



# ─────────────────────────────────────────────────────────────────────────────




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
	
	if step.get("highlight", "") == "minimap":
		# panneau à gauche
		_panel.anchor_left = 0.0
		_panel.anchor_right = 0.0
		_panel.offset_left = 20.0
		_panel.offset_right = 400.0
	else:
		# panneau à droite (comportement normal)
		_panel.anchor_left = 1.0
		_panel.anchor_right = 1.0
		_panel.offset_left = -400.0
		_panel.offset_right = -20.0
	while _next_btn.pressed.get_connections().size() > 0:
		var c = _next_btn.pressed.get_connections()[0]
		_next_btn.pressed.disconnect(c["callable"])

	if is_last:
		_next_btn.text = "Recommencer !"
		_next_callable = Callable(self, "_finish")
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
	_panel.offset_top = -480.0   # ← remonte moins haut = plus bas sur l'écran
	_panel.offset_bottom = -38.0  # ← colle plus au bord bas
	_panel.custom_minimum_size = Vector2(380.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE 
	UITheme.style_card(_panel, false, true, 0.96)
	add_child(_panel)
	_panel.gui_input.connect(_on_panel_gui_input) 

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

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_active = true
				# offset entre le coin haut-gauche du panel et la souris
				_drag_offset = _panel.global_position - get_viewport().get_mouse_position()
			else:
				_drag_active = false

	elif event is InputEventMouseMotion and _drag_active:
		var new_pos: Vector2 = get_viewport().get_mouse_position() + _drag_offset
		# Repositionner en mode offset absolu (désactiver les anchors dynamiques)
		_panel.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, vp_size.x - _panel.size.x)
		new_pos.y = clamp(new_pos.y, 0.0, vp_size.y - _panel.size.y)
		_panel.set_position(new_pos)
		
func _finish() -> void:
	SaveSystem.tutorial_mode = false  # ← false, pas true
	get_tree().change_scene_to_file("res://scene/level.tscn")
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
