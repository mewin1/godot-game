class_name NoirArena3D
extends Node3D
## Арена «славянский нуар» по new_concept/05_arena.jpg: мощёный двор, дорога, частокол с воротами
## у входа дороги, жаровни по углам, терем в конце дороги, лес с интервалами в дымке.
## Двор растёт с уровнем магазина: частокол обносит только открытую часть поля (клетки в радиусе
## постройки от открытого пути), терем стоит за частоколом в конце открытой дороги. Закрытая часть
## поля — лесная подстилка с кустами и подлеском. Реквизит — GLB из сеток Hunyuan3D
## (assets/noir_h3d/arena/<id>.glb); нет файла — деталь пропускается.
## Поле: X 0..18, Z -20..0 (клетка 2 м, как ArenaLayout3D). Только вид: правила не меняются.

const PROPS: String = "res://assets/noir_h3d/arena/%s.glb"
const BOARD_MIN: Vector2 = Vector2(0.0, -20.0)
const BOARD_MAX: Vector2 = Vector2(18.0, 0.0)
const CELL: float = 2.0
## Мелкая сетка двора (м): клетка поля — 2×2 мелких, частокол отступает от открытых клеток на 1 мелкую.
const FINE: float = 1.0
const YARD_PAD: int = 1
const GATE_WIDTH: float = 3.2
const FIRE_COLOR: Color = Color(1.0, 0.52, 0.18)
const ROAD_HALF_WIDTH: float = 1.0
## Стена и жаровни крупнее, как на концепте арены (стена выше человека, жаровни — по пояс-грудь).
const WALL_SCALE: float = 1.25
const FIRE_SCALE: float = 1.6
const TORCH_STEP: float = 7.0
const ROAD_EDGE: Color = Color(0.42, 0.4, 0.42)
const TEREM_OFFSET: float = 4.4
const TEREM_SCALE: float = 2.3
## Лес: россыпь с интервалами (как на концепте — стволы стоят порознь, между ними дымка).
const FOREST_MIN: Vector2 = Vector2(-26.0, -52.0)
const FOREST_MAX: Vector2 = Vector2(44.0, 14.0)
const TREE_GAP: float = 3.1
## Вокруг поля полоса без деревьев (частокол, терем); у ближнего к камере края — шире, чтобы не закрыть двор.
const CLEAR_FAR: float = 7.5
const CLEAR_SIDE: float = 4.5
const CLEAR_NEAR: float = 9.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _layout: ArenaLayout3D
var _yard: Node3D
var _open_key: int = -1
var _terem_scene: PackedScene


func _ready() -> void:
	_rng.seed = 22
	_build_ground()


## Неизменная часть (земля леса, лес, дымка) — один раз, когда ArenaStage3D получит раскладку.
func build_for_layout(layout: ArenaLayout3D) -> void:
	if _layout != null:
		return
	_layout = layout
	_terem_scene = NoirModels.base()
	_build_forest()
	_build_mist()


## Двор под открытую часть поля: вызывается при смене длины пути (уровня магазина).
func set_open(field: FieldState) -> void:
	if _layout == null:
		return
	var key: int = hash([field.path_length, field.config.build_radius])
	if key == _open_key:
		return
	_open_key = key
	if _yard != null:
		_yard.queue_free()
	_yard = Node3D.new()
	_yard.name = "Yard"
	add_child(_yard)
	var path: Array[Vector2i] = field.get_active_path()
	var cells: Dictionary[Vector2i, bool] = _open_cells(field, path)
	var fine: Dictionary[Vector2i, bool] = _fine_region(cells)
	var end_cell: Vector2i = path[path.size() - 1]
	var outward: Vector2i = _edge_direction(field.layout, path)
	var end_point: Vector3 = _layout.cell_center(end_cell)
	var out3: Vector3 = Vector3(outward.x, 0, outward.y)
	var door: Vector3 = end_point + out3 * (CELL * 0.5 + YARD_PAD * FINE + 0.6)
	var terem_at: Vector3 = end_point + out3 * TEREM_OFFSET
	_build_paving(fine)
	_build_road(_layout.path_length_at(path.size() - 1), door, out3)
	_build_terem(terem_at, out3)
	var entry: Vector3 = _layout.road_point(0.0)
	_build_walls(fine, Vector2(entry.x, entry.z), Vector2(door.x, door.z))
	_build_fires(fine, Vector2(terem_at.x, terem_at.z))
	_build_undergrowth(field.layout, cells, fine)


