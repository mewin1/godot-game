class_name ArenaTower3D
extends Node3D
## 3D-постройка на арене: плитки под каждой клеткой фигуры + модель тира в центре.
## Три базовые модели (тир 1 — деревянный пост, 2 — каменная башня, 3 — резная башня
## с кристаллом), окраска и свечение — по богу из Arena3DStyle. Уровень слияния — кольца.

const PULSE_SECONDS: float = 0.18
const POP_SECONDS: float = 0.35
## Клетка поля (м) и рамка стихии вокруг постройки: отступ от края клетки, ширина, высота над плитой.
const CELL: float = 2.0
const FRAME_INSET: float = 0.2
const FRAME_WIDTH: float = 0.1
const FRAME_HEIGHT: float = 0.47
## Насколько модель может выступать за рамку (ветви, лопасти): 1 — ровно по рамке.
const FIT_SLACK: float = 1.35
## Ниже этой доли общего масштаба модель не сжимается (длинные стрелы и ветви — пусть выступают).
const FIT_FLOOR: float = 0.8

var _model: Node3D
var _accent: MeshInstance3D
var _pulse_left: float = 0.0
var _pop_left: float = 0.0
var _time: float = 0.0
var _base_scale: float = 1.0
var _noir_height: float = 0.0


## Собирает постройку. cell_offsets — центры клеток фигуры относительно центра модели.
func build(tower: TowerState, style: Arena3DStyle, cell_offsets: Array[Vector3]) -> void:
	if _build_noir(tower, style, cell_offsets):
		return
	var paint: Color = style.get_god_color(tower.data.god)
	var accent: Color = style.get_god_glow(tower.data.god)
	var tile_color: Color = paint.lerp(ArenaMaterials3D.STONE, style.tile_stone_mix)
	var tile_material: StandardMaterial3D = ArenaMaterials3D.solid(tile_color.darkened(0.35))
	var rim_material: StandardMaterial3D = ArenaMaterials3D.solid(paint.darkened(0.1))
	for offset: Vector3 in cell_offsets:
		ArenaMaterials3D.part(self, ArenaMaterials3D.box(Vector3(1.86, 0.08, 1.86)), rim_material,
				offset + Vector3(0, 0.03, 0))
		ArenaMaterials3D.part(self, ArenaMaterials3D.box(Vector3(1.66, 0.04, 1.66)), tile_material,
				offset + Vector3(0, 0.08, 0))
	_model = Node3D.new()
	add_child(_model)
	var tier: int = clampi(tower.data.tier, 1, 3)
	var height: float = style.tier_heights[tier - 1]
	match tier:
		1:
			_build_post(paint, accent, height)
		2:
			_build_stone(paint, accent, height)
		_:
			_build_carved(paint, accent, height)
	_add_level_rings(tower.level)
	_base_scale = style.tower_scale * (1.0 + style.level_scale_step * (tower.level - 1))
	_model.scale = Vector3.ONE * _base_scale


## Модель «славянского нуара»: плита уровня под каждой клеткой фигуры + модель в центре.
## Нет GLB для этой постройки — false, строится прежняя процедурная.
func _build_noir(tower: TowerState, style: Arena3DStyle, cell_offsets: Array[Vector3]) -> bool:
	var scene: PackedScene = NoirModels.tower(tower.data.id)
	if scene == null:
		return false
	var tier: int = clampi(tower.data.tier, 1, 3)
	var plate: PackedScene = NoirModels.plate(tier, tower.data.god)
	var own_plate: PackedScene = NoirModels.tower_plate(tower.data.id)
	for i: int in cell_offsets.size():
		var offset: Vector3 = cell_offsets[i]
		# своя плита постройки — под всеми клетками фигуры (у моделей Hunyuan3D общие плиты выбиваются из стиля)
		var scene_for_cell: PackedScene = own_plate if own_plate != null else plate
		if scene_for_cell != null:
			var tile: Node3D = scene_for_cell.instantiate() as Node3D
			_tune_materials(tile, style.noir_plate_glow, style.noir_plate_tone)
			add_child(tile)
			tile.position = offset
	_model = Node3D.new()
	add_child(_model)
	var body: Node3D = scene.instantiate() as Node3D
	var glow: float = style.noir_glow_by_id.get(tower.data.id, style.noir_model_glow)
	var tone: float = style.noir_tone_by_id.get(tower.data.id, style.noir_model_tone)
	_tune_materials(body, glow, tone, style.noir_model_rim)
	_model.add_child(body)
	# цветное пятно света стихии на брусчатке вокруг постройки (как на концепте арены)
	if tower.data.god != &"":
		var aura: OmniLight3D = OmniLight3D.new()
		aura.light_color = GodSymbols.get_color(tower.data.god)
		aura.light_energy = style.noir_aura_energy
		aura.omni_range = style.noir_aura_range
		aura.omni_attenuation = 1.6
		aura.position = Vector3(0, 1.4, 0)
		add_child(aura)
	_noir_height = NoirModels.TIER_HEIGHT[tier - 1]
	if tower.data.god != &"":
		_add_element_frame(cell_offsets, style.get_god_color(tower.data.god), style.noir_frame_energy)
	_add_level_marks(cell_offsets, tower.level)
	_base_scale = style.noir_model_scale * (1.0 + style.level_scale_step * (tower.level - 1))
	# крупная модель не должна вылезать за свою рамку на соседние клетки и дорогу
	_base_scale = clampf(_fit_scale(body, cell_offsets), _base_scale * FIT_FLOOR, _base_scale)
	_model.scale = Vector3.ONE * _base_scale
	return true


