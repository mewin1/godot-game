class_name RitualIdols3D
extends Node3D
## Идолы «Обряда» на площади терема (docs/37 §8): пьедестал с моделью бога и свой огонь —
## он заменил чаши и растёт с числом заговоров, так вложение видно на карте. Только вид.

const ROOT: String = "res://assets/noir_h3d/idols/"
## Места пьедесталов в мире (critique_3 п. 19): два ряда со сдвигом за теремом — святилище, а не
## столбики у забора. Терем без плиты (п. 17) освободил полосу 3 м между подклетом и частоколом:
## передний ряд (x 46,66) — левый и правый идолы, задний (x 47,8, на ступени) — средний и детинец
## (docs/37 D5) у северного угла. Зазор плит до частокола и подклета не меньше 0,3 м (--dump).
const SPOTS: Array[Vector3] = [Vector3(46.66, 0.0, -1.0), Vector3(47.8, 0.0, 1.2), Vector3(46.66, 0.0, 3.4),
	Vector3(47.8, 0.0, -3.1)]
## Высота каменной ступени под плитой: задний ряд выше — силуэты не сливаются; детинец выше всех.
const SPOT_LIFT: Array[float] = [0.0, 0.22, 0.0, 0.34]
## Идолы темнее (critique_3 п. 19): светлое дерево читалось как гидранты.
const MODEL_TONE: float = 0.72
## Кострище у ног идола (critique_4 п. 12): кольцо камней и поленья на плите, а не серая чаша
## жаровни ворот; FIRE_LIFT — высота плиты, на которой оно лежит, FIRE_OUT — от центра к лицу идола.
const FIRE_LIFT: float = 0.13
const FIRE_OUT: float = 0.5
const MODEL_SCALE: float = 0.85
## Плита меньше фигуры: восточная полоса площади между цоколем терема и частоколом — 2,1 м.
const PLATE_SCALE: float = 0.74
## Плита стоит по осям мира (как мостовая и терем); к дороге (−x) и чуть к камере повёрнута только фигура.
const FACE_YAW: float = -PI * 0.5 + 0.35
## Огонь у подножия: пустой идол — лампадка, каждый заговор чуть больше (до предела).
const FLAME_BASE: float = 0.6
const FLAME_STEP: float = 0.05
const FLAME_MAX: float = 1.35
const LIGHT_BASE: float = 2.2
const LIGHT_STEP: float = 0.12
const LIGHT_MAX: float = 4.4
const LIGHT_REACH: float = 8.0
## Пятно выбора и подсветки под курсором.
const RING_COLOR: Color = Color("f0c27a")

var _gods: Array[StringName] = []
var _rites: Array[int] = []
var _models: Array[Node3D] = []
var _flames: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _rings: Array[MeshInstance3D] = []
## Золотые обручи на пьедестале: по одному за пройденную веху 5/10/15 (docs/37 IDL-3).
var _bands: Array[Node3D] = []
## Пороги вех: обруч за каждый пройденный (данные режима, RitualTrialConfig.idol_milestones).
var milestone_steps: Array[int] = [5, 10, 15]
var _style: Arena3DStyle
var _shown: int = 3


func _init(style: Arena3DStyle) -> void:
	_style = style
	name = "RitualIdols"
	for index: int in SPOTS.size():
		var base: Node3D = Node3D.new()
		base.position = SPOTS[index] + Vector3.UP * SPOT_LIFT[index]
		add_child(base)
		if SPOT_LIFT[index] > 0.0:
			# Ступень — внутри узла идола: дети RitualIdols3D идут по номерам идолов.
			var step: MeshInstance3D = ArenaMaterials3D.part(base, ArenaMaterials3D.box(Vector3(1.4, SPOT_LIFT[index], 1.4)),
					ArenaMaterials3D.stone(Color(0.4, 0.4, 0.38)), Vector3.DOWN * SPOT_LIFT[index] * 0.5)
			step.name = "Step"
		var face: Vector3 = Vector3(sin(FACE_YAW), 0.0, cos(FACE_YAW))
		_build_hearth(base, face * FIRE_OUT + Vector3.UP * FIRE_LIFT)
		_gods.append(&"?")
		_rites.append(-1)
		_models.append(null)
		var flame: MeshInstance3D = _make_flame(index)
		# Огонь — в кострище у подножия фигуры, со стороны лица (не у частокола).
		flame.position = face * FIRE_OUT + Vector3(0.0, FIRE_LIFT + 0.03, 0.0)
		base.add_child(flame)
		_flames.append(flame)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = NoirArena3D.FIRE_COLOR
		light.omni_range = LIGHT_REACH
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.light_specular = 0.2
		light.position = face * 0.9 + Vector3(0.0, 1.4, 0.0)
		base.add_child(light)
		_lights.append(light)
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 1.05
		torus.outer_radius = 1.2
		ring.mesh = torus
		ring.material_override = ArenaMaterials3D.glow(RING_COLOR, 2.2)
		ring.position.y = 0.3
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		base.add_child(ring)
		_rings.append(ring)
		var bands: Node3D = Node3D.new()
		base.add_child(bands)
		_bands.append(bands)