## Открытые клетки: в радиусе постройки от открытого пути (как места для построек), включая
## будущий путь рядом — двор без дыр.
func _open_cells(field: FieldState, path: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var radius: int = field.config.build_radius
	var cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in path:
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var near: Vector2i = cell + Vector2i(dx, dy)
				if field.layout.is_inside(near):
					cells[near] = true
	return cells


## Мелкие клетки двора: открытые клетки поля с отступом YARD_PAD под частокол.
func _fine_region(cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var fine: Dictionary[Vector2i, bool] = {}
	var per: int = int(CELL / FINE)
	for cell: Vector2i in cells:
		for fy: int in range(cell.y * per - YARD_PAD, (cell.y + 1) * per + YARD_PAD):
			for fx: int in range(cell.x * per - YARD_PAD, (cell.x + 1) * per + YARD_PAD):
				fine[Vector2i(fx, fy)] = true
	return fine


static func _fine_to_world(fine: Vector2) -> Vector2:
	return Vector2(BOARD_MIN.x + fine.x * FINE, BOARD_MIN.y + fine.y * FINE)


## Куда терем от конца пути: наружу через ближайший край поля (путь всегда кончается у края).
func _edge_direction(board: BoardLayout, path: Array[Vector2i]) -> Vector2i:
	var end_cell: Vector2i = path[path.size() - 1]
	if path.size() >= 2:
		var step: Vector2i = end_cell - path[path.size() - 2]
		if not board.is_inside(end_cell + step):
			return step
	var options: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var best: Vector2i = Vector2i(0, -1)
	var best_gap: int = 1 << 30
	for option: Vector2i in options:
		var gap: int = 0
		var probe: Vector2i = end_cell + option
		while board.is_inside(probe):
			gap += 1
			probe += option
		if gap < best_gap:
			best_gap = gap
			best = option
	return best


func _prop(id: String) -> Node3D:
	var path: String = PROPS % id
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _place(id: String, at: Vector3, yaw: float = 0.0, scale_by: float = 1.0, parent: Node3D = null) -> Node3D:
	var node: Node3D = _prop(id)
	if node == null:
		return null
	(parent if parent != null else _yard).add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_by
	return node


static func _textured(path: String, uv_scale: Vector3, roughness: float = 0.9) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	material.uv1_scale = uv_scale
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _build_ground() -> void:
	var outside: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(160, 160)
	outside.mesh = plane
	outside.material_override = _textured("res://assets/noir/arena/tex/forest_floor.png", Vector3(26, 26, 1))
	outside.position = Vector3(9, -0.04, -14)
	add_child(outside)


## Плиты двора по мелким клеткам открытой части; швы плит — по мировой сетке (по краям клеток поля).
func _build_paving(fine: Dictionary[Vector2i, bool]) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for cell: Vector2i in fine:
		var a: Vector2 = _fine_to_world(Vector2(cell))
		var b: Vector2 = a + Vector2(FINE, FINE)
		var corners: Array[Vector3] = [Vector3(a.x, -0.01, a.y), Vector3(b.x, -0.01, a.y),
				Vector3(b.x, -0.01, b.y), Vector3(a.x, -0.01, b.y)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(corners[index])
	var yard: MeshInstance3D = MeshInstance3D.new()
	yard.mesh = tool.commit()
	var material: StandardMaterial3D = _textured("res://assets/noir/arena/tex/courtyard.png", Vector3.ONE, 0.55)
	material.albedo_color = Color(0.78, 0.76, 0.76)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.25, 0.25, 0.25)
	yard.material_override = material
	_yard.add_child(yard)


## Утоптанная светлая дорога поверх плит: от ворот до конца открытого пути и дальше к крыльцу терема.
func _build_road(finish: float, door: Vector3, out3: Vector3) -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var sides: PackedVector3Array = PackedVector3Array()
	var length: float = -2.0
	while length < finish:
		var at: float = maxf(length, 0.0)
		var point: Vector3 = _layout.road_point(at)
		if length < 0.0:  # продолжение за ворота
			point = _layout.road_point(0.0) + _layout.road_direction(0.0) * length
		points.append(point)
		sides.append(_side(_layout.road_direction(at)))
		length += 0.4
	# к терему — плавный поворот (кривая Безье) из направления дороги наружу через край поля
	var start: Vector3 = _layout.road_point(finish)
	var tangent: Vector3 = _layout.road_direction(finish)
	var reach: float = start.distance_to(door)
	var control: Vector3 = start + tangent * reach * 0.45
	for k: int in 13:
		var t: float = k / 12.0
		var point: Vector3 = start.lerp(control, t).lerp(control.lerp(door, t), t)
		var direction: Vector3 = (control - start).lerp(door - control, t)
		direction.y = 0.0
		points.append(Vector3(point.x, start.y, point.z))
		sides.append(_side(direction.normalized() if direction.length() > 0.01 else out3))
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	var lift: Vector3 = Vector3(0, 0.025, 0)
	var shade: Array[Color] = [ROAD_EDGE, Color.WHITE, ROAD_EDGE]
	var us: Array[float] = [0.0, 0.5, 1.0]
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side_a: Vector3 = sides[i] * ROAD_HALF_WIDTH
		var side_b: Vector3 = sides[i + 1] * ROAD_HALF_WIDTH
		var v0: float = along / 4.0
		var v1: float = (along + (b - a).length()) / 4.0
		# три ряда вершин: тёмный край — светлая утоптанная середина — тёмный край
		var rows_a: Array[Vector3] = [a - side_a + lift, a + lift * 1.2, a + side_a + lift]
		var rows_b: Array[Vector3] = [b - side_b + lift, b + lift * 1.2, b + side_b + lift]
		for k: int in 2:
			_road_vertex(tool, rows_a[k], us[k], v0, shade[k])
			_road_vertex(tool, rows_b[k + 1], us[k + 1], v1, shade[k + 1])
			_road_vertex(tool, rows_a[k + 1], us[k + 1], v0, shade[k + 1])
			_road_vertex(tool, rows_a[k], us[k], v0, shade[k])
			_road_vertex(tool, rows_b[k], us[k], v1, shade[k])
			_road_vertex(tool, rows_b[k + 1], us[k + 1], v1, shade[k + 1])
		along += (b - a).length()
	var road: MeshInstance3D = MeshInstance3D.new()
	road.mesh = tool.commit()
	var material: StandardMaterial3D = _textured("res://assets/noir/arena/tex/road.png", Vector3(1, 1, 1))
	material.albedo_color = Color(0.7, 0.57, 0.45)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yard.add_child(road)


static func _road_vertex(tool: SurfaceTool, at: Vector3, u: float, v: float, shade: Color) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_color(shade)
	tool.set_uv(Vector2(u, v))
	tool.add_vertex(at)


static func _side(direction: Vector3) -> Vector3:
	return Vector3(-direction.z, 0, direction.x)


func _build_terem(at: Vector3, out3: Vector3) -> void:
	if _terem_scene == null:
		return
	# терем за частоколом в конце дороги (как на концепте) и смотрит навстречу дороге
	var house: Node3D = _terem_scene.instantiate() as Node3D
	_yard.add_child(house)
	house.position = Vector3(at.x, 0, at.z)
	house.rotation.y = atan2(-out3.x, -out3.z)
	house.scale = Vector3.ONE * TEREM_SCALE  # на концепте арены терем — самый большой дом двора
	_warm_light(house.position - out3 * 2.2 + Vector3(0, 2.4, 0), 4.0, 9.0)
	var plate_scene: PackedScene = NoirModels.base_plate()
	if plate_scene != null:
		house.add_child(plate_scene.instantiate())


## Отрезки стены: границы мелких клеток двора, слитые в прямые пробеги. Наружная нормаль — out.
class Run:
	var a: Vector2
	var b: Vector2
	var out: Vector2


func _wall_runs(fine: Dictionary[Vector2i, bool]) -> Array[Run]:
	# ребро между клеткой двора и внешней: ключ — (направление наружу, линия), значение — позиции вдоль линии
	var lines: Dictionary[Vector3i, Array] = {}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell: Vector2i in fine:
		for d: int in 4:
			var dir: Vector2i = dirs[d]
			if fine.has(cell + dir):
				continue
			var line: int = cell.x + (1 if dir.x > 0 else 0) if dir.x != 0 else cell.y + (1 if dir.y > 0 else 0)
			var pos: int = cell.y if dir.x != 0 else cell.x
			var key: Vector3i = Vector3i(d, line, 0)
			if not lines.has(key):
				lines[key] = []
			lines[key].append(pos)
	var runs: Array[Run] = []
	for key: Vector3i in lines:
		var positions: Array = lines[key]
		positions.sort()
		var dir: Vector2i = dirs[key.x]
		var first: int = positions[0]
		var last: int = first
		for i: int in range(1, positions.size() + 1):
			var pos: int = positions[i] if i < positions.size() else 1 << 30
			if pos == last + 1:
				last = pos
				continue
			var run: Run = Run.new()
			if dir.x != 0:
				run.a = _fine_to_world(Vector2(key.y, first))
				run.b = _fine_to_world(Vector2(key.y, last + 1))
			else:
				run.a = _fine_to_world(Vector2(first, key.y))
				run.b = _fine_to_world(Vector2(last + 1, key.y))
			run.out = Vector2(dir)
			runs.append(run)
			first = pos
			last = pos
	return runs


## Частокол по границе двора; проём ворот там, где дорога входит на поле, и у крыльца терема.
func _build_walls(fine: Dictionary[Vector2i, bool], entry: Vector2, door: Vector2) -> void:
	var probe: Node3D = _prop("palisade")
	var segment: float = 2.2
	var long_axis_x: bool = true
	if probe != null:
		var box: AABB = _bounds(probe)
		long_axis_x = box.size.x >= box.size.z
		segment = maxf(box.size.x, box.size.z) * 0.92
		probe.free()
	var runs: Array[Run] = _wall_runs(fine)
	# ворота — на стене, ближайшей к входу дороги
	var gate_point: Vector2 = entry
	var gate_run: Run = null
	var best: float = INF
	for run: Run in runs:
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(entry, run.a, run.b)
		if p.distance_to(entry) < best:
			best = p.distance_to(entry)
			gate_point = p
			gate_run = run
	var corners: Dictionary[Vector2, bool] = {}
	for run: Run in runs:
		var wall: Vector2 = run.b - run.a
		var direction: Vector2 = wall.normalized()
		var yaw: float = -atan2(direction.y, direction.x) + (0.0 if long_axis_x else PI * 0.5)
		var count: int = maxi(1, roundi(wall.length() / segment))
		var step: float = wall.length() / count
		for k: int in count:
			var center: Vector2 = run.a + direction * (step * (k + 0.5))
			if center.distance_to(gate_point) < GATE_WIDTH * 0.5 + step * 0.5:
				continue
			if center.distance_to(door) < 2.6:
				continue
			_place("palisade", Vector3(center.x, 0, center.y), yaw, step / segment * 1.02 * WALL_SCALE)
			if k % 3 == 0 and k > 0:
				var post: Vector2 = run.a + direction * step * k
				_place("palisade_post", Vector3(post.x, 0, post.y), yaw + PI)
		# факелы вдоль стены изнутри двора
		var torches: int = int(wall.length() / TORCH_STEP)
		for k: int in torches:
			var p: Vector2 = run.a.lerp(run.b, (k + 0.5) / torches) - run.out * 0.55
			if p.distance_to(gate_point) < GATE_WIDTH or p.distance_to(door) < 3.0:
				continue
			_place("torch_post", Vector3(p.x, 0, p.y), _rng.randf() * TAU)
			_warm_light(Vector3(p.x, 2.5, p.y), 1.6, 5.5)
		for end: Vector2 in [run.a, run.b]:
			corners[end] = true
	# круглые срубы-башенки на выступающих углах (как на концепте), столбы — на внутренних
	for corner: Vector2 in corners:
		if _corner_inside_count(fine, corner) == 1:
			_place("corner_tower", Vector3(corner.x, 0, corner.y), _rng.randf() * TAU)
		else:
			_place("palisade_post", Vector3(corner.x, 0, corner.y), _rng.randf() * TAU)
	if gate_run != null:
		var gate_yaw: float = 0.0 if gate_run.out.y != 0.0 else PI * 0.5
		_place("gate", Vector3(gate_point.x, 0, gate_point.y), gate_yaw)
		_warm_light(Vector3(gate_point.x, 3.0, gate_point.y), 3.0, 7.0)


## Сколько из четырёх мелких клеток вокруг угла — двор (1 — выступающий угол, 3 — внутренний).
func _corner_inside_count(fine: Dictionary[Vector2i, bool], corner: Vector2) -> int:
	var at: Vector2i = Vector2i(roundi((corner.x - BOARD_MIN.x) / FINE), roundi((corner.y - BOARD_MIN.y) / FINE))
	var count: int = 0
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		if fine.has(at + offset):
			count += 1
	return count


func _warm_light(at: Vector3, energy: float, reach: float, parent: Node3D = null) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.5
	light.position = at
	(parent if parent != null else _yard).add_child(light)


func _bounds(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		var local: AABB = mesh_node.transform * mesh_node.get_aabb()
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	return box


## Жаровни в выступающих углах двора с тёплым светом (как на концепте); у терема — не ставим.
func _build_fires(fine: Dictionary[Vector2i, bool], terem: Vector2) -> void:
	var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
	var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in fine:
		lo = lo.min(cell)
		hi = hi.max(cell)
	for cell: Vector2i in fine:
		var nx: int = int(fine.has(cell + Vector2i(1, 0))) + int(fine.has(cell + Vector2i(-1, 0)))
		var ny: int = int(fine.has(cell + Vector2i(0, 1))) + int(fine.has(cell + Vector2i(0, -1)))
		if nx != 1 or ny != 1:
			continue  # только мелкие клетки в выступающем углу
		var inward: Vector2 = Vector2(1 if fine.has(cell + Vector2i(1, 0)) else -1,
				1 if fine.has(cell + Vector2i(0, 1)) else -1)
		var corner: Vector2 = _fine_to_world(Vector2(cell) + Vector2(0.5, 0.5)) + inward * 0.25
		if corner.distance_to(terem) < 5.0:
			continue
		var at: Vector3 = Vector3(corner.x, 0, corner.y)
		_place("fire_bowl", at, _rng.randf() * TAU, FIRE_SCALE)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = FIRE_COLOR
		light.light_energy = 5.0
		light.omni_range = 11.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.position = at + Vector3(0, 1.9 * FIRE_SCALE, 0)
		_yard.add_child(light)


## Закрытая часть поля — лесная опушка: папоротник, камни, молодые ели. Выбор по клетке (сид клетки),
## поэтому при росте двора подлесок не «перепрыгивает», а просто исчезает с открытых клеток.
func _build_undergrowth(board: BoardLayout, cells: Dictionary[Vector2i, bool],
		fine: Dictionary[Vector2i, bool]) -> void:
	var per: int = int(CELL / FINE)
	for y: int in board.height:
		for x: int in board.width:
			var cell: Vector2i = Vector2i(x, y)
			if cells.has(cell):
				continue
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash(cell) + 7
			for k: int in 2:
				var offset: Vector2 = Vector2(rng.randf_range(0.2, 1.8), rng.randf_range(0.2, 1.8))
				var fine_at: Vector2i = Vector2i(x * per + int(offset.x / FINE), y * per + int(offset.y / FINE))
				var roll: float = rng.randf()
				var yaw: float = rng.randf() * TAU
				var size: float = rng.randf_range(0.7, 1.2)
				if fine.has(fine_at):
					continue  # полоса под частоколом
				var at: Vector3 = Vector3(BOARD_MIN.x + x * CELL + offset.x, 0, BOARD_MIN.y + y * CELL + offset.y)
				if roll < 0.18 and k == 0:
					_place("pine", at, yaw, size * 0.42)
				elif roll < 0.6:
					_place("fern", at, yaw, size)
				elif roll < 0.8:
					_place("rock", at, yaw, size * 0.8)


## Лес вокруг двора: россыпь с минимальным интервалом (Пуассон), ели и берёзы разного роста —
## одной MultiMesh на вид дерева. У ближнего к камере края — только кусты и камни.
func _build_forest() -> void:
	var points: Array[Vector2] = _scatter(FOREST_MIN, FOREST_MAX, TREE_GAP)
	var pines: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	var low: Array[Vector2] = []
	for p: Vector2 in points:
		var clear: float = _clearance(p)
		if clear < 0.0:
			continue
		if p.y > BOARD_MAX.y and clear < CLEAR_NEAR + 8.0:
			low.append(p)
			continue
		var size: float = _rng.randf_range(0.8, 1.35)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size)
		var tree: Transform3D = Transform3D(basis, Vector3(p.x, 0, p.y))
		if _rng.randf() < 0.3:
			birches.append(tree)
		else:
			pines.append(tree)
	_multimesh("pine", pines)
	_multimesh("birch", birches)
	for p: Vector2 in low:
		_place("fern" if _rng.randf() < 0.6 else "rock", Vector3(p.x, 0, p.y), _rng.randf() * TAU,
				_rng.randf_range(0.8, 1.4), self)
	# подлесок между деревьями: камни и папоротник вдоль полосы у частокола
	for p: Vector2 in _scatter(FOREST_MIN, FOREST_MAX, 2.6):
		var clear: float = _clearance(p)
		if clear < -1.0 or clear > 9.0 or _rng.randf() < 0.55:
			continue
		_place("fern" if _rng.randf() < 0.65 else "rock", Vector3(p.x, 0, p.y), _rng.randf() * TAU,
				_rng.randf_range(0.6, 1.2), self)


## Расстояние от точки до края полосы без деревьев вокруг поля (меньше нуля — внутри полосы).
func _clearance(p: Vector2) -> float:
	var lo: Vector2 = BOARD_MIN - Vector2(CLEAR_SIDE, CLEAR_FAR)
	var hi: Vector2 = BOARD_MAX + Vector2(CLEAR_SIDE, CLEAR_NEAR)
	var dx: float = maxf(lo.x - p.x, p.x - hi.x)
	var dy: float = maxf(lo.y - p.y, p.y - hi.y)
	if dx < 0.0 and dy < 0.0:
		return maxf(dx, dy)
	return Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()


## Россыпь точек с минимальным расстоянием gap (метод «дротиков» по сетке).
func _scatter(lo: Vector2, hi: Vector2, gap: float) -> Array[Vector2]:
	var cell: float = gap / sqrt(2.0)
	var cols: int = ceili((hi.x - lo.x) / cell)
	var rows: int = ceili((hi.y - lo.y) / cell)
	var grid: Dictionary[Vector2i, Vector2] = {}
	var points: Array[Vector2] = []
	for attempt: int in cols * rows * 6:
		var p: Vector2 = Vector2(_rng.randf_range(lo.x, hi.x), _rng.randf_range(lo.y, hi.y))
		var key: Vector2i = Vector2i(floori((p.x - lo.x) / cell), floori((p.y - lo.y) / cell))
		var free: bool = true
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				var other: Vector2i = key + Vector2i(dx, dy)
				if grid.has(other) and grid[other].distance_to(p) < gap:
					free = false
		if free:
			grid[key] = p
			points.append(p)
	return points


## Все копии одного вида реквизита — одной MultiMesh на каждую сетку модели (одна отрисовка).
func _multimesh(id: String, transforms: Array[Transform3D]) -> void:
	var model: Node3D = _prop(id)
	if model == null or transforms.is_empty():
		return
	add_child(model)  # временно — чтобы посчитать мировые преобразования частей модели
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = model.global_transform.affine_inverse() * part.global_transform
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part.mesh
		multi.instance_count = transforms.size()
		for i: int in transforms.size():
			multi.set_instance_transform(i, transforms[i] * local)
		var holder: MultiMeshInstance3D = MultiMeshInstance3D.new()
		holder.multimesh = multi
		holder.name = "%s_forest" % id
		add_child(holder)
	model.queue_free()


## Дымка в лесу за стеной (как на концепте), гуще вдали; двор остаётся чистым и читаемым.
func _build_mist() -> void:
	var material: FogMaterial = FogMaterial.new()
	material.density = 0.4
	material.albedo = Color(0.5, 0.64, 0.7)
	material.height_falloff = 0.5
	material.edge_fade = 0.8
	var lo: Vector2 = BOARD_MIN - Vector2(3.0, 3.0)
	var hi: Vector2 = BOARD_MAX + Vector2(3.0, 3.0)
	var strips: Array[Rect2] = [
		Rect2(FOREST_MIN.x, FOREST_MIN.y, FOREST_MAX.x - FOREST_MIN.x, lo.y - FOREST_MIN.y),
		Rect2(FOREST_MIN.x, hi.y + 6.0, FOREST_MAX.x - FOREST_MIN.x, FOREST_MAX.y - hi.y - 6.0),
		Rect2(FOREST_MIN.x, lo.y, lo.x - FOREST_MIN.x, hi.y - lo.y),
		Rect2(hi.x, lo.y, FOREST_MAX.x - hi.x, hi.y - lo.y)]
	for strip: Rect2 in strips:
		var volume: FogVolume = FogVolume.new()
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		volume.size = Vector3(strip.size.x, 4.0, strip.size.y)
		volume.position = Vector3(strip.get_center().x, 1.2, strip.get_center().y)
		volume.material = material
		add_child(volume)
