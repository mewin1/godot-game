class_name OfferCard
extends Control
## Карточка лавки, резерва или подарка. ЛКМ покупает/выбирает, ПКМ поворачивает.

signal clicked(index: int)
signal item_dropped(payload: DragPayload, target_id: int)
signal rotation_requested(tower_id: int)

const CARD_SIZE: Vector2 = Vector2(110, 112)
const TAP_SLOP: float = 10.0
const CARD_COLOR: Color = Color(0.085, 0.12, 0.17)
const TEXT_COLOR: Color = Color(0.94, 0.87, 0.74)

var offer_index: int = 0
var rite: RiteData
var stored_tower: TowerState
var is_reserve_slot: bool = false
var data: TowerData
var rotation_turns: int = 0
var is_active: bool = true
var ticks_per_second: int = 20
var tower_cost: int = 6
var is_gift: bool = false
var is_free_catalog: bool = false
var rite_player: PlayerState

var _press_position: Vector2 = Vector2.ZERO
var _tower_label: Label
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _rite_label: Label


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_normal_style = DuskTheme.panel(CARD_COLOR, Color("5e5546"), 0)
	_hover_style = DuskTheme.panel(Color("152635"), DuskTheme.GOLD, 0)
	_tower_label = Label.new()
	_tower_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tower_label.add_theme_font_size_override("font_size", 12)
	_tower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tower_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_tower_label)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rite_label = Label.new()
	_rite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rite_label.add_theme_font_size_override("font_size", 12)
	_rite_label.max_lines_visible = 4
	_rite_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_rite_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _rite_label != null:
		_layout_caption()


func _layout_caption() -> void:
	_rite_label.position = Vector2(7, size.y - 56)
	_rite_label.size = Vector2(size.x - 14, 39)
	_tower_label.position = Vector2(4, size.y - 38)
	_tower_label.size = Vector2(size.x - 8, 18)


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
	_tower_label.text = data.display_name if data != null else ""
	_tower_label.visible = data != null and not is_reserve_slot and not is_gift
	rite = null
	_rite_label.visible = false
	tooltip_text = data.description if data != null else ""
	queue_redraw()


## Заговор перетаскивается прямо на идол или собственную постройку.
func show_rite(rite_data: RiteData, context: String = "") -> void:
	rite = rite_data
	data = null
	_tower_label.visible = false
	_rite_label.visible = true
	_rite_label.text = rite.display_name
	tooltip_text = "%s\n%s · %d зол." % [rite.description,
			"На идол" if rite.target == RiteData.Target.IDOL else "На башню", rite.cost]
	if context != "":
		tooltip_text += "\n" + context
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_active:
		return null
	if rite != null:
		var label: Label = Label.new()
		label.text = rite.display_name
		label.add_theme_font_size_override("font_size", 20)
		set_drag_preview(label)
		var rite_payload: DragPayload = DragPayload.for_rite(offer_index, rite)
		rite_payload.rite_feedback = label
		return rite_payload
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
		var reason: String = TowerUpgradeGuide.rejection(rite_player, payload.rite,
				stored_tower.id if stored_tower != null else 0)
		payload.show_rite_feedback(reason)
		return reason == ""
	if stored_tower == null:
		return payload.kind != DragPayload.Kind.RESERVE
	return (payload.tower_id != stored_tower.id and payload.data == stored_tower.data
			and payload.level == stored_tower.level and stored_tower.level < 3)


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	item_dropped.emit(payload, stored_tower.id if stored_tower != null else 0)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var is_hovered: bool = rect.has_point(get_local_mouse_position())
	draw_style_box(_hover_style if is_hovered and is_active else _normal_style, rect.grow(-2))
	var font: Font = get_theme_default_font()
	if rite != null:
		var symbol: Texture2D = GodSymbols.get_icon(rite.god)
		var icon_side: float = minf(size.y - 60, 44)
		draw_texture_rect(symbol, Rect2(Vector2((size.x - icon_side) * 0.5, 5),
				Vector2.ONE * icon_side), false)
		draw_string(font, Vector2(8, size.y - 8), "◈ %d" % rite.cost,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 15, TEXT_COLOR)
		return
	if data == null:
		draw_rect(rect.grow(-2), Color(0.35, 0.29, 0.22), false, 1)
		return
	var visual: TowerVisual = VisualCatalog.get_default().get_tower(data.id)
	draw_line(Vector2(10, 2), Vector2(size.x - 10, 2), visual.plate_edge_color, 2, true)
	if visual.icon != null:
		var available: Vector2 = Vector2(size.x - 12,
				size.y - (22 if is_reserve_slot or is_gift else 40))
		var dimensions: Vector2 = Vector2(visual.icon.get_size())
		dimensions *= minf(available.x / dimensions.x, available.y / dimensions.y)
		var position: Vector2 = Vector2((size.x - dimensions.x) * 0.5, 3)
		draw_texture_rect(visual.icon, Rect2(position, dimensions), false)
	var bounds: Vector2 = Vector2(ShapePreview.get_shape_size(data, rotation_turns))
	var cell: float = minf(7.0, (size.x * 0.25) / maxf(bounds.x, bounds.y))
	var cells: Array[Vector2i] = TowerState.rotated_shape(data.shape, rotation_turns)
	draw_rect(Rect2(Vector2(4, 4), bounds * cell + Vector2.ONE * 4),
			Color(0.02, 0.04, 0.06, 0.8))
	TowerPainter.draw_plates(self, cells, Vector2(6, 6), cell, visual, 1)
	if stored_tower != null:
		TowerPainter.draw_stars(self, stored_tower.level,
				Vector2(size.x * 0.5, size.y - 10), 28)
	var caption: String = ""
	if not is_reserve_slot:
		caption = "Подарок" if is_gift else "◉ %d" % tower_cost
		if is_free_catalog:
			caption = "Перетащите на поле"
	elif stored_tower != null and stored_tower.enchantment >= 0:
		caption = "Чары"
	draw_string(font, Vector2(6, size.y - 6), caption, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 12, 16, TEXT_COLOR)
	if not is_active:
		draw_rect(rect, Color(0, 0, 0, 0.35))
	_draw_rite_target()


func _process(_delta: float) -> void:
	if is_reserve_slot:
		queue_redraw()


func _draw_rite_target() -> void:
	if not is_reserve_slot or not is_active or stored_tower == null:
		return
	var value: Variant = get_viewport().gui_get_drag_data()
	if not (value is DragPayload):
		return
	var payload: DragPayload = value
	if payload.kind != DragPayload.Kind.RITE:
		return
	var reason: String = TowerUpgradeGuide.rejection(rite_player, payload.rite, stored_tower.id)
	var color: Color = Color(0.55, 0.8, 0.4) if reason == "" else Color(0.7, 0.3, 0.25)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-3), color, false, 3)
