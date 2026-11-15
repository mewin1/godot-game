class_name RitualBuildChip
extends Control
## Карточка каталога в нижнем доке забега (docs/37 UI-3): полоса цвета стихии, дом на всю
## карточку (иконка запечена из той же модели, что стоит на карте, — tools/ritual_house_icons.gd),
## цена бейджем, имя внизу в одну-две строки. Числа и правила — у RitualTrial.

signal chosen(index: int)
signal hovered(index: int)
signal cancelled()

## Крупная карточка вкладки тира (просьба автора 13 ноября: иконки крупнее, на весь отсек).
const CHIP_SIZE: Vector2 = Vector2(96, 104)
const TIER_NAMES: Array[String] = ["I", "II", "III"]
const TIER_COLORS: Array[Color] = [Color("b9814f"), Color("b8c3cc"), Color("f0c869")]
const NIGHT_PRICE: Color = Color("ffe066")
const NIGHT_ARROW: Color = Color("ff6258")
const PRICE_COLOR: Color = Color("ffe2a8")
const NAME_COLOR: Color = Color("f1e6cf")
## Иконки домов «Городища» по id постройки; нет файла — прежняя картинка машины (VisualCatalog).
const HOUSE_ICONS: String = "res://assets/ritual/town/icons/%s.png"
const NAME_SIZE: int = 14
const PRICE_SIZE: int = 15

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
	var lines: PackedStringArray = _name_lines(font, size.x - 8.0)
	var text_height: float = NAME_SIZE * 1.15 * lines.size() + 6.0
	var art: Rect2 = Rect2(3, 7, size.x - 6, size.y - 9)
	if _icon != null:
		# Дом крупно: картинка по пропорции поля, чуть выше середины (без пустого неба).
		var source: Vector2 = Vector2(_icon.get_size())
		var fit: float = minf(source.x / art.size.x, source.y / art.size.y) * 0.86
		var crop: Vector2 = art.size * fit
		var region: Rect2 = Rect2(Vector2((source.x - crop.x) * 0.5, (source.y - crop.y) * 0.2), crop)
		draw_texture_rect_region(_icon, art, region)
	# Затемнение снизу под имя — читается на любой крыше.
	var shade_top: float = size.y - text_height - 14.0
	draw_polygon(PackedVector2Array([Vector2(2, shade_top), Vector2(size.x - 2, shade_top),
			Vector2(size.x - 2, size.y - 2), Vector2(2, size.y - 2)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.03, 0.05, 0.92),
			Color(0.02, 0.03, 0.05, 0.92)]))
	var color: Color = GodSymbols.get_color(data.god)
	draw_rect(Rect2(4, 2, size.x - 8, 4), color)
	var symbol: Texture2D = GodSymbols.get_icon(data.god)
	if symbol != null:
		draw_rect(Rect2(Vector2(5, 9), Vector2(20, 20)), Color(0.02, 0.04, 0.06, 0.75))
		draw_texture_rect(symbol, Rect2(Vector2(6, 10), Vector2(18, 18)), false)
	for row: int in lines.size():
		var baseline: float = size.y - 6.0 - (lines.size() - 1 - row) * NAME_SIZE * 1.15
		draw_string(font, Vector2(4, baseline), lines[row], HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, NAME_SIZE,
				NAME_COLOR)
	if locked_text.is_empty():
		# Цена — бейджем в правом верхнем углу; ночью жёлтая со стрелкой (наценка).
		var label: String = "◉ %d%s" % [price, "↑" if at_night else ""]
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
		var badge: Rect2 = Rect2(size.x - width - 12.0, 9.0, width + 8.0, PRICE_SIZE + 5.0)
		draw_rect(badge, Color(0.02, 0.04, 0.06, 0.82))
		draw_string(font, badge.position + Vector2(4, PRICE_SIZE + 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				PRICE_SIZE, NIGHT_PRICE if at_night else PRICE_COLOR)
	if not locked_text.is_empty():
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(4, size.y * 0.45), "🔒 " + locked_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8,
				NAME_SIZE, Color(0.85, 0.85, 0.85, 0.9))
	elif not affordable:
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.38))


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
