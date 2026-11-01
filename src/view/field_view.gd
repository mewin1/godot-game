class_name FieldView
extends Control
## Каменный двор 2.5D, точная сетка и перенос фигур.
## Постройки, бойцы и эффекты рисует дочерний BattleLayer с сортировкой по глубине.
## Только читает FieldState; действия игрока отдаёт наверх сигналом command_requested.

signal command_requested(command: SimCommand)
## Нажатие (без перетаскивания) на клетку: id башни или 0, если там пусто.
signal tower_tapped(tower_id: int)
signal cell_tapped(cell: Vector2i)
## Боевой слой просит сыграть звук (звуком управляет экран матча).
signal sound_requested(sound_id: StringName)

const MILLI: float = 1000.0
const TITLE_HEIGHT: float = 34.0
const TITLE_FONT_SIZE: int = 20
const TITLE_COLOR: Color = Color(0.94, 0.89, 0.81)
## Насколько можно сдвинуть палец, чтобы нажатие ещё считалось нажатием, а не перетаскиванием.
const TAP_SLOP: float = 12.0
## Сколько секунд башня «вздрагивает» после выстрела.
const FIRE_PULSE_SECONDS: float = TowerPainter.FIRE_PULSE_SECONDS
const HERO_SHAKE_SECONDS: float = 0.4
const HERO_SHAKE_PIXELS: float = 6.0
## «Пружинка» башни после покупки или слияния.
const POP_SECONDS: float = TowerPainter.POP_SECONDS
const SIEGE_PULSE_SPEED: float = 5.0
const MERGE_BURST_COLOR: Color = Color(1.0, 0.82, 0.4)
const SELL_BURST_COLOR: Color = Color(0.75, 0.62, 0.45)
const LESHY_COLOR: Color = Color(0.55, 0.8, 0.35)
const SCORCH_SHADE: Color = Color(0.05, 0.03, 0.02, 0.55)
const SCORCH_EMBER: Color = Color(1.0, 0.5, 0.2)
const GRID_ASPECT: float = CourtyardPainter.GRID_ASPECT

var preparation_court: PreparationCourt
var has_atmosphere: bool = false
var _air: ColorRect
var _air_material: ShaderMaterial
var field: FieldState
var config: GameConfig
var title: String = ""
var hero_hp: int = 0
## Можно ли сейчас менять поле (своё поле в фазе подготовки).
var can_edit: bool = false
var editing_player: PlayerState
var _combo_cache_key: int = -1
var _combo_cells: Array[Vector2i] = []
var selected_tower_id: int = 0
var show_target_labels: bool = false:
	set(value):
		show_target_labels = value
		_battle.show_target_labels = value
var selected_mob_id: int = 0:
	set(value):
		selected_mob_id = value
		_battle.selected_mob_id = value
var playback_speed: int = 1:
	set(value):
		playback_speed = value
		_battle.playback_speed = value
## Доля пути до следующего тика (0..1): мобы рисуются плавно между тиками.
var interpolation: float = 0.0:
	set(value):
		interpolation = value
		_battle.interpolation = value
## Своё поле: над убитыми мобами всплывает «+N» золота.
var is_own_field: bool = false:
	set(value):
		is_own_field = value
		_battle.is_own_field = value
## На это поле идут сразу двое (осада): рамка поля мигает красным.
var is_under_siege: bool = false

var _style: FieldStyle
var _battle: BattleLayer
var _cell_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO
var _hover: DragPayload
var _hover_anchor: Vector2i = Vector2i.ZERO
var _hover_valid: bool = false
var _hover_merge_target: TowerState
var _press_position: Vector2 = Vector2.ZERO
var _fire_pulses: Dictionary[int, float] = {}
var _hero_shake_left: float = 0.0
var _time: float = 0.0
var _pops: Dictionary[int, float] = {}
## Уровни и центры башен на прошлом кадре — так видно покупку, слияние и продажу.
var _known_levels: Dictionary[int, int] = {}
var _known_centers: Dictionary[int, Vector2i] = {}


