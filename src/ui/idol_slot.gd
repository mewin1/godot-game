class_name IdolSlot
extends Control
## Постоянное место под картой. Заговор применяется перетаскиванием прямо сюда.

signal command_requested(command: SimCommand)

var slot_index: int = 0
var idol: IdolState
var can_edit: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Обновляет только отображение, без изменения идола.
func refresh(state: IdolState, editable: bool) -> void:
	idol = state
	can_edit = editable
	tooltip_text = "Урон +%d%% · разряд: на %d ударов меньше · цепь +%d\n" % [
			idol.damage_percent, idol.chain_reduction, idol.chain_targets]
	tooltip_text += "Горение +%d%% · ветер +%d%% · длина +%.1f клетки" % [
			idol.burn_percent, idol.wind_power, idol.wind_length_milli / 1000.0]
	queue_redraw()


## Одинаковые отображаемые имена в идолах и карточках лавки.
static func god_name(god: StringName) -> String:
	match god:
		&"perun":
			return "Перун"
		&"svarog":
			return "Сварог"
		&"stribog":
			return "Стрибог"
	return "Пустой идол"


func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if not can_edit or idol == null or not (value is DragPayload):
		return false
	var payload: DragPayload = value
	return (payload.kind == DragPayload.Kind.RITE
			and payload.rite.target == RiteData.Target.IDOL
			and idol.check_rite(payload.rite) == "")


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	command_requested.emit(BuyRiteCommand.new(payload.offer_index, slot_index))


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-2)
	draw_rect(rect, Color(0.15, 0.12, 0.1))
	draw_rect(rect, Color(0.65, 0.53, 0.33), false, 2)
	if idol == null:
		return
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(12, 25), god_name(idol.god), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24, 20, Color(0.94, 0.8, 0.5))
	var count: int = 0
	for value: int in idol.purchases.values():
		count += value
	var text: String = "Перетащите заговор" if idol.god == &"" else "Заговоров: %d" % count
	draw_string(font, Vector2(12, 49), text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24, 15, Color(0.8, 0.8, 0.75))
