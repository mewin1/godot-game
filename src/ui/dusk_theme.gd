class_name DuskTheme
extends RefCounted
## Общие панели сумеречной заставы; не меняет данные и размеры игровых механик.

const INK: Color = Color("0e1215")
## Янтарный акцент интерфейса «нуар» (new_concept/06_battle_ui.jpg).
const GOLD: Color = Color("dca253")
const TEXT: Color = Color("eee3cd")
const MUTED: Color = Color("a9b1b5")
## Дымчатое стекло: почти чёрное с лёгкой бирюзой.
const GLASS: Color = Color("0a0f12")
const GLASS_EDGE: Color = Color(1.0, 0.96, 0.9, 0.14)
## Цена, на которую не хватает золота.
const SHORT: Color = Color("ff8a72")


## Копия базовой темы: прежние экраны и авторский ресурс остаются самостоятельными.
static func create() -> Theme:
	var base: Theme = load("res://data/ui/ui_theme.tres") as Theme
	var result: Theme = base.duplicate(true) as Theme
	result.default_font_size = 17
	for type: StringName in [&"Label", &"Button", &"RichTextLabel"]:
		result.set_color(&"font_color", type, TEXT)
	result.set_color(&"font_disabled_color", &"Button", Color("76818d"))
	result.set_color(&"font_hover_color", &"Button", Color("fff0cf"))
	for type: StringName in [&"PanelContainer", &"HudPanel", &"CardPanel"]:
		result.set_stylebox(&"panel", type, panel(Color(INK, 0.84), GLASS_EDGE, 8))
	result.set_stylebox(&"panel", &"CardPanelActive", panel(Color(INK.lightened(0.05), 0.9), GOLD, 8))
	result.set_stylebox(&"normal", &"Button", panel(Color("161b1f", 0.88), GLASS_EDGE))
	result.set_stylebox(&"hover", &"Button", panel(Color("20272b", 0.92), GOLD))
	result.set_stylebox(&"pressed", &"Button", panel(Color("2b2217"), GOLD.lightened(0.15)))
	result.set_stylebox(&"disabled", &"Button", panel(Color("101417", 0.8), Color(1, 1, 1, 0.06)))
	# янтарная кнопка действия (как «Варево · Q» на концепте): заливка янтарём, тёмный текст
	result.set_stylebox(&"normal", &"AccentButton", panel(GOLD.darkened(0.08), GOLD.lightened(0.25)))
	result.set_stylebox(&"hover", &"AccentButton", panel(GOLD.lightened(0.1), Color("ffe2ad")))
	result.set_stylebox(&"pressed", &"AccentButton", panel(GOLD.darkened(0.25), GOLD))
	result.set_color(&"font_color", &"AccentButton", Color("1d1307"))
	result.set_color(&"font_hover_color", &"AccentButton", Color("120b03"))
	result.set_color(&"font_pressed_color", &"AccentButton", Color("120b03"))
	result.set_stylebox(&"panel", &"TooltipPanel", panel(Color(GLASS, 0.94), GLASS_EDGE.lightened(0.2), 12))
	result.set_color(&"font_color", &"TooltipLabel", TEXT)
	return result


## «Стеклянная» панель поверх 3D-сцены: дымчатая почти чёрная, тонкая светлая кромка, тень.
static func glass(alpha: float = 0.66, margin: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(GLASS, alpha)
	style.border_color = GLASS_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	return style


## Панель с тонкой латунной кромкой вместо тяжёлой объёмной рамки.
static func panel(background: Color = INK, border: Color = GOLD,
		margin: int = 7) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	return style
