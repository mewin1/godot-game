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


## Название берётся из действующего улучшения. Полное описание остаётся в подсказке.
func setup(upgrade: ArmyUpgradeData) -> void:
	_title = upgrade.display_name
	if upgrade.mob != null:
		_portrait = VisualCatalog.get_default().get_mob(upgrade.mob.id).texture
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	_name_label.text = _title
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	_name_label.add_theme_constant_override("line_spacing", -2)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	resized.connect(_layout_name)


## В плотной раскладке изображения уменьшаются, подписи по-прежнему переносятся.
func show_price(cost: int, compact: bool) -> void:
	_price = cost
	custom_minimum_size.y = (60 if compact else 78) if _portrait != null else 54
	_name_label.add_theme_font_size_override("font_size",
			12 if compact or _portrait == null else 13)
	_name_label.modulate = Color("c2cbd0") if disabled else Color.WHITE
	_layout_name()
	queue_redraw()


func _art_width() -> float:
	return minf(size.x * 0.37, size.y * 0.77) if _portrait != null else 0.0


func _layout_name() -> void:
	var left: float = 7 + _art_width()
	_name_label.position = Vector2(left, CONTENT_MARGIN)
	_name_label.size = Vector2(maxf(1, size.x - left - CONTENT_MARGIN),
			maxf(1, size.y - PRICE_HEIGHT - CONTENT_MARGIN))
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _draw() -> void:
	var art_width: float = _art_width()
	if _portrait != null:
		var dims: Vector2 = Vector2(_portrait.get_size())
		dims *= minf((size.y - 4) / dims.y, art_width / dims.x)
		var at: Vector2 = Vector2((art_width - dims.x) * 0.5 + 3, size.y - dims.y - 2)
		draw_texture_rect(_portrait, Rect2(at, dims), false,
				Color("c3cbd3") if disabled else Color.WHITE)
	var x_pos: float = 7 + art_width
	draw_texture_rect(COIN, Rect2(x_pos, size.y - 20, 15, 15), false)
	draw_string(get_theme_default_font(), Vector2(x_pos + 19, size.y - 7),
			str(_price), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e6cea1"))