func _init() -> void:
	_style = VisualCatalog.get_default().field
	clip_contents = true
	_battle = BattleLayer.new()
	_battle.draw_world_towers = true
	_battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.sound_requested.connect(_on_battle_sound_requested)
	add_child(_battle)
	_air = ColorRect.new()
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air_material = ShaderMaterial.new()
	_air_material.shader = preload("res://assets/shaders/court_air.gdshader")
	_air.material = _air_material
	add_child(_air)
	_air.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	delta *= playback_speed
	if _hover != null and get_viewport().gui_is_dragging():
		if Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
			_update_hover(_hover, get_local_mouse_position())
		else:
			_hover = null
			_hover_merge_target = null
	for tower_id: int in _fire_pulses.keys():
		_fire_pulses[tower_id] -= delta
		if _fire_pulses[tower_id] <= 0.0:
			_fire_pulses.erase(tower_id)
	_hero_shake_left = maxf(0.0, _hero_shake_left - delta)
	_time += delta
	_air_material.set_shader_parameter("clock", _time)
	for tower_id: int in _pops.keys():
		_pops[tower_id] -= delta
		if _pops[tower_id] <= 0.0:
			_pops.erase(tower_id)
	if field != null and is_own_field:
		_track_tower_changes()
	_battle.tower_pulses = _fire_pulses
	_battle.tower_pops = _pops
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and field != null:
		_update_layout()
	if what == NOTIFICATION_DRAG_END:
		_hover = null
		_hover_merge_target = null


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or field == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and can_edit:
		var tower: TowerState = field.get_tower_at(_cell_at(button.position))
		if tower != null:
			command_requested.emit(RotateTowerCommand.new(tower.id))
		accept_event()
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_position = button.position
		elif button.position.distance_to(_press_position) <= TAP_SLOP:
			var tower: TowerState = field.get_tower_at(_cell_at(button.position))
			tower_tapped.emit(tower.id if tower != null else 0)
			cell_tapped.emit(_cell_at(button.position))


## Подключает поле. Повторный вызов с другим полем переключает отображение.
func show_field(field_state: FieldState, game_config: GameConfig, caption: String) -> void:
	title = caption
	config = game_config
	if field == field_state:
		return
	if field != null:
		field.tower_fired.disconnect(_on_field_tower_fired)
		field.mob_breached.disconnect(_on_field_mob_breached)
	field = field_state
	_update_layout()
	_fire_pulses.clear()
	_pops.clear()
	_remember_towers()
	field.tower_fired.connect(_on_field_tower_fired)
	field.mob_breached.connect(_on_field_mob_breached)
	_battle.set_field(field)


## Экранная точка центра башни — для эффектов покупки и слияния.
func get_tower_screen_center(tower: TowerState) -> Vector2:
	return _to_screen(Vector2(tower.center_milli()))


#region Перетаскивание

func _get_drag_data(at_position: Vector2) -> Variant:
	if not can_edit or field == null:
		return null
	var tower: TowerState = field.get_tower_at(_cell_at(at_position))
	if tower == null:
		return null
	var payload: DragPayload = DragPayload.for_tower(tower)
	payload.preview = ShapePreview.create_drag_preview(tower.data, tower.rotation, tower.level,
			_cell_size * 0.6)
	set_drag_preview(payload.preview)
	return payload


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not can_edit or field == null or not (data is DragPayload):
		_hover = null
		return false
	var payload: DragPayload = data
	_update_hover(payload, at_position)
	return _hover_valid


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var payload: DragPayload = data
	_update_hover(payload, at_position)
	var command: SimCommand = _make_drop_command(payload)
	_hover = null
	_hover_merge_target = null
	if command != null:
		command_requested.emit(command)


func _update_hover(payload: DragPayload, at_position: Vector2) -> void:
	_hover = payload
	var cell: Vector2i = _cell_at(at_position)
	if payload.kind == DragPayload.Kind.RITE:
		_hover_merge_target = field.get_tower_at(cell)
		var reason: String = TowerUpgradeGuide.rejection(editing_player, payload.rite,
				_hover_merge_target.id if _hover_merge_target != null else 0)
		_hover_valid = reason == ""
		payload.show_rite_feedback(reason)
		return
	_hover_merge_target = _find_merge_target(payload, cell)
	if _hover_merge_target != null:
		_hover_valid = true
		return
	var bounds: Vector2i = ShapePreview.get_shape_size(payload.data, payload.rotation)
	_hover_anchor = cell - Vector2i((bounds.x - 1) / 2, (bounds.y - 1) / 2)
	var cells: Array[Vector2i] = TowerState.shape_cells_at(payload.data.shape, _hover_anchor,
			payload.rotation)
	_hover_valid = field.can_place(cells, payload.tower_id)


