class_name NoirArena3D
extends Node3D
## Арена «славянский нуар» по new_concept/05_arena.jpg: мощёный двор поля, дорога, частокол с воротами
## у входа дороги, жаровни по углам, кольца елей и берёз, валуны. Реквизит — GLB из сеток Hunyuan3D
## (assets/noir_h3d/arena/<id>.glb, tools/blender/noir/h3d.py); нет файла — деталь пропускается.
## Поле: X 0..18, Z -20..0 (клетка 2 м, как ArenaLayout3D).

const PROPS: String = "res://assets/noir_h3d/arena/%s.glb"
const BOARD_MIN: Vector2 = Vector2(0.0, -20.0)
const BOARD_MAX: Vector2 = Vector2(18.0, 0.0)
const WALL_MARGIN: float = 1.3
const GATE_WIDTH: float = 3.2
const FIRE_COLOR: Color = Color(1.0, 0.52, 0.18)
const ROAD_HALF_WIDTH: float = 0.95

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built_road: bool = false


func _ready() -> void:
	_rng.seed = 22
	_build_ground()
	_build_forest()


## Дорога и ворота зависят от раскладки поля — строятся, когда ArenaStage3D её получит.
func build_for_layout(layout: ArenaLayout3D) -> void:
	if _built_road:
		return
	_built_road = true
	_build_road(layout)
	var entry: Vector3 = layout.road_point(0.0)
	_build_walls(Vector2(entry.x, entry.z))
	_build_fires()


func _prop(id: String) -> Node3D:
	var path: String = PROPS % id
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _place(id: String, at: Vector3, yaw: float = 0.0, scale_by: float = 1.0) -> Node3D:
	var node: Node3D = _prop(id)
	if node == null:
		return null
	add_child(node)
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
	plane.size = Vector2(140, 140)
	outside.mesh = plane
	outside.material_override = _textured("res://assets/noir/arena/tex/forest_floor.png", Vector3(22, 22, 1))
	outside.position = Vector3(9, -0.04, -10)
	add_child(outside)
	# двор: плиты как на концепте — по 2 плиты на клетку (текстура 4×4 плиты на 2 клетки)
	var yard: MeshInstance3D = MeshInstance3D.new()
	var yard_plane: PlaneMesh = PlaneMesh.new()
	var extent: Vector2 = BOARD_MAX - BOARD_MIN + Vector2(WALL_MARGIN, WALL_MARGIN) * 2.0
	yard_plane.size = extent
	yard.mesh = yard_plane
	var yard_material: StandardMaterial3D = _textured("res://assets/noir/arena/tex/courtyard.png",
			Vector3(extent.x / 4.0, extent.y / 4.0, 1), 0.55)
	yard_material.albedo_color = Color(0.78, 0.76, 0.76)
	yard.material_override = yard_material
	yard.position = Vector3((BOARD_MIN.x + BOARD_MAX.x) * 0.5, -0.01, (BOARD_MIN.y + BOARD_MAX.y) * 0.5)
	add_child(yard)


## Утоптанная светлая дорога поверх плит (как на концепте) — лента вдоль линии дороги.
func _build_road(layout: ArenaLayout3D) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = 0.4
	var length: float = -2.0
	var finish: float = layout.road_end_length()
	var along: float = 0.0
	while length < finish:
		var next: float = minf(length + step, finish)
		var a: Vector3 = layout.road_point(maxf(length, 0.0))
		var b: Vector3 = layout.road_point(maxf(next, 0.0))
		if length < 0.0:  # продолжение за ворота
			a = layout.road_point(0.0) - layout.road_direction(0.0) * -length
			b = layout.road_point(0.0) - layout.road_direction(0.0) * -minf(next, 0.0)
		var side_a: Vector3 = _side(layout, maxf(length, 0.0)) * ROAD_HALF_WIDTH
		var side_b: Vector3 = _side(layout, maxf(next, 0.0)) * ROAD_HALF_WIDTH
		var lift: Vector3 = Vector3(0, 0.025, 0)
		var v0: float = along / 4.0
		var v1: float = (along + (b - a).length()) / 4.0
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(0, v0))
		tool.add_vertex(a - side_a + lift)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(1, v0))
		tool.add_vertex(a + side_a + lift)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(1, v1))
		tool.add_vertex(b + side_b + lift)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(0, v0))
		tool.add_vertex(a - side_a + lift)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(1, v1))
		tool.add_vertex(b + side_b + lift)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(0, v1))
		tool.add_vertex(b - side_b + lift)
		along += (b - a).length()
		length = next
	var road: MeshInstance3D = MeshInstance3D.new()
	road.mesh = tool.commit()
	var material: StandardMaterial3D = _textured("res://assets/noir/arena/tex/road.png", Vector3(1, 1, 1))
	material.albedo_color = Color(0.85, 0.72, 0.58)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)


func _side(layout: ArenaLayout3D, length: float) -> Vector3:
	var direction: Vector3 = layout.road_direction(length)
	return Vector3(-direction.z, 0, direction.x)


