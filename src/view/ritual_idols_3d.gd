class_name RitualIdols3D
extends Node3D
## Идолы «Обряда» на площади терема (docs/37 §8): пьедестал с моделью бога и свой огонь —
## он заменил чаши и растёт с числом заговоров, так вложение видно на карте. Только вид.

const ROOT: String = "res://assets/noir_h3d/idols/"
## Места пьедесталов в мире: по бокам крыльца терема и у ближнего угла площади.
const SPOTS: Array[Vector3] = [Vector3(39.6, 0.0, -3.4), Vector3(39.6, 0.0, 5.4), Vector3(47.2, 0.0, 5.6)]
const MODEL_SCALE: float = 0.85
## Огонь у подножия: пустой идол — лампадка, каждый заговор чуть больше (до предела).
const FLAME_BASE: float = 0.55
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


func _init(style: Arena3DStyle) -> void:
	_style = style
	name = "RitualIdols"
	for index: int in SPOTS.size():
		var base: Node3D = Node3D.new()
		base.position = SPOTS[index]
		# Лицом к дороге (−x) и чуть к камере.
		base.rotation.y = -PI * 0.5 + 0.35
		add_child(base)
		_gods.append(&"?")
		_rites.append(-1)
		_models.append(null)
		var flame: MeshInstance3D = _make_flame(index)
		flame.position = Vector3(0.0, 0.25, 0.85)
		base.add_child(flame)
		_flames.append(flame)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = NoirArena3D.FIRE_COLOR
		light.omni_range = LIGHT_REACH
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0.0, 1.4, 0.9)
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


func _make_flame(index: int) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.85, 1.22)
	quad.center_offset = Vector3(0, 0.5, 0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = NoirArena3D.FLAME_SHADER
	material.set_shader_parameter("seed", 1.7 + index * 3.1)
	quad.material = material
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flame


## Модель — по посвящению, огонь — по числу заговоров; hovered/selected — кольцо.
func sync(idols: Array[IdolState], hovered: int, selected: int) -> void:
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
	holder.scale = Vector3.ONE * MODEL_SCALE
	for file: String in ["idol_%s_plate.glb" % key, "idol_%s.glb" % key]:
		if not ResourceLoader.exists(ROOT + file):
			continue
		var part: Node3D = (load(ROOT + file) as PackedScene).instantiate() as Node3D
		holder.add_child(part)
	ArenaTower3D._tune_materials(holder, _style.noir_model_glow, _style.noir_model_tone, _style.noir_model_rim)
	(get_child(index) as Node3D).add_child(holder)
	_models[index] = holder


## Точка идола для экранных подсказок и попадания мышью (мир).
static func spot_at(index: int) -> Vector3:
	return SPOTS[index]
