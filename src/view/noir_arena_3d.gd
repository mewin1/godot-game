class_name NoirArena3D
extends Node3D
## Растущий двор PvP по new_concept/arena/arena_battle_25.png. Мостовая, въезд и терем
## следуют открытой дороге. Внешний лес из assets/noir/courtyard расставлен по мастер-сцене Blender.
## Клетка поля занимает 2 м. Границы двора определяет поле матча.

const PROPS: String = "res://assets/noir_h3d/arena/%s.glb"
## Камни опушки по концептам new_concept/rocks (tools/blender/noir/rocks.py) и их композиция.
const ROCKS: String = "res://assets/noir/rocks/%s.glb"
const ROCK_LAYOUT: CourtyardForestLayout = preload("res://assets/noir/courtyard/rock_layout.tres")
const FOREST_LAYOUT: CourtyardForestLayout = preload("res://assets/noir/courtyard/forest_layout.tres")
const FOREST_FILL: CourtyardForestLayout = preload("res://assets/noir/courtyard/forest_fill.tres")
## Радиус камня при масштабе 1 (м) — звери обходят.
const ROCK_RADIUS: Dictionary[String, float] = {"rock_boulder": 0.85, "rock_slab": 1.1, "rock_menhir": 0.45,
		"rock_cluster": 1.0, "rock_split": 0.95, "rock_flat": 0.5}
## Камни у ручья и в подлеске: мелкие формы (крупные стоят группами из ROCK_LAYOUT).
## Сколько куртин травы на поляне вокруг двора.
const MEADOW_CLUMPS: int = 78
const SMALL_ROCKS: Array[String] = ["rock_flat", "rock_flat", "rock_cluster", "rock_boulder", "rock_split"]
const CellarGeometry = preload("res://src/view/courtyard_cellars.gd")
const COURTYARD_PROPS: Dictionary[String, PackedScene] = {
	"cellar_arch": preload("res://assets/noir/courtyard/cellar_arch.glb"),
	"cellar_wall": preload("res://assets/noir/courtyard/cellar_wall.glb"),
	"fire_bowl": preload("res://assets/noir/courtyard/fire_bowl.glb"),
	"gate": preload("res://assets/noir/courtyard/gate.glb"),
	"palisade": preload("res://assets/noir/courtyard/palisade.glb"),
	"palisade_post": preload("res://assets/noir/courtyard/palisade_post.glb"),
	"terem": preload("res://assets/noir/courtyard/terem.glb"),
	"sedge": preload("res://assets/noir/courtyard/sedge.glb"),
	"seed_grass": preload("res://assets/noir/courtyard/seed_grass.glb"),
	"fern": preload("res://assets/noir/courtyard/fern.glb"),
	"shingle": preload("res://assets/noir/courtyard/shingle.glb"),
	"moss_rock": preload("res://assets/noir/courtyard/moss_rock.glb"),
	"spruce": preload("res://assets/noir/courtyard/spruce.glb"),
	"birch": preload("res://assets/noir/courtyard/birch.glb"),
}
## Слой окружения (лес, трава, камни): солнце и луна дают от него тени, факелы — нет
## (их тени нужны только от частокола, иначе каждый факел перерисовывает весь лес).
const ENV_LAYER: int = 2
## Насколько днём сдвинуть траву и лесную землю из жёлто-зелёного в сине-зелёный
## (noir_forest_shade.gdshaderinc): иначе на свету лимонная трава — «кислотно» и «болото».
## Ночью и в PvP не действует (тень леса там 0).
const GRASS_DAY_TINT: float = 0.85
const GROUND_DAY_TINT: float = 0.6
## Слои, от которых факелы бросают тени (всё, кроме окружения).
const TORCH_SHADOW_MASK: int = 0xFFFFF & ~ENV_LAYER
## Трава (Poly Haven) — без теней; под пологом леса рисуется её часть (_keep_grass).
const GRASS_IDS_3D: Array[String] = ["sedge", "seed_grass", "fern"]
## Насколько за край поляны трава ещё густая (м).
const GRASS_GLADE_MARGIN: float = 6.0
## Деревья дальше этого от двора (м, от середины участка) не отбрасывают тени солнца.
const FAR_SHADOW: float = 18.0
const BOARD_MIN: Vector2 = Vector2(0.0, -20.0)
const BOARD_MAX: Vector2 = Vector2(18.0, 0.0)
const CELL: float = 2.0
## Мелкая сетка двора (м): клетка поля — 2×2 мелких, частокол отступает от открытых клеток на 1 мелкую.
const FINE: float = 1.0
const YARD_PAD: int = 1
const GATE_WIDTH: float = 3.2
const FIRE_COLOR: Color = Color(1.0, 0.49, 0.16)
const ROAD_HALF_WIDTH: float = 1.0
## Стена и жаровни крупнее, как на концепте арены (стена выше человека, жаровни — по пояс-грудь).
const WALL_SCALE: float = 1.25
const FIRE_SCALE: float = 1.05
const TORCH_STEP: float = 12.0
const TEREM_OFFSET: float = 4.4
const TEREM_SCALE: float = 1.55
## Лес: россыпь с интервалами (как на концепте — стволы стоят порознь, между ними дымка).
## Камера перспективная и пологая — дальний лес уходит к горизонту в дымку.
const FOREST_MIN: Vector2 = Vector2(-60.0, -120.0)
const FOREST_MAX: Vector2 = Vector2(80.0, 14.0)
## Земля леса: яркость и оттенок фактур (зелёный мох).
const GROUND_TINT: float = 0.19
const GROUND_HUE: Vector3 = Vector3(0.82, 0.93, 0.91)
## Вокруг поля полоса без деревьев (частокол, терем); у ближнего к камере края — шире, чтобы не закрыть двор.
const CLEAR_FAR: float = 7.5
const CLEAR_SIDE: float = 4.5
const CLEAR_NEAR: float = 9.0
## Деревья под луной: лунный контур отделяет кроны от тёмной земли (как на концепте).
const CANOPY: Shader = preload("res://assets/shaders/noir_canopy.gdshader")
const CANOPY_HASHED: Shader = preload("res://assets/shaders/noir_canopy_hashed.gdshader")
## Кора с ветками елей и берёз: гнётся ветром вместе с листвой (иначе лапы съезжают с веток).
const TREE_BARK: Shader = preload("res://assets/shaders/noir_tree_bark.gdshader")
const TREE_RIM: float = 0.045
const TREE_BRIGHT: float = 0.72
## Земля леса — смесь трёх фактур Poly Haven (CC0) пятнами по шуму, темнее двора, с ямками и буграми.
const PAVING_SHADER: Shader = preload("res://assets/shaders/noir_paving.gdshader")
const FLAME_SHADER: Shader = preload("res://assets/shaders/noir_flame.gdshader")
const FOREST_FOG: Shader = preload("res://assets/shaders/noir_forest_fog.gdshader")
const STREAM_SHADER: Shader = preload("res://assets/shaders/noir_stream.gdshader")
## Ручей через лес слева от двора (точки русла в координатах вида, см. _w): из глубины леса к переднему краю.
const STREAM_POINTS: Array[Vector2] = [Vector2(-30.0, -90.0), Vector2(-17.0, -55.0), Vector2(-9.0, -32.0),
		Vector2(-6.4, -17.0), Vector2(-7.2, -6.0), Vector2(-5.5, 3.0), Vector2(-9.0, 12.0), Vector2(-18.0, 20.0)]