## Свечение и яркость материалов модели «нуар» + анизотропная фильтрация (плиты видны под углом —
## без неё фактура мылится). Материалы общие у всех копий модели, поэтому правятся один раз.
static func _tune_materials(root: Node3D, glow: float, tone: float, rim: float = 0.0) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var material: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or material.has_meta(&"noir_tuned"):
				continue
			material.set_meta(&"noir_tuned", true)
			material.emission_energy_multiplier = glow
			material.albedo_color = Color(tone, tone, tone)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			# лунный контур по краю силуэта: тёмная постройка отделяется от тёмной брусчатки
			if rim > 0.0:
				material.rim_enabled = true
				material.rim = rim
				material.rim_tint = 0.25


## Точка навершия (кристалл/огонь) в координатах сцены — отсюда летят снаряды.
func get_top() -> Vector3:
	if _accent == null:
		return global_position + Vector3.UP * (_noir_height * 0.92 * _base_scale if _noir_height > 0.0 else 2.0)
	return _accent.global_position


## Выстрел: короткое «вздрагивание» модели.
func pulse() -> void:
	_pulse_left = PULSE_SECONDS


## Покупка или слияние: модель вырастает из земли.
func pop() -> void:
	_pop_left = POP_SECONDS


func _process(delta: float) -> void:
	_time += delta
	_pulse_left = maxf(0.0, _pulse_left - delta)
	_pop_left = maxf(0.0, _pop_left - delta)
	var squash: float = sin(_pulse_left / PULSE_SECONDS * PI) * 0.07
	var growth: float = 1.0 - _pop_left / POP_SECONDS
	var grow: float = ease(growth, 0.4) if _pop_left > 0.0 else 1.0
	_model.scale = Vector3(1.0 + squash, 1.0 - squash * 0.5, 1.0 + squash) * _base_scale * grow
	if _accent != null:
		_accent.rotation.y = _time * 0.9
		_accent.position.y = _accent.get_meta(&"rest_y", 0.0) + sin(_time * 2.2) * 0.06


## Тир 1: деревянный пост на настиле, окрашенный флажок и огонёк сверху.
func _build_post(paint: Color, accent: Color, height: float) -> void:
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.WOOD)
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.62, 0.58, 0.22, 6),
			ArenaMaterials3D.solid(ArenaMaterials3D.DARK_WOOD), Vector3(0, 0.27, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.16, 0.13, height, 6), wood,
			Vector3(0, 0.38 + height * 0.5, 0))
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.07, 0.07, height * 0.75, 5), wood,
				Vector3(side * 0.34, 0.38 + height * 0.3, 0), Vector3(0, 0, side * -0.38))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.box(Vector3(0.9, 0.1, 0.1)), wood,
			Vector3(0, 0.38 + height * 0.72, 0))
	# Флажок бога на перекладине и маленькая шапка — пост, а не домик.
	ArenaMaterials3D.part(_model, ArenaMaterials3D.box(Vector3(0.36, 0.5, 0.04)),
			ArenaMaterials3D.solid(paint), Vector3(0.26, 0.38 + height * 0.5, 0.0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.26, 0.0, 0.3, 6),
			ArenaMaterials3D.solid(paint), Vector3(0, 0.38 + height + 0.1, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.2, 0.2, 0.08, 6),
			ArenaMaterials3D.solid(ArenaMaterials3D.DARK_WOOD), Vector3(0, 0.38 + height - 0.05, 0))
	_add_accent(ArenaMaterials3D.sphere(0.14, 8, 4), accent, 0.38 + height + 0.45)


