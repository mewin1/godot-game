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
const FIRE_SCALE: float = 2.2
const TORCH_STEP: float = 12.0
const ROAD_EDGE: Color = Color(0.42, 0.4, 0.42)
const TEREM_OFFSET: float = 4.4
## Сторона, откуда смотрит камера матча (ArenaStage3D: поворот ≈ 83°, камера над краем поля x = 18).
const VIEW_FROM: Vector3 = Vector3(1.0, 0.0, 0.0)
const TEREM_SCALE: float = 2.3
## Лес: россыпь с интервалами (как на концепте — стволы стоят порознь, между ними дымка).
## Камера перспективная и пологая — дальний лес уходит к горизонту в дымку.
const FOREST_MIN: Vector2 = Vector2(-60.0, -120.0)
const FOREST_MAX: Vector2 = Vector2(80.0, 14.0)
const TREE_GAP: float = 4.4
## Вокруг поля полоса без деревьев (частокол, терем); у ближнего к камере края — шире, чтобы не закрыть двор.
const CLEAR_FAR: float = 7.5
const CLEAR_SIDE: float = 4.5
const CLEAR_NEAR: float = 9.0
## Луна (как на концепте — над лесом в дымке): место на экране в долях кадра; верх кадра занят лесом,
## луна стоит за ближними кронами (см. MOON_DEPTH), её ореол высветляет дымку вокруг.
const MOON_SCREEN: Vector2 = Vector2(0.47, 0.05)  # над задним левым углом двора (как на концепте), левее портретов игроков
## Луна стоит за ближним лесом (дальше ближних елей, но выше земли под этим лучом — камера смотрит вниз),
## и кроны перед ней её заслоняют: луна светит из-за деревьев, а не висит перед ними.
const MOON_DEPTH: float = 46.0
const MOON_SIZE: float = 19.0
## Высота луны над землёй (м): ниже крон старых елей (20–28 м), выше дымки.
const MOON_HEIGHT: float = 5.0
const MOON_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 disc_color = vec3(0.86, 0.92, 0.95);
uniform vec3 halo_color = vec3(0.32, 0.46, 0.52);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float disc = smoothstep(0.125, 0.115, r);
	// пятна «морей» на диске — мягкие и тусклые
	float seas = 0.82 + 0.18 * smoothstep(0.01, 0.055, length(p - vec2(0.03, -0.025)))
			* smoothstep(0.005, 0.035, length(p - vec2(-0.045, 0.04)));
	float halo = (exp(-r * r * 18.0) * 0.45 + exp(-r * 2.4) * 0.14) * smoothstep(1.0, 0.6, r);  // круглый, без кромки карточки
	// диск закрывает то, что за ним (ствол не просвечивает), ореол добавляется к фону и кроны не прячет
	ALBEDO = disc_color * disc * seas * DISC_PART + halo_color * halo * HALO_PART * 1.8;
	ALPHA = disc * DISC_PART + HALO_PART;
}
"""
## Деревья под луной: лунный контур отделяет кроны от тёмной земли (как на концепте).
const TREE_RIM: float = 0.22
const TREE_BRIGHT: float = 1.0
## Земля леса — смесь трёх фактур Poly Haven (CC0) пятнами по шуму, темнее двора, с ямками и буграми.
const PAVING_SHADER: Shader = preload("res://assets/shaders/noir_paving.gdshader")
const FLAME_SHADER: Shader = preload("res://assets/shaders/noir_flame.gdshader")
const MIST_SHADER: Shader = preload("res://assets/shaders/noir_mist.gdshader")
const STREAM_SHADER: Shader = preload("res://assets/shaders/noir_stream.gdshader")
## Ручей через лес слева от двора (точки русла в координатах вида, см. _w): из глубины леса к переднему краю.
const STREAM_POINTS: Array[Vector2] = [Vector2(-30.0, -90.0), Vector2(-17.0, -55.0), Vector2(-9.0, -32.0),
		Vector2(-6.4, -17.0), Vector2(-7.2, -6.0), Vector2(-5.5, 3.0), Vector2(-9.0, 12.0), Vector2(-18.0, 20.0)]
const STREAM_WIDTH: float = 2.0
## Деревья и кусты не ближе этого к оси ручья (м).
const STREAM_CLEAR: float = 2.8
const GROUND_MIST_SHADER: Shader = preload("res://assets/shaders/noir_ground_mist.gdshader")
## Как рисуется туман в лесу: CARDS — прежние полотна + объём; LAYER — слой у земли шейдером
## по глубине сцены; LAYER_VOLUME — слой + прежний объёмный FogVolume.
enum MistMode { CARDS, LAYER, LAYER_VOLUME }
const MIST_MODE: MistMode = MistMode.LAYER
## Клубы тумана за частоколом: ряды полотен по удалению от стены (м), их непрозрачность и цвет.
const MIST_ROWS: PackedFloat32Array = [4.0, 10.0, 18.0, 30.0]
const MIST_ROW_OPACITY: PackedFloat32Array = [0.4, 0.6, 0.72, 0.8]
const MIST_SIDE_OPACITY: float = 0.2
const MIST_MOON_TINT: Color = Color(0.68, 0.73, 0.72)
const MIST_SIDE_TINT: Color = Color(0.42, 0.47, 0.47)
## Высота языка пламени на единицу масштаба чаши, м.
const FLAME_HEIGHT: float = 0.85
const ROAD_SHADER: Shader = preload("res://assets/shaders/noir_road.gdshader")
const GROUND_DIR: String = "res://assets/noir_h3d/arena/ground/"
const GROUND_SHADER: String = """
shader_type spatial;
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blend_noise : filter_linear, repeat_enable;
uniform vec4 yard_rect;
uniform float tile = 4.5;
uniform float tint = 0.1;
uniform vec3 hue = vec3(0.62, 1.0, 0.64);
uniform float bumps = 0.45;
varying vec3 world;