## Кострище: семь тёмных камней кольцом, два скрещённых полена и тлеющие угли.
func _build_hearth(base: Node3D, at: Vector3) -> void:
	var stone: StandardMaterial3D = ArenaMaterials3D.stone(Color(0.3, 0.3, 0.29))
	var log_wood: StandardMaterial3D = ArenaMaterials3D.wood(0.45)
	for index: int in 7:
		var angle: float = TAU * index / 7.0 + 0.3
		var rock: SphereMesh = SphereMesh.new()
		rock.radius = 0.075 + 0.015 * sin(index * 2.3)
		rock.height = rock.radius * 1.3
		rock.radial_segments = 7
		rock.rings = 4
		ArenaMaterials3D.part(base, rock, stone, at + Vector3(cos(angle), 0.03, sin(angle)) * Vector3(0.2, 1.0, 0.2)
				+ Vector3.UP * 0.03, Vector3(0.0, angle, 0.0))
	for turn: float in [0.5, -0.6]:
		ArenaMaterials3D.part(base, ArenaMaterials3D.cylinder(0.035, 0.035, 0.34, 6), log_wood,
				at + Vector3.UP * 0.05, Vector3(0.0, turn, PI * 0.5))
	ArenaMaterials3D.part(base, ArenaMaterials3D.cylinder(0.13, 0.13, 0.02, 8),
			ArenaMaterials3D.glow(Color("ff6a2a"), 1.6), at + Vector3.UP * 0.02)


func _make_flame(index: int) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.85, 1.22)
	quad.center_offset = Vector3(0, 0.5, 0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = NoirArena3D.FLAME_SHADER
	material.set_shader_parameter("seed", 1.7 + index * 3.1)
	material.set_shader_parameter("upright", true)
	quad.material = material
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flame


## Модель — по посвящению, огонь — по числу заговоров; hovered/selected — кольцо.
func sync(idols: Array[IdolState], hovered: int, selected: int) -> void:
	_shown = mini(idols.size(), SPOTS.size())
	for index: int in SPOTS.size():
		(get_child(index) as Node3D).visible = index < _shown
	for index: int in mini(idols.size(), SPOTS.size()):
		var idol: IdolState = idols[index]
		if idol.god != _gods[index]:
			_gods[index] = idol.god
			_set_model(index, idol.god)
		var count: int = 0
		for rite_id: StringName in idol.purchases:
			count += idol.purchases[rite_id]
		if count != _rites[index]:
			_rites[index] = count
			var size: float = minf(FLAME_MAX, FLAME_BASE + FLAME_STEP * count)
			_flames[index].scale = Vector3.ONE * size
			_lights[index].light_energy = minf(LIGHT_MAX, LIGHT_BASE + LIGHT_STEP * count)
			var tint: Color = GodSymbols.get_color(idol.god) if idol.god != &"" else NoirArena3D.FIRE_COLOR
			_lights[index].light_color = NoirArena3D.FIRE_COLOR.lerp(tint, 0.35)
			_set_bands(index, count, tint)
		_rings[index].visible = index == hovered or index == selected
		(_rings[index].material_override as StandardMaterial3D).emission_energy_multiplier = \
				3.2 if index == selected else 1.6


func _set_bands(index: int, count: int, tint: Color) -> void:
	for child: Node in _bands[index].get_children():
		child.queue_free()
	var reached: int = 0
	for step: int in milestone_steps:
		reached += int(count >= step)
	for band: int in reached:
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.42 - band * 0.04
		torus.outer_radius = 0.5 - band * 0.04
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = torus
		mesh.material_override = ArenaMaterials3D.glow(ArenaMaterials3D.GOLD.lerp(tint, 0.3), 2.4)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position.y = 0.55 + band * 0.55
		_bands[index].add_child(mesh)


func _set_model(index: int, god: StringName) -> void:
	if _models[index] != null:
		_models[index].queue_free()
	var key: String = String(god) if god != &"" else "empty"
	var holder: Node3D = Node3D.new()
	for file: String in ["idol_%s_plate.glb" % key, "idol_%s.glb" % key]:
		if not ResourceLoader.exists(ROOT + file):
			continue
		var part: Node3D = (load(ROOT + file) as PackedScene).instantiate() as Node3D
		var plate: bool = file.ends_with("_plate.glb")
		part.scale = Vector3.ONE * (PLATE_SCALE if plate else MODEL_SCALE)
		part.rotation.y = 0.0 if plate else FACE_YAW
		holder.add_child(part)
	ArenaTower3D._tune_materials(holder, _style.noir_model_glow, _style.noir_model_tone * MODEL_TONE,
			_style.noir_model_rim)
	(get_child(index) as Node3D).add_child(holder)
	_models[index] = holder


## Сколько пьедесталов стоит (3, с детинцем 4).
func shown() -> int:
	return _shown


## Точка идола для экранных подсказок и попадания мышью (мир).
static func spot_at(index: int) -> Vector3:
	return SPOTS[index]
