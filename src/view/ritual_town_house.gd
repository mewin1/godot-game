class_name RitualTownHouse
extends ArenaTower3D
## Дом на одном участке. Класс мастерской и машина задаются типом, стены — уровнем.
## Обе специализации сохраняют архитектуру своего дома.

const FINISHES: Texture2D = preload("res://assets/ritual/town/finishes.jpg")
const FINISH_SHADER: Shader = preload("res://assets/ritual/town/finishes.gdshader")
const HOUSES: Array[PackedScene] = [
	preload("res://assets/ritual/town/house_1.glb"), preload("res://assets/ritual/town/house_2.glb"),
	preload("res://assets/ritual/town/house_3.glb")]
const PALETTES: Array[StringName] = [&"svarog", &"ice", &"water", &"stribog", &"war", &"perun", &"curse"]
const MACHINES: Dictionary[StringName, PackedScene] = {
	&"bolt": preload("res://assets/ritual/town/bolt.glb"),
	&"brazier": preload("res://assets/ritual/town/brazier.glb"),
	&"cinder": preload("res://assets/ritual/town/cinder.glb"),
	&"dew": preload("res://assets/ritual/town/dew.glb"),
	&"doom": preload("res://assets/ritual/town/doom.glb"),
	&"furnace": preload("res://assets/ritual/town/furnace.glb"),
	&"gale": preload("res://assets/ritual/town/gale.glb"),
	&"glacier": preload("res://assets/ritual/town/glacier.glb"),
	&"hex": preload("res://assets/ritual/town/hex.glb"),
	&"ice_lance": preload("res://assets/ritual/town/ice_lance.glb"),
	&"plague": preload("res://assets/ritual/town/plague.glb"),
	&"porok": preload("res://assets/ritual/town/porok.glb"),
	&"rain": preload("res://assets/ritual/town/rain.glb"),
	&"rime": preload("res://assets/ritual/town/rime.glb"),
	&"spark": preload("res://assets/ritual/town/spark.glb"),
	&"storm": preload("res://assets/ritual/town/storm.glb"),
	&"thunder": preload("res://assets/ritual/town/thunder.glb"),
	&"vortex": preload("res://assets/ritual/town/vortex.glb"),
	&"war_engine": preload("res://assets/ritual/town/war_engine.glb"),
	&"water": preload("res://assets/ritual/town/water.glb"),
	&"wind": preload("res://assets/ritual/town/wind.glb"),
}
## Свечение машины в покое по тиру (critique_3 п. 6: тир I вдвое тише, ночью ярче всего — враги и идолы).
const IDLE_ENERGY: Array[float] = [0.36, 0.55, 0.9]
## Вид крыш (critique_3 п. 5, сравнение по кадрам 17 ноября): 0 — цвет школы приглушён (крыши 148-164
## при дороге 158 — ярче нормы 130), 1 — тёмный тёс с оттенком школы (94-102) — выбран.
static var roof_mode: int = 1
## Модель вдвое крупнее сборки Blender: дом выше врага и шире клетки, через клетку-зазор (D8)
## соседние дома стоят почти вплотную, улица выглядит сплошной.
const MODEL_SCALE: float = 2.0
static var _paints: Dictionary[StringName, ShaderMaterial] = {}

var _tower: RitualTower
var _installation: Node3D
var _pick_meshes: Array[MeshInstance3D] = []
var _label_height: float = 0.0
var _works: MeshInstance3D
var _moving: MeshInstance3D
var _outlet: Node3D
var _idle_energy: float
var _previous_energy: float = -1.0


