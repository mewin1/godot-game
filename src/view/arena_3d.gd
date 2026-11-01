class_name Arena3D
extends SubViewport
## Редактируемая 3D-арена. Читает FieldState и создаёт только видимые модели.

const STONE: Color = Color(0.21, 0.25, 0.32)
const ROAD: Color = Color(0.43, 0.35, 0.29)
const CLOSED: Color = Color(0.10, 0.13, 0.18)
const FIRE: Color = Color(0.95, 0.25, 0.13)
const WATER: Color = Color(0.12, 0.55, 0.94)
const ICE: Color = Color(0.43, 0.84, 1.0)
const WIND: Color = Color(0.37, 0.88, 0.73)
const LIGHTNING: Color = Color(0.87, 0.74, 1.0)
const CURSE: Color = Color(0.62, 0.32, 0.78)
const METAL: Color = Color(0.72, 0.57, 0.37)
const TOWER_SCENE: PackedScene = preload("res://scenes/tower_3d.tscn")
const UNIT_SCENE: PackedScene = preload("res://scenes/unit_3d.tscn")
const TILE_SCENE: PackedScene = preload("res://scenes/arena_tile_3d.tscn")

@onready var _tiles: Node3D = $World/Tiles
@onready var _towers: Node3D = $World/Towers
@onready var _units: Node3D = $World/Units
@onready var _perimeter: Node3D = $World/Perimeter
@onready var _camera: Camera3D = $World/Camera

var _field: FieldState
var _tile_signature: int = -1
var _tower_signature: int = -1
var _tower_nodes: Dictionary[int, Tower3D] = {}
var _unit_nodes: Dictionary[int, Unit3D] = {}
var _interpolation: float = 0.0
var _elapsed: float = 0.0


## Проекция точки сетки в координаты 3D-кадра.
func project_grid_point(point: Vector2) -> Vector2:
	return _camera.unproject_position(Vector3(point.x, 0, point.y))


## Клетка под экранной точкой кадра, по пересечению луча с плоскостью поля.
func grid_point_under(screen_point: Vector2) -> Vector2:
	var origin: Vector3 = _camera.project_ray_origin(screen_point)
	var direction: Vector3 = _camera.project_ray_normal(screen_point)
	if absf(direction.y) < 0.001:
		return Vector2(-1, -1)
	var distance: float = -origin.y / direction.y
	var hit: Vector3 = origin + direction * distance
	return Vector2(hit.x, hit.z)


## Подключает состояние поля. При смене поля перестраивает всю арену.
func show_field(field_state: FieldState) -> void:
	if _field == field_state:
		return
	_field = field_state
	_tile_signature = -1
	_tower_signature = -1
	if is_node_ready():
		_clear(_units)
		_unit_nodes.clear()
	refresh()


## Обновляет геометрию только после изменения пути, места или башен.
func refresh() -> void:
	if _field == null or not is_node_ready():
		return
	var tiles_hash: int = hash([_field.path_length, _field.layout.width,
			_field.layout.height, _field.get_buildable_cells().size()])
	if tiles_hash != _tile_signature:
		_tile_signature = tiles_hash
		_rebuild_tiles()
		_rebuild_perimeter()
	var tower_parts: Array[int] = []
	for tower: TowerState in _field.towers:
		tower_parts.append(hash([tower.id, tower.anchor, tower.rotation, tower.level]))
	var towers_hash: int = hash(tower_parts)
	if towers_hash != _tower_signature:
		_tower_signature = towers_hash
		_rebuild_towers()
	_sync_units()


## Положение бойцов плавно меняется между тиками симуляции.
func set_interpolation(fraction: float, elapsed: float) -> void:
	_interpolation = fraction
	_elapsed = elapsed


## Короткий световой импульс на башне, которая выстрелила.
func pulse_tower(tower_id: int) -> void:
	var model: Tower3D = _tower_nodes.get(tower_id)
	if model == null:
		return
	model.pulse()


func _rebuild_tiles() -> void:
	_clear(_tiles)
	var active: Dictionary[Vector2i, bool] = {}
	var future: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _field.get_active_path():
		active[cell] = true
	for cell: Vector2i in _field.get_future_path():
		future[cell] = true
	for y: int in _field.layout.height:
		for x: int in _field.layout.width:
			var cell: Vector2i = Vector2i(x, y)
			var color: Color = STONE
			if active.has(cell):
				color = ROAD
			elif not _field.is_buildable(cell):
				color = CLOSED
			var tile: ArenaTile3D = TILE_SCENE.instantiate() as ArenaTile3D
			tile.position = Vector3(x + 0.5, 0, y + 0.5)
			_tiles.add_child(tile)
			tile.setup(color, color.lightened(0.07))
			if future.has(cell):
				var mark: MeshInstance3D = _box(Vector3(0.14, 0.012, 0.14), METAL.darkened(0.45))
				mark.position = Vector3(x + 0.5, 0.005, y + 0.5)
				_tiles.add_child(mark)
	var edge: MeshInstance3D = _box(Vector3(9.25, 0.32, 10.25), CLOSED.darkened(0.3))
	edge.position = Vector3(4.5, -0.25, 5)
	_tiles.add_child(edge)
	var active_path: Array[Vector2i] = _field.get_active_path()
	var entrance: Vector2i = active_path[0]
	var exit_cell: Vector2i = active_path[active_path.size() - 1]
	var entry_mark: MeshInstance3D = _box(Vector3(0.64, 0.05, 0.64), FIRE.darkened(0.18))
	entry_mark.position = Vector3(entrance.x + 0.5, 0.04, entrance.y + 0.5)
	_tiles.add_child(entry_mark)
	# Орудие — только образ конца пути; урон и HP по-прежнему считает симуляция.
	var exit_weapon: Tower3D = TOWER_SCENE.instantiate() as Tower3D
	exit_weapon.name = "ExitWeapon"
	exit_weapon.position = Vector3(exit_cell.x + 0.5, 0.02, exit_cell.y + 0.5)
	exit_weapon.scale = Vector3.ONE * 0.72
	_tiles.add_child(exit_weapon)
	exit_weapon.setup(METAL, 1)


