class_name RitualBuildChip
extends Control
## Карточка каталога в нижнем доке забега (docs/37 UI-3): полоса цвета стихии, картинка,
## имя, цена и тир. Весь каталог виден сразу — 7 богов × 3 тира. Числа и правила — у RitualTrial.

signal chosen(index: int)
signal hovered(index: int)
signal cancelled()

## Крупная карточка вкладки тира (просьба автора 13 ноября: иконки крупнее, на весь отсек).
const CHIP_SIZE: Vector2 = Vector2(96, 112)
const TIER_NAMES: Array[String] = ["I", "II", "III"]
const TIER_COLORS: Array[Color] = [Color("b9814f"), Color("b8c3cc"), Color("f0c869")]
const NIGHT_PRICE: Color = Color("ffe066")
const NIGHT_ARROW: Color = Color("ff6258")
const PRICE_COLOR: Color = Color("ffe2a8")
const NAME_COLOR: Color = Color("f1e6cf")

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
	_normal = DuskTheme.panel(Color(0.05, 0.09, 0.14, 0.86), Color(0.62, 0.74, 0.9, 0.2), 6)
	_hover = DuskTheme.panel(Color(0.1, 0.18, 0.27, 0.95), DuskTheme.GOLD, 6)
	_chosen = DuskTheme.panel(Color(0.16, 0.14, 0.08, 0.95), Color("f0c869"), 6)
	_chosen.set_border_width_all(3)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func setup(catalogue_index: int, tower: TowerData) -> void:
	index = catalogue_index
	data = tower
	name = "CatalogueChip_%s" % tower.id
	_icon = VisualCatalog.get_default().get_tower(tower.id).icon


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
	var color: Color = GodSymbols.get_color(data.god)
	draw_rect(Rect2(4, 2, size.x - 8, 4), color)
	var font: Font = get_theme_default_font()
	var art: Rect2 = Rect2(6, 9, size.x - 12, size.y - 44)
	if _icon != null:
		# Середина картинки по пропорции поля: постройка крупно, без пустого неба.
		var source: Vector2 = Vector2(_icon.get_size())
		var scale: float = minf(source.x / art.size.x, source.y / art.size.y)
		var crop: Vector2 = art.size * scale
		var region: Rect2 = Rect2(Vector2((source.x - crop.x) * 0.5, (source.y - crop.y) * 0.55), crop)
		draw_texture_rect_region(_icon, art, region)
	var symbol: Texture2D = GodSymbols.get_icon(data.god)
	if symbol != null:
		draw_rect(Rect2(art.position + Vector2(2, 2), Vector2(20, 20)), Color(0.02, 0.04, 0.06, 0.75))
		draw_texture_rect(symbol, Rect2(art.position + Vector2(3, 3), Vector2(18, 18)), false)
	draw_string(font, Vector2(6, size.y - 22), data.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 12,
		NAME_COLOR)
	if locked_text.is_empty():
		var label: String = "◉ %d" % price
		var price_color: Color = NIGHT_PRICE if at_night else PRICE_COLOR
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var x: float = (size.x - width - (12.0 if at_night else 0.0)) * 0.5
		draw_string(font, Vector2(x, size.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, price_color)
		if at_night:
			draw_string(font, Vector2(x + width + 2, size.y - 6), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, NIGHT_ARROW)
	if not locked_text.is_empty():
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(6, size.y - 6), "🔒 " + locked_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 12,
			Color(0.85, 0.85, 0.85, 0.9))
	elif not affordable:
		draw_rect(rect.grow(-1), Color(0, 0, 0, 0.38))