func build(tower: TowerState, style: Arena3DStyle, offsets: Array[Vector3]) -> void:
	_tower = tower as RitualTower
	var data: TowerData = tower.data
	var paint: ShaderMaterial = _finish(data.school)
	_model = HOUSES[data.tier - 1].instantiate() as Node3D
	add_child(_model)
	for level: int in range(1, 5):
		var walls: MeshInstance3D = _model.get_node("Level%d" % level) as MeshInstance3D
		if level == tower.level:
			walls.material_override = paint
		else:
			walls.free()
	(_model.get_node("Roof") as MeshInstance3D).material_override = paint
	_installation = MACHINES[data.id].instantiate() as Node3D
	_model.add_child(_installation)
	_works = _installation.get_node("Works") as MeshInstance3D
	_works.material_override = paint
	_moving = _installation.get_node_or_null("Moving") as MeshInstance3D
	if _moving != null:
		_moving.material_override = paint
	_outlet = _installation.get_node("Outlet") as Node3D
	_idle_energy = IDLE_ENERGY[data.tier - 1]
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		_pick_meshes.append(part)
		var box: AABB = part.transform * part.get_aabb()
		_label_height = maxf(_label_height, box.end.y)
	_add_workshop_marks(offsets, tower.level, style.get_god_color(data.god))


static func _finish(school: StringName) -> ShaderMaterial:
	if not _paints.has(school):
		var paint: ShaderMaterial = ShaderMaterial.new()
		paint.shader = FINISH_SHADER
		paint.set_shader_parameter(&"finishes", FINISHES)
		paint.set_shader_parameter(&"roof_column", PALETTES.find(school))
		paint.set_shader_parameter(&"roof_mode", roof_mode)
		_paints[school] = paint
	return _paints[school]


func get_top() -> Vector3:
	return _outlet.global_position


## Фасад к улице (клетки поля: +y - к камере). Дом у меридиональной улицы стоит к ней торцом
## клетки: глубина дома равна клетке, а ширина x2 заняла бы край дороги.
func face(front: Vector2i) -> void:
	_model.rotation.y = atan2(float(front.x), float(front.y))


func aim_wind(direction: Vector2i) -> void:
	# Ноль GLB направлен на +Z (фасад). Поворачивается только механизм на седле, поворот дома вычитается.
	_installation.rotation.y = atan2(float(direction.x), float(direction.y)) - _model.rotation.y


func label_position() -> Vector3:
	return global_position + Vector3.UP * _label_height * MODEL_SCALE


## Малые отдельные объёмы крыши, стен и установки: не перекрываем проезд рядом.
func pick_distance(from: Vector3, direction: Vector3) -> float:
	var nearest: float = INF
	for part: MeshInstance3D in _pick_meshes:
		var local: Transform3D = part.global_transform.affine_inverse()
		var hit: Variant = part.get_aabb().grow(0.035).intersects_ray(local * from, local.basis * direction)
		if hit is Vector3:
			# intersects_ray возвращает Vector3 или null; тип проверен выше.
			@warning_ignore("unsafe_cast")
			nearest = minf(nearest, from.distance_squared_to(part.to_global(hit as Vector3)))
	return nearest


func _process(delta: float) -> void:
	var operational: bool = _tower.durability != 0 and not _tower.is_action_blocked()
	_pop_left = maxf(0.0, _pop_left - delta)
	_pulse_left = maxf(0.0, _pulse_left - delta)
	var growth: float = ease(1.0 - _pop_left / POP_SECONDS, 0.4)
	_model.scale = Vector3.ONE * maxf(0.001, growth) * MODEL_SCALE
	var flash: float = sin(_pulse_left / PULSE_SECONDS * PI) if operational else 0.0
	var energy: float = _idle_energy * (1.0 + 1.4 * flash) if operational else 0.0
	if energy != _previous_energy:
		_works.set_instance_shader_parameter(&"working_light", energy)
		_previous_energy = energy
	if _moving == null:
		return
	if _tower.data.wind_length_milli > 0:
		if operational and DivineCombat.is_wind_blowing(_tower):
			_moving.rotate_z(delta * 1.25)
	elif _tower.data.id == &"porok":
		_moving.rotation.z = 0.34 * flash
	elif _tower.data.id == &"plague":
		_moving.rotation.x = 0.24 * flash
