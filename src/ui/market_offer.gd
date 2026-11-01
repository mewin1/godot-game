class_name MarketOffer
extends OfferCard
## Карточка предложения в подготовке. Цена поверх витрины, снизу имя до двух строк.

const COIN: Texture2D = preload("res://assets/ui/icon_gold.svg")
const CAPTION_HEIGHT: float = 43.0
const ART_TOP: float = 24.0
const ART_SIDE_TOP: float = 7.0
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
	_normal_style.bg_color = Color("111c27")


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
	var hue: Color = DuskTheme.GOLD
	if data != null:
		var visual: TowerVisual = VisualCatalog.get_default().get_tower(data.id)
		texture = visual.icon
		hue = visual.plate_edge_color
		var cells: Array[Vector2i] = TowerState.rotated_shape(data.shape, rotation_turns)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(8, 9) + Vector2(cell) * 5, Vector2(4, 4)),
					Color("ceb890"))
	else:
		texture = GodSymbols.get_icon(rite.god)
		price = rite.cost
	var font: Font = get_theme_default_font()
	var price_width: float = font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15).x
	var left: float = size.x - price_width - 28
	# Выбираем большее изображение: под ценой либо слева от неё до верхнего края.
	var room: Vector2 = Vector2(size.x - CONTENT_MARGIN * 2,
			maxf(1, size.y - CAPTION_HEIGHT - ART_TOP - CONTENT_MARGIN))
	var dims: Vector2 = Vector2(texture.get_size())
	var scale_factor: float = minf(room.x / dims.x, room.y / dims.y)
	var side_room: Vector2 = Vector2(maxf(1, left - CONTENT_MARGIN * 2),
			maxf(1, size.y - CAPTION_HEIGHT - ART_SIDE_TOP - CONTENT_MARGIN))
	var side_scale: float = minf(side_room.x / dims.x, side_room.y / dims.y)
	var center: Vector2 = Vector2(size.x * 0.5, ART_TOP + room.y * 0.5)
	if side_scale > scale_factor:
		room = side_room
		scale_factor = side_scale
		center = Vector2(CONTENT_MARGIN + room.x * 0.5, ART_SIDE_TOP + room.y * 0.5)
	dims *= scale_factor
	if rite != null:
		dims *= 0.78
	draw_texture_rect(preload("res://data/visuals/soft_light.tres"),
			Rect2(center - room * 0.56, room * 1.12), false, Color(hue, 0.21))
	draw_texture_rect(texture, Rect2(center - dims * 0.5, dims), false)
	draw_texture_rect(COIN, Rect2(left, 6, 16, 16), false)
	draw_string(font, Vector2(left + 19, 19), str(price), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, Color("f3dbab"))
	draw_line(Vector2(8, size.y - CAPTION_HEIGHT),
			Vector2(size.x - 8, size.y - CAPTION_HEIGHT),
			Color(0.69, 0.61, 0.45, 0.24))
	if not is_active:
		draw_rect(rect, Color(0.03, 0.05, 0.08, 0.24))