const STREAM_WIDTH: float = 2.4
## Где на ручье отражается луна (координаты вида, на русле у левого края двора).
const STREAM_MOON: Vector2 = Vector2(-6.6, -14.0)
const GROUND_MIST_SHADER: Shader = preload("res://assets/shaders/noir_ground_mist.gdshader")
## Высота языка пламени на единицу масштаба чаши, м.
const FLAME_HEIGHT: float = 1.16
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
uniform sampler2D river_margin : filter_linear, repeat_disable;
uniform vec4 margin_extent;
// Мир → координаты расстановки леса (маска берегов снята в них); в PvP — тождество.
uniform mat4 env_from_world = mat4(1.0);
uniform float tile = 4.5;
uniform float tint = 0.1;
uniform vec3 hue = vec3(0.62, 1.0, 0.64);
uniform float bumps = 0.085;
// поляна вокруг двора: за ней земля днём в тени леса (noir_forest_shade.gdshaderinc)
uniform vec4 glade_a = vec4(-1e5, -1e5, 1e5, 1e5);
uniform vec4 glade_b = vec4(-1e5, -1e5, 1e5, 1e5);
#include "res://assets/shaders/noir_forest_shade.gdshaderinc"
varying vec3 world;

float yard_fade(vec2 p) {
	vec2 d = max(yard_rect.xy - p, p - yard_rect.zw);
	return smoothstep(1.0, 6.0, length(max(d, vec2(0.0))));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = textureLod(blend_noise, world.xz * 0.045, 0.0).r;
	vec2 creek_uv = ((env_from_world * vec4(world, 1.0)).xz - margin_extent.xy) / margin_extent.zw;
	VERTEX.y -= n * bumps * yard_fade(world.xz) + 0.24 * textureLod(river_margin, creek_uv, 0.0).r;
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
	// Зелень подушки мха и тёплая хвоя остаются раздельными пятнами даже в сумерках.
	a *= mix(vec3(0.97, 0.84, 0.73), vec3(0.83, 1.16, 0.92), wm * (1.0 - wl * 0.6));
	vec3 nm = mix(texture(mud_normal, uv2).rgb, texture(moss_normal, uv).rgb, wm);
	nm = mix(nm, texture(litter_normal, uv * 1.21).rgb, wl * 0.75);
	// за частоколом — тёмная лесная трава (концепт: двор — самое светлое место, лес вокруг почти чёрный)
	vec3 margin = texture(river_margin, ((env_from_world * vec4(world, 1.0)).xz - margin_extent.xy) / margin_extent.zw).rgb;
	a = mix(a, texture(mud_albedo, uv2).rgb * vec3(0.64, 0.74, 0.77), margin.g * 0.73);
	a *= mix(vec3(1.0), vec3(0.87, 1.17, 0.87), margin.b * wm);
	a = mix(vec3(dot(a, vec3(0.25, 0.60, 0.15))), a, 0.55);
	ALBEDO = noir_floor_shaded(noir_day_tinted(a * hue * tint * mix(1.0, 0.62, yard_fade(world.xz))), world.xz, glade_a, glade_b);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.36;
	ROUGHNESS = mix(mix(0.59, 0.95, max(wm, wl)), 0.53, margin.g);
}
"""
## Трава и подлесок Poly Haven (облегчённые — tools/blender/noir/polyhaven.py): пучки крупнее
## настоящих — в масштабе игры трава по колено, как на концепте.
## Камни — Quaternius Stylized Nature MegaKit (CC0, tools/concepts/quaternius_copy.py), приглушены под ночь.
const QUATERNIUS: String = "res://assets/quaternius/nature/%s"
## Дальний лес — рисованные силуэты, одна MultiMesh на картинку. В поясе двора
## _collect подбирает объёмные деревья, осоку и папоротник. Масштаб деревьев — высота в метрах.
const BILLBOARDS: String = "res://assets/noir_h3d/arena/forest/%s.png"
const PINE_IDS: Array[String] = ["bb/spruce_11", "bb/spruce_37", "bb/spruce_52", "bb/spruce_64"]
const BIRCH_IDS: Array[String] = ["bb/birch_11", "bb/birch_37", "bb/birch_52"]
const GRASS_IDS: Array[String] = ["bb/grass_11", "bb/grass_37", "bb/grass_52"]
const FERN_IDS: Array[String] = ["bb/fern_37", "bb/fern_52", "bb/fern_64"]
## Подрост между стволами — средний ярус леса (на концепте под кронами тёмная масса, а не пустота).
const SAPLING_IDS: Array[String] = ["bb/sapling_11", "bb/sapling_37", "bb/sapling_52", "bb/sapling_64"]
const GRASS_SCALE: float = 0.9
## Двор в координатах вида (см. _w): 20 м поперёк кадра, 18 м в глубину.
const VIEW_MIN: Vector2 = Vector2(0.0, -18.0)
const VIEW_MAX: Vector2 = Vector2(20.0, 0.0)
## Пояс елей за частоколом: от и до (м от края поля).
const FENCE_BELT: Vector2 = Vector2(1.6, 5.5)
## Яркость рисованных картинок в сцене (рисунок ночной и тёмный — чуть светлее, чтобы читались силуэты).
const BILLBOARD_TINT: Color = Color(1.0, 1.08, 1.04)
## Белые берёзы не должны перетягивать внимание с двора.
const BIRCH_DIM: float = 1.0
## Молодые ели нарисованы светлее старых — в поясе у частокола они не должны выделяться.
const SAPLING_DIM: float = 0.9
## Плотность низовой дымки: за задней стеной (под луной) и по бокам/спереди.
const PROP_TINTS: Dictionary[String, Color] = {"q/Rock": Color(0.32, 0.36, 0.36)}
## Факелы вдоль частокола: на концепте стена тёмная, тёплые пятна — у жаровен.
const TORCH_ENERGY: float = 1.4
## На длинной стене жаровня чередуется с факелами.
const WALL_BOWLS: bool = true
const WALL_BOWL_SCALE: float = 0.8
const BOWL_ENERGY: float = 2.4
const BOWL_REACH: float = 5.5
## Большие чаши в углах двора: тёплое пятно, но не заливать двор оранжевым.
const CORNER_FIRE_ENERGY: float = 3.25
## Отступ чаши внутрь двора от углового столба.
const CORNER_FIRE_INSET: float = 0.25
## Жаровни по сторонам ворот.
const GATE_BOWL_SCALE: float = 1.2
const GATE_BOWL_ENERGY: float = 2.80
const CORNER_FIRE_REACH: float = 9.0
const TORCH_REACH: float = 4.8

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _layout: ArenaLayout3D
var _cellars: CellarGeometry
var _yard: Node3D
var _open_key: int = -1
var _leaf_material: ShaderMaterial = ShaderMaterial.new()
var _terem_scene: PackedScene
## Габариты настоящей модели, включая главку и крыльцо, для кадра PvP.
var terem_bounds: AABB
## Трава двора (вдоль частокола, в закрытых клетках) — пересобирается вместе с двором.
var _yard_grass: Dictionary[String, Array] = {}
## Ветер, листья, светлячки, вороны, медвежонок (src/view/arena_ambience_3d.gd).
var _ambience: ArenaAmbience3D
## Верх столбов частокола — куда садятся вороны (собирается в _build_walls).
var _perches: Array[Transform3D] = []
var _post_top: float = -1.0
## Камни леса и берега (x, z, радиус) — для обхода зверями.
var _rock_spots: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	_leaf_material.shader = preload("res://assets/shaders/noir_leaves.gdshader")
	_set_glades(_leaf_material)
	_leaf_material.set_shader_parameter("day_tint", GRASS_DAY_TINT)
	_rng.seed = 22
	_build_ground()


## Неизменная часть (земля леса, лес, дымка) — один раз, когда ArenaStage3D получит раскладку.
func build_for_layout(layout: ArenaLayout3D) -> void:
	if _layout != null:
		return
	_layout = layout
	_terem_scene = COURTYARD_PROPS["terem"]
	_build_stream()
	_build_forest()
	_build_rocks()
	_build_meadow()
	_ambience = ArenaAmbience3D.new()
	_ambience.name = "Ambience"
	add_child(_ambience)
	_ambience.setup(_yard_rect())
	# двор с оградой и терем за дальней стороной поля (z < −20) — медвежонку туда нельзя
	var yard_and_terem: Rect2 = _yard_rect().grow(2.4).grow_side(_terem_side(), 6.0)
	_ambience.setup_wildlife(_wild_zone(), yard_and_terem, _wild_obstacles(),
			_world_stream())
	# Объёмная дымка — только Forward+ на ПК; телефонный профиль рисует дешёвый слой у земли.
	var volume_supported: bool = RenderingServer.get_current_rendering_method() == &"forward_plus" \
			and not RenderQuality.is_mobile()
	var world_env: WorldEnvironment = get_parent().get_node("Environment") as WorldEnvironment
	world_env.environment.volumetric_fog_enabled = volume_supported
	if volume_supported:
		_build_mist()
	else:
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
	var paving: Material = _build_paving(fine)
	var lane: PackedVector2Array = _build_road(_layout.path_length_at(path.size() - 1), door, out3)
	_cellars = CellarGeometry.new()
	var roofs: MeshInstance3D = MeshInstance3D.new()
	roofs.name = "CellarRoofs"
	roofs.mesh = _cellars.roofs(field, _layout, lane)
	roofs.material_override = paving
	_yard.add_child(roofs)
	_multimesh("cellar_arch", _cellars.arches, _yard)
	_multimesh("cellar_wall", _cellars.walls, _yard)
	_build_terem(terem_at, out3)
	var entry: Vector3 = _layout.road_point(0.0)
	_build_walls(fine, Vector2(entry.x, entry.z), Vector2(door.x, door.z))
	_build_fires(fine, Vector2(terem_at.x, terem_at.z))
	_build_undergrowth(field.layout, cells, fine)
	_build_collected(_yard_grass, _yard)
	if _ambience != null:
		_ambience.set_perches(_perches)


## Поляна (до двух прямоугольников мира x, z): за ней земля и трава днём в тени леса.
## В PvP поляны нет — тень леса там не включается (всегда ночь).
func _glades() -> Array[Rect2]:
	return []


func _set_glades(material: ShaderMaterial) -> void:
	var rects: Array[Rect2] = _glades()
	for index: int in mini(rects.size(), 2):
		var rect: Rect2 = rects[index]
		material.set_shader_parameter("glade_a" if index == 0 else "glade_b",
				Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y))


## Двор поля в мире (x, z). Другой режим на этой арене задаёт свой двор.
func _yard_rect() -> Rect2:
	return Rect2(BOARD_MIN, BOARD_MAX - BOARD_MIN)


## С какой стороны двора стоит терем.
func _terem_side() -> Side:
	return SIDE_TOP


## Куда переносится расстановка окружения из мастер-сцены (лес, камни, ручей, маска берегов).
## В PvP — как есть; режим с другим двором поворачивает и сдвигает лес вокруг своего двора.
func _env_transform() -> Transform3D:
	return Transform3D.IDENTITY


## Оставить ли дерево / камень окружения в этой точке мира (режим с большим двором прореживает лес).
func _keep_env(_at: Vector3, _tree: bool) -> bool:
	return true


## Лес (деревья, подлесок) и камни из мастер-сцены; режим может добавить свою досадку.
func _forest_layouts() -> Array[CourtyardForestLayout]:
	return [FOREST_LAYOUT, FOREST_FILL]


func _rock_layouts() -> Array[CourtyardForestLayout]:
	return [ROCK_LAYOUT]


## Точка мира во дворе с оградой или под теремом — луг и камни туда не ставятся.
func _in_yard(p: Vector2) -> bool:
	return _yard_rect().grow(1.0).grow_side(_terem_side(), 6.5).has_point(p)


## Расстановка из мастер-сцены → мир, без того, что режим велит убрать.
func _env_placements(placed: Array, tree: bool) -> Array[Transform3D]:
	var env: Transform3D = _env_transform()
	var result: Array[Transform3D] = []
	for at: Transform3D in placed:
		var moved: Transform3D = env * at
		if _keep_env(moved.origin, tree):
			result.append(moved)
	return result


## Точка русла (координаты вида) после переноса окружения.
func _env_view(p: Vector2) -> Vector2:
	var env: Transform3D = _env_transform()
	if env == Transform3D.IDENTITY:
		return p
	var at: Vector3 = env * _w3(p)
	return Vector2(-at.z, at.x - BOARD_MAX.x)


## Во дворе идёт бой: вороны слетают с частокола и не садятся на него, пока бой не кончится.
func set_battle(active: bool) -> void:
	if _ambience != null:
		_ambience.set_battle(active)


## Скругление на повороте открывает землю под углом строительной клетки.
func roof_contains(cell: Vector2i, point: Vector2) -> bool:
	if _cellars == null or not _cellars.footprints.has(cell):
		return false
	for polygon: PackedVector2Array in _cellars.footprints[cell]:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


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
	if COURTYARD_PROPS.has(id):
		var prop: Node3D = COURTYARD_PROPS[id].instantiate() as Node3D
		if id in ["fern", "sedge", "seed_grass", "moss_rock", "shingle"]:
			_apply_courtyard_pigment(prop)
		return prop
	var path: String = PROPS % id
	if id.begins_with("rock_"):
		path = ROCKS % id
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


## Цвет листьев и камней записан в COLOR_0. Параметры импорта материала GLB
## могут отключить его использование; стебли с обычным материалом оставляем как есть.
func _apply_courtyard_pigment(prop: Node3D) -> void:
	for part: MeshInstance3D in _mesh_parts(prop):
		for surface: int in part.mesh.get_surface_count():
			var material: StandardMaterial3D = part.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			match material.resource_name:
				"Лист • окраска вершинами":
					part.mesh.surface_set_material(surface, _leaf_material)
				"Камень • лишайник":
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = false


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
	_set_glades(material)
	material.set_shader_parameter("day_tint", GROUND_DAY_TINT)
	# Маска снята с оси ручья PvP в Blender; координаты X/Z мира, метры.
	material.set_shader_parameter("river_margin", preload("res://assets/noir/courtyard/river_margin.png"))
	material.set_shader_parameter("margin_extent", Vector4(-80.0, -28.0, 124.0, 64.0))
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
	material.set_shader_parameter("tint", GROUND_TINT)  # мшисто-зелёная, как на концепте 05, а не серо-оливковая
	material.set_shader_parameter("hue", GROUND_HUE)
	var yard: Rect2 = _yard_rect().grow(1.5)
	material.set_shader_parameter("yard_rect", Vector4(yard.position.x, yard.position.y, yard.end.x, yard.end.y))
	material.set_shader_parameter("env_from_world", Projection(_env_transform().affine_inverse()))
	return material


## Плиты двора по мелким клеткам открытой части; швы плит — по мировой сетке (по краям клеток поля).
func _build_paving(fine: Dictionary[Vector2i, bool]) -> Material:
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
	material.set_shader_parameter("setts", preload("res://assets/noir/courtyard/setts.png"))
	material.set_shader_parameter("relief", preload("res://assets/noir/courtyard/setts_relief.png"))
	material.set_shader_parameter("origin", BOARD_MIN)
	yard.material_override = material
	_yard.add_child(yard)
	return material


## Утоптанная светлая дорога поверх плит: от ворот до конца открытого пути и дальше к крыльцу терема.
func _build_road(finish: float, door: Vector3, out3: Vector3) -> PackedVector2Array:
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
	var us: Array[float] = [0.0, 0.5, 1.0]
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side_a: Vector3 = sides[i] * ROAD_HALF_WIDTH
		var side_b: Vector3 = sides[i + 1] * ROAD_HALF_WIDTH
		var v0: float = along / 4.0
		var v1: float = (along + (b - a).length()) / 4.0
		# Три ряда вершин дают небольшой подъём колеи над мостовой.
		var rows_a: Array[Vector3] = [a - side_a + lift, a + lift * 1.2, a + side_a + lift]
		var rows_b: Array[Vector3] = [b - side_b + lift, b + lift * 1.2, b + side_b + lift]
		for k: int in 2:
			_road_vertex(tool, rows_a[k], us[k], v0)
			_road_vertex(tool, rows_b[k + 1], us[k + 1], v1)
			_road_vertex(tool, rows_a[k + 1], us[k + 1], v0)
			_road_vertex(tool, rows_a[k], us[k], v0)
			_road_vertex(tool, rows_b[k], us[k], v1)
			_road_vertex(tool, rows_b[k + 1], us[k + 1], v1)
		along += (b - a).length()
	var road: MeshInstance3D = MeshInstance3D.new()
	road.mesh = tool.commit()
	# бледная грунтовка с колеями и мхом по обочине (шейдер — как на концепте)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ROAD_SHADER
	material.set_shader_parameter("cartway", preload("res://assets/noir/courtyard/cartway.png"))
	material.set_shader_parameter("earth_normal", preload("res://assets/noir_h3d/arena/ground/brown_mud_leaves_01_nor_gl_1k.jpg"))
	material.set_shader_parameter("earth", preload("res://assets/noir_h3d/arena/ground/brown_mud_leaves_01_diff_1k.jpg"))
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yard.add_child(road)
	# Вырез под проезд и узкий водосток у цоколя. Крупные каменные грани на поворотах.
	var left_bank: PackedVector2Array = PackedVector2Array()
	var right_bank: PackedVector2Array = PackedVector2Array()
	for i: int in points.size():
		if i != points.size() - 1 and i % 3 != 0:
			continue
		var side: Vector3 = sides[i] * (ROAD_HALF_WIDTH + 0.12)
		var left: Vector3 = points[i] - side
		var right: Vector3 = points[i] + side
		left_bank.append(Vector2(left.x, left.z))
		right_bank.append(Vector2(right.x, right.z))
	right_bank.reverse()
	left_bank.append_array(right_bank)
	return left_bank


static func _road_vertex(tool: SurfaceTool, at: Vector3, u: float, v: float) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_uv(Vector2(u, v))
	tool.add_vertex(at)


static func _side(direction: Vector3) -> Vector3:
	return Vector3(-direction.z, 0, direction.x)


func _build_terem(at: Vector3, out3: Vector3) -> void:
	terem_bounds = AABB()
	if _terem_scene == null:
		return
	# терем за частоколом в конце дороги (как на концепте) и смотрит навстречу дороге
	var house: Node3D = _terem_scene.instantiate() as Node3D
	_yard.add_child(house)
	house.position = Vector3(at.x, 0, at.z)
	# Фасад и крыльцо ориентированы в мастерской Blender.
	house.scale = Vector3.ONE * TEREM_SCALE  # на концепте арены терем — самый большой дом двора
	terem_bounds = house.transform * _bounds(house)
	_warm_light(house.position - out3 * 2.2 + Vector3(0, 2.4, 0), 4.0, 9.0)


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
		segment = maxf(0.1, maxf(box.size.x, box.size.z))
		probe.free()
	var runs: Array[Run] = _wall_runs(fine)
	_perches = []
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
			var panel: Node3D = _place("palisade", Vector3(center.x, 0, center.y), yaw)
			if panel != null:
				panel.scale = Vector3(step / segment, WALL_SCALE, 1.0)
			if k % 2 == 0 and k > 0:
				var post: Vector2 = run.a + direction * step * k
				_place("palisade_post", Vector3(post.x, 0, post.y), yaw + PI)
				_add_perch(post, 1.0, run.out)
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
			var pool: Vector2 = p - run.out * 0.32
			# у стен, повёрнутых к камере (ближняя и правая), свет без теней проходит сквозь колья и красит их
			# наружную сторону в рыжий — на концепте она тёмная; таким факелам — тени
			var facing_camera: bool = run.out.y > 0.0 or run.out.x > 0.0
			_warm_light(Vector3(pool.x, 1.85, pool.y), BOWL_ENERGY if bowl else TORCH_ENERGY,
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
	# Резные столбы поднимаются над частоколом и читаются на поворотах двора.
	for corner: Vector2 in corners:
		var post_scale: float = 1.14 if _corner_inside_count(fine, corner) == 1 else 1.0
		_place("palisade_post", Vector3(corner.x, 0, corner.y), 0.0, post_scale)
		_add_perch(corner, post_scale, (corner - _yard_rect().get_center()).normalized())
	if gate_run != null:
		var gate_yaw: float = 0.0 if gate_run.out.y != 0.0 else PI * 0.5
		_place("gate", Vector3(gate_point.x, 0, gate_point.y), gate_yaw)
		_warm_light(Vector3(gate_point.x, 2.15, gate_point.y), 2.2, 4.5)
		# ворота — тёплый акцент слева (как на концепте 05): по жаровне с огнём по обе стороны, снаружи двора
		var along: Vector2 = Vector2(-gate_run.out.y, gate_run.out.x)
		for side: float in [-1.0, 1.0]:
			var spot: Vector2 = gate_point + along * side * (GATE_WIDTH * 0.5 + 0.9) + gate_run.out * 0.9
			_add_flame(_place("fire_bowl", Vector3(spot.x, 0, spot.y), _rng.randf() * TAU, GATE_BOWL_SCALE),
					FLAME_HEIGHT * GATE_BOWL_SCALE)
			_warm_light(Vector3(spot.x, 1.5, spot.y), GATE_BOWL_ENERGY, 5.0)


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
	light.shadow_enabled = shadow and RenderQuality.torch_shadows()
	light.shadow_caster_mask = TORCH_SHADOW_MASK
	light.light_color = FIRE_COLOR
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.5
	light.position = at
	(parent if parent != null else _yard).add_child(light)


static func _mesh_parts(root: Node3D) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		parts.append(root as MeshInstance3D)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		parts.append(child as MeshInstance3D)
	return parts


func _bounds(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh_node: MeshInstance3D in _mesh_parts(node):
		var local: AABB = mesh_node.get_aabb()
		var ancestor: Node3D = mesh_node
		while ancestor != node and ancestor != null:
			local = ancestor.transform * local
			ancestor = ancestor.get_parent() as Node3D
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
		# Два внешних угла дают свет по диагонали, в тесных изломах двора чаш нет.
		if cell != lo and cell != hi:
			continue
		var corner: Vector2 = _fine_to_world(Vector2(cell) + Vector2(0.5, 0.5)) + inward * CORNER_FIRE_INSET
		if corner.distance_to(terem) < 5.0:
			continue
		var at: Vector3 = Vector3(corner.x, 0, corner.y)
		_add_flame(_place("fire_bowl", at, _rng.randf() * TAU, FIRE_SCALE), FLAME_HEIGHT * FIRE_SCALE)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = FIRE_COLOR
		light.light_energy = CORNER_FIRE_ENERGY
		light.omni_range = CORNER_FIRE_REACH
		light.omni_attenuation = 1.5
		light.shadow_enabled = RenderQuality.torch_shadows()
		light.shadow_caster_mask = TORCH_SHADOW_MASK
		light.position = at + Vector3(0, 1.88, 0) + Vector3(inward.x, 0, inward.y) * 0.23
		_yard.add_child(light)


## Язык пламени над чашей (шейдер, лицом к камере) — у модели огонь сверху выглядит плоскими углями.
func _add_flame(bowl: Node3D, height: float) -> void:
	if bowl == null:
		return
	var top: float = _bounds(bowl).end.y * bowl.scale.y
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(height * 0.85, height * 1.22)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("seed", _rng.randf() * 10.0)
	quad.material = material
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = bowl.position + Vector3(0, top - 0.16 * bowl.scale.y, 0)
	_yard.add_child(flame)
	var fx: Node3D = ArenaAmbience3D.make_fire_fx(height)
	fx.position = flame.position
	_yard.add_child(fx)


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
					_place(SMALL_ROCKS[absi(hash(cell)) % SMALL_ROCKS.size()], at, yaw, size * 0.5)
			for k: int in 2:
				var tuft: Vector2 = Vector2(BOARD_MIN.x + x * CELL + rng.randf_range(0.1, 1.9),
						BOARD_MIN.y + y * CELL + rng.randf_range(0.1, 1.9))
				_collect(_yard_grass, GRASS_IDS[rng.randi() % GRASS_IDS.size()], tuft, GRASS_SCALE * rng.randf_range(0.8, 1.2))


## Внешний лес расставлен в courtyard.blend. Места внутри растущего двора и берег
## ручья по-прежнему заполняются относительно действующей игровой геометрии.
## forest_fill.tres (tools/concepts/forest_fill.py) досаживает лес туда, куда камера смотрит, а мастер-сцена
## деревьев не ставила, — левая половина кадра. Виды сливаются: одна MultiMesh на вид.
func _build_forest() -> void:
	var merged: Dictionary[String, Array] = {}
	for layout: CourtyardForestLayout in _forest_layouts():
		for species: String in layout.placements:
			if species == "moss_rock" or ROCK_RADIUS.has(species):
				continue  # одинаковые валуны мастер-сцены заменены композицией из rock_layout.tres (_build_rocks)
			if not merged.has(species):
				merged[species] = []
			merged[species].append_array(layout.placements[species])
	for species: String in merged:
		_multimesh(species, _env_placements(merged[species], species == "spruce" or species == "birch"), self)


## Поляна вокруг двора: трава куртинами (пятна гуще и реже, а не ровная россыпь), папоротник и осока
## у подножия камней, мягкая опушка из папоротника и ёлочек на краю леса. Свой RNG — прежняя расстановка
## двора и берегов не сдвигается.
func _build_meadow() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7707
	var sets: Dictionary[String, Array] = {}
	var zone: Rect2 = _wild_zone().grow(4.0)
	var stream: PackedVector2Array = _world_stream()
	var to_env: Transform3D = _env_transform().affine_inverse()
	var rocks: Array[Vector3] = []
	for layout: CourtyardForestLayout in _rock_layouts():
		for kind: String in layout.placements:
			if not ROCK_RADIUS.has(kind):
				continue
			for at: Transform3D in _env_placements(layout.placements[kind], false):
				rocks.append(Vector3(at.origin.x, at.origin.z, ROCK_RADIUS[kind] * at.basis.get_scale().x))
	var free: Callable = func(p: Vector2, near_stream: float) -> bool:
		if _in_yard(p) or _stream_gap(p, stream) < near_stream:
			return false
		var env: Vector3 = to_env * Vector3(p.x, 0.0, p.y)
		if absf(env.x - 3.0) < 1.1 and env.z > -0.5 and env.z < 8.0:
			return false  # тропа от ворот к броду
		for rock: Vector3 in rocks:
			if p.distance_to(Vector2(rock.x, rock.y)) < rock.z * 0.75:
				return false
		return true
	# куртины травы
	for clump: int in MEADOW_CLUMPS:
		var center: Vector2 = Vector2(rng.randf_range(zone.position.x, zone.end.x), rng.randf_range(zone.position.y, zone.end.y))
		var radius: float = rng.randf_range(1.0, 2.6)
		# каждая пятая куртина — папоротниковая, остальные — осока со злаком
		var ferny: bool = rng.randf() < 0.2
		for k: int in rng.randi_range(14, 32):
			var p: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
			if not free.call(p, 1.5):
				continue
			if ferny and rng.randf() < 0.6:
				_collect(sets, "fern", p, rng.randf_range(0.7, 1.2), rng.randf() * TAU)
			else:
				var id: String = "sedge" if rng.randf() < 0.62 else "seed_grass"
				_collect(sets, id, p, GRASS_SCALE * rng.randf_range(0.75, 1.4), rng.randf() * TAU)
	# камни «садятся» в землю: папоротник и осока у подножия
	for rock: Vector3 in rocks:
		for k: int in rng.randi_range(2, 5):
			var p: Vector2 = Vector2(rock.x, rock.y) + Vector2.from_angle(rng.randf() * TAU) * rock.z * rng.randf_range(0.85, 1.35)
			if free.call(p, 1.3):
				var fern: bool = rng.randf() < 0.55
				_collect(sets, "fern" if fern else "sedge", p,
						(rng.randf_range(0.8, 1.2) * 1.1) if fern else GRASS_SCALE * rng.randf_range(0.7, 1.1), rng.randf() * TAU)
	# опушка: край полосы без деревьев — папоротник и молодые ели вперемешку, без ровной линии
	var edge: Rect2 = _wild_zone().grow(1.2)
	var corners: Array[Vector2] = [edge.position, Vector2(edge.end.x, edge.position.y), edge.end,
			Vector2(edge.position.x, edge.end.y)]
	for side: int in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var outward: Vector2 = (a + b - edge.get_center() * 2.0).normalized()
		var along: float = 0.0
		while along < a.distance_to(b):
			var p: Vector2 = a + (b - a).normalized() * along + outward * rng.randf_range(-0.6, 2.6)
			along += rng.randf_range(0.6, 1.2)
			if not free.call(p, 1.8):
				continue
			var roll: float = rng.randf()
			if roll < 0.45:
				_collect(sets, "fern", p, rng.randf_range(0.9, 1.4), rng.randf() * TAU)
			elif roll < 0.62:
				_collect(sets, "spruce", p, rng.randf_range(1.5, 3.2), 0.0)
			elif roll < 0.68:
				_collect(sets, "birch", p, rng.randf_range(2.0, 3.2), 0.0)
			elif roll < 0.92:
				_collect(sets, "seed_grass", p, GRASS_SCALE * rng.randf_range(0.9, 1.4), rng.randf() * TAU)
	_build_collected(sets, self)


func _stream_gap(p: Vector2, stream: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in stream.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, stream[i], stream[i + 1])))
	return best


## Камни опушки: группы и одиночные валуны разных форм (tools/concepts/rock_layout.py).
func _build_rocks() -> void:
	for layout: CourtyardForestLayout in _rock_layouts():
		for kind: String in layout.placements:
			if not ROCK_RADIUS.has(kind):
				continue
			var transforms: Array[Transform3D] = _env_placements(layout.placements[kind], false)
			_multimesh(kind, transforms, self)
			for at: Transform3D in transforms:
				_rock_spots.append(Vector3(at.origin.x, at.origin.z, ROCK_RADIUS[kind] * at.basis.get_scale().x))


func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	var near_yard: bool = Rect2(BOARD_MIN - Vector2(12.0, 12.0),
			BOARD_MAX - BOARD_MIN + Vector2(24.0, 24.0)).has_point(at)
	if near_yard:
		if id.begins_with("bb/grass_"):
			id = "seed_grass" if id.ends_with("52") else "sedge"
		elif id.begins_with("bb/fern_"):
			id = "fern"
		elif id.begins_with("bb/sapling_") or id.begins_with("bb/spruce_"):
			id = "spruce"
		elif id.begins_with("bb/birch_"):
			id = "birch"
	if not into.has(id):
		into[id] = []
	var turn: float = yaw if yaw >= 0.0 else _rng.randf() * TAU
	if id == "spruce" or id == "birch":
		turn = fposmod(at.x * 1.73 + at.y * 2.41, TAU)
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


## Камень берега: мелкие формы, реже прежнего (одинаковые валуны стояли сплошной цепью).
## Два вызова _rng — как раньше, чтобы остальная расстановка у ручья не сдвинулась.
func _place_rock(at: Vector3, parent: Node3D = null) -> void:
	var yaw: float = _rng.randf() * TAU
	var size: float = _rng.randf_range(0.7, 1.55)
	var pick: int = absi(hash(Vector2i(roundi(at.x * 10.0), roundi(at.z * 10.0))))
	if pick % 3 == 0:
		return
	var kind: String = SMALL_ROCKS[pick % SMALL_ROCKS.size()]
	_place(kind, at, yaw, size * (0.75 if kind == "rock_flat" else 0.45), parent)
	_rock_spots.append(Vector3(at.x, at.z, ROCK_RADIUS[kind] * size * 0.6))



## Ручей: лента по сглаженному руслу (Catmull-Rom), по берегам — камни и папоротник.
func _build_stream() -> void:
	var line: Array[Vector2] = _stream_line()
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var banks_tool: SurfaceTool = SurfaceTool.new()
	banks_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	for i: int in line.size():
		var ahead: Vector2 = line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]
		# Берег плавно сужается и расширяется между корнями.
		var half_width: float = STREAM_WIDTH * (0.5 + 0.055 * sin(line[i].y * 0.51) + 0.035 * sin(line[i].x * 1.3))
		var normal: Vector2 = Vector2(-ahead.y, ahead.x).normalized()
		if i > 0:
			along += line[i].distance_to(line[i - 1])
		for k: int in 2:
			var outward: Vector2 = normal * (1.0 if k == 0 else -1.0)
			var phase: float = float(k) * 2.17
			var ripple: float = 0.17 * sin(along * 0.72 + phase) + 0.07 * sin(along * 1.91 + phase)
			var bar: float = smoothstep(0.05, 0.92, 0.5 + 0.5 * sin(along * 0.31 + phase))
			var edge: Vector2 = line[i] + outward * (half_width + ripple - 0.16 * bar)
			tool.set_uv(Vector2(along, float(k)))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(_w3(edge) + Vector3(0, 0.05, 0))
			var ridge: float = 0.085 + 0.050 * sin(along * 1.13 + phase)
			for row: Vector3 in [Vector3(-0.27, -0.09, 0.0), Vector3(0.06 + bar * 0.15, 0.056, 0.22),
					Vector3(0.20 + bar * 0.61, ridge, 0.61), Vector3(0.54 + bar * 0.98, -0.13, 1.0)]:
				banks_tool.set_uv(Vector2(along, row.z))
				banks_tool.add_vertex(_w3(edge + outward * row.x) + Vector3.UP * row.y)
			if i > 0:
				var start: int = (i - 1) * 8 + k * 4
				for row_index: int in 3:
					var a: int = start + row_index
					var indices: Array[int] = [a, a + 1, a + 8, a + 1, a + 9, a + 8]
					if k == 0:
						indices.reverse()
					for index: int in indices:
						banks_tool.add_index(index)
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
	material.set_shader_parameter("bed", preload("res://assets/noir/courtyard/river_gravel.png"))
	material.set_shader_parameter("moon_spot", _w3(_env_view(STREAM_MOON)))  # отражение луны — на видном участке русла
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Stream"
	water.mesh = tool.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	banks_tool.generate_normals()
	var shore_mat: ShaderMaterial = ShaderMaterial.new()
	shore_mat.shader = preload("res://assets/shaders/noir_stream_bank.gdshader")
	shore_mat.render_priority = -1  # влажный грунт за прозрачной водой
	shore_mat.set_shader_parameter("gravel", preload("res://assets/noir/courtyard/river_gravel.png"))
	shore_mat.set_shader_parameter("soil", preload("res://assets/noir_h3d/arena/ground/brown_mud_leaves_01_diff_1k.jpg"))
	var shore: MeshInstance3D = MeshInstance3D.new()
	shore.name = "StreamBanks"
	shore.mesh = banks_tool.commit()
	shore.material_override = shore_mat
	add_child(shore)
	# берега: камни и папоротник вперемешку, чтобы лента не лежала на голой земле
	var banks: Dictionary[String, Array] = {}
	for i: int in range(0, line.size(), 1):
		for k: int in 2:
			if _rng.randf() < 0.45:
				continue
			var ahead: Vector2 = line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]
			var side: Vector2 = Vector2(-ahead.y, ahead.x).normalized() * (1.0 if k == 0 else -1.0)
			var bank: Vector2 = line[i] + side * (STREAM_WIDTH * 0.5 + _rng.randf_range(0.1, 0.9))
			if _clearance(bank) < 0.5:
				continue
			if i % 3 == k:
				var gravel: Vector2 = bank - side * _rng.randf_range(0.35, 0.76)
				_collect(banks, "shingle", _w(gravel), _rng.randf_range(0.78, 1.32))
			if _rng.randf() < 0.45:
				_place_rock(_w3(bank), self)
				if i % 4 == k:
					var shoal: Vector2 = bank - side * _rng.randf_range(0.55, 1.10)
					_place("rock_flat", _w3(shoal) + Vector3.DOWN * 0.1,
							_rng.randf() * TAU, _rng.randf_range(0.46, 0.76) * 0.7, self)
			else:
				_collect(banks, "seed_grass", _w(bank), _rng.randf_range(0.8, 1.35))
				_collect(banks, "sedge", _w(bank + side * 0.27), _rng.randf_range(0.55, 0.90))
	_build_collected(banks, self)


## Русло ручья точками через ~0,7 м (координаты вида).
func _stream_line() -> Array[Vector2]:
	var line: Array[Vector2] = []
	var points: Array[Vector2] = []
	for point: Vector2 in STREAM_POINTS:
		points.append(_env_view(point))
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


static func _w(v: Vector2) -> Vector2:
	return Vector2(v.y + BOARD_MAX.x, -v.x)


static func _w3(v: Vector2) -> Vector3:
	var p: Vector2 = _w(v)
	return Vector3(p.x, 0.0, p.y)


## Расстояние от точки до края полосы без деревьев вокруг поля (меньше нуля — внутри полосы).
func _clearance(p: Vector2) -> float:
	var lo: Vector2 = VIEW_MIN - Vector2(CLEAR_SIDE, CLEAR_FAR)
	var hi: Vector2 = VIEW_MAX + Vector2(CLEAR_SIDE, CLEAR_NEAR)
	var dx: float = maxf(lo.x - p.x, p.x - hi.x)
	var dy: float = maxf(lo.y - p.y, p.y - hi.y)
	if dx < 0.0 and dy < 0.0:
		return maxf(dx, dy)
	return Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()


## Место вороны на макушке столба; смотрит наружу или вдоль стены (в сторону камеры чаще).
func _add_perch(at: Vector2, post_scale: float, outward: Vector2) -> void:
	if _post_top < 0.0:
		var probe: Node3D = _prop("palisade_post")
		_post_top = _bounds(probe).end.y if probe != null else 2.4
		if probe != null:
			probe.free()
	# поворот от места, а не от _rng: иначе сдвинулась бы вся прежняя расстановка травы
	var look: Vector2 = outward.rotated(sin(at.x * 1.73 + at.y * 2.41) * 1.6)
	var yaw: float = atan2(-look.x, -look.y)
	_perches.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, _post_top * post_scale - 0.04, at.y)))


## Полоса без деревьев вокруг поля (см. _clearance) — по ней ходит медвежонок, на ней кормятся вороны.
func _wild_zone() -> Rect2:
	# полоса задана в координатах вида (как ручей) — переводим углы в мировые
	var a: Vector2 = _w(VIEW_MIN - Vector2(CLEAR_SIDE, CLEAR_FAR))
	var b: Vector2 = _w(VIEW_MAX + Vector2(CLEAR_SIDE, CLEAR_NEAR))
	return Rect2(a.min(b), (a - b).abs()).grow(-0.8)


## Деревья и камни леса (x, z, радиус) — их обходят звери.
func _wild_obstacles() -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for layout: CourtyardForestLayout in _forest_layouts():
		_tree_obstacles(layout, result)
	for rock: Vector3 in _rock_spots:
		result.append(rock)
	return result


func _tree_obstacles(layout: CourtyardForestLayout, result: PackedVector3Array) -> void:
	for species: String in layout.placements:
		if species != "spruce" and species != "birch":
			continue
		for at: Transform3D in _env_placements(layout.placements[species], true):
			result.append(Vector3(at.origin.x, at.origin.z, 0.9))


## Середина русла ручья в мировых x, z.
func _world_stream() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _stream_line():
		result.append(_w(p))
	return result


## Копии одного вида реквизита — MultiMesh на каждую сетку модели, по участкам RenderQuality.env_chunk() м.
## Одна MultiMesh на весь лес не отсекается ни камерой, ни светом: каждый факел с тенью
## перерисовывал в свою карту теней все ели карты (6 граней × 5 факелов — половина кадра).
func _multimesh(id: String, transforms: Array[Transform3D], parent: Node3D = null) -> void:
	if transforms.is_empty():
		return
	var model: Node3D = _prop(id)
	if model == null:
		return
	add_child(model)  # временно — чтобы посчитать мировые преобразования частей модели
	var grass: bool = id in GRASS_IDS_3D
	var chunk: float = RenderQuality.env_chunk()
	var chunks: Dictionary[Vector2i, Array] = {}
	for at: Transform3D in transforms:
		if grass and not _keep_grass(Vector2(at.origin.x, at.origin.z)):
			continue
		var key: Vector2i = Vector2i(floori(at.origin.x / chunk), floori(at.origin.z / chunk))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(at)
	# Своды и стены погребов — часть двора: от них факелы бросают тени, как от частокола.
	var environment: bool = id not in ["cellar_arch", "cellar_wall"]
	for part: MeshInstance3D in _mesh_parts(model):
		var local: Transform3D = model.global_transform.affine_inverse() * part.global_transform
		if id not in ["sedge", "fern", "seed_grass", "moss_rock", "shingle", "cellar_arch", "cellar_wall"]:
			_moonlit(part.mesh, id == "spruce" or id == "birch")
		for key: Vector2i in chunks:
			var group: Array = chunks[key]
			var multi: MultiMesh = MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = part.mesh
			multi.instance_count = group.size()
			for i: int in group.size():
				var at: Transform3D = group[i]
				multi.set_instance_transform(i, at * local)
			var holder: MultiMeshInstance3D = MultiMeshInstance3D.new()
			holder.multimesh = multi
			holder.name = "%s_%d_%d" % [id, key.x, key.y]
			if environment:
				holder.layers = ENV_LAYER
			if grass or id == "shingle" or not RenderQuality.env_shadows() or _far_from_yard(key):
				holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # не видно, а кадр дорожает
			(parent if parent != null else self).add_child(holder)
	model.queue_free()


## Трава под пологом леса (за краем поляны) днём в тени, ночью почти не видна — рисуется её часть
## (RenderQuality); на поляне и в PvP (поляны нет) — вся, кроме телефонного профиля.
func _keep_grass(at: Vector2) -> bool:
	var glades: Array[Rect2] = _glades()
	var keep: float = RenderQuality.grass_keep_glade()
	if not glades.is_empty():
		var open: bool = false
		for rect: Rect2 in glades:
			open = open or rect.grow(GRASS_GLADE_MARGIN).has_point(at)
		if not open:
			keep = RenderQuality.grass_keep_under_canopy()
	if keep >= 1.0:
		return true
	# одно и то же место — всегда одно решение (без мигания при перестройке двора)
	var x: float = sin(at.x * 12.9898 + at.y * 78.233) * 43758.5453
	return x - floorf(x) < keep


## Участок дальше FAR_SHADOW от двора: тени его деревьев падают в глубину леса, где их не видно
## (лес там и так в тени), а карта теней солнца перерисовывает их каждый кадр.
func _far_from_yard(key: Vector2i) -> bool:
	var center: Vector2 = (Vector2(key) + Vector2(0.5, 0.5)) * RenderQuality.env_chunk()
	var yard: Rect2 = _yard_rect()
	var gap: Vector2 = Vector2(maxf(maxf(yard.position.x - center.x, center.x - yard.end.x), 0.0),
			maxf(maxf(yard.position.y - center.y, center.y - yard.end.y), 0.0))
	return gap.length() > FAR_SHADOW


## Материалы леса (только у копий в MultiMesh): чуть светлее и с лунным контуром.
static func _moonlit(mesh: Mesh, tree: bool = false) -> void:
	for surface: int in mesh.get_surface_count():
		var material: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null or material.has_meta(&"moonlit"):
			continue
		if material.resource_name in ["Еловая лапа", "Листва берёзы"]:
			var crown: ShaderMaterial = ShaderMaterial.new()
			crown.shader = CANOPY_HASHED if RenderQuality.hashed_foliage() else CANOPY
			crown.set_shader_parameter("foliage", material.albedo_texture)
			crown.set_shader_parameter("pigment", material.albedo_color)
			crown.set_shader_parameter("broadleaf", material.resource_name == "Листва берёзы")
			mesh.surface_set_material(surface, crown)
			continue
		material.set_meta(&"moonlit", true)
		var tint: Color = material.albedo_color * TREE_BRIGHT
		tint.a = material.albedo_color.a
		if tree:
			var bark: ShaderMaterial = ShaderMaterial.new()
			bark.shader = TREE_BARK
			bark.set_shader_parameter("bark", material.albedo_texture)
			bark.set_shader_parameter("use_texture", material.albedo_texture != null)
			bark.set_shader_parameter("tint", tint)
			bark.set_shader_parameter("flex", 1.4 if material.resource_name in ["Береста", "Чечевички бересты"] else 1.0)
			bark.set_shader_parameter("rim", TREE_RIM)
			mesh.surface_set_material(surface, bark)
			continue
		material.albedo_color = tint
		if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			material.alpha_antialiasing_edge = material.alpha_scissor_threshold * 0.65
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.rim_enabled = true
		material.rim = TREE_RIM
		material.rim_tint = 0.4


## Низовой туман слоем у земли (noir_ground_mist.gdshader): полноэкранный квад в сцене считает туман
## по глубине каждого пикселя — стволы стоят в тумане, кроны над ним. Двор (с частоколом) чистый.
func _build_ground_mist() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GROUND_MIST_SHADER
	material.render_priority = -50  # раньше огня и эффектов: пламя поверх тумана, а не в нём
	var clear: Rect2 = _yard_rect().grow(1.6)
	material.set_shader_parameter("yard_rect", Vector4(clear.position.x, clear.position.y, clear.end.x, clear.end.y))
	quad.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "GroundMist"
	instance.mesh = quad
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 16384.0  # квад растянут на экран в шейдере — не отсекать по рамке
	add_child(instance)

## Дымка в лесу за стеной (как на концепте), гуще вдали; двор остаётся чистым и читаемым.
func _build_mist() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FOREST_FOG
	var clear: Rect2 = _yard_rect().grow(1.4)
	material.set_shader_parameter("yard_rect", Vector4(clear.position.x, clear.position.y, clear.end.x, clear.end.y))
	var volume: FogVolume = FogVolume.new()
	volume.name = "ForestMist"
	volume.size = Vector3(104, 12, 112)
	volume.position = Vector3(-10, 4.5, -5)
	volume.material = material
	add_child(volume)
