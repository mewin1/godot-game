class_name ArenaStage3D
extends SubViewportContainer
## Лесная 3D-арена под полем матча: своя SubViewport с ареной, светом и камерой.
## Только показывает состояние FieldState (башни, мобы, закрытые места) и переводит
## точки поля в экран и обратно (с учётом высот террас и дороги).

const ARENA_SCENE: PackedScene = preload("res://scenes/match_arena_3d.tscn")
const STYLE: Arena3DStyle = preload("res://data/visuals/arena_3d_style.tres")
const MILLI: float = 1000.0
## Наклон и поворот камеры — как в превью арены (вид сверху-спереди, чуть справа).
const CAMERA_PITCH: float = -0.94
const CAMERA_YAW: float = 0.1745
const CAMERA_DISTANCE: float = 70.0
## Объём поля для кадрирования: x 0..18, z −20..0, высоты 0..6.5 м.
const BOARD_MIN: Vector3 = Vector3(0.0, 0.3, -20.0)
const BOARD_MAX: Vector3 = Vector3(18.0, 6.5, 0.0)
const FILL: float = 0.97
const SPEED_SMOOTHING: float = 8.0
const SIDE_SPREAD: float = 0.45
const DEFAULT_CELL_H: float = 3.0

var layout: ArenaLayout3D
## Пикселей на метр после кадрирования (для размеров 2D-эффектов поверх сцены).
var pixels_per_meter: float = 20.0
var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _field: FieldState
var _towers: Dictionary[int, ArenaTower3D] = {}
var _tower_keys: Dictionary[int, int] = {}
var _units: Dictionary[int, ArenaUnit3D] = {}
var _unit_speeds: Dictionary[int, float] = {}
var _unit_positions: Dictionary[int, Vector3] = {}
var _dying: Array[ArenaUnit3D] = []
var _fog: Node3D
var _fog_key: int = -1
var _player_colors: Callable


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_world = ARENA_SCENE.instantiate() as Node3D
	_viewport.add_child(_world)
	_camera = _world.get_node("Camera") as Camera3D
	_camera.rotation = Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)
	_fog = Node3D.new()
	_world.add_child(_fog)


## Подключает поле. player_colors(index) -> Color — цвет кольца армии игрока.
func show_field(field: FieldState, player_colors: Callable) -> void:
	_player_colors = player_colors
	if layout == null:
		layout = ArenaLayout3D.get_shared(field.layout)
	if _field == field:
		return
	_field = field
	_clear_dict_nodes()
	_fog_key = -1


## Кадрирует камеру, чтобы поле заняло прямоугольник target (координаты этого узла).
func frame_board(target: Rect2) -> void:
	if target.size.x < 4.0 or size.y < 4.0:
		return
	var basis: Basis = _camera.transform.basis
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for i: int in 8:
		var corner: Vector3 = Vector3(BOARD_MAX.x if i & 1 else BOARD_MIN.x,
				BOARD_MAX.y if i & 2 else BOARD_MIN.y, BOARD_MAX.z if i & 4 else BOARD_MIN.z)
		var local: Vector3 = basis.inverse() * corner
		low = low.min(Vector2(local.x, local.y))
		high = high.max(Vector2(local.x, local.y))
	var extent: Vector2 = high - low
	pixels_per_meter = minf(target.size.x / extent.x, target.size.y / extent.y) * FILL
	_camera.size = size.y / pixels_per_meter
	var center: Vector2 = (low + high) * 0.5
	var offset: Vector2 = (target.get_center() - size * 0.5) / pixels_per_meter
	var camera_local: Vector3 = Vector3(center.x - offset.x, center.y + offset.y, 0.0)
	_camera.position = basis * camera_local + basis.z * CAMERA_DISTANCE


## Точка сцены → координаты этого узла.
func project(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)


## Точка поля (тысячные клетки) на поверхности, поднятая на lift метров.
func project_milli(milli: Vector2, lift: float = 0.0) -> Vector2:
	return project(layout.milli_to_world(milli) + Vector3(0, lift, 0))


## Угол клетки на высоте этой клетки (для обводки клеток с учётом террас).
func project_cell_corner(cell: Vector2i, corner: Vector2, lift: float = 0.0) -> Vector2:
	var flat: Vector2 = layout.corner_xz((Vector2(cell) + corner) * MILLI)
	return project(Vector3(flat.x, layout.cell_height(cell) + lift, flat.y))


