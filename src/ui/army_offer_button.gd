class_name ArmyOfferButton
extends Button
## Покупка улучшения армии. Изображению, имени и цене отведено отдельное место.

const COIN: Texture2D = preload("res://assets/ui/icon_gold.svg")
const PRICE_HEIGHT: float = 21.0
const CONTENT_MARGIN: float = 4.0

var _name_label: Label = Label.new()
var _portrait: Texture2D
var _price: int
var _title: String
var _damage: int = 0


## Настройка кнопки один раз; юнит подставляется позже через show_upgrade.
func setup() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	_name_label.add_theme_constant_override("line_spacing", -2)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	resized.connect(_layout_name)


## Обновляет карточку под конкретное улучшение армии (название и портрет).
func show_upgrade(upgrade: ArmyUpgradeData) -> void:
	_title = upgrade.display_name
	_portrait = null
	_damage = 0
	if upgrade.mob != null:
		_portrait = VisualCatalog.get_default().get_mob(upgrade.mob.id).texture
		_damage = upgrade.mob.breach_damage
	_name_label.text = _title
	_layout_name()
	queue_redraw()


## Карточка по концепту: портрет сверху, имя, нижняя плашка с ценой и уроном.
func show_price(cost: int, compact: bool) -> void:
	_price = cost
	custom_minimum_size.y = (82 if compact else 100) if _portrait != null else 60
	_name_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	_name_label.modulate = Color("c2cbd0") if disabled else Color.WHITE
	_layout_name()
	queue_redraw()


func _layout_name() -> void:
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(CONTENT_MARGIN, size.y - PRICE_HEIGHT - 19)
	_name_label.size = Vector2(maxf(1, size.x - CONTENT_MARGIN * 2), 17)


func _draw() -> void:
	var art_bottom: float = size.y - PRICE_HEIGHT - 19
	if _portrait != null:
		var room: Vector2 = Vector2(size.x - 10, maxf(1.0, art_bottom - 4))
		var dims: Vector2 = Vector2(_portrait.get_size())
		dims *= minf(room.x / dims.x, room.y / dims.y)
		var at: Vector2 = Vector2((size.x - dims.x) * 0.5, art_bottom - dims.y)
		draw_texture_rect(preload("res://data/visuals/soft_light.tres"),
				Rect2(Vector2(size.x * 0.5 - room.y * 0.7, 2), Vector2(room.y * 1.4, room.y)), false,
				Color(1.0, 0.85, 0.6, 0.12))
		draw_texture_rect(_portrait, Rect2(at, dims), false,
				Color("c3cbd3") if disabled else Color.WHITE)
	var footer: Rect2 = Rect2(Vector2(1, size.y - PRICE_HEIGHT - 1),
			Vector2(size.x - 2, PRICE_HEIGHT))
	draw_rect(footer, Color(0.02, 0.04, 0.07, 0.72))
	var font: Font = get_theme_default_font()
	draw_texture_rect(COIN, Rect2(Vector2(6, footer.position.y + 3), Vector2(15, 15)), false)
	draw_string(font, Vector2(24, footer.end.y - 5), str(_price), HORIZONTAL_ALIGNMENT_LEFT, -1,
			16, DuskTheme.SHORT if disabled else Color("ffe2a8"))
	if _damage > 0:
		var text: String = str(_damage)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_texture_rect(MarketOffer.SWORD, Rect2(Vector2(size.x - width - 24,
				footer.position.y + 4), Vector2(14, 14)), false)
		draw_string(font, Vector2(size.x - width - 7, footer.end.y - 5), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6e0e6"))
