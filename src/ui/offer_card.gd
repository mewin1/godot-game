class_name OfferCard
extends Control
## Карточка предложения витрины. Перетащи на своё поле, чтобы купить и поставить.
## Кнопка ⟳ поворачивает фигуру перед покупкой.

const CARD_SIZE: Vector2 = Vector2(196, 150)
const ROTATE_BUTTON_SIZE: Vector2 = Vector2(48, 48)
const NAME_FONT_SIZE: int = 20
const INFO_FONT_SIZE: int = 15
const COLOR_CARD: Color = Color(0.18, 0.19, 0.24)
const COLOR_EMPTY: Color = Color(0.12, 0.12, 0.15)

var offer_index: int = 0
var data: TowerData
var rotation_turns: int = 0
## Можно ли сейчас покупать (фаза подготовки).
var is_active: bool = true
## Из конфига: нужен, чтобы показать скорострельность в выстрелах в секунду.
var ticks_per_second: int = 20

var _rotate_button: Button


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	_rotate_button = Button.new()
	_rotate_button.text = "⟳"
	_rotate_button.custom_minimum_size = ROTATE_BUTTON_SIZE
	_rotate_button.focus_mode = Control.FOCUS_NONE
	_rotate_button.pressed.connect(_on_rotate_button_pressed)
	add_child(_rotate_button)


func _ready() -> void:
	_place_rotate_button()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _rotate_button != null:
		_place_rotate_button()


## Показывает предложение (null — место пустое: башню уже купили).
func show_offer(tower_data: TowerData) -> void:
	if tower_data != data:
		rotation_turns = 0
	data = tower_data
	_rotate_button.visible = data != null
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if data == null or not is_active:
		return null
	set_drag_preview(ShapePreview.create_drag_preview(data, rotation_turns, 1, 40.0))
	return DragPayload.for_offer(offer_index, data, rotation_turns)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if data == null:
		draw_rect(rect, COLOR_EMPTY)
		draw_string(get_theme_default_font(), Vector2(0, size.y / 2), "куплено",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, INFO_FONT_SIZE, Color(1, 1, 1, 0.4))
		return
	draw_rect(rect, COLOR_CARD)
	draw_rect(rect, data.color, false, 3.0)
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(10, 26), data.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - ROTATE_BUTTON_SIZE.x - 14, NAME_FONT_SIZE)
	draw_string(font, Vector2(10, size.y - 30), _stats_text(), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 14, INFO_FONT_SIZE, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(10, size.y - 10), _effects_text(), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 14, INFO_FONT_SIZE, Color(1, 1, 0.7, 0.9))
	var shape_area: Rect2 = Rect2(Vector2(10, 34), Vector2(size.x - 20, size.y - 76))
	var bounds: Vector2 = Vector2(ShapePreview.get_shape_size(data, rotation_turns))
	var cell: float = floorf(minf(22.0, minf(shape_area.size.x / bounds.x,
			shape_area.size.y / bounds.y)))
	var top_left: Vector2 = shape_area.position + (shape_area.size - bounds * cell) / 2.0
	ShapePreview.draw_shape(self, data, rotation_turns, 1, top_left, cell)


func _stats_text() -> String:
	var shots_per_second: float = float(ticks_per_second) / data.cooldown_ticks
	return "урон %d · %.1f выстр./с" % [data.damage, shots_per_second]


func _effects_text() -> String:
	var parts: PackedStringArray = []
	parts.append("радиус %.1f" % (data.range_milli / 1000.0))
	if data.splash_radius_milli > 0:
		parts.append("по площади")
	if data.slow_percent > 0:
		parts.append("замедл. %d%%" % data.slow_percent)
	return " · ".join(parts)


func _place_rotate_button() -> void:
	_rotate_button.position = Vector2(size.x - ROTATE_BUTTON_SIZE.x - 4, 4)
	_rotate_button.size = ROTATE_BUTTON_SIZE


func _on_rotate_button_pressed() -> void:
	rotation_turns = (rotation_turns + 1) % TowerState.ROTATIONS
	queue_redraw()
