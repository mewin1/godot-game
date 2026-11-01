class_name MarketOffer
extends OfferCard
## Карточка предложения в подготовке. Цена поверх витрины, снизу имя до двух строк.

const COIN: Texture2D = preload("res://assets/ui/icon_gold.svg")
const CAPTION_HEIGHT: float = 43.0
const STRIPE_HEIGHT: float = 7.0
const HEADER_TOP: float = 11.0
const SYMBOL_SIZE: float = 19.0
const ART_TOP: float = 34.0
const ART_SIDE_LEFT: float = 29.0
const CONTENT_MARGIN: float = 4.0


func _init() -> void:
	super()
	clip_contents = true
	_tower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tower_label.max_lines_visible = 2
	_rite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rite_label.max_lines_visible = 2
	for caption: Label in [_tower_label, _rite_label]:
		caption.clip_text = true
		caption.add_theme_constant_override("line_spacing", -2)
	_normal_style.bg_color = Color("111c27d4")


## Подсказка сохраняет описание ресурса и явно называет стихию предложения.
func show_offer(tower_data: TowerData) -> void:
	super(tower_data)
	if data != null:
		tooltip_text = GodSymbols.get_power_name(data.god) + "\n" + tooltip_text


## Заговор использует ту же полосу и имя силы, что соответствующие постройки.
func show_rite(rite_data: RiteData, context: String = "") -> void:
	super(rite_data, context)
	tooltip_text = GodSymbols.get_power_name(rite.god) + "\n" + tooltip_text


func _layout_caption() -> void:
	for caption: Label in [_tower_label, _rite_label]:
		caption.position = Vector2(CONTENT_MARGIN, size.y - CAPTION_HEIGHT + CONTENT_MARGIN)
		caption.size = Vector2(size.x - CONTENT_MARGIN * 2,
				CAPTION_HEIGHT - CONTENT_MARGIN * 2)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12 if size.y < 140 else 13)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-1)
	var lit: bool = is_active and rect.has_point(get_local_mouse_position())
	draw_style_box(_hover_style if lit else _normal_style, rect)
	if data == null and rite == null:
		return
	var texture: Texture2D
	var price: int = tower_cost
	var god: StringName = data.god if data != null else rite.god
	var hue: Color = GodSymbols.get_color(god)
	if data != null:
		var visual: TowerVisual = VisualCatalog.get_default().get_tower(data.id)
		texture = visual.icon
		var cells: Array[Vector2i] = TowerState.rotated_shape(data.shape, rotation_turns)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(9, HEADER_TOP + SYMBOL_SIZE + 4) + Vector2(cell) * 4,
					Vector2(3, 3)),
					Color("ceb890"))
	else:
		texture = GodSymbols.get_icon(rite.god)
		price = rite.cost
	var font: Font = get_theme_default_font()
	var price_width: float = font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15).x
	var left: float = size.x - price_width - 28
	# Высокий арт может подняться между символом слева и ценой справа.
	var room: Vector2 = Vector2(size.x - ART_SIDE_LEFT - CONTENT_MARGIN,
			maxf(1, size.y - CAPTION_HEIGHT - ART_TOP - CONTENT_MARGIN))
	var dims: Vector2 = Vector2(texture.get_size())
	var scale_factor: float = minf(room.x / dims.x, room.y / dims.y)
	var center: Vector2 = Vector2(ART_SIDE_LEFT + room.x * 0.5, ART_TOP + room.y * 0.5)
	var side_room: Vector2 = Vector2(maxf(1, left - ART_SIDE_LEFT - CONTENT_MARGIN),
			maxf(1, size.y - CAPTION_HEIGHT - HEADER_TOP - CONTENT_MARGIN))
	var side_scale: float = minf(side_room.x / dims.x, side_room.y / dims.y)
	if side_scale > scale_factor:
		room = side_room
		scale_factor = side_scale
		center = Vector2(ART_SIDE_LEFT + room.x * 0.5, HEADER_TOP + room.y * 0.5)
	dims *= scale_factor
	if rite != null:
		dims *= 0.78
	draw_texture_rect(preload("res://data/visuals/soft_light.tres"),
			Rect2(center - room * 0.56, room * 1.12), false, Color(hue, 0.21))
	draw_texture_rect(texture, Rect2(center - dims * 0.5, dims), false)
	draw_texture_rect(GodSymbols.get_icon(god),
			Rect2(Vector2(6, HEADER_TOP), Vector2.ONE * SYMBOL_SIZE), false)
	draw_texture_rect(COIN, Rect2(left, HEADER_TOP + 1, 16, 16), false)
	draw_string(font, Vector2(left + 19, HEADER_TOP + 14), str(price), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, Color("f3dbab"))
	draw_line(Vector2(8, size.y - CAPTION_HEIGHT),
			Vector2(size.x - 8, size.y - CAPTION_HEIGHT),
			Color(0.69, 0.61, 0.45, 0.24))
	if not is_active:
		draw_rect(rect, Color(0.03, 0.05, 0.08, 0.24))
	# Стихия остаётся видна и при нехватке золота, независимо от оттенка картинки.
	draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, STRIPE_HEIGHT)), hue)