## Тир 2: каменная башня с окрашенным поясом, зубцами и светящимся окном.
func _build_stone(paint: Color, accent: Color, height: float) -> void:
	var stone: StandardMaterial3D = ArenaMaterials3D.stone(ArenaMaterials3D.STONE)
	var dark: StandardMaterial3D = ArenaMaterials3D.stone(ArenaMaterials3D.DARK_STONE)
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.78, 0.7, 0.32, 8), dark,
			Vector3(0, 0.3, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.58, 0.46, height, 8), stone,
			Vector3(0, 0.46 + height * 0.5, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.54, 0.5, height * 0.35, 8),
			ArenaMaterials3D.solid(paint), Vector3(0, 0.46 + height * 0.45, 0))
	var top: float = 0.46 + height
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.62, 0.62, 0.24, 8), dark,
			Vector3(0, top, 0))
	for i: int in 6:
		var angle: float = TAU * i / 6.0
		ArenaMaterials3D.part(_model, ArenaMaterials3D.box(Vector3(0.2, 0.22, 0.2)), stone,
				Vector3(cos(angle) * 0.5, top + 0.22, sin(angle) * 0.5), Vector3(0, -angle, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.box(Vector3(0.18, 0.3, 0.08)),
			ArenaMaterials3D.glow(accent, 1.2),
			Vector3(0, 0.46 + height * 0.7, 0.5))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.5, 0.0, 0.7, 8),
			ArenaMaterials3D.solid(paint), Vector3(0, top + 0.5, 0))
	_add_accent(ArenaMaterials3D.sphere(0.17, 6, 3), accent, top + 1.1)


## Тир 3: высокая резная башня — гранёный ствол, окрашенные кольца, балкон, шпиль и кристалл.
func _build_carved(paint: Color, accent: Color, height: float) -> void:
	var stone: StandardMaterial3D = ArenaMaterials3D.stone(ArenaMaterials3D.STONE)
	var dark: StandardMaterial3D = ArenaMaterials3D.stone(ArenaMaterials3D.DARK_STONE)
	var painted: StandardMaterial3D = ArenaMaterials3D.solid(paint)
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.86, 0.76, 0.36, 8), dark,
			Vector3(0, 0.32, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.56, 0.38, height, 8), stone,
			Vector3(0, 0.5 + height * 0.5, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.44, 0.4, height * 0.3, 8),
			ArenaMaterials3D.solid(paint.lerp(ArenaMaterials3D.STONE, 0.2)),
			Vector3(0, 0.5 + height * 0.8, 0))
	for ring: float in [0.25, 0.55]:
		ArenaMaterials3D.part(_model,
				ArenaMaterials3D.cylinder(0.52 - ring * 0.16, 0.5 - ring * 0.16, 0.14, 8), painted,
				Vector3(0, 0.5 + height * ring, 0))
	for i: int in 4:
		var angle: float = TAU * i / 4.0 + PI / 4.0
		ArenaMaterials3D.part(_model, ArenaMaterials3D.box(Vector3(0.14, height * 0.55, 0.14)),
				dark,
				Vector3(cos(angle) * 0.5, 0.5 + height * 0.28, sin(angle) * 0.5),
				Vector3(0, -angle, 0))
	var top: float = 0.5 + height
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.62, 0.5, 0.16, 8), dark,
			Vector3(0, top, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.34, 0.0, 0.7, 8), painted,
			Vector3(0, top + 0.43, 0))
	ArenaMaterials3D.part(_model, ArenaMaterials3D.cylinder(0.66, 0.66, 0.05, 8),
			ArenaMaterials3D.glow(accent, 0.9), Vector3(0, top - 0.1, 0))
	var crystal: SphereMesh = ArenaMaterials3D.sphere(0.22, 4, 2)
	_add_accent(crystal, accent, top + 1.2, Vector3(1.0, 1.9, 1.0))


func _add_accent(mesh: Mesh, color: Color, height: float,
		scale_factor: Vector3 = Vector3.ONE) -> void:
	_accent = ArenaMaterials3D.part(_model, mesh, ArenaMaterials3D.glow(color, 1.3),
			Vector3(0, height, 0), Vector3.ZERO,
			scale_factor)
	_accent.set_meta(&"rest_y", height)
	_accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Уровень слияния: золотые кольца у основания (уровень 2 — одно, 3 — два).
