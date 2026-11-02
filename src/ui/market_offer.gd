class_name MarketOffer
extends OfferCard
## Карточка предложения в подготовке (по концепту): бейдж тира и символ стихии сверху,
## картинка, имя, нижняя плашка с крупной ценой, уроном и формой фигуры.
## Подробности (радиус, скорострельность, описание) — в подсказке по наведению.

const COIN: Texture2D = preload("res://assets/ui/icon_gold.svg")
const SWORD: Texture2D = preload("res://assets/ui/icon_damage.svg")
const FOOTER_HEIGHT: float = 26.0
const NAME_HEIGHT: float = 18.0
const BADGE_SIZE: Vector2 = Vector2(30, 19)
const SYMBOL_SIZE: float = 20.0
const CONTENT_MARGIN: float = 5.0
const TIER_NAMES: Array[String] = ["I", "II", "III"]
## Бейдж тира: бронза, серебро, золото.
const TIER_COLORS: Array[Color] = [Color("b9814f"), Color("b8c3cc"), Color("f0c869")]
const FOOTER_COLOR: Color = Color(0.02, 0.04, 0.07, 0.72)
const PRICE_COLOR: Color = Color("ffe2a8")
const STAT_COLOR: Color = Color("d6e0e6")


func _init() -> void:
	super()
	clip_contents = true
	_tower_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tower_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rite_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rite_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for caption: Label in [_tower_label, _rite_label]:
		caption.clip_text = true
		caption.add_theme_color_override("font_color", Color("f1e6cf"))
	_normal_style.bg_color = Color(0.06, 0.11, 0.18, 0.78)
	_normal_style.border_color = Color(0.62, 0.74, 0.9, 0.22)
	_normal_style.set_corner_radius_all(7)
	_hover_style.set_corner_radius_all(7)
	_hover_style.bg_color = Color(0.1, 0.18, 0.27, 0.92)


## Подсказка: стихия, описание и числа — как всплывающая карточка в концепте.
func show_offer(tower_data: TowerData) -> void:
	super(tower_data)
	if data == null:
		return
	var seconds: float = data.cooldown_ticks / float(maxi(1, ticks_per_second))
	var lines: PackedStringArray = [
		"%s · %s · тир %s" % [data.display_name, GodSymbols.get_power_name(data.god),
				TIER_NAMES[clampi(data.tier, 1, 3) - 1]],
		data.description,
	]
	if data.attacks:
		var stats: String = "⚔ Урон %d   ◎ Радиус %.1f кл.   ⏱ %.1f с" % [data.damage,
				data.range_milli / 1000.0, seconds]
		if data.splash_radius_milli > 0:
			stats += "   ✸ По области %.1f кл." % (data.splash_radius_milli / 1000.0)
		lines.append(stats)
	lines.append("Клеток: %d · ПКМ — поворот" % data.shape.size())
	tooltip_text = "\n".join(lines)


## Заговор использует ту же раскладку: символ силы, имя и цена.
func show_rite(rite_data: RiteData, context: String = "") -> void:
	super(rite_data, context)
	tooltip_text = GodSymbols.get_power_name(rite.god) + "\n" + tooltip_text


