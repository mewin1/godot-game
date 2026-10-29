class_name FieldView
extends Control
## Рисует поле игрока (трава, дорога, декор, башни, терем героя) и принимает перетаскивание
## башен. Мобы, снаряды и эффекты — в дочернем слое BattleLayer (рисуется поверх).
## Только читает FieldState; действия игрока отдаёт наверх сигналом command_requested.

signal command_requested(command: SimCommand)
## Нажатие (без перетаскивания) на клетку: id башни или 0, если там пусто.
signal tower_tapped(tower_id: int)
## Боевой слой просит сыграть звук (звуком управляет экран матча).
signal sound_requested(sound_id: StringName)

const MILLI: float = 1000.0
const TITLE_HEIGHT: float = 34.0
const TITLE_FONT_SIZE: int = 20
const TITLE_COLOR: Color = Color(0.94, 0.89, 0.81)
## Насколько можно сдвинуть палец, чтобы нажатие ещё считалось нажатием, а не перетаскиванием.
const TAP_SLOP: float = 12.0
## Сколько секунд башня «вздрагивает» после выстрела.
const FIRE_PULSE_SECONDS: float = 0.18
const HERO_SHAKE_SECONDS: float = 0.4
const HERO_SHAKE_PIXELS: float = 6.0
const FRAME_MARGIN: float = 0.14
## Терем шире клетки: в долях клетки.
const HERO_WIDTH: float = 1.2
const DECOR_SIZE: float = 0.92
## «Пружинка» башни после покупки или слияния.
const POP_SECONDS: float = 0.35
const SIEGE_PULSE_SPEED: float = 5.0
const POP_STRENGTH: float = 0.3
const MERGE_BURST_COLOR: Color = Color(1.0, 0.82, 0.4)
const SELL_BURST_COLOR: Color = Color(0.75, 0.62, 0.45)

var field: FieldState
var config: GameConfig
var title: String = ""
var hero_hp: int = 0
## Можно ли сейчас менять поле (своё поле в фазе подготовки).
var can_edit: bool = false
var selected_tower_id: int = 0
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
## Множитель урона прорыва в этом раунде — для подписи «−N» над теремом.
var breach_multiplier: int = 1:
	set(value):
		breach_multiplier = value
		_battle.breach_multiplier = value

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
	_battle = BattleLayer.new()
	_battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.sound_requested.connect(_on_battle_sound_requested)
	add_child(_battle)


func _process(delta: float) -> void:
	for tower_id: int in _fire_pulses.keys():
		_fire_pulses[tower_id] -= delta
		if _fire_pulses[tower_id] <= 0.0:
			_fire_pulses.erase(tower_id)
	_hero_shake_left = maxf(0.0, _hero_shake_left - delta)
	_time += delta
	for tower_id: int in _pops.keys():
		_pops[tower_id] -= delta
		if _pops[tower_id] <= 0.0:
			_pops.erase(tower_id)
	if field != null and is_own_field:
		_track_tower_changes()
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
		field.mob_breached.disconnect(_on_field_mob_breached)
	field = field_state
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
	draw_rect(Rect2(Vector2.ZERO, size), _style.background_color)
	if field == null:
		return
	_update_layout()
	_battle.set_layout(_origin, _cell_size)
	_draw_title()
	_draw_board()
	_draw_road()
	_draw_decor()
	_draw_spawn()
	_draw_towers()
	_draw_hover()
	_draw_hero()


func _update_layout() -> void:
	var board: BoardLayout = field.layout
	var available: Vector2 = size - Vector2(0, TITLE_HEIGHT)
	# Поле с рамкой: клетка считается с запасом на рамку с обеих сторон.
	var frame: Vector2 = Vector2.ONE * FRAME_MARGIN * 2.0
	var cells_with_frame: Vector2 = Vector2(board.width, board.height) + frame
	_cell_size = floorf(minf(available.x / cells_with_frame.x, available.y / cells_with_frame.y))
	var board_size: Vector2 = Vector2(board.width, board.height) * _cell_size
	_origin = Vector2(0, TITLE_HEIGHT) + (available - board_size) / 2.0