## Частокол по периметру двора из сегментов; проём ворот там, где дорога входит на поле.
func _build_walls(entry: Vector2) -> void:
	var lo: Vector2 = BOARD_MIN - Vector2(WALL_MARGIN, WALL_MARGIN)
	var hi: Vector2 = BOARD_MAX + Vector2(WALL_MARGIN, WALL_MARGIN)
	var corners: Array[Vector2] = [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
	var probe: Node3D = _prop("palisade")
	var segment: float = 2.2
	var long_axis_x: bool = true
	if probe != null:
		var box: AABB = _bounds(probe)
		long_axis_x = box.size.x >= box.size.z
		segment = maxf(box.size.x, box.size.z) * 0.92
		probe.free()
	# ворота — на стене, ближайшей к входу дороги
	var gate_point: Vector2 = entry
	var best: float = INF
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var t: float = clampf((entry - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var p: Vector2 = a + (b - a) * t
		if p.distance_to(entry) < best:
			best = p.distance_to(entry)
			gate_point = p
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var wall: Vector2 = b - a
		var direction: Vector2 = wall.normalized()
		var yaw: float = -atan2(direction.y, direction.x) + (0.0 if long_axis_x else PI * 0.5)
		var count: int = maxi(1, roundi(wall.length() / segment))
		var step: float = wall.length() / count
		for k: int in count:
			var center: Vector2 = a + direction * (step * (k + 0.5))
			if center.distance_to(gate_point) < GATE_WIDTH * 0.5 + step * 0.5:
				continue
			var at: Vector3 = Vector3(center.x, 0, center.y)
			# фасадом внутрь двора: у дальних и боковых стен разворот на 180° для разнообразия не нужен
			_place("palisade", at, yaw, step / segment * 1.02)
			if k % 3 == 0:
				_place("palisade_post", Vector3(a.x + direction.x * step * k, 0, a.y + direction.y * step * k),
						yaw + PI)
	var gate_yaw: float = 0.0
	if absf(gate_point.x - lo.x) < 0.01 or absf(gate_point.x - hi.x) < 0.01:
		gate_yaw = PI * 0.5
	_place("gate", Vector3(gate_point.x, 0, gate_point.y), gate_yaw)


func _bounds(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		var local: AABB = mesh_node.get_aabb()
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	return box


## Жаровни по углам двора с тёплым светом (как на концепте).
func _build_fires() -> void:
	var lo: Vector2 = BOARD_MIN - Vector2(WALL_MARGIN, WALL_MARGIN) * 0.55
	var hi: Vector2 = BOARD_MAX + Vector2(WALL_MARGIN, WALL_MARGIN) * 0.55
	for corner: Vector2 in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
		var at: Vector3 = Vector3(corner.x, 0, corner.y)
		_place("fire_bowl", at, _rng.randf() * TAU)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = FIRE_COLOR
		light.light_energy = 5.0
		light.omni_range = 11.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.position = at + Vector3(0, 1.9, 0)
		add_child(light)


## Три кольца елей с редкими берёзами, валуны и папоротник вдоль частокола.
func _build_forest() -> void:
	var center: Vector2 = (BOARD_MIN + BOARD_MAX) * 0.5
	var half: Vector2 = (BOARD_MAX - BOARD_MIN) * 0.5 + Vector2(WALL_MARGIN, WALL_MARGIN)
	for ring: int in 3:
		var pad: float = 2.6 + ring * 3.4
		var perimeter: float = 4.0 * (half.x + half.y + 2.0 * pad)
		var count: int = int(perimeter / (3.4 - ring * 0.3))
		for i: int in count:
			var t: float = float(i) / count
			var p: Vector2 = _rect_point(center, half + Vector2(pad, pad), t)
			p += Vector2(_rng.randf_range(-1.1, 1.1), _rng.randf_range(-1.1, 1.1))
			var kind: String = "birch" if _rng.randf() < 0.2 else "pine"
			_place(kind, Vector3(p.x, 0, p.y), _rng.randf() * TAU, _rng.randf_range(0.75, 1.25))
	for i: int in 34:
		var p: Vector2 = _rect_point(center, half + Vector2(1.2, 1.2), _rng.randf())
		p += Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
		_place("rock" if i % 2 == 0 else "fern", Vector3(p.x, 0, p.y), _rng.randf() * TAU,
				_rng.randf_range(0.6, 1.2))


static func _rect_point(center: Vector2, half: Vector2, t: float) -> Vector2:
	var perimeter: float = 4.0 * (half.x + half.y)
	var d: float = fposmod(t, 1.0) * perimeter
	var w: float = half.x * 2.0
	var h: float = half.y * 2.0
	if d < w:
		return center + Vector2(-half.x + d, -half.y)
	d -= w
	if d < h:
		return center + Vector2(half.x, -half.y + d)
	d -= h
	if d < w:
		return center + Vector2(half.x - d, half.y)
	d -= w
	return center + Vector2(-half.x, half.y - d)
