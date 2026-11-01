class_name DuskTheme
extends RefCounted
## Общие панели сумеречной заставы; не меняет данные и размеры игровых механик.

const INK: Color = Color("0b141e")
const GOLD: Color = Color("b7955d")
const TEXT: Color = Color("eee3cd")
const MUTED: Color = Color("a8b5c5")


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
		result.set_stylebox(&"panel", type, panel(INK, GOLD.darkened(0.48), 8))
	result.set_stylebox(&"panel", &"CardPanelActive", panel(INK.lightened(0.04), GOLD, 8))
	result.set_stylebox(&"normal", &"Button", panel(INK.lightened(0.025), GOLD.darkened(0.5)))
	result.set_stylebox(&"hover", &"Button", panel(Color("1d303d"), GOLD))
	result.set_stylebox(&"pressed", &"Button", panel(Color("263a43"), TEXT))
	result.set_stylebox(&"disabled", &"Button", panel(Color("101821"), Color("34404a")))
	result.set_stylebox(&"normal", &"AccentButton", panel(Color("3a2a17"), GOLD))
	result.set_stylebox(&"hover", &"AccentButton", panel(Color("574022"), GOLD.lightened(0.2)))
	result.set_stylebox(&"pressed", &"AccentButton", panel(Color("291e12"), GOLD))
	result.set_stylebox(&"panel", &"TooltipPanel", panel(Color("071019"), GOLD, 12))
	result.set_color(&"font_color", &"TooltipLabel", TEXT)
	return result


## Панель с тонкой латунной кромкой вместо тяжёлой объёмной рамки.
static func panel(background: Color = INK, border: Color = GOLD,
		margin: int = 7) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	return style