func _draw_title() -> void:
	var font: Font = get_theme_default_font()
	var baseline: Vector2 = Vector2(12, TITLE_HEIGHT - 9)
	draw_string_outline(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24,
			TITLE_FONT_SIZE, 4, Color(0, 0, 0, 0.6))
	draw_string(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, TITLE_FONT_SIZE,
			TITLE_COLOR)


func _draw_board() -> void:
	var board: BoardLayout = field.layout
	var board_rect: Rect2 = Rect2(_origin, Vector2(board.width, board.height) * _cell_size)
	draw_rect(board_rect.grow(_cell_size * FRAME_MARGIN), _style.frame_color)
	var frame_line: Color = _style.selected_color.darkened(0.55)
	var frame_width: float = 2.0
	if is_under_siege:
		var pulse: float = 0.5 + 0.5 * sin(_time * SIEGE_PULSE_SPEED)
		frame_line = _style.breach_color.lerp(Color(1.0, 0.5, 0.35), pulse)
		frame_width = 3.0 + 3.0 * pulse
	draw_rect(board_rect.grow(_cell_size * FRAME_MARGIN * 0.35), frame_line, false, frame_width)
	var grass_count: int = _style.grass_textures.size()
	for y: int in board.height:
		for x: int in board.width:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = _cell_rect(cell)
			var grass: Texture2D = _style.grass_textures[_cell_hash(cell) % grass_count]
			draw_texture_rect(grass, rect, false)
			if field.is_buildable(cell):
				draw_rect(rect, _style.buildable_tint)
				var grid_color: Color = _style.grid_color
				if not can_edit:
					grid_color.a *= 0.4
				draw_rect(rect.grow(-1.5), grid_color, false, 1.0)
			else:
				draw_rect(rect, _style.blocked_shade)


## Дорога — толстая линия по центрам клеток пути, будущая дорога — бледный пунктир.
func _draw_road() -> void:
	var active: PackedVector2Array = _path_points(field.get_active_path())
	var future: Array[Vector2i] = field.get_future_path()
	if not future.is_empty():
		var future_points: PackedVector2Array = _path_points(future)
		future_points.insert(0, active[active.size() - 1])
		for i: int in future_points.size() - 1:
			draw_dashed_line(future_points[i], future_points[i + 1], _style.future_road_color,
					_cell_size * 0.22, _cell_size * 0.18)
	_draw_thick_path(active, _style.road_edge_color, _cell_size * (_style.road_width + 0.12))
	_draw_thick_path(active, _style.road_color, _cell_size * _style.road_width)
	_draw_thick_path(active, _style.road_light_color, _cell_size * _style.road_width * 0.35)


func _draw_thick_path(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, color, width, true)
	# Круги в точках поворота — иначе толстая линия рисует углы с зазубринами.
	for point: Vector2 in points:
		draw_circle(point, width * 0.5, color, true, -1.0, true)


func _draw_decor() -> void:
	var board: BoardLayout = field.layout
	var reserved: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in field.get_active_path():
		reserved[cell] = true
	for cell: Vector2i in field.get_future_path():
		reserved[cell] = true
	var decor_count: int = _style.decor_textures.size()
	for y: int in board.height:
		for x: int in board.width:
			var cell: Vector2i = Vector2i(x, y)
			if reserved.has(cell) or field.is_buildable(cell):
				continue
			var cell_hash: int = _cell_hash(cell)
			if cell_hash % 100 >= _style.decor_percent:
				continue
			var texture: Texture2D = _style.decor_textures[(cell_hash / 100) % decor_count]
			var decor_size: float = _cell_size * DECOR_SIZE
			var rect: Rect2 = _cell_rect(cell)
			var draw_position: Vector2 = rect.get_center() \
					- Vector2(decor_size * 0.5, decor_size * 0.6)
			draw_texture_rect(texture, Rect2(draw_position, Vector2.ONE * decor_size), false)


