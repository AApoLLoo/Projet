class_name UITheme
extends RefCounted

const INK_DARK := Color("#10202D")
const INK_MUTED := Color("#5F7286")
const SURFACE := Color("#F5F1EA")
const SURFACE_SOFT := Color("#FFF9F1")
const SURFACE_DARK := Color("#1A2B38")
const SURFACE_GLASS := Color(0.97, 0.95, 0.90, 0.82)
const BORDER_SOFT := Color("#CFD7DC")
const BORDER_STRONG := Color("#2A4E64")
const ACCENT_TEAL := Color("#4FA39A")
const ACCENT_GOLD := Color("#D8A454")
const ACCENT_RED := Color("#C86B57")
const ACCENT_SKY := Color("#6E95C4")
const TEXT_LIGHT := Color("#F7FAFC")

static func style_screen(root: Control) -> void:
	if root == null:
		return
	root.add_theme_color_override("font_color", INK_DARK)
	root.add_theme_color_override("font_disabled_color", INK_MUTED)
	root.add_theme_constant_override("outline_size", 0)

static func style_card(panel: PanelContainer, dark: bool = false, translucent: bool = false, alpha: float = -1.0) -> void:
	if panel == null:
		return
	var fill: Color = SURFACE_DARK if dark else SURFACE
	var border: Color = BORDER_STRONG if dark else BORDER_SOFT
	if translucent:
		var resolved_alpha: float = alpha if alpha >= 0.0 else 0.88
		fill = Color(fill.r, fill.g, fill.b, resolved_alpha)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.14)
	style.shadow_size = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 14.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

static func style_button(button: BaseButton, fill_color: Color = ACCENT_TEAL, text_color: Color = INK_DARK, outlined: bool = false, compact: bool = false) -> void:
	if button == null:
		return
	var normal_fill: Color = fill_color if not outlined else Color(fill_color.r, fill_color.g, fill_color.b, 0.16)
	var hover_fill: Color = fill_color.lightened(0.08) if not outlined else Color(fill_color.r, fill_color.g, fill_color.b, 0.22)
	var pressed_fill: Color = fill_color.darkened(0.1) if not outlined else Color(fill_color.r, fill_color.g, fill_color.b, 0.3)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_fill, fill_color, compact))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_fill, fill_color.darkened(0.1), compact))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_fill, fill_color.darkened(0.18), compact))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_fill, fill_color, compact))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", 18 if compact else 20)
	button.focus_mode = Control.FOCUS_NONE

static func style_label(label: Label, role: String = "body", light_text: bool = false) -> void:
	if label == null:
		return
	var color: Color = TEXT_LIGHT if light_text else INK_DARK
	var size: int = 16
	match role:
		"hero":
			size = 52
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.18))
			label.add_theme_constant_override("shadow_outline_size", 4)
		"title":
			size = 30
		"section":
			size = 22
		"caption":
			size = 13
			color = Color("#7C8A97") if not light_text else Color("#D6E2EA")
		"metric":
			size = 24
		"small":
			size = 14
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

static func style_option_button(option_button: OptionButton, fill_color: Color = SURFACE_SOFT) -> void:
	if option_button == null:
		return
	option_button.add_theme_stylebox_override("normal", _make_button_style(fill_color, BORDER_SOFT, true))
	option_button.add_theme_stylebox_override("hover", _make_button_style(fill_color.lightened(0.03), BORDER_STRONG, true))
	option_button.add_theme_stylebox_override("pressed", _make_button_style(fill_color.darkened(0.03), BORDER_STRONG, true))
	option_button.add_theme_color_override("font_color", INK_DARK)
	option_button.add_theme_font_size_override("font_size", 17)

static func style_slider(slider: HSlider, accent: Color = ACCENT_TEAL) -> void:
	if slider == null:
		return
	var groove: StyleBoxFlat = StyleBoxFlat.new()
	groove.bg_color = Color("#DCE4E8")
	groove.corner_radius_top_left = 6
	groove.corner_radius_top_right = 6
	groove.corner_radius_bottom_left = 6
	groove.corner_radius_bottom_right = 6
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = SURFACE_SOFT
	grabber.border_color = accent.darkened(0.14)
	grabber.border_width_left = 2
	grabber.border_width_top = 2
	grabber.border_width_right = 2
	grabber.border_width_bottom = 2
	grabber.corner_radius_top_left = 9
	grabber.corner_radius_top_right = 9
	grabber.corner_radius_bottom_left = 9
	grabber.corner_radius_bottom_right = 9
	grabber.expand_margin_left = 9
	grabber.expand_margin_top = 9
	grabber.expand_margin_right = 9
	grabber.expand_margin_bottom = 9
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber)

static func style_item_list(item_list: ItemList) -> void:
	if item_list == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SURFACE_SOFT
	style.border_color = BORDER_SOFT
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	item_list.add_theme_stylebox_override("panel", style)
	item_list.add_theme_color_override("font_color", INK_DARK)
	item_list.add_theme_color_override("font_selected_color", INK_DARK)
	item_list.add_theme_color_override("guide_color", BORDER_SOFT)
	item_list.add_theme_color_override("selection_fill", Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.32))

static func style_spin_box(spin_box: SpinBox) -> void:
	if spin_box == null:
		return
	spin_box.add_theme_stylebox_override("normal", _make_button_style(SURFACE_SOFT, BORDER_SOFT, true))
	spin_box.add_theme_stylebox_override("focus", _make_button_style(SURFACE_SOFT, BORDER_STRONG, true))
	spin_box.add_theme_color_override("font_color", INK_DARK)
	spin_box.add_theme_font_size_override("font_size", 17)

static func style_toggle(button: BaseButton, accent: Color = ACCENT_TEAL) -> void:
	style_button(button, accent, INK_DARK, true, true)

static func style_dialog(dialog: Window) -> void:
	if dialog == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BORDER_STRONG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 12
	dialog.add_theme_stylebox_override("panel", style)
	dialog.add_theme_font_size_override("title_font_size", 20)

static func _make_button_style(fill_color: Color, border_color: Color, compact: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.08)
	style.shadow_size = 4
	style.content_margin_left = 10.0 if compact else 16.0
	style.content_margin_right = 10.0 if compact else 16.0
	style.content_margin_top = 5.0 if compact else 10.0
	style.content_margin_bottom = 5.0 if compact else 10.0
	return style