func _layout_caption() -> void:
	for caption: Label in [_tower_label, _rite_label]:
		caption.position = Vector2(CONTENT_MARGIN, size.y - FOOTER_HEIGHT - NAME_HEIGHT - 2)
		caption.size = Vector2(size.x - CONTENT_MARGIN * 2, NAME_HEIGHT)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 13)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-1)
	var lit: bool = is_active and rect.has_point(get_local_mouse_position())
	draw_style_box(_hover_style if lit else _normal_style, rect)
	if data == null and rite == null:
		return
	var god: StringName = data.god if data != null else rite.god
	var hue: Color = GodSymbols.get_color(god)
	var texture: Texture2D = GodSymbols.get_icon(rite.god) if rite != null \
			else VisualCatalog.get_default().get_tower(data.id).icon
	var price: int = rite.cost if rite != null else tower_cost
	var font: Font = get_theme_default_font()
	# Мягкий ореол стихии за картинкой.
	var art_top: float = BADGE_SIZE.y + 8
	var art_bottom: float = size.y - FOOTER_HEIGHT - NAME_HEIGHT - 2
	var room: Vector2 = Vector2(size.x - 16, maxf(1.0, art_bottom - art_top))
	var center: Vector2 = Vector2(size.x * 0.5, art_top + room.y * 0.5)
	draw_texture_rect(preload("res://data/visuals/soft_light.tres"),
			Rect2(center - room * 0.62, room * 1.24), false, Color(hue, 0.26))
	var dims: Vector2 = Vector2(texture.get_size())
	dims *= minf(room.x / dims.x, room.y / dims.y) * (0.72 if rite != null else 1.0)
	draw_texture_rect(texture, Rect2(center - dims * 0.5, dims), false,
			Color.WHITE if is_active else Color(0.75, 0.75, 0.78))
	draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, 3)), hue)
	draw_texture_rect(GodSymbols.get_icon(god),
			Rect2(Vector2(size.x - SYMBOL_SIZE - 6, 7), Vector2.ONE * SYMBOL_SIZE), false)
	if data != null:
		_draw_tier_badge(font, clampi(data.tier, 1, 3))
	else:
		_draw_badge(font, "чары", Color("9fb6c9"))
	_draw_footer(font, price)
	if not is_active:
		draw_rect(rect, Color(0.02, 0.03, 0.06, 0.38))


func _draw_tier_badge(font: Font, tier: int) -> void:
	_draw_badge(font, TIER_NAMES[tier - 1], TIER_COLORS[tier - 1])


func _draw_badge(font: Font, text: String, color: Color) -> void:
	var width: float = maxf(BADGE_SIZE.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13).x + 12)
	var badge: Rect2 = Rect2(Vector2(6, 7), Vector2(width, BADGE_SIZE.y))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.darkened(0.62), 0.92)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	draw_style_box(style, badge)
	draw_string(font, Vector2(badge.position.x, badge.end.y - 5), text,
			HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, color.lightened(0.25))


## Нижняя плашка: монета и цена (красная, если не хватает), урон и форма фигуры.
func _draw_footer(font: Font, price: int) -> void:
	var footer: Rect2 = Rect2(Vector2(1, size.y - FOOTER_HEIGHT - 1),
			Vector2(size.x - 2, FOOTER_HEIGHT))
	draw_rect(footer, FOOTER_COLOR)
	var baseline: float = footer.end.y - 7
	draw_texture_rect(COIN, Rect2(Vector2(7, footer.position.y + 5), Vector2(16, 16)), false)
	draw_string_outline(font, Vector2(26, baseline), str(price), HORIZONTAL_ALIGNMENT_LEFT, -1,
			18, 3, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(26, baseline), str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			PRICE_COLOR if is_active else DuskTheme.SHORT)
	if data == null:
		return
	var cells: Array[Vector2i] = TowerState.rotated_shape(data.shape, rotation_turns)
	var bounds: Vector2i = Vector2i.ZERO
	for cell: Vector2i in cells:
		bounds = bounds.max(cell + Vector2i.ONE)
	var step: float = minf(6.0, (FOOTER_HEIGHT - 8) / maxf(1, bounds.y))
	var shape_left: float = size.x - 7 - bounds.x * step
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(shape_left, footer.position.y + 4) + Vector2(cell) * step,
				Vector2.ONE * (step - 1)), Color("e8d2a2"))
	if data.attacks:
		var text: String = str(data.damage)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var text_left: float = shape_left - width - 6
		draw_texture_rect(SWORD, Rect2(Vector2(text_left - 16, footer.position.y + 5),
				Vector2(15, 15)), false)
		draw_string(font, Vector2(text_left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				STAT_COLOR)
