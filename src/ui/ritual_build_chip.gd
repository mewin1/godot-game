class_name RitualBuildChip
extends Control
## Карточка каталога в нижнем доке забега (docs/37 UI-3): полоса цвета стихии, дом на всю
## карточку (иконка запечена из той же модели, что стоит на карте, — tools/ritual_house_icons.gd),
## цена бейджем, имя внизу в одну-две строки. Числа и правила — у RitualTrial.

signal chosen(index: int)
signal hovered(index: int)
signal cancelled()

## Крупная карточка вкладки тира (просьба автора 13 ноября: иконки крупнее, на весь отсек).
const CHIP_SIZE: Vector2 = Vector2(98, 124)
## Верхний ярус (значок бога, цена) и полоса имени снизу.
const TOP_BAND: float = 26.0
const NAME_STRIP: float = 40.0
const TIER_NAMES: Array[String] = ["I", "II", "III"]
const TIER_COLORS: Array[Color] = [Color("b9814f"), Color("b8c3cc"), Color("f0c869")]
const NIGHT_PRICE: Color = Color("ffa04a")
const NIGHT_ARROW: Color = Color("ff6258")
const PRICE_COLOR: Color = Color("ffe2a8")
const NAME_COLOR: Color = Color("f1e6cf")
## Иконки домов «Городища» по id постройки; нет файла — прежняя картинка машины (VisualCatalog).
const HOUSE_ICONS: String = "res://assets/ritual/town/icons/%s.png"
const NAME_SIZE: int = 18
const PRICE_SIZE: int = 18

var index: int = 0
var data: TowerData
var price: int = 0
var affordable: bool = true
var locked_text: String = ""
var at_night: bool = false
var is_chosen: bool = false
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _chosen: StyleBoxFlat
var _icon: Texture2D


func _init() -> void:
	custom_minimum_size = CHIP_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# В покое без рамки (critique.md п. 20): рамка — только при наведении и выборе.
	_normal = DuskTheme.panel(Color(0.05, 0.09, 0.14, 0.86), Color(0.0, 0.0, 0.0, 0.0), 6)
	_hover = DuskTheme.panel(Color(0.1, 0.18, 0.27, 0.95), DuskTheme.GOLD, 6)
	_chosen = DuskTheme.panel(Color(0.16, 0.14, 0.08, 0.95), Color("f0c869"), 6)
	_chosen.set_border_width_all(3)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func setup(catalogue_index: int, tower: TowerData) -> void:
	index = catalogue_index
	data = tower
	name = "CatalogueChip_%s" % tower.id
	var house: String = HOUSE_ICONS % tower.id
	_icon = load(house) as Texture2D if ResourceLoader.exists(house) \
			else VisualCatalog.get_default().get_tower(tower.id).icon


func _on_enter() -> void:
	hovered.emit(index)
	queue_redraw()


func _on_exit() -> void:
	hovered.emit(-1)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(index)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		cancelled.emit()
		accept_event()


func _draw() -> void:
	if data == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var hovered_now: bool = rect.has_point(get_local_mouse_position())
	draw_style_box(_chosen if is_chosen else _hover if hovered_now else _normal, rect)
	var font: Font = get_theme_default_font()
	var number_font: Font = DuskTheme.NUMBER_FONT
	# Три яруса (critique_3 п. 58, 60, 4): сверху значок бога и цена, в середине дом с машиной на
	# коньке (ничем не закрыта), снизу имя на сплошной полосе. Кегли не мельче 18 (14 px на 1280x720).
	var strip_top: float = size.y - NAME_STRIP
	var art: Rect2 = Rect2(3, TOP_BAND, size.x - 6, strip_top - TOP_BAND)
	if _icon != null:
		var source: Vector2 = Vector2(_icon.get_size())
		var fit: float = minf(source.x / art.size.x, source.y / art.size.y) * 0.92
		var crop: Vector2 = art.size * fit
		var region: Rect2 = Rect2(Vector2((source.x - crop.x) * 0.5, (source.y - crop.y) * 0.32), crop)
		draw_texture_rect_region(_icon, art, region)
	draw_rect(Rect2(2, strip_top, size.x - 4, NAME_STRIP - 2), Color(0.02, 0.03, 0.05, 0.92))
	var color: Color = GodSymbols.get_color(data.god)
	draw_rect(Rect2(4, 2, size.x - 8, 4), color)
	var symbol: Texture2D = GodSymbols.get_icon(data.god)
	if symbol != null:
		draw_texture_rect(symbol, Rect2(Vector2(5, 7), Vector2(20, 20)), false)
	var lines: PackedStringArray = _name_lines(font, size.x - 6.0)
	var line_height: float = NAME_SIZE * 1.05
	var first: float = strip_top + (NAME_STRIP - line_height * lines.size()) * 0.5 + NAME_SIZE * 0.8
	for row: int in lines.size():
		draw_string(font, Vector2(3, first + row * line_height), lines[row], HORIZONTAL_ALIGNMENT_CENTER,
				size.x - 6, NAME_SIZE, NAME_COLOR)
	if locked_text.is_empty():
		# Цена — справа в верхнем ярусе, над небом иконки. Ночью оранжевая с луной (наценка —
		# в подсказке): стрелка «↑» путалась со стрелкой улучшения (critique_3 п. 62).
		var amount: String = str(price)
		var width: float = DuskTheme.price_width(number_font, amount, PRICE_SIZE)
		var left: float = size.x - width - 5.0
		if at_night:
			left -= 12.0
			_draw_moon(Vector2(size.x - 10.0, 15.0))
		DuskTheme.draw_price(self, number_font, Vector2(left, 6.0 + PRICE_SIZE * 0.9), amount, PRICE_SIZE,
				NIGHT_PRICE if at_night else PRICE_COLOR)
	if not locked_text.is_empty():
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(3, size.y * 0.42), "🔒 " + locked_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6,
				NAME_SIZE, Color(0.85, 0.85, 0.85, 0.9))
	elif not affordable:
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.38))


## Серп луны — знак ночной цены.
func _draw_moon(center: Vector2) -> void:
	draw_circle(center, 5.5, NIGHT_PRICE)
	draw_circle(center + Vector2(2.6, -1.6), 4.6, Color(0.05, 0.09, 0.14))


## Имя в одну строку, а длинное — в две по пробелу; не влезает и так — многоточие
## (было: «Жаровня Свар» обрезалось без знака).
func _name_lines(font: Font, width: float) -> PackedStringArray:
	var title: String = data.display_name
	if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x <= width:
		return PackedStringArray([title])
	var space: int = title.find(" ")
	if space < 0:
		return PackedStringArray([_ellipsis(font, title, width)])
	return PackedStringArray([_ellipsis(font, title.substr(0, space), width),
			_ellipsis(font, title.substr(space + 1), width)])


static func _ellipsis(font: Font, text: String, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x <= width:
		return text
	var cut: String = text
	while cut.length() > 1 and font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x > width:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "…"


## Своя подсказка карточки (critique_3 п. 72): имя крупно (Kurale), ниже роль и строки подсказки.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var lines: PackedStringArray = for_text.split("\n")
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title: Label = Label.new()
	title.text = data.display_name if data != null else lines[0]
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GodSymbols.get_color(data.god) if data != null else DuskTheme.GOLD)
	box.add_child(title)
	for row: int in range(1, lines.size()):
		var line: Label = Label.new()
		line.text = lines[row]
		line.add_theme_font_size_override("font_size", 18 if row == 1 else 17)
		line.add_theme_color_override("font_color", DuskTheme.TEXT if row == 1 else DuskTheme.MUTED)
		box.add_child(line)
	return box
