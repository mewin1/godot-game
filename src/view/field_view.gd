class_name FieldView
extends Control
## Рисует поле игрока квадратиками и принимает перетаскивание башен.
## Только читает FieldState; действия игрока отдаёт наверх сигналом command_requested.

signal command_requested(command: SimCommand)
## Нажатие (без перетаскивания) на клетку: id башни или 0, если там пусто.
signal tower_tapped(tower_id: int)

const MILLI: float = 1000.0
const TITLE_HEIGHT: float = 34.0
const TITLE_FONT_SIZE: int = 22
const SHOT_LIFETIME: float = 0.12
## Насколько можно сдвинуть палец, чтобы нажатие ещё считалось нажатием, а не перетаскиванием.
const TAP_SLOP: float = 12.0

const COLOR_BACKGROUND: Color = Color(0.09, 0.1, 0.13)
const COLOR_CELL: Color = Color(0.14, 0.15, 0.19)
const COLOR_BUILDABLE: Color = Color(0.21, 0.33, 0.24)
const COLOR_PATH: Color = Color(0.62, 0.53, 0.36)
const COLOR_FUTURE_PATH: Color = Color(0.27, 0.24, 0.2)
const COLOR_ENTRY: Color = Color(0.4, 0.85, 0.45)
const COLOR_HERO: Color = Color(0.95, 0.3, 0.35)
const COLOR_SELECTED: Color = Color(1.0, 0.95, 0.4)
const COLOR_VALID: Color = Color(0.4, 1.0, 0.5, 0.45)
const COLOR_INVALID: Color = Color(1.0, 0.3, 0.3, 0.45)
const COLOR_RANGE: Color = Color(1, 1, 1, 0.12)

var field: FieldState
var config: GameConfig
var title: String = ""
var hero_hp: int = 0
## Можно ли сейчас менять поле (своё поле в фазе подготовки).
var can_edit: bool = false
var selected_tower_id: int = 0
## Доля пути до следующего тика (0..1): мобы рисуются плавно между тиками.
var interpolation: float = 0.0

var _cell_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO
var _hover: DragPayload
var _hover_anchor: Vector2i = Vector2i.ZERO
var _hover_valid: bool = false
var _hover_merge_target: TowerState
var _press_position: Vector2 = Vector2.ZERO
var _shots: Array[Shot] = []


func _process(delta: float) -> void:
	var alive_shots: Array[Shot] = []
	for shot: Shot in _shots:
		shot.time_left -= delta
		if shot.time_left > 0.0:
			alive_shots.append(shot)
	_shots = alive_shots
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hover = null
		_hover_merge_target = null


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or field == null:
		return
	if button.pressed:
		_press_position = button.position
	elif button.position.distance_to(_press_position) <= TAP_SLOP:
		var tower: TowerState = field.get_tower_at(_cell_at(button.position))
		tower_tapped.emit(tower.id if tower != null else 0)


## Подключает поле. Повторный вызов с другим полем переключает отображение.
func show_field(field_state: FieldState, game_config: GameConfig, caption: String) -> void:
	title = caption
	config = game_config
	if field == field_state:
		return
	if field != null:
		field.tower_fired.disconnect(_on_field_tower_fired)
	field = field_state
	_shots.clear()
	field.tower_fired.connect(_on_field_tower_fired)


#region Перетаскивание

func _get_drag_data(at_position: Vector2) -> Variant:
	if not can_edit or field == null:
		return null
	var tower: TowerState = field.get_tower_at(_cell_at(at_position))
	if tower == null:
		return null
	set_drag_preview(ShapePreview.create_drag_preview(tower.data, tower.rotation, tower.level,
			_cell_size * 0.6))
	return DragPayload.for_tower(tower)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not can_edit or field == null or not (data is DragPayload):
		_hover = null
		return false
	var payload: DragPayload = data
	_update_hover(payload, at_position)
	return _hover_valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload: DragPayload = data
	var command: SimCommand = _make_drop_command(payload)
	_hover = null
	_hover_merge_target = null
	if command != null:
		command_requested.emit(command)


func _update_hover(payload: DragPayload, at_position: Vector2) -> void:
	_hover = payload
	var cell: Vector2i = _cell_at(at_position)
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
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	if field == null:
		return
	_update_layout()
	draw_string(get_theme_default_font(), Vector2(12, TITLE_HEIGHT - 8), title,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, TITLE_FONT_SIZE)
	_draw_cells()
	_draw_path_markers()
	_draw_towers()
	_draw_hover()
	_draw_mobs()
	_draw_shots()


func _update_layout() -> void:
	var board: BoardLayout = field.layout
	var available: Vector2 = size - Vector2(0, TITLE_HEIGHT)
	_cell_size = floorf(minf(available.x / board.width, available.y / board.height))
	var board_size: Vector2 = Vector2(board.width, board.height) * _cell_size
	_origin = Vector2(0, TITLE_HEIGHT) + (available - board_size) / 2.0