## Башня под пальцем, с которой можно слить перетаскиваемую (та же башня, тот же уровень).
func _find_merge_target(payload: DragPayload, cell: Vector2i) -> TowerState:
	var target: TowerState = field.get_tower_at(cell)
	if target == null or target.id == payload.tower_id:
		return null
	if target.data != payload.data or target.level != payload.level:
		return null
	if target.level >= config.max_tower_level:
		return null
	return target


func _make_drop_command(payload: DragPayload) -> SimCommand:
	if not _hover_valid:
		return null
	if payload.kind == DragPayload.Kind.RITE:
		return BuyRiteCommand.new(payload.offer_index, _hover_merge_target.id)
	if payload.kind == DragPayload.Kind.GIFT:
		if _hover_merge_target != null:
			return GiftCommand.new(GiftCommand.Action.MERGE, payload.offer_index,
					_hover_merge_target.id)
		return PlaceGiftCommand.new(payload.offer_index, _hover_anchor, payload.rotation)
	if payload.kind == DragPayload.Kind.OFFER:
		if _hover_merge_target != null:
			return BuyIntoTowerCommand.new(payload.offer_index, _hover_merge_target.id)
		return BuyTowerCommand.new(payload.offer_index, _hover_anchor, payload.rotation)
	if _hover_merge_target != null:
		return MergeTowersCommand.new(payload.tower_id, _hover_merge_target.id)
	return MoveTowerCommand.new(payload.tower_id, _hover_anchor, payload.rotation)

#endregion


#region Рисование

func _draw() -> void:
	var in_court: bool = preparation_court != null and preparation_court.visible
	_battle.is_preparation_court = in_court
	_battle.has_atmosphere = has_atmosphere
	_air.visible = has_atmosphere
	if not in_court:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.09, 0.14))
	if field == null:
		return
	_update_layout()
	_battle.set_layout(_origin, _cell_size)
	_battle.point_projector = Callable(self, "_to_screen")
	if in_court:
		CourtyardPainter.draw_preparation(self, field, _origin, _cell_size, _time)
	else:
		_draw_title()
		CourtyardPainter.draw_field(self, field, _origin, _cell_size, _time)
	_draw_footprints()
	_draw_court_lights()
	_draw_combo_coverage()
	_draw_knockback_mark()
	_draw_wind()
	_draw_tower_marks()
	_draw_rite_targets()
	_draw_hover()
	_update_hero_plate()
	_draw_siege_frame()


func _update_layout() -> void:
	var board: BoardLayout = field.layout
	if preparation_court != null and preparation_court.visible:
		var floor_rect: Rect2 = preparation_court.floor_for(board)
		_cell_size = floor_rect.size.x / board.width
		_origin = floor_rect.position - global_position
		_update_air(board)
		return
	var available: Vector2 = size - Vector2(0, TITLE_HEIGHT)
	var board_units: Vector2 = Vector2(board.width, board.height * GRID_ASPECT)
	var frame_units: Vector2 = Vector2(2.4, 2.1)
	_cell_size = maxf(1.0, floorf(minf(available.x / (board_units.x + frame_units.x),
			available.y / (board_units.y + frame_units.y))))
	_origin = Vector2(0, TITLE_HEIGHT) + (available - board_units * _cell_size) * 0.5
	_update_air(board)


func _update_air(board: BoardLayout) -> void:
	if _air_material == null or size.x <= 0 or size.y <= 0:
		return
	var extent: Vector2 = Vector2(board.width, board.height * GRID_ASPECT) * _cell_size
	_air_material.set_shader_parameter("board", Vector4(
			_origin.x / size.x, _origin.y / size.y, extent.x / size.x, extent.y / size.y))


func _draw_court_lights() -> void:
	if not has_atmosphere:
		return
	for tower: TowerState in field.towers:
		var visual: TowerVisual = VisualCatalog.get_default().get_tower(tower.data.id)
		if not visual.has_embers:
			continue
		var foot: Vector2 = _to_screen(Vector2(tower.center_milli()))
		CourtAtmosphere.draw_lamp(self, foot, _cell_size, _time, float(tower.id))


func _draw_title() -> void:
	var font: Font = get_theme_default_font()
	var baseline: Vector2 = Vector2(12, TITLE_HEIGHT - 9)
	draw_string_outline(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24,
			TITLE_FONT_SIZE, 4, Color(0, 0, 0, 0.6))
	draw_string(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, TITLE_FONT_SIZE,
			TITLE_COLOR)


