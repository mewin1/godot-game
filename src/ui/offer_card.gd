class_name OfferCard
extends Control
## Карточка лавки, резерва или подарка. ЛКМ покупает/выбирает, ПКМ поворачивает.

signal clicked(index: int)
signal item_dropped(payload: DragPayload, target_id: int)
signal rotation_requested(tower_id: int)

const CARD_SIZE: Vector2 = Vector2(175, 104)
const TAP_SLOP: float = 10.0
const CARD_COLOR: Color = Color(0.17, 0.13, 0.1)
const TEXT_COLOR: Color = Color(0.94, 0.87, 0.74)

var offer_index: int = 0
var rite: RiteData
var stored_tower: TowerState
var is_reserve_slot: bool = false
var data: TowerData
var rotation_turns: int = 0
var is_active: bool = true
var ticks_per_second: int = 20
var is_gift: bool = false

var _press_position: Vector2 = Vector2.ZERO
var _rite_label: Label


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rite_label = Label.new()
	_rite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rite_label.add_theme_font_size_override("font_size", 14)
	_rite_label.max_lines_visible = 4
	_rite_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_rite_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _rite_label != null:
		_rite_label.position = Vector2(8, 4)
		_rite_label.size = Vector2(size.x - 16, size.y - 28)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not is_active:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and data != null:
		if stored_tower != null:
			rotation_requested.emit(stored_tower.id)
		else:
			rotation_turns = (rotation_turns + 1) % TowerState.ROTATIONS
		queue_redraw()
		accept_event()
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_position = button.position
		elif button.position.distance_to(_press_position) <= TAP_SLOP \
				and not get_viewport().gui_is_dragging():
			clicked.emit(offer_index)


## null означает пустое место; поворот сохраняется, пока предложение то же.
func show_offer(tower_data: TowerData) -> void:
	if data != tower_data:
		rotation_turns = 0
	data = tower_data
	rite = null
	_rite_label.visible = false
	tooltip_text = data.description if data != null else ""
	queue_redraw()


## Заговор перетаскивается прямо на идол или собственную постройку.
func show_rite(rite_data: RiteData) -> void:
	rite = rite_data
	data = null
	_rite_label.visible = true
	_rite_label.text = "%s\n%s" % [rite.display_name, rite.description.get_slice(". ", 0)]
	tooltip_text = "%s\n%s · %d зол." % [rite.description,
			"На идол" if rite.target == RiteData.Target.IDOL else "На башню", rite.cost]
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_active:
		return null
	if rite != null:
		var label: Label = Label.new()
		label.text = rite.display_name
		label.add_theme_font_size_override("font_size", 20)
		set_drag_preview(label)
		return DragPayload.for_rite(offer_index, rite)
	if data == null:
		return null
	var payload: DragPayload
	if is_gift:
		payload = DragPayload.for_gift(offer_index, data, rotation_turns)
	elif is_reserve_slot and stored_tower != null:
		payload = DragPayload.for_tower(stored_tower)
		payload.kind = DragPayload.Kind.RESERVE
	else:
		payload = DragPayload.for_offer(offer_index, data, rotation_turns)
	var preview: ShapePreview = ShapePreview.create_drag_preview(data, payload.rotation,
			payload.level, 38.0)
	payload.preview = preview
	set_drag_preview(preview)
	return payload


func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if not is_reserve_slot or not is_active or not (value is DragPayload):
		return false
	var payload: DragPayload = value
	if payload.kind == DragPayload.Kind.RITE:
		return stored_tower != null and payload.rite.target == RiteData.Target.TOWER
	if stored_tower == null:
		return payload.kind != DragPayload.Kind.RESERVE
	return (payload.tower_id != stored_tower.id and payload.data == stored_tower.data
			and payload.level == stored_tower.level and stored_tower.level < 3)


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	item_dropped.emit(payload, stored_tower.id if stored_tower != null else 0)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(-1), CARD_COLOR)
	var font: Font = get_theme_default_font()
	if rite != null:
		draw_rect(rect.grow(-2), Color(0.45, 0.65, 0.85), false, 2)
		draw_string(font, Vector2(8, size.y - 8), "%s · %d" % [
				"На идол" if rite.target == RiteData.Target.IDOL else "На башню", rite.cost],
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 15, TEXT_COLOR)
		return
	if data == null:
		draw_rect(rect.grow(-2), Color(0.35, 0.29, 0.22), false, 1)
		return
	var visual: TowerVisual = VisualCatalog.get_default().get_tower(data.id)
	draw_rect(rect.grow(-2), visual.plate_edge_color, false, 2)
	var font_size: int = 13 if is_reserve_slot else 17
	draw_string(font, Vector2(5, 20), data.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 10, font_size, TEXT_COLOR)
	var bounds: Vector2 = Vector2(ShapePreview.get_shape_size(data, rotation_turns))
	var available: Vector2 = Vector2(size.x - 12, maxf(12, size.y - 58))
	var cell: float = minf(36, minf(available.x / bounds.x, available.y / bounds.y))
	var origin: Vector2 = Vector2((size.x - bounds.x * cell) / 2, 31)
	ShapePreview.draw_shape(self, data, rotation_turns,
			stored_tower.level if stored_tower != null else 1, origin, cell)
	var caption: String = ""
	if not is_reserve_slot:
		caption = "Подарок" if is_gift else "6 зол. · " + IdolSlot.god_name(data.god)
	elif stored_tower != null and stored_tower.enchantment >= 0:
		caption = "Чары"
	draw_string(font, Vector2(6, size.y - 6), caption, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 12, 13, TEXT_COLOR)
	if not is_active:
		draw_rect(rect, Color(0, 0, 0, 0.35))