## Клетка под точкой экрана: луч против плоскостей террас, берётся ближайшее попадание.
func cell_at(point: Vector2) -> Vector2i:
	var origin: Vector3 = _camera.project_ray_origin(point)
	var direction: Vector3 = _camera.project_ray_normal(point)
	if absf(direction.y) < 0.0001 or _field == null:
		return Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_t: float = INF
	var board: BoardLayout = _field.layout
	for y: int in board.height:
		for x: int in board.width:
			var cell: Vector2i = Vector2i(x, y)
			var t: float = (layout.cell_height(cell) - origin.y) / direction.y
			if t <= 0.0 or t >= best_t:
				continue
			var hit: Vector3 = origin + direction * t
			var low: Vector2 = layout.corner_xz(Vector2(cell) * MILLI)
			if hit.x >= low.x and hit.x < low.x + layout.cell_m \
					and hit.z >= low.y and hit.z < low.y + layout.cell_m:
				best = cell
				best_t = t
	if best.x >= 0:
		return best
	var flat_t: float = (DEFAULT_CELL_H - origin.y) / direction.y
	var flat: Vector3 = origin + direction * flat_t
	return Vector2i(floori(flat.x / layout.cell_m), floori((flat.z + 20.0) / layout.cell_m))


## Обновляет 3D-башни, юнитов и закрытые места по состоянию поля.
func sync(delta: float, interpolation: float) -> void:
	if _field == null:
		return
	_sync_fog()
	_sync_towers()
	_sync_units(delta, interpolation)


## Выстрел башни — короткое вздрагивание модели.
func pulse_tower(tower_id: int) -> void:
	if _towers.has(tower_id):
		_towers[tower_id].pulse()


## Высота головы моба над дорогой (для полоски HP поверх сцены).
func mob_head(mob: MobState, interpolation: float) -> Vector2:
	var world: Vector3 = _mob_world(mob, interpolation)
	return project(world + Vector3(0, STYLE.get_mob_height(mob.data.id) * 1.15 + 0.2, 0))


func mob_feet(mob: MobState, interpolation: float) -> Vector2:
	return project(_mob_world(mob, interpolation))


func _mob_world(mob: MobState, interpolation: float) -> Vector3:
	var progress: float = lerpf(mob.previous_progress, mob.progress, interpolation)
	var length: float = layout.progress_to_length(progress)
	var point: Vector3 = layout.road_point(length)
	var direction: Vector3 = layout.road_direction(length)
	var side: float = (float((mob.id * 7919) % 11) / 10.0 - 0.5) * 2.0 * SIDE_SPREAD
	point += Vector3(-direction.z, 0, direction.x) * side
	if mob.data.is_flying:
		point.y += STYLE.fly_height
	return point


func _sync_towers() -> void:
	var seen: Dictionary[int, bool] = {}
	for tower: TowerState in _field.towers:
		seen[tower.id] = true
		var key: int = hash([tower.data.id, tower.level, tower.anchor, tower.rotation])
		if _towers.has(tower.id) and _tower_keys[tower.id] == key:
			continue
		var is_new: bool = not _towers.has(tower.id)
		var was_merge: bool = not is_new
		if _towers.has(tower.id):
			_towers[tower.id].queue_free()
		var node: ArenaTower3D = _build_tower(tower)
		_towers[tower.id] = node
		_tower_keys[tower.id] = key
		if is_new or was_merge:
			node.pop()
	for tower_id: int in _towers.keys():
		if not seen.has(tower_id):
			_towers[tower_id].queue_free()
			_towers.erase(tower_id)
			_tower_keys.erase(tower_id)


func _build_tower(tower: TowerState) -> ArenaTower3D:
	var cells: Array[Vector2i] = tower.cells()
	var top: float = -INF
	for cell: Vector2i in cells:
		top = maxf(top, layout.cell_height(cell))
	var flat: Vector2 = layout.corner_xz(Vector2(tower.center_milli()))
	var origin: Vector3 = Vector3(flat.x, top, flat.y)
	var offsets: Array[Vector3] = []
	for cell: Vector2i in cells:
		offsets.append(layout.cell_center(cell) - origin)
	var node: ArenaTower3D = ArenaTower3D.new()
	_world.add_child(node)
	node.position = origin
	node.build(tower, STYLE, offsets)
	return node