func _rebuild_towers() -> void:
	_clear(_towers)
	_tower_nodes.clear()
	for tower: TowerState in _field.towers:
		var root: Tower3D = TOWER_SCENE.instantiate() as Tower3D
		root.name = "Tower_%d" % tower.id
		var center: Vector2i = tower.center_milli()
		root.position = Vector3(center.x / 1000.0, 0, center.y / 1000.0)
		_towers.add_child(root)
		_tower_nodes[tower.id] = root
		var color: Color = _school_color(tower.data.school)
		root.setup(color, tower.level)
		for cell: Vector2i in tower.cells():
			var footprint: MeshInstance3D = _box(Vector3(0.88, 0.03, 0.88), color.darkened(0.5))
			footprint.position = Vector3(cell.x + 0.5 - root.position.x, 0.025,
					cell.y + 0.5 - root.position.z)
			root.add_child(footprint)


func _rebuild_perimeter() -> void:
	_clear(_perimeter)
	var ground: MeshInstance3D = _box(Vector3(11, 0.12, 12), CLOSED.darkened(0.2))
	ground.position = Vector3(4.5, -0.38, 5)
	_perimeter.add_child(ground)
	for x: int in range(-1, 11):
		_add_wall_block(Vector3(x + 0.5, 0.06, -0.6))
		_add_wall_block(Vector3(x + 0.5, 0.06, 10.6))
	for z: int in range(0, 10):
		_add_wall_block(Vector3(-0.6, 0.06, z + 0.5))
		_add_wall_block(Vector3(9.6, 0.06, z + 0.5))
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(9.5, -0.5),
			Vector2(-0.5, 10.5), Vector2(9.5, 10.5)]:
		var pillar: MeshInstance3D = _box(Vector3(0.52, 0.8, 0.52), STONE.lightened(0.16))
		pillar.position = Vector3(corner.x, 0.4, corner.y)
		_perimeter.add_child(pillar)
		var brazier: MeshInstance3D = _box(Vector3(0.28, 0.08, 0.28), FIRE)
		brazier.position = Vector3(corner.x, 0.84, corner.y)
		_perimeter.add_child(brazier)
		var firelight: OmniLight3D = OmniLight3D.new()
		firelight.position = Vector3(corner.x, 1.05, corner.y)
		firelight.light_color = Color(1.0, 0.55, 0.26)
		firelight.light_energy = 1.25
		firelight.omni_range = 3.0
		_perimeter.add_child(firelight)


func _add_wall_block(at: Vector3) -> void:
	var stone: MeshInstance3D = _box(Vector3(0.95, 0.42, 0.42), STONE.darkened(0.18))
	if at.x < 0 or at.x > 9:
		stone.mesh = BoxMesh.new()
		(stone.mesh as BoxMesh).size = Vector3(0.42, 0.42, 0.95)
	stone.position = at
	_perimeter.add_child(stone)


func _sync_units() -> void:
	var present: Dictionary[int, bool] = {}
	for mob: MobState in _field.mobs:
		present[mob.id] = true
		var model: Unit3D = _unit_nodes.get(mob.id)
		if model == null:
			model = UNIT_SCENE.instantiate() as Unit3D
			_units.add_child(model)
			_unit_nodes[mob.id] = model
			var color: Color = Color(0.57, 0.57, 0.58)
			if mob.sender_index >= 0:
				color = Color(0.57, 0.28, 0.22) if mob.sender_index % 2 == 0 \
						else Color(0.25, 0.48, 0.65)
			model.setup(color, clampf(mob.data.view_size * 2.0, 0.65, 1.5))
		var previous: Vector2i = _field.get_path_point(mob.previous_progress)
		var current: Vector2i = _field.get_path_point(mob.progress)
		var point: Vector2 = Vector2(previous).lerp(Vector2(current), _interpolation) / 1000.0
		var bob: float = absf(sin(_elapsed * 9.0 + mob.id)) * 0.035
		model.position = Vector3(point.x, bob + (0.35 if mob.data.is_flying else 0.0), point.y)
		var travel: Vector2 = Vector2(current - previous)
		if travel.length_squared() > 0.0:
			model.rotation.y = atan2(travel.x, travel.y)
	for mob_id: int in _unit_nodes.keys():
		if not present.has(mob_id):
			_unit_nodes[mob_id].queue_free()
			_unit_nodes.erase(mob_id)


func _school_color(school: StringName) -> Color:
	match school:
		&"fire", &"svarog": return FIRE
		&"water": return WATER
		&"ice": return ICE
		&"stribog": return WIND
		&"perun": return LIGHTNING
		&"curse": return CURSE
		_: return METAL


func _box(dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = _material(color)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	return result


func _clear(parent: Node3D) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