func _add_level_rings(level: int) -> void:
	for i: int in range(1, clampi(level, 1, 3)):
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.5 + i * 0.1
		ring.outer_radius = 0.55 + i * 0.1
		ring.rings = 24
		ring.ring_segments = 4
		ArenaMaterials3D.part(_model, ring, ArenaMaterials3D.glow(ArenaMaterials3D.GOLD, 0.8),
				Vector3(0, 0.46 + i * 0.05, 0))


## Светящаяся рамка цвета стихии по внешнему краю фигуры: в тесном дворе постройки разных стихий
## различаются цветом с одного взгляда, а границы соседних построек видны (внутри фигуры линий нет).
func _add_element_frame(cell_offsets: Array[Vector3], color: Color, energy: float) -> void:
	var material: StandardMaterial3D = ArenaMaterials3D.glow(color, energy)
	# смещения клеток — от центра фигуры (у фигур чётного размера кратны половине клетки): сетка в полуклетках
	var cells: Dictionary[Vector2i, bool] = {}
	for offset: Vector3 in cell_offsets:
		cells[Vector2i(roundi(offset.x * 2.0 / CELL), roundi(offset.z * 2.0 / CELL))] = true
	var half: float = CELL * 0.5 - FRAME_INSET
	for cell: Vector2i in cells:
		var center: Vector3 = Vector3(cell.x * CELL * 0.5, FRAME_HEIGHT, cell.y * CELL * 0.5)
		for side: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(cell + side * 2):
				continue
			# вдоль края: к соседней клетке фигуры полоса доходит до края клетки (контур не рвётся),
			# на свободном углу — кончается в углу рамки (без торчащих концов)
			var along: Vector2i = Vector2i(side.y, side.x)
			var reach_plus: float = CELL * 0.5 if cells.has(cell + along * 2) else half + FRAME_WIDTH * 0.5
			var reach_minus: float = CELL * 0.5 if cells.has(cell - along * 2) else half + FRAME_WIDTH * 0.5
			var length: float = reach_plus + reach_minus
			var shift: float = (reach_plus - reach_minus) * 0.5
			var size: Vector3 = Vector3(FRAME_WIDTH, 0.05, length) if side.x != 0 else Vector3(length, 0.05, FRAME_WIDTH)
			var at: Vector3 = Vector3(side.x * half + along.x * shift, 0.0, side.y * half + along.y * shift)
			ArenaMaterials3D.part(self, ArenaMaterials3D.box(size), material, center + at)


## Уровень постройки — золотые зарубки (1–3) у края, обращённого к камере (камера матча — со стороны +x).
func _add_level_marks(cell_offsets: Array[Vector3], level: int) -> void:
	var front: Vector3 = cell_offsets[0]
	for offset: Vector3 in cell_offsets:
		if offset.x > front.x + 0.01 or (absf(offset.x - front.x) < 0.01 and offset.z > front.z):
			front = offset
	var material: StandardMaterial3D = ArenaMaterials3D.glow(ArenaMaterials3D.GOLD, 2.6)
	var count: int = clampi(level, 1, 3)
	# черточки поперёк края (как римские I, II, III), крупные — читаются с высоты камеры
	for i: int in count:
		var z: float = (float(i) - float(count - 1) * 0.5) * 0.32
		ArenaMaterials3D.part(self, ArenaMaterials3D.box(Vector3(0.5, 0.1, 0.16)), material,
				front + Vector3(CELL * 0.5 - FRAME_INSET - 0.38, FRAME_HEIGHT + 0.03, z))


## Наибольший масштаб, при котором модель помещается в рамку своей фигуры (по каждой оси отдельно).
static func _fit_scale(body: Node3D, cell_offsets: Array[Vector3]) -> float:
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for offset: Vector3 in cell_offsets:
		low = low.min(Vector2(offset.x, offset.z))
		high = high.max(Vector2(offset.x, offset.z))
	var room: Vector2 = high - low + Vector2.ONE * (CELL - 2.0 * FRAME_INSET)
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var local: AABB = body.global_transform.affine_inverse() * mesh_node.global_transform * mesh_node.get_aabb() \
				if body.is_inside_tree() else mesh_node.transform * mesh_node.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first or box.size.x <= 0.01 or box.size.z <= 0.01:
		return INF
	# модель стоит в центре фигуры: считаем от центра, а не от края коробки
	var half: Vector2 = Vector2(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z)))
	return minf(room.x * 0.5 / half.x, room.y * 0.5 / half.y) * FIT_SLACK
