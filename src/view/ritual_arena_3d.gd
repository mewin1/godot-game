extends NoirArena3D
## Двор «Обряда» (мостовая, частокол, терем, чаши — свои) внутри леса PvP-двора.
## Лес, камни, ручей, луг, туман и звери — из мастер-сцены PvP, повёрнуты на четверть
## оборота и сдвинуты: ручей идёт слева у ворот, терем справа, как в кадре PvP.

## Двор «Обряда» с частоколом в мире (x, z): клетки 1..18 × 2..12 поля по 2 м.
const YARD: Rect2 = Rect2(1.0, -17.0, 38.0, 24.0)
## Расстановка PvP → мир «Обряда»: −90° вокруг вертикали (терем PvP с −z уходит на +x),
## ручей встаёт к воротам слева, брод — напротив входа (z = −15).
const ENV: Transform3D = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
		Vector3(1.5, 0.0, -18.0))
## Поляна без деревьев: двор, терем справа и полоса луга; ближе к камере (+x, +z) — шире.
const CLEARING: Rect2 = Rect2(-2.5, -24.5, 55.5, 40.5)


func _yard_rect() -> Rect2:
	return YARD


func _terem_side() -> Side:
	return SIDE_RIGHT


func _env_transform() -> Transform3D:
	return ENV


## Деревья — вне поляны; камни и трава — вне двора с теремом.
func _keep_env(at: Vector3, tree: bool) -> bool:
	var point: Vector2 = Vector2(at.x, at.z)
	return not (CLEARING if tree else _yard_block()).has_point(point)


func _yard_block() -> Rect2:
	return YARD.grow(1.2).grow_side(SIDE_RIGHT, 8.0)


func _open_cells(field: FieldState, path: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in field.get_buildable_cells() + path:
		cells[cell] = true
	return cells


## Трава и подлесок не растут во дворе и под теремом (двор «Обряда» чистый).
func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	if _yard_block().has_point(at):
		return
	super._collect(into, id, at, scale_by, yaw)


## Расстояние от точки русла (координаты вида) до края поляны; меньше нуля — внутри.
func _clearance(p: Vector2) -> float:
	var at: Vector2 = _w(p)
	var dx: float = maxf(CLEARING.position.x - at.x, at.x - CLEARING.end.x)
	var dy: float = maxf(CLEARING.position.y - at.y, at.y - CLEARING.end.y)
	if dx < 0.0 and dy < 0.0:
		return maxf(dx, dy)
	return Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()


func _wild_zone() -> Rect2:
	return CLEARING.grow(-0.8)


## Дымка леса PvP, перенесённая вместе с лесом.
func _build_mist() -> void:
	super._build_mist()
	var volume: FogVolume = get_node("ForestMist") as FogVolume
	volume.position = ENV * volume.position
	volume.size = Vector3(volume.size.z, volume.size.y, volume.size.x)


func _build_fires(_fine: Dictionary[Vector2i, bool], _terem: Vector2) -> void:
	for point: Vector2 in [Vector2(1, -13), Vector2(35, -13), Vector2(1, 4), Vector2(32, 6)]:
		var at: Vector3 = Vector3(point.x, 0, point.y)
		var bowl: Node3D = _place("fire_bowl", at, 0, 1.6)
		_add_flame(bowl, 1.25)
		_warm_light(at + Vector3(0, 1.2, 0), 3.2, 7.0)


func _build_paving(fine: Dictionary[Vector2i, bool]) -> Material:
	var paving: Material = super._build_paving(fine)
	for child: Node in _yard.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			var material: ShaderMaterial = mesh.material_override as ShaderMaterial
			if material != null and material.shader == PAVING_SHADER:
				material.set_shader_parameter("custom_palette", true)
				material.set_shader_parameter("grout_color", Color("343c3b"))
				material.set_shader_parameter("stone_dark", Color("222a2b"))
				material.set_shader_parameter("stone_light", Color("3a4140"))
	return paving