func _draw_cells() -> void:
	var board: BoardLayout = field.layout
	for y: int in board.height:
		for x: int in board.width:
			var cell: Vector2i = Vector2i(x, y)
			var color: Color = COLOR_BUILDABLE if field.is_buildable(cell) else COLOR_CELL
			draw_rect(_cell_rect(cell).grow(-1.0), color)
	for cell: Vector2i in field.get_future_path():
		draw_rect(_cell_rect(cell).grow(-1.0), COLOR_FUTURE_PATH)
	for cell: Vector2i in field.get_active_path():
		draw_rect(_cell_rect(cell).grow(-1.0), COLOR_PATH)


func _draw_path_markers() -> void:
	var path: Array[Vector2i] = field.get_active_path()
	var entry: Rect2 = _cell_rect(path[0])
	draw_rect(entry.grow(-_cell_size * 0.3), COLOR_ENTRY)
	var hero: Rect2 = _cell_rect(path[path.size() - 1]).grow(-_cell_size * 0.08)
	draw_rect(hero, COLOR_HERO)
	draw_string(get_theme_default_font(), hero.position + Vector2(0, hero.size.y * 0.68),
			str(hero_hp), HORIZONTAL_ALIGNMENT_CENTER, hero.size.x, int(_cell_size * 0.42))


func _draw_towers() -> void:
	for tower: TowerState in field.towers:
		var top_left: Vector2 = _origin + Vector2(tower.anchor) * _cell_size
		ShapePreview.draw_shape(self, tower.data, tower.rotation, tower.level, top_left, _cell_size)
		if tower.id == selected_tower_id:
			for cell: Vector2i in tower.cells():
				draw_rect(_cell_rect(cell), COLOR_SELECTED, false, 3.0)
			_draw_range(tower.center_milli(), tower.data.range_milli)


func _draw_hover() -> void:
	if _hover == null:
		return
	if _hover_merge_target != null:
		for cell: Vector2i in _hover_merge_target.cells():
			draw_rect(_cell_rect(cell), COLOR_SELECTED, false, 5.0)
		return
	var cells: Array[Vector2i] = TowerState.shape_cells_at(_hover.data.shape, _hover_anchor,
			_hover.rotation)
	for cell: Vector2i in cells:
		draw_rect(_cell_rect(cell).grow(-2.0), COLOR_VALID if _hover_valid else COLOR_INVALID)
	_draw_range(TowerState.center_of(cells), _hover.data.range_milli)


func _draw_range(center_milli: Vector2i, range_milli: int) -> void:
	var radius: float = range_milli / MILLI * _cell_size
	draw_circle(_to_screen(Vector2(center_milli)), radius, COLOR_RANGE)
	draw_arc(_to_screen(Vector2(center_milli)), radius, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)


func _draw_mobs() -> void:
	for mob: MobState in field.mobs:
		var center: Vector2 = _mob_screen_position(mob)
		var half: float = mob.data.view_size * _cell_size / 2.0
		var body: Rect2 = Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
		var color: Color = mob.data.color
		if mob.slow_percent > 0:
			color = color.lerp(Color(0.5, 0.8, 1.0), 0.5)
		draw_rect(body, color)
		draw_rect(body, color.darkened(0.5), false, 2.0)
		_draw_hp_bar(body, float(mob.hp) / mob.max_hp)


func _draw_hp_bar(body: Rect2, ratio: float) -> void:
	var bar: Rect2 = Rect2(body.position + Vector2(0, -7), Vector2(body.size.x, 4))
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)),
			Color(0.4, 1.0, 0.4))


func _draw_shots() -> void:
	for shot: Shot in _shots:
		var alpha: float = shot.time_left / SHOT_LIFETIME
		var color: Color = Color(shot.color, alpha)
		draw_line(_to_screen(shot.from), _to_screen(shot.to), color, 3.0)

#endregion


func _mob_screen_position(mob: MobState) -> Vector2:
	var previous: Vector2 = Vector2(field.get_path_point(mob.previous_progress))
	var current: Vector2 = Vector2(field.get_path_point(mob.progress))
	return _to_screen(previous.lerp(current, interpolation))


func _to_screen(milli: Vector2) -> Vector2:
	return _origin + milli / MILLI * _cell_size


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(cell) * _cell_size, Vector2.ONE * _cell_size)


func _cell_at(screen_position: Vector2) -> Vector2i:
	var local: Vector2 = (screen_position - _origin) / _cell_size
	return Vector2i(floori(local.x), floori(local.y))


func _on_field_tower_fired(tower: TowerState, mob: MobState) -> void:
	var shot: Shot = Shot.new()
	shot.from = Vector2(tower.center_milli())
	shot.to = Vector2(field.get_mob_position(mob))
	shot.color = tower.data.color.lightened(0.3)
	shot.time_left = SHOT_LIFETIME
	_shots.append(shot)


## Короткая вспышка выстрела от башни к мобу.
class Shot:
	var from: Vector2
	var to: Vector2
	var color: Color
	var time_left: float