float yard_fade(vec2 p) {
	vec2 d = max(yard_rect.xy - p, p - yard_rect.zw);
	return smoothstep(1.0, 6.0, length(max(d, vec2(0.0))));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = textureLod(blend_noise, world.xz * 0.045, 0.0).r;
	VERTEX.y -= n * bumps * yard_fade(world.xz);  // только вниз: стволы и реквизит не повисают в воздухе
}

void fragment() {
	vec2 uv = world.xz / tile;
	float n = texture(blend_noise, world.xz * 0.03).r;
	float n2 = texture(blend_noise, world.xz * 0.08 + vec2(0.37, 0.11)).r;
	float wm = smoothstep(0.25, 0.5, n);
	float wl = smoothstep(0.55, 0.78, n2);
	vec2 uv2 = vec2(uv.y, -uv.x) * 0.83;
	vec3 a = mix(texture(mud_albedo, uv2).rgb, texture(moss_albedo, uv).rgb, wm);
	a = mix(a, texture(litter_albedo, uv * 1.21).rgb, wl * 0.75);
	vec3 nm = mix(texture(mud_normal, uv2).rgb, texture(moss_normal, uv).rgb, wm);
	nm = mix(nm, texture(litter_normal, uv * 1.21).rgb, wl * 0.75);
	// за частоколом — тёмная лесная трава (концепт: двор — самое светлое место, лес вокруг почти чёрный)
	ALBEDO = a * hue * tint * mix(0.95, 0.75, yard_fade(world.xz));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 0.92;
}
"""
## Трава и подлесок Poly Haven (облегчённые — tools/blender/noir/polyhaven.py): пучки крупнее
## настоящих — в масштабе игры трава по колено, как на концепте.
## Камни — Quaternius Stylized Nature MegaKit (CC0, tools/concepts/quaternius_copy.py), приглушены под ночь.
const QUATERNIUS: String = "res://assets/quaternius/nature/%s"
## Деревья, трава и папоротник — рисованные картинки в стиле концепта (tools/concepts/billboard_gen.py):
## вертикальные, повёрнуты к камере вокруг оси Y, одна MultiMesh на картинку. Масштаб = высота в метрах.
## Стиль (выбор автора): чистые тёмные силуэты средней детализации + мягкие круглые кусты вместо острой травы.
const BILLBOARDS: String = "res://assets/noir_h3d/arena/forest/%s.png"
const PINE_IDS: Array[String] = ["bb/spruce_11", "bb/spruce_37", "bb/spruce_52", "bb/spruce_64"]
const BIRCH_IDS: Array[String] = ["bb/birch_11", "bb/birch_37", "bb/birch_52"]
const GRASS_IDS: Array[String] = ["bb/grass_11", "bb/grass_37", "bb/grass_52"]
const FERN_IDS: Array[String] = ["bb/fern_37", "bb/fern_52", "bb/fern_64"]
## Подрост между стволами — средний ярус леса (на концепте под кронами тёмная масса, а не пустота).
const SAPLING_IDS: Array[String] = ["bb/sapling_11", "bb/sapling_37", "bb/sapling_52", "bb/sapling_64"]
const GRASS_SCALE: float = 0.9
## Старые ели у ближних углов поля (рамка кадра), в метрах мира.
const FRAME_SPRUCES: Array[Vector2] = [Vector2(-5.0, 7.0)]  # справа камера ближе — там плоская картинка бросается в глаза
## Справа старые деревья не ближе этого (м от полосы у поля).
const NEAR_RIGHT_GAP: float = 2.0
## Двор в координатах вида (см. _w): 20 м поперёк кадра, 18 м в глубину.
const VIEW_MIN: Vector2 = Vector2(0.0, -18.0)
const VIEW_MAX: Vector2 = Vector2(20.0, 0.0)
## Пояс елей за частоколом: от и до (м от края поля).
const FENCE_BELT: Vector2 = Vector2(1.6, 5.5)
## Старый лес вокруг терема: высокие ели и берёзы, внизу голые стволы.
const SPRUCE_HEIGHT: Vector2 = Vector2(20.0, 28.0)
const BIRCH_HEIGHT: Vector2 = Vector2(17.0, 23.0)
## Яркость рисованных картинок в сцене (рисунок ночной и тёмный — чуть светлее, чтобы читались силуэты).
const BILLBOARD_TINT: Color = Color(1.0, 1.08, 1.04)
## Белые берёзы не должны перетягивать внимание с двора.
const BIRCH_DIM: float = 1.0
## Молодые ели нарисованы светлее старых — в поясе у частокола они не должны выделяться.
const SAPLING_DIM: float = 0.9
## Плотность низовой дымки: за задней стеной (под луной) и по бокам/спереди.
const MIST_BACK: float = 0.18
const MIST_SIDES: float = 0.05
const PROP_TINTS: Dictionary[String, Color] = {"q/Rock": Color(0.45, 0.5, 0.52)}
const ROCK_IDS: Array[String] = ["q/Rock_Medium_1", "q/Rock_Medium_2", "q/Rock_Medium_3"]
## Факелы вдоль частокола: на концепте стена тёмная, тёплые пятна — у жаровен.
const TORCH_ENERGY: float = 1.4
## Чаша-жаровня в середине каждой стены (выключено: вместе с угловыми чашами двор был в огнях).
const WALL_BOWLS: bool = false
const WALL_BOWL_SCALE: float = 1.3
const BOWL_ENERGY: float = 4.0
const BOWL_REACH: float = 7.5
## Большие чаши в углах двора: тёплое пятно, но не заливать двор оранжевым.
const CORNER_FIRE_ENERGY: float = 6.0
const CORNER_FIRE_REACH: float = 9.0
const TORCH_REACH: float = 6.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _layout: ArenaLayout3D
var _yard: Node3D
var _open_key: int = -1
var _terem_scene: PackedScene
var _moon: MeshInstance3D
## Трава двора (вдоль частокола, в закрытых клетках) — пересобирается вместе с двором.
var _yard_grass: Dictionary[String, Array] = {}


func _ready() -> void:
	_rng.seed = 22
	_build_ground()
	_build_moon()


## Луна привязана к кадру (как настоящая — не плывёт с полем).
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or _moon == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size * MOON_SCREEN
	# по лучу камеры — до высоты MOON_HEIGHT над землёй: при любом наезде камеры луна за ближними кронами
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var depth: float = MOON_DEPTH
	if direction.y < -0.05 and origin.y > MOON_HEIGHT:
		depth = (origin.y - MOON_HEIGHT) / -direction.y
	var spot: Vector3 = origin + direction * depth
	_moon.global_transform = Transform3D(camera.global_basis.scaled(Vector3.ONE * depth / MOON_DEPTH), spot)


func _build_moon() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(MOON_SIZE, MOON_SIZE)
	# диск — с проверкой глубины (ближние кроны его заслоняют); ореол — отдельной картинкой поверх крон,
	# поэтому свет «пробивается» из-за деревьев
	var disc: Shader = Shader.new()
	disc.code = MOON_SHADER.replace("DISC_PART", "1.0").replace("HALO_PART", "0.0")
	var halo: Shader = Shader.new()
	halo.code = MOON_SHADER.replace("depth_draw_never,", "depth_draw_never, depth_test_disabled,") \
			.replace("blend_premul_alpha", "blend_add").replace("DISC_PART", "0.0").replace("HALO_PART", "1.0")
	var disc_material: ShaderMaterial = ShaderMaterial.new()
	disc_material.shader = disc
	var halo_material: ShaderMaterial = ShaderMaterial.new()
	halo_material.shader = halo
	halo_material.render_priority = 10  # после слоя тумана (-50), иначе туман его гасит
	quad.material = disc_material
	_moon = MeshInstance3D.new()
	_moon.mesh = quad
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_moon)
	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.mesh = quad
	glow.material_override = halo_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.add_child(glow)


## Неизменная часть (земля леса, лес, дымка) — один раз, когда ArenaStage3D получит раскладку.
func build_for_layout(layout: ArenaLayout3D) -> void:
	if _layout != null:
		return
	_layout = layout
	_terem_scene = NoirModels.base()
	_build_stream()
	_build_forest()
	if MIST_MODE != MistMode.LAYER:
		_build_mist()
	if MIST_MODE == MistMode.CARDS:
		_build_mist_cards()
	# объёмный туман движка нужен только FogVolume; без них он лишь даёт ореолы вокруг огней и стоит кадров
	var world_env: WorldEnvironment = get_parent().get_node_or_null("Environment") as WorldEnvironment
	if world_env != null:
		world_env.environment.volumetric_fog_enabled = MIST_MODE != MistMode.LAYER
	if MIST_MODE != MistMode.CARDS:
		_build_ground_mist()


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
	_yard_grass = {}
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
	_build_collected(_yard_grass, _yard)


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
	if id.begins_with("q/"):
		path = QUATERNIUS % (id.trim_prefix("q/") + ".gltf")
		if not ResourceLoader.exists(path):
			path = QUATERNIUS % (id.trim_prefix("q/") + ".glb")
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return null
	var node: Node3D = scene.instantiate() as Node3D
	for prefix: String in PROP_TINTS:
		if id.begins_with(prefix):
			_tint(node, PROP_TINTS[prefix])
	return node


## Фото-фактуры Poly Haven под палитру концепта (материал общий для всех копий — правится один раз).
static func _tint(root: Node, tint: Color) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var material: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or material.has_meta(&"tinted"):
				continue
			material.set_meta(&"tinted", true)
			material.albedo_color = material.albedo_color * tint
			material.emission_enabled = false


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
	plane.size = Vector2(320, 320)
	plane.subdivide_width = 159
	plane.subdivide_depth = 159
	outside.mesh = plane
	outside.material_override = _ground_material()
	outside.position = Vector3(9, -0.04, -14)
	add_child(outside)


func _ground_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = GROUND_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var sets: Dictionary[String, String] = {"moss": "forrest_ground_01", "mud": "brown_mud_leaves_01",
			"litter": "forest_leaves_04"}
	for slot: String in sets:
		var prefix: String = GROUND_DIR + sets[slot]
		material.set_shader_parameter(slot + "_albedo", load(prefix + "_diff_1k.jpg"))
		material.set_shader_parameter(slot + "_normal", load(prefix + "_nor_gl_1k.jpg"))
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 512
	texture.height = 512
	material.set_shader_parameter("blend_noise", texture)
	material.set_shader_parameter("yard_rect", Vector4(BOARD_MIN.x - 1.5, BOARD_MIN.y - 1.5, BOARD_MAX.x + 1.5, BOARD_MAX.y + 1.5))
	return material


## Плиты двора по мелким клеткам открытой части; швы плит — по мировой сетке (по краям клеток поля).
func _build_paving(fine: Dictionary[Vector2i, bool]) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var offsets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
	for cell: Vector2i in fine:
		var a: Vector2 = _fine_to_world(Vector2(cell))
		var b: Vector2 = a + Vector2(FINE, FINE)
		var corners: Array[Vector3] = [Vector3(a.x, -0.01, a.y), Vector3(b.x, -0.01, a.y),
				Vector3(b.x, -0.01, b.y), Vector3(a.x, -0.01, b.y)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			# угол на краю двора (вокруг него не все 4 мелкие клетки) — мох у частокола
			var corner: Vector2i = cell + offsets[index]
			var inner: bool = fine.has(corner) and fine.has(corner - Vector2i(1, 0)) \
					and fine.has(corner - Vector2i(0, 1)) and fine.has(corner - Vector2i(1, 1))
			tool.set_color(Color.BLACK if inner else Color.RED)
			tool.add_vertex(corners[index])
	var yard: MeshInstance3D = MeshInstance3D.new()
	yard.mesh = tool.commit()
	# булыжник в крупных квадратах по клеткам поля, влажный блик, мох у частокола (шейдер — как на концепте)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PAVING_SHADER
	material.set_shader_parameter("origin", BOARD_MIN)
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
	# бледная грунтовка с колеями и мхом по обочине (шейдер — как на концепте)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ROAD_SHADER
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
	# лицом к камере (к дороге камера видела бы глухой бок); поворот кратен 90° — плита вровень с двором
	house.rotation.y = atan2(VIEW_FROM.x, VIEW_FROM.z)
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
			# чаша посреди стены — только если так задано: огня во дворе хватает от угловых чаш
			var bowl: bool = WALL_BOWLS and k == torches / 2
			var prop: Node3D = _place("fire_bowl" if bowl else "torch_post", Vector3(p.x, 0, p.y), _rng.randf() * TAU,
					WALL_BOWL_SCALE if bowl else 1.0)
			if bowl:
				_add_flame(prop, FLAME_HEIGHT * WALL_BOWL_SCALE)
			var pool: Vector2 = p - run.out * 0.9
			# у стен, повёрнутых к камере (ближняя и правая), свет без теней проходит сквозь колья и красит их
			# наружную сторону в рыжий — на концепте она тёмная; таким факелам — тени
			var facing_camera: bool = run.out.y > 0.0 or run.out.x > 0.0
			_warm_light(Vector3(pool.x, 1.6, pool.y), BOWL_ENERGY if bowl else TORCH_ENERGY,
					BOWL_REACH if bowl else TORCH_REACH, null, facing_camera)
		# трава у подножия частокола с обеих сторон (как на концепте), внутри — узкой полосой
		var along: float = 0.0
		while along < wall.length():
			var foot: Vector2 = run.a + direction * along
			along += 0.9
			if foot.distance_to(gate_point) < GATE_WIDTH * 0.6:
				continue
			var outer: Array[String] = FERN_IDS if _rng.randf() < 0.5 else GRASS_IDS
			_collect(_yard_grass, outer[_rng.randi() % outer.size()],
					foot + run.out * _rng.randf_range(0.2, 1.8), GRASS_SCALE * _rng.randf_range(0.5, 1.0))
			if _rng.randf() < 0.5:
				_collect(_yard_grass, GRASS_IDS[_rng.randi() % GRASS_IDS.size()],
						foot - run.out * _rng.randf_range(0.12, 0.45), GRASS_SCALE * _rng.randf_range(0.35, 0.6))
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


func _warm_light(at: Vector3, energy: float, reach: float, parent: Node3D = null, shadow: bool = false) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.shadow_enabled = shadow
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
		_add_flame(_place("fire_bowl", at, _rng.randf() * TAU, FIRE_SCALE), FLAME_HEIGHT * FIRE_SCALE)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = FIRE_COLOR
		light.light_energy = CORNER_FIRE_ENERGY
		light.omni_range = CORNER_FIRE_REACH
		light.omni_attenuation = 1.5
		light.shadow_enabled = true
		light.position = at + Vector3(0, 1.3, 0) + Vector3(inward.x, 0, inward.y) * 0.8  # у пола, внутрь двора
		_yard.add_child(light)


## Язык пламени над чашей (шейдер, лицом к камере) — у модели огонь сверху выглядит плоскими углями.
func _add_flame(bowl: Node3D, height: float) -> void:
	if bowl == null:
		return
	var top: float = _bounds(bowl).end.y * bowl.scale.y
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(height * 0.62, height)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("seed", _rng.randf() * 10.0)
	quad.material = material
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = bowl.position + Vector3(0, top * 0.8, 0)
	_yard.add_child(flame)


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
					_collect(_yard_grass, SAPLING_IDS[rng.randi() % SAPLING_IDS.size()], Vector2(at.x, at.z), size * 2.6)
				elif roll < 0.6:
					_collect(_yard_grass, FERN_IDS[rng.randi() % FERN_IDS.size()], Vector2(at.x, at.z), size * 1.2, yaw)
				elif roll < 0.8:
					_place(ROCK_IDS[rng.randi() % ROCK_IDS.size()], at, yaw, size * 0.25)
			for k: int in 2:
				var tuft: Vector2 = Vector2(BOARD_MIN.x + x * CELL + rng.randf_range(0.1, 1.9),
						BOARD_MIN.y + y * CELL + rng.randf_range(0.1, 1.9))
				_collect(_yard_grass, GRASS_IDS[rng.randi() % GRASS_IDS.size()], tuft, GRASS_SCALE * rng.randf_range(0.8, 1.2))


## Лес вокруг двора: россыпь с минимальным интервалом (Пуассон), ели и берёзы разного роста —
## одной MultiMesh на вид дерева. У ближнего к камере края — только кусты и камни.
func _build_forest() -> void:
	var points: Array[Vector2] = _scatter(FOREST_MIN, FOREST_MAX, TREE_GAP)
	var pines: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	var kinds: Dictionary[String, Array] = {}
	var low: Array[Vector2] = []
	for p: Vector2 in points:
		var clear: float = _clearance(p)
		if clear < 0.0 or _stream_distance(p) < STREAM_CLEAR:
			continue
		if p.y > VIEW_MAX.y and clear < CLEAR_NEAR + 8.0:
			low.append(p)
			continue
		if p.x > VIEW_MAX.x and clear < NEAR_RIGHT_GAP:
			continue  # справа камера ближе всего: высокие деревья — только поодаль
		var birch: bool = _rng.randf() < 0.2
		var span: Vector2 = BIRCH_HEIGHT if birch else SPRUCE_HEIGHT
		var size: float = _rng.randf_range(span.x, span.y)
		# картинка повёрнута к камере сама; зеркалим половину для разнообразия
		var basis: Basis = Basis.from_scale(Vector3(size * (1.0 if _rng.randf() < 0.5 else -1.0), size, size))
		var tree: Transform3D = Transform3D(basis, _w3(p))
		var kind: String = BIRCH_IDS[_rng.randi() % BIRCH_IDS.size()] if birch else PINE_IDS[_rng.randi() % PINE_IDS.size()]
		if not kinds.has(kind):
			kinds[kind] = []
		kinds[kind].append(tree)
		(birches if birch else pines).append(tree)
	_build_collected(kinds, self)
	# подножие: стволы не «втыкаются» в ровную землю — корни под елями, трава и папоротник у комля
	var grass: Dictionary[String, Array] = {}
	for tree: Transform3D in pines + birches:
		var base: Vector2 = _v(Vector2(tree.origin.x, tree.origin.z))
		# средний ярус: молодая ель — её лапы закрывают голые стволы старых (на концепте под кронами тёмная масса)
		if _rng.randf() < 0.55:
			var mid: Vector2 = base + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.5, 5.0)
			if _clearance(mid) > 1.0:
				_collect(grass, PINE_IDS[_rng.randi() % PINE_IDS.size()], _w(mid), _rng.randf_range(7.0, 13.0), 0.0)
		if _rng.randf() < 0.6:
			var young: Vector2 = base + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, 4.0)
			if _clearance(young) > 0.5:
				_collect(grass, SAPLING_IDS[_rng.randi() % SAPLING_IDS.size()], _w(young), _rng.randf_range(1.8, 3.4))
		for k: int in 3:
			var around: Vector2 = base + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.6, 2.2)
			_collect(grass, GRASS_IDS[_rng.randi() % GRASS_IDS.size()], _w(around), GRASS_SCALE * _rng.randf_range(0.8, 1.3))
	_fence_spruces(grass)
	_ground_grass(grass)
	var ferns: Array[String] = FERN_IDS
	for p: Vector2 in low:
		if _rng.randf() < 0.6:
			_collect(grass, ferns[_rng.randi() % ferns.size()], _w(p), _rng.randf_range(1.0, 1.6))
		else:
			_place_rock(_w3(p), self)
	# подлесок между деревьями: камни и папоротник вдоль полосы у частокола (только в полосе у поля:
	# россыпь по всему лесу заметно удлиняла загрузку)
	var lo: Vector2 = VIEW_MIN - Vector2(CLEAR_SIDE + 9.0, CLEAR_FAR + 9.0)
	var hi: Vector2 = VIEW_MAX + Vector2(CLEAR_SIDE + 9.0, CLEAR_NEAR + 9.0)
	for p: Vector2 in _scatter(lo, hi, 2.6):
		var clear: float = _clearance(p)
		if clear < -1.0 or clear > 9.0 or _rng.randf() < 0.55:
			continue
		if _rng.randf() < 0.65:
			_collect(grass, ferns[_rng.randi() % ferns.size()], _w(p), _rng.randf_range(0.9, 1.4))
		else:
			_place_rock(_w3(p), self)
	_build_collected(grass, self)


## Пояс густых елей с лапами до земли сразу за частоколом (сзади и по бокам): на концепте на высоте забора —
## сплошная тёмная масса леса, а не поляна. Спереди — только у углов (рамка кадра), иначе закрыли бы двор.
func _fence_spruces(into: Dictionary[String, Array]) -> void:
	var lo: Vector2 = VIEW_MIN - Vector2(FENCE_BELT.y, FENCE_BELT.y)
	var hi: Vector2 = VIEW_MAX + Vector2(FENCE_BELT.y, FENCE_BELT.y)
	for p: Vector2 in _scatter(lo, hi, 2.6):
		if _stream_distance(p) < STREAM_CLEAR:
			continue
		var outside: Vector2 = Vector2(maxf(VIEW_MIN.x - p.x, p.x - VIEW_MAX.x), maxf(VIEW_MIN.y - p.y, p.y - VIEW_MAX.y))
		var gap: float = maxf(outside.x, outside.y)
		var front_corner: bool = p.y > VIEW_MAX.y - 2.0 and outside.x > FENCE_BELT.x and p.x < VIEW_MIN.x
		if gap < FENCE_BELT.x or (p.y > VIEW_MAX.y - 2.0 and not front_corner) or _rng.randf() < 0.3:
			continue
		# ближе к камере (передняя половина боков и весь правый бок) — только невысокие ёлочки: высокая плоская картинка
		# сверху выглядит вырезанной из бумаги
		if p.y > (VIEW_MIN.y + VIEW_MAX.y) * 0.5 or p.x > VIEW_MAX.x:
			_collect(into, SAPLING_IDS[_rng.randi() % SAPLING_IDS.size()], _w(p), _rng.randf_range(3.0, 5.0), 0.0)
			continue
		var roll: float = _rng.randf()
		if roll < 0.12 and p.y < VIEW_MIN.y:
			_collect(into, BIRCH_IDS[_rng.randi() % BIRCH_IDS.size()], _w(p), _rng.randf_range(13.0, 18.0), 0.0)
		elif roll < 0.45:
			_collect(into, PINE_IDS[_rng.randi() % PINE_IDS.size()], _w(p), _rng.randf_range(7.0, 12.0), 0.0)
		else:
			_collect(into, SAPLING_IDS[_rng.randi() % SAPLING_IDS.size()], _w(p), _rng.randf_range(3.5, 8.5), 0.0)
	# рамка кадра: старые ели у ближних углов, ближе к камере (на концепте лапы обрезаны краем кадра)
	for corner: Vector2 in FRAME_SPRUCES:
		_collect(into, PINE_IDS[_rng.randi() % PINE_IDS.size()], _w(corner), _rng.randf_range(15.0, 19.0), 0.0)


## Трава пятнами вокруг поля (шум): гуще у частокола, вдали реже; внутрь поля не заходит.
func _ground_grass(grass: Dictionary[String, Array]) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.08
	var lo: Vector2 = VIEW_MIN - Vector2(22.0, 30.0)
	var hi: Vector2 = VIEW_MAX + Vector2(22.0, 14.0)
	var step: float = 1.6
	var y: float = lo.y
	while y < hi.y:
		var x: float = lo.x
		while x < hi.x:
			var p: Vector2 = Vector2(x, y) + Vector2(_rng.randf(), _rng.randf()) * step
			x += step
			if p.x > VIEW_MIN.x - 1.2 and p.x < VIEW_MAX.x + 1.2 and p.y > VIEW_MIN.y - 1.2 and p.y < VIEW_MAX.y + 1.2:
				continue
			if _stream_distance(p) < STREAM_WIDTH * 0.5:
				continue
			if _clearance(p) > 4.0:
				continue  # кусты — только у частокола, дальше чистая тёмная земля под елями
			var near: float = clampf(1.0 - _clearance(p) / 14.0, 0.0, 1.0)
			if noise.get_noise_2dv(p) + near * 0.5 < 0.35:  # кустами, между ними — тёмная земля
				continue
			for k: int in _rng.randi_range(1, 2):  # кустик — пара пучков рядом, между кустами — чистая тёмная земля
				var tuft: Vector2 = p + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
				var kind: Array[String] = FERN_IDS if _rng.randf() < 0.5 else GRASS_IDS
				_collect(grass, kind[_rng.randi() % kind.size()], _w(tuft), GRASS_SCALE * _rng.randf_range(0.6, 1.4))
		y += step


func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	if not into.has(id):
		into[id] = []
	var turn: float = yaw if yaw >= 0.0 else _rng.randf() * TAU
	into[id].append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale_by), Vector3(at.x, 0.0, at.y)))


func _build_collected(sets: Dictionary[String, Array], parent: Node3D) -> void:
	for id: String in sets:
		var typed: Array[Transform3D] = []
		typed.assign(sets[id])
		if id.begins_with("bb/"):
			_billboards(id.trim_prefix("bb/"), typed, parent)
		else:
			_multimesh(id, typed, parent)


## Рисованные картинки одного вида — одной MultiMesh. Нарисованный свет уже в картинке (без освещения сцены),
## туман на них ложится; тени не отбрасывают (плоские).
func _billboards(name: String, transforms: Array[Transform3D], parent: Node3D) -> void:
	var path: String = BILLBOARDS % name
	if transforms.is_empty() or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	var quad: QuadMesh = QuadMesh.new()
	var aspect: float = float(texture.get_width()) / float(texture.get_height())
	quad.size = Vector2(aspect, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	var dim: float = BIRCH_DIM if name.begins_with("birch") else (SAPLING_DIM if name.begins_with("sapling") else 1.0)
	material.albedo_color = BILLBOARD_TINT * dim
	material.albedo_color.a = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.6  # без светлой каймы по краю лап
	# мягкие края листвы (сглаживание по MSAA вьюпорта) вместо рваной «пилы»
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	material.alpha_antialiasing_edge = 0.3
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material = material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var holder: MultiMeshInstance3D = MultiMeshInstance3D.new()
	holder.multimesh = multi
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.name = "%s_bb" % name
	parent.add_child(holder)


## Замшелый валун Poly Haven (вместо прежних камней), разного размера.
func _place_rock(at: Vector3, parent: Node3D = null) -> void:
	_place(ROCK_IDS[_rng.randi() % ROCK_IDS.size()], at, _rng.randf() * TAU, _rng.randf_range(0.18, 0.4), parent)



## Ручей: лента по сглаженному руслу (Catmull-Rom), по берегам — камни и папоротник.
func _build_stream() -> void:
	var line: Array[Vector2] = _stream_line()
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	for i: int in line.size():
		var ahead: Vector2 = line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]
		var side: Vector2 = Vector2(-ahead.y, ahead.x).normalized() * STREAM_WIDTH * 0.5
		if i > 0:
			along += line[i].distance_to(line[i - 1])
		for k: int in 2:
			var edge: Vector2 = line[i] + side * (1.0 if k == 0 else -1.0)
			tool.set_uv(Vector2(along, float(k)))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(_w3(edge) + Vector3(0, 0.05, 0))
	for i: int in line.size() - 1:
		var a: int = i * 2
		tool.add_index(a)
		tool.add_index(a + 1)
		tool.add_index(a + 2)
		tool.add_index(a + 1)
		tool.add_index(a + 3)
		tool.add_index(a + 2)
	tool.generate_tangents()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STREAM_SHADER
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Stream"
	water.mesh = tool.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# берега: камни и папоротник вперемешку, чтобы лента не лежала на голой земле
	var banks: Dictionary[String, Array] = {}
	for i: int in range(0, line.size(), 3):
		for k: int in 2:
			if _rng.randf() < 0.35:
				continue
			var ahead: Vector2 = line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]
			var side: Vector2 = Vector2(-ahead.y, ahead.x).normalized() * (1.0 if k == 0 else -1.0)
			var bank: Vector2 = line[i] + side * (STREAM_WIDTH * 0.5 + _rng.randf_range(0.1, 0.9))
			if _clearance(bank) < 0.5:
				continue
			if _rng.randf() < 0.45:
				_place_rock(_w3(bank), self)
			else:
				_collect(banks, FERN_IDS[_rng.randi() % FERN_IDS.size()], _w(bank), _rng.randf_range(0.9, 1.4))
	_build_collected(banks, self)


## Русло ручья точками через ~0,7 м (координаты вида).
func _stream_line() -> Array[Vector2]:
	var line: Array[Vector2] = []
	var points: Array[Vector2] = STREAM_POINTS
	for i: int in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		var steps: int = maxi(2, ceili(p1.distance_to(p2) / 0.7))
		for k: int in steps:
			line.append(p1.cubic_interpolate(p2, p0, p3, float(k) / steps))
	line.append(points[points.size() - 1])
	return line


## Расстояние от точки (координаты вида) до оси ручья по ломаной опорных точек.
static func _stream_distance(v: Vector2) -> float:
	var best: float = INF
	for i: int in STREAM_POINTS.size() - 1:
		var a: Vector2 = STREAM_POINTS[i]
		var b: Vector2 = STREAM_POINTS[i + 1]
		var t: float = clampf((v - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, v.distance_to(a + (b - a) * t))
	return best

## Лес и дымка расставляются в «координатах вида»: x — поперёк кадра (слева направо), y — к камере
## (дальний край двора — VIEW_MIN.y, ближний — VIEW_MAX.y). Камера матча смотрит с края поля x = 18,
## поэтому вид повёрнут к миру на 90°: x вида = −z мира, y вида = x мира − 18.
static func _w(v: Vector2) -> Vector2:
	return Vector2(v.y + BOARD_MAX.x, -v.x)


static func _w3(v: Vector2) -> Vector3:
	var p: Vector2 = _w(v)
	return Vector3(p.x, 0.0, p.y)


static func _v(p: Vector2) -> Vector2:
	return Vector2(-p.y, p.x - BOARD_MAX.x)


## Расстояние от точки до края полосы без деревьев вокруг поля (меньше нуля — внутри полосы).
func _clearance(p: Vector2) -> float:
	var lo: Vector2 = VIEW_MIN - Vector2(CLEAR_SIDE, CLEAR_FAR)
	var hi: Vector2 = VIEW_MAX + Vector2(CLEAR_SIDE, CLEAR_NEAR)
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
func _multimesh(id: String, transforms: Array[Transform3D], parent: Node3D = null) -> void:
	var model: Node3D = _prop(id)
	if model == null or transforms.is_empty():
		return
	add_child(model)  # временно — чтобы посчитать мировые преобразования частей модели
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = model.global_transform.affine_inverse() * part.global_transform
		_moonlit(part.mesh)
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part.mesh
		multi.instance_count = transforms.size()
		for i: int in transforms.size():
			multi.set_instance_transform(i, transforms[i] * local)
		var holder: MultiMeshInstance3D = MultiMeshInstance3D.new()
		holder.multimesh = multi
		holder.name = "%s_forest" % id
		(parent if parent != null else self).add_child(holder)
	model.queue_free()


## Материалы леса (только у копий в MultiMesh): чуть светлее и с лунным контуром.
static func _moonlit(mesh: Mesh) -> void:
	for surface: int in mesh.get_surface_count():
		var material: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null or material.has_meta(&"moonlit"):
			continue
		material.set_meta(&"moonlit", true)
		material.albedo_color = material.albedo_color * TREE_BRIGHT
		material.rim_enabled = true
		material.rim = TREE_RIM
		material.rim_tint = 0.4


## Клубы тумана между деревьями (как на концепте): полотна с клубящимся шумом. Деревья стоят
## перед ними и режут туман на слои; за задней стеной (под луной) гуще и светлее, по бокам реже,
## между камерой и двором — нет.
func _build_mist_cards() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var lo: Vector2 = VIEW_MIN - FENCE_BELT.x * Vector2.ONE
	var hi: Vector2 = VIEW_MAX + FENCE_BELT.x * Vector2.ONE
	for row: int in MIST_ROWS.size():
		var z: float = lo.y - MIST_ROWS[row]
		var x: float = lo.x - 30.0 - row * 6.0
		while x < hi.x + 30.0 + row * 6.0:
			var width: float = rng.randf_range(18.0, 28.0) + row * 4.0
			_add_mist_card(_w3(Vector2(x + width * 0.5, z + rng.randf_range(-2.0, 2.0))),
					Vector2(width, rng.randf_range(5.0, 8.0) + row * 1.5), MIST_MOON_TINT,
					MIST_ROW_OPACITY[row], rng.randf() * 10.0)
			x += width * 0.62
	for side: float in [-1.0, 1.0]:
		var edge: float = lo.x if side < 0.0 else hi.x
		for depth: float in [6.0, 14.0]:
			var z: float = lo.y + 2.0
			while z < hi.y - 2.0:
				var width: float = rng.randf_range(12.0, 18.0)
				_add_mist_card(_w3(Vector2(edge + side * depth, z + width * 0.3)),
						Vector2(width, rng.randf_range(4.0, 6.0)), MIST_SIDE_TINT,
						MIST_SIDE_OPACITY * (0.7 if depth < 10.0 else 1.0), rng.randf() * 10.0)
				z += width * 0.55


func _add_mist_card(at: Vector3, card: Vector2, tint: Color, opacity: float, seed: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = card
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MIST_SHADER
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("card_size", card)
	material.set_shader_parameter("seed", seed)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at + Vector3(0.0, card.y * 0.5 - 0.8, 0.0)
	add_child(instance)


## Низовой туман слоем у земли (noir_ground_mist.gdshader): полноэкранный квад в сцене считает туман
## по глубине каждого пикселя — стволы стоят в тумане, кроны над ним. Двор (с частоколом) чистый.
func _build_ground_mist() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GROUND_MIST_SHADER
	material.render_priority = -50  # раньше огня и эффектов: пламя поверх тумана, а не в нём
	var pad: float = 1.6
	var a: Vector2 = Vector2(BOARD_MIN.x - pad, BOARD_MIN.y - pad)
	var b: Vector2 = Vector2(BOARD_MAX.x + pad, BOARD_MAX.y + pad)
	material.set_shader_parameter("yard_rect", Vector4(a.x, a.y, b.x, b.y))
	quad.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "GroundMist"
	instance.mesh = quad
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 16384.0  # квад растянут на экран в шейдере — не отсекать по рамке
	add_child(instance)

## Дымка в лесу за стеной (как на концепте), гуще вдали; двор остаётся чистым и читаемым.
func _build_mist() -> void:
	# концепт: за частоколом дымка яркая и заметная, клочьями; во дворе её почти нет
	var material: FogMaterial = FogMaterial.new()
	material.density = MIST_BACK
	material.albedo = Color(0.64, 0.68, 0.7)
	material.emission = Color(0.15, 0.16, 0.16)  # светится сама — лунная дымка
	material.height_falloff = 0.35
	material.edge_fade = 0.5
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	var patches: NoiseTexture3D = NoiseTexture3D.new()
	patches.noise = noise
	patches.width = 64
	patches.height = 16
	patches.depth = 64
	patches.seamless = true
	material.density_texture = patches
	var lo: Vector2 = VIEW_MIN - Vector2(1.6, 1.6)
	var hi: Vector2 = VIEW_MAX + Vector2(1.6, 1.6)
	var strips: Array[Rect2] = [
		Rect2(FOREST_MIN.x, FOREST_MIN.y, FOREST_MAX.x - FOREST_MIN.x, lo.y - FOREST_MIN.y),
		Rect2(FOREST_MIN.x, hi.y + 3.0, FOREST_MAX.x - FOREST_MIN.x, FOREST_MAX.y - hi.y - 3.0),
		Rect2(FOREST_MIN.x, lo.y, lo.x - FOREST_MIN.x, hi.y - lo.y),
		Rect2(hi.x, lo.y, FOREST_MAX.x - hi.x, hi.y - lo.y)]
	var dim: FogMaterial = material.duplicate() as FogMaterial
	dim.density = MIST_SIDES
	for strip: Rect2 in strips:
		var volume: FogVolume = FogVolume.new()
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		# низовой туман клочьями: кроны выступают тёмными силуэтами над светлой дымкой
		volume.size = Vector3(strip.size.y, 2.6, strip.size.x)  # поворот вида на 90°: оси меняются
		volume.position = _w3(strip.get_center()) + Vector3(0, 0.5, 0)
		volume.material = material if strip == strips[0] else dim  # первая полоса — за задней стеной, под луной
		add_child(volume)