func _draw_footprints() -> void:
	for tower: TowerState in field.towers:
		var visual: TowerVisual = VisualCatalog.get_default().get_tower(tower.data.id)
		var cells: Array[Vector2i] = tower.cells()
		for cell: Vector2i in cells:
			var rect: Rect2 = _cell_rect(cell).grow(-1.5)
			if _battle.is_preparation_court:
				draw_rect(rect, Color(visual.plate_color, 0.14))
				_draw_foundation_edges(rect, cell, cells, visual)
				continue
			draw_rect(rect, Color(visual.plate_color, 0.24))
			draw_rect(rect, Color(visual.plate_edge_color, 0.8), false, 1.5)


func _draw_foundation_edges(rect: Rect2, cell: Vector2i, cells: Array[Vector2i],
		visual: TowerVisual) -> void:
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]
	var edge: Color = visual.plate_edge_color.lerp(Color("b9a588"), 0.65)
	for side: int in TowerPainter.NEIGHBORS.size():
		if not cells.has(cell + TowerPainter.NEIGHBORS[side]):
			draw_line(corners[side], corners[(side + 1) % 4], Color(edge, 0.74), 1.3, true)


func _draw_tower_marks() -> void:
	for tower: TowerState in field.towers:
		if field.silence_ticks_left > 0:
			_draw_scorched(tower)
		_draw_boost_mark(tower)
		if tower.id == selected_tower_id:
			for cell: Vector2i in tower.cells():
				draw_rect(_cell_rect(cell).grow(-1.0), _style.selected_color, false, 3.0)
			if tower.data.attacks:
				_draw_range(tower.center_milli(), field.get_tower_range(tower),
						_style.selected_color)
			_draw_neighbor_links(tower)


## Леший: на середине пути мобов отбрасывает назад — отмечаем это место зелёным кругом.
func _draw_knockback_mark() -> void:
	if field.knockback_milli <= 0:
		return
	var center: Vector2 = _to_screen(Vector2(field.get_path_point(field.get_path_end_progress() / 2)))
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.0)
	draw_circle(center, _cell_size * 0.42, Color(LESHY_COLOR, 0.15 + 0.1 * pulse))
	draw_arc(center, _cell_size * 0.42, 0.0, TAU, 24, Color(LESHY_COLOR, 0.8), 2.5, true)
	for i: int in 6:
		var angle: float = TAU * i / 6.0 + _time * 0.6
		draw_circle(center + Vector2.from_angle(angle) * _cell_size * 0.42, _cell_size * 0.06,
				LESHY_COLOR)


## Значок «усилена»: золотой уголок со стрелкой, если соседи или школа дают бонус.
func _draw_boost_mark(tower: TowerState) -> void:
	# Геттер сам пересчитает бонусы, если башни менялись.
	field.get_tower_damage(tower)
	if not tower.data.attacks:
		return
	if tower.bonus_damage_percent <= 0 and tower.bonus_fire_rate_percent <= 0 \
			and tower.bonus_range_milli <= 0:
		return
	var corner: Vector2 = _cell_rect(tower.cells()[0]).position + Vector2.ONE * _cell_size * 0.08
	var mark: float = _cell_size * 0.22
	var triangle: PackedVector2Array = [corner + Vector2(mark * 0.5, 0),
			corner + Vector2(mark, mark), corner + Vector2(0, mark)]
	draw_colored_polygon(triangle, _style.selected_color)
	draw_polyline(triangle + PackedVector2Array([triangle[0]]), Color(0.11, 0.08, 0.06), 1.5)


## Соседи выбранной постройки: золотые линии от центра к центрам соседей.
func _draw_neighbor_links(tower: TowerState) -> void:
	var from: Vector2 = _to_screen(Vector2(tower.center_milli()))
	for neighbor: TowerState in field.get_neighbors(tower):
		var to: Vector2 = _to_screen(Vector2(neighbor.center_milli()))
		draw_line(from, to, Color(_style.selected_color, 0.85), 4.0, true)
		draw_circle(to, _cell_size * 0.1, _style.selected_color)


## Опалённая башня (навык Змея Горыныча): тёмная дымка и тлеющие искры на клетках.
func _draw_scorched(tower: TowerState) -> void:
	for cell: Vector2i in tower.cells():
		var rect: Rect2 = _cell_rect(cell)
		draw_rect(rect.grow(-2.0), SCORCH_SHADE)
		var flicker: float = 0.5 + 0.5 * sin(_time * 9.0 + cell.x * 3.0 + cell.y)
		draw_circle(rect.get_center() + Vector2(0, -_cell_size * 0.15 * flicker),
				_cell_size * 0.12, Color(SCORCH_EMBER, 0.4 + 0.5 * flicker))