func _draw_spawn() -> void:
	var path: Array[Vector2i] = field.get_active_path()
	var rect: Rect2 = _cell_rect(path[0])
	var spawn_size: float = _cell_size * 1.1
	var draw_position: Vector2 = rect.get_center() - Vector2(spawn_size * 0.5, spawn_size * 0.55)
	draw_texture_rect(_style.spawn_texture, Rect2(draw_position, Vector2.ONE * spawn_size), false)


func _draw_towers() -> void:
	for tower: TowerState in field.towers:
		var top_left: Vector2 = _origin + Vector2(tower.anchor) * _cell_size
		var pulse: float = _fire_pulses.get(tower.id, 0.0) / FIRE_PULSE_SECONDS
		if _pops.has(tower.id):
			var progress: float = 1.0 - _pops[tower.id] / POP_SECONDS
			var pop_scale: float = 1.0 + POP_STRENGTH * sin(progress * PI)
			var center: Vector2 = _to_screen(Vector2(tower.center_milli()))
			draw_set_transform(center * (1.0 - pop_scale), 0.0, Vector2.ONE * pop_scale)
		TowerPainter.draw_tower(self, tower.data, tower.rotation, tower.level, top_left, _cell_size,
				pulse)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if tower.id == selected_tower_id:
			for cell: Vector2i in tower.cells():
				draw_rect(_cell_rect(cell).grow(-1.0), _style.selected_color, false, 3.0)
			_draw_range(tower.center_milli(), tower.data.range_milli, _style.selected_color)


func _draw_hover() -> void:
	if _hover == null:
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
	draw_circle(center, radius, Color(color, 0.1))
	draw_arc(center, radius, 0.0, TAU, 64, Color(color, 0.6), 2.0, true)


## Терем в конце пути, под ним табличка с HP. При прорыве терем трясётся.
func _draw_hero() -> void:
	var path: Array[Vector2i] = field.get_active_path()
	var rect: Rect2 = _cell_rect(path[path.size() - 1])
	var shake: Vector2 = Vector2.ZERO
	if _hero_shake_left > 0.0:
		var strength: float = _hero_shake_left / HERO_SHAKE_SECONDS * HERO_SHAKE_PIXELS
		shake = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	var texture: Texture2D = _style.hero_texture
	var width: float = _cell_size * HERO_WIDTH
	var height: float = width * texture.get_height() / texture.get_width()
	var bottom_center: Vector2 = Vector2(rect.get_center().x, rect.end.y + _cell_size * 0.05)
	var draw_position: Vector2 = bottom_center - Vector2(width * 0.5, height) + shake
	draw_texture_rect(texture, Rect2(draw_position, Vector2(width, height)), false)
	if _hero_shake_left > 0.0:
		var flash: Color = Color(_style.breach_color, 0.5 * _hero_shake_left / HERO_SHAKE_SECONDS)
		draw_texture_rect(texture, Rect2(draw_position, Vector2(width, height)), false, flash)
	# Табличку HP рисует боевой слой — поверх мобов, чтобы толпа у терема её не закрывала.
	_battle.hero_hp = hero_hp
	_battle.hero_plate_center = Vector2(rect.get_center().x, rect.end.y - _cell_size * 0.1) + shake


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


func _path_points(cells: Array[Vector2i]) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for cell: Vector2i in cells:
		points.append(_cell_rect(cell).get_center())
	return points


## Устойчивое «случайное» число для клетки: трава и декор не мигают от кадра к кадру.
func _cell_hash(cell: Vector2i) -> int:
	return absi(hash(cell))


func _to_screen(milli: Vector2) -> Vector2:
	return _origin + milli / MILLI * _cell_size


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(cell) * _cell_size, Vector2.ONE * _cell_size)


func _cell_at(screen_position: Vector2) -> Vector2i:
	var local: Vector2 = (screen_position - _origin) / _cell_size
	return Vector2i(floori(local.x), floori(local.y))


func _on_field_tower_fired(tower: TowerState, _mob: MobState) -> void:
	_fire_pulses[tower.id] = FIRE_PULSE_SECONDS


func _on_field_mob_breached(_mob: MobState) -> void:
	_hero_shake_left = HERO_SHAKE_SECONDS


func _on_battle_sound_requested(sound_id: StringName) -> void:
	sound_requested.emit(sound_id)
