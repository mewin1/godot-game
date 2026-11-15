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
## Шрифты (выбор автора 15 ноября, OFL, assets/fonts/README.md): Fira Sans — подписи, полужирный —
## числа; Kurale — заголовки (HeaderLabel): «летопись» поверх современного интерфейса.
const BODY_FONT: FontFile = preload("res://assets/fonts/fira_sans/FiraSans-Regular.ttf")
const NUMBER_FONT: FontFile = preload("res://assets/fonts/fira_sans/FiraSans-SemiBold.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/kurale/Kurale-Regular.ttf")
## Одна монета на весь интерфейс (critique_3 п. 49): та же, что у золота в доке; кружок-мишень читался как «цель».
const COIN: Texture2D = preload("res://assets/ui/icon_gold.svg")


## Цена с монетой в своём _draw: монета высотой с кегль, число справа. Возвращает ширину.
static func draw_price(canvas: CanvasItem, font: Font, left_baseline: Vector2, amount: String, font_size: int,
		color: Color) -> float:
	var coin: float = font_size * 0.95
	canvas.draw_texture_rect(COIN, Rect2(left_baseline + Vector2(0, -coin * 0.86), Vector2(coin, coin)), false,
			Color(1, 1, 1, color.a))
	canvas.draw_string(font, left_baseline + Vector2(coin + 3, 0), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			color)
	return coin + 3 + font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func price_width(font: Font, amount: String, font_size: int) -> float:
	return font_size * 0.95 + 3 + font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Копия базовой темы: прежние экраны и авторский ресурс остаются самостоятельными.
static func create() -> Theme:
	var base: Theme = load("res://data/ui/ui_theme.tres") as Theme
	var result: Theme = base.duplicate(true) as Theme
	# 18 логических — 14 px на 1280x720 (critique_3 п. 4, SCN-12).
	result.default_font_size = 18
	result.default_font = BODY_FONT
	result.set_font(&"font", &"HeaderLabel", TITLE_FONT)
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


## Окно забега (critique_3 п. 68-74): одна плашка для выбора героя, дара, поражения, легенды и идола —
## тёмное стекло с янтарной кромкой и тенью; заголовок — HeaderLabel (Kurale).
static func modal(margin: int = 22) -> StyleBoxFlat:
	var style: StyleBoxFlat = glass(0.94, margin)
	style.border_color = Color(GOLD, 0.55)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	return style


## Заголовок окна: Kurale, янтарь, с тенью.
static func modal_title(text: String, font_size: int = 30) -> Label:
	var title: Label = Label.new()
	title.text = text
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color("f0d39c"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return title


## Главная кнопка окна — янтарём (AccentButton); снимает общие переопределения кнопок панели.
static func make_primary(button: Button) -> Button:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		button.remove_theme_stylebox_override(state)
	button.theme_type_variation = &"AccentButton"
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 40)
	return button


## Второстепенная кнопка окна — текстом без рамки.
static func make_quiet(button: Button) -> Button:
	button.flat = true
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", TEXT)
	return button


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