func _draw_hover() -> void:
	if _hover == null:
		return
	if _hover.kind == DragPayload.Kind.RITE:
		if _hover_merge_target != null:
			for cell: Vector2i in _hover_merge_target.cells():
				var tint: Color = _style.valid_color if _hover_valid else _style.invalid_color
				draw_rect(_cell_rect(cell).grow(-2), Color(tint, 0.4))
		return
	if _hover_merge_target != null:
		for cell: Vector2i in _hover_merge_target.cells():
			draw_rect(_cell_rect(cell), _style.selected_color, false, 5.0)
		return
	var cells: Array[Vector2i] = TowerState.shape_cells_at(_hover.data.shape, _hover_anchor,
			_hover.rotation)
	var color: Color = _style.valid_color if _hover_valid else _style.invalid_color
	for cell: Vector2i in cells:
		draw_rect(_cell_rect(cell).grow(-2.0), color)
	_draw_range(TowerState.center_of(cells), _hover.data.range_milli, Color(color, 1.0))


func _draw_range(center_milli: Vector2i, range_milli: int, color: Color) -> void:
	var radius: float = range_milli / MILLI * _cell_size
	var center: Vector2 = _to_screen(Vector2(center_milli))
	draw_set_transform(center, 0, Vector2(1, GRID_ASPECT))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.6), 2.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _update_hero_plate() -> void:
	var path: Array[Vector2i] = field.get_active_path()
	var rect: Rect2 = _cell_rect(path[path.size() - 1])
	var strength: float = _hero_shake_left / HERO_SHAKE_SECONDS * HERO_SHAKE_PIXELS
	_battle.hero_shake = Vector2(sin(_time * 50.0), cos(_time * 41.0)) * strength
	_battle.hero_hp = hero_hp
	_battle.hero_plate_center = Vector2(rect.get_center().x, rect.end.y - _cell_size * 0.1)


#endregion


## Сравнивает башни с прошлым кадром: новая — покупка, выросший уровень — слияние,
## пропавшая (без слияния) — продажа. Только для своего поля.
func _track_tower_changes() -> void:
	var has_merge: bool = false
	var has_new: bool = false
	for tower: TowerState in field.towers:
		if not _known_levels.has(tower.id):
			has_new = true
			_pops[tower.id] = POP_SECONDS
		elif _known_levels[tower.id] < tower.level:
			has_merge = true
			_pops[tower.id] = POP_SECONDS
			_battle.play_burst(get_tower_screen_center(tower), MERGE_BURST_COLOR)
	var has_removed: bool = false
	for tower_id: int in _known_levels:
		if field.get_tower(tower_id) == null:
			has_removed = true
			if not has_merge:
				_battle.play_burst(_to_screen(Vector2(_known_centers[tower_id])), SELL_BURST_COLOR)
	if has_merge:
		sound_requested.emit(&"merge")
	elif has_new:
		sound_requested.emit(&"buy")
	elif has_removed:
		sound_requested.emit(&"sell")
	if has_merge or has_new or has_removed or _known_levels.size() != field.towers.size():
		_remember_towers()
	else:
		for tower: TowerState in field.towers:
			_known_centers[tower.id] = tower.center_milli()


func _remember_towers() -> void:
	_known_levels.clear()
	_known_centers.clear()
	for tower: TowerState in field.towers:
		_known_levels[tower.id] = tower.level
		_known_centers[tower.id] = tower.center_milli()


func _to_screen(milli: Vector2) -> Vector2:
	return _origin + milli / MILLI * Vector2(_cell_size, _cell_size * GRID_ASPECT)


func _cell_rect(cell: Vector2i) -> Rect2:
	var first: Vector2 = _to_screen(Vector2(cell) * MILLI)
	var last: Vector2 = _to_screen((Vector2(cell) + Vector2.ONE) * MILLI)
	return Rect2(first, last - first).abs()


func _cell_at(screen_position: Vector2) -> Vector2i:
	var local: Vector2 = (screen_position - _origin) \
			/ Vector2(_cell_size, _cell_size * GRID_ASPECT)
	return Vector2i(floori(local.x), floori(local.y))


func _on_field_tower_fired(tower: TowerState, _mob: MobState) -> void:
	_fire_pulses[tower.id] = FIRE_PULSE_SECONDS


func _on_field_mob_breached(_mob: MobState) -> void:
	_hero_shake_left = HERO_SHAKE_SECONDS