func _sync_units(delta: float, interpolation: float) -> void:
	var seen: Dictionary[int, bool] = {}
	for mob: MobState in _field.mobs:
		seen[mob.id] = true
		var unit: ArenaUnit3D = _units.get(mob.id)
		if unit == null:
			unit = ArenaUnit3D.new()
			_world.add_child(unit)
			var sender: Color = Color(0, 0, 0, 0)
			if mob.sender_index >= 0 and _player_colors.is_valid():
				sender = _player_colors.call(mob.sender_index)
			unit.build(STYLE.get_mob_model(mob.data.id), STYLE.get_mob_tint(mob.data.id),
					STYLE.get_mob_height(mob.data.id), sender)
			_units[mob.id] = unit
		var world: Vector3 = _mob_world(mob, interpolation)
		var previous: Vector3 = _unit_positions.get(mob.id, world)
		var moved: Vector3 = world - previous
		moved.y = 0.0
		var speed: float = moved.length() / maxf(delta, 0.001)
		var last_speed: float = _unit_speeds.get(mob.id, speed)
		var smoothed: float = lerpf(last_speed, speed,
				clampf(delta * SPEED_SMOOTHING, 0.0, 1.0))
		_unit_speeds[mob.id] = smoothed
		_unit_positions[mob.id] = world
		unit.position = world
		if moved.length() > 0.002:
			unit.rotation.y = lerp_angle(unit.rotation.y, atan2(moved.x, moved.z),
					clampf(delta * 10.0, 0.0, 1.0))
		unit.animate(delta, smoothed, STYLE.steps_per_meter)
	for mob_id: int in _units.keys():
		if not seen.has(mob_id):
			var unit: ArenaUnit3D = _units[mob_id]
			unit.dying_left = ArenaUnit3D.DEATH_SECONDS
			_dying.append(unit)
			_units.erase(mob_id)
			_unit_speeds.erase(mob_id)
			_unit_positions.erase(mob_id)
	for i: int in range(_dying.size() - 1, -1, -1):
		if _dying[i].update_death(delta):
			_dying[i].queue_free()
			_dying.remove_at(i)


## Закрытые террасы и неоткрытая дорога — тёмный туман; конец открытой дороги — завал.
func _sync_fog() -> void:
	var key: int = hash([_field.path_length, _field.get_buildable_cells().size()])
	if key == _fog_key:
		return
	_fog_key = key
	for child: Node in _fog.get_children():
		child.queue_free()
	var fog: StandardMaterial3D = ArenaMaterials3D.flat(STYLE.fog_color)
	var edge: StandardMaterial3D = ArenaMaterials3D.flat(STYLE.fog_edge_color)
	var path: Array[Vector2i] = _field.layout.path_cells
	for y: int in _field.layout.height:
		for x: int in _field.layout.width:
			var cell: Vector2i = Vector2i(x, y)
			if path.has(cell) or _field.is_buildable(cell):
				continue
			var center: Vector3 = layout.cell_center(cell)
			ArenaMaterials3D.part(_fog, _plane(Vector2(1.96, 1.96)), fog, center + Vector3(0, 0.04, 0))
			ArenaMaterials3D.part(_fog, _plane(Vector2(1.5, 1.5)), edge, center + Vector3(0, 0.05, 0))
	var start: float = layout.path_length_at(_field.path_length - 1) + layout.cell_m * 0.5
	if _field.path_length < path.size():
		_fog.add_child(_road_ribbon(start, layout.road_end_length(), fog))
		_add_barricade(start)


func _plane(extent: Vector2) -> PlaneMesh:
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = extent
	return mesh


## Полоса тумана вдоль дороги от length_from до length_to.
func _road_ribbon(length_from: float, length_to: float, material: Material) -> MeshInstance3D:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = 0.5
	var length: float = length_from
	while length < length_to:
		var next: float = minf(length + step, length_to)
		var a: Vector3 = layout.road_point(length) + Vector3(0, 0.08, 0)
		var b: Vector3 = layout.road_point(next) + Vector3(0, 0.08, 0)
		var side_a: Vector3 = _side(length) * 1.7
		var side_b: Vector3 = _side(next) * 1.7
		tool.add_vertex(a - side_a)
		tool.add_vertex(a + side_a)
		tool.add_vertex(b + side_b)
		tool.add_vertex(a - side_a)
		tool.add_vertex(b + side_b)
		tool.add_vertex(b - side_b)
		length = next
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	return instance


func _side(length: float) -> Vector3:
	var direction: Vector3 = layout.road_direction(length)
	return Vector3(-direction.z, 0, direction.x)


## Завал поперёк дороги: два столба и перекрещённые брёвна.
func _add_barricade(length: float) -> void:
	var holder: Node3D = Node3D.new()
	_fog.add_child(holder)
	holder.position = layout.road_point(length)
	var direction: Vector3 = layout.road_direction(length)
	holder.rotation.y = atan2(direction.x, direction.z)
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.WOOD)
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.DARK_WOOD)
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.12, 0.1, 1.3, 6), dark,
				Vector3(side * 1.25, 0.65, 0))
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.09, 0.09, 2.9, 6), wood,
				Vector3(0, 0.6, 0.05 * side), Vector3(0, 0, PI * 0.5 + side * 0.32))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.1, 0.1, 2.7, 6), wood,
			Vector3(0, 1.05, 0), Vector3(0, 0, PI * 0.5))


func _clear_dict_nodes() -> void:
	for node: ArenaTower3D in _towers.values():
		node.queue_free()
	for unit: ArenaUnit3D in _units.values():
		unit.queue_free()
	for unit: ArenaUnit3D in _dying:
		unit.queue_free()
	_towers.clear()
	_tower_keys.clear()
	_units.clear()
	_unit_speeds.clear()
	_unit_positions.clear()
	_dying.clear()
