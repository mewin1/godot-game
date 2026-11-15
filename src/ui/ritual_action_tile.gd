class_name RitualActionTile
extends Button
## Плитка действия в доке забега (critique_2 п. 23-24): иконка, число — бейджем справа внизу,
## клавиша — мелким бейджем слева сверху (число больше не путается с клавишей). Пустой припас —
## силуэт; если его можно купить, внизу цена — щелчок покупает. Правила и цены — у RitualTrial.

const COUNT_COLOR: Color = Color("fff0cf")
const PRICE_COLOR: Color = Color("ffe2a8")
const BADGE: Color = Color(0.02, 0.04, 0.06, 0.86)
const BADGE_SIZE: int = 18

var picture: Texture2D
var key_hint: String = ""
## Сколько есть (-1 — без числа).
var count: int = -1
## Цена покупки (-1 — купить нельзя): показывается на пустой плитке.
var price: int = -1
var empty: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_state(new_count: int, new_empty: bool, new_price: int) -> void:
	if new_count == count and new_empty == empty and new_price == price:
		return
	count = new_count
	empty = new_empty
	price = new_price
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var art: Rect2 = Rect2(Vector2.ZERO, size).grow(-8)
	if picture != null:
		# Пустой припас узнаётся (critique_3 п. 50): не темнее 60%.
		var alpha: float = 0.6 if empty else 0.7 if disabled else 1.0
		draw_texture_rect(picture, art, false, Color(1, 1, 1, alpha))
	# Бейджи не мельче 18 (critique_3 п. 4, critique_4 п. 39): клавиша слева сверху, число или цена — внизу.
	if not key_hint.is_empty() and not (empty and price >= 0):
		var key_width: float = font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_SIZE).x
		draw_rect(Rect2(2, 2, key_width + 6, BADGE_SIZE + 3), BADGE)
		DuskTheme.note_drawn(key_hint, BADGE_SIZE)
		draw_string(font, Vector2(5, BADGE_SIZE + 1), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_SIZE,
				Color(0.8, 0.84, 0.86))
	var numbers: Font = DuskTheme.NUMBER_FONT
	# Одно место — один смысл (п. 50): внизу справа всегда количество (0 — серым); цена покупки —
	# отдельным бейджем «+» сверху справа, только когда купить можно.
	if count >= 0:
		var number: String = str(count)
		var width: float = numbers.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_rect(Rect2(size.x - width - 8, size.y - 22, width + 6, 20), BADGE)
		DuskTheme.note_drawn(number, 18)
		draw_string(numbers, Vector2(size.x - width - 5, size.y - 5), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				COUNT_COLOR if count > 0 else Color(0.6, 0.62, 0.64))
	if empty and price >= 0:
		var amount: String = str(price)
		var width_price: float = DuskTheme.price_width(numbers, amount, BADGE_SIZE)
		var left: float = size.x - width_price - 4
		draw_rect(Rect2(left - 2, 1, width_price + 4, BADGE_SIZE + 4), BADGE)
		DuskTheme.draw_price(self, numbers, Vector2(left, BADGE_SIZE + 1), amount, BADGE_SIZE, PRICE_COLOR)