func _on_battle_sound_requested(sound_id: StringName) -> void:
	sound_requested.emit(sound_id)


## Стрелка всегда видна; при выборе подсвечивается реальная полоса на дороге.
func _draw_wind() -> void:
	for tower: TowerState in field.towers:
		if tower.data.wind_length_milli > 0:
			_draw_wind_tower(tower, tower.id == selected_tower_id)
	if _hover != null and _hover.data != null and _hover.data.wind_length_milli > 0 \
			and _hover_merge_target == null:
		var preview: TowerState = TowerState.new()
		preview.data = _hover.data
		preview.anchor = _hover_anchor
		preview.rotation = _hover.rotation
		_draw_wind_tower(preview, true)


func _draw_wind_tower(tower: TowerState, show_area: bool) -> void:
	var direction: Vector2i = DivineCombat.wind_direction(tower)
	var start: Vector2 = _to_screen(Vector2(tower.center_milli()))
	var end: Vector2 = _to_screen(Vector2(tower.center_milli())
			+ Vector2(direction) * MILLI * 1.6)
	var color: Color = Color(0.6, 0.93, 0.79, 0.9)
	draw_line(start, end, color, 3, true)
	var projected_direction: Vector2 = (end - start).normalized()
	var side: Vector2 = projected_direction.orthogonal() * _cell_size * 0.16
	var behind: Vector2 = end - projected_direction * _cell_size * 0.3
	draw_colored_polygon(PackedVector2Array([end, behind + side, behind - side]), color)
	if not show_area:
		return
	var path: Array[Vector2i] = field.get_active_path()
	for i: int in path.size():
		var point: Vector2i = path[i] * FieldState.MILLI + Vector2i(500, 500)
		if not DivineCombat.is_in_wind(field, tower, point):
			continue
		var next: int = mini(i + 1, path.size() - 1)
		var movement: Vector2i = path[next] - path[maxi(0, next - 1)]
		var alignment: int = movement.x * direction.x + movement.y * direction.y
		var tint: Color = Color(0.85, 0.3, 0.2, 0.35) if alignment > 0 \
				else Color(0.3, 0.85, 0.65, 0.3)
		draw_rect(_cell_rect(path[i]).grow(-2), tint)


func _draw_combo_coverage() -> void:
	var selected: TowerState = field.get_tower(selected_tower_id)
	if selected == null:
		return
	var hasher: StateHasher = StateHasher.new()
	hasher.add(selected_tower_id)
	hasher.add(field.path_length)
	for tower: TowerState in field.towers:
		hasher.add_many([tower.id, tower.anchor.x, tower.anchor.y, tower.rotation,
				tower.level, tower.enchantment, tower.awakening])
	for idol: IdolState in field.idols:
		idol.add_to_hash(hasher)
	if hasher.value != _combo_cache_key:
		_combo_cache_key = hasher.value
		_combo_cells = CombatCoverage.reaction_cells(field, selected)
	for cell: Vector2i in _combo_cells:
		var rect: Rect2 = _cell_rect(cell).grow(-_cell_size * 0.18)
		draw_rect(rect, Color(1.0, 0.78, 0.25, 0.28))
		draw_rect(rect, Color(1.0, 0.78, 0.25, 0.8), false, 2.0)


func _draw_rite_targets() -> void:
	if not can_edit or editing_player == null:
		return
	var value: Variant = get_viewport().gui_get_drag_data()
	if not (value is DragPayload):
		return
	var payload: DragPayload = value
	if payload.kind != DragPayload.Kind.RITE or payload.rite.target != RiteData.Target.TOWER:
		return
	for tower: TowerState in field.towers:
		var reason: String = TowerUpgradeGuide.rejection(editing_player, payload.rite, tower.id)
		var tint: Color = _style.valid_color if reason == "" else _style.invalid_color
		for cell: Vector2i in tower.cells():
			draw_rect(_cell_rect(cell).grow(-2), tint, false, 3)


## Осада остаётся заметной и после смены рисовальщика поля.
func _draw_siege_frame() -> void:
	if not is_under_siege:
		return
	var board_size: Vector2 = Vector2(field.layout.width,
			field.layout.height * GRID_ASPECT) * _cell_size
	var pulse: float = 0.5 + 0.5 * sin(_time * SIEGE_PULSE_SPEED)
	draw_rect(Rect2(_origin, board_size).grow(3),
			Color(1.0, 0.3, 0.16, 0.4 + pulse * 0.4), false, 2 + pulse * 2)
