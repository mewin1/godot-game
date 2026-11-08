class_name ArenaAmbience3D
extends Node3D
## Живость арены — только отображение: ветер с порывами, падающие листья, листва в порыве у земли,
## светлячки на опушке, лунная пыль; искры и дым над огнём (make_fire_fx). Вороны и медвежонок — свои узлы.
## Случайность — свой RNG отображения (на sim не влияет).

const LEAF_ATLAS: Texture2D = preload("res://assets/noir/ambience/leaves.png")
const LEAF_SHADER: Shader = preload("res://assets/shaders/noir_falling_leaf.gdshader")
const MOTE_SHADER: Shader = preload("res://assets/shaders/noir_glow_mote.gdshader")
const SMOKE_SHADER: Shader = preload("res://assets/shaders/noir_smoke_puff.gdshader")
## Видимая камерой земля вокруг поля (x, z), м — с запасом за край кадра.
const VIEW_AREA: Rect2 = Rect2(-18.0, -36.0, 54.0, 50.0)
const LEAF_COUNT: int = 110
const LEAF_LIFE: float = 16.0
const LEAF_HEIGHT: float = 10.0
const LEAF_SIZE: float = 0.42
const GUST_LEAF_COUNT: int = 35
const FIREFLY_COUNT: int = 70
const DUST_COUNT: int = 160
## Снос листа ветром (ускорение, м/с²): в покое и в самый сильный порыв.
const LEAF_DRIFT_CALM: float = 0.05
const LEAF_DRIFT_GUST: float = 0.55
## Вороны: сколько сидит одновременно, как часто прилетают (с), сколько сидят (с).
const MAX_PERCHED: int = 4
const CROW_EVERY: Vector2 = Vector2(4.0, 11.0)
const CROW_STAY: Vector2 = Vector2(12.0, 32.0)
const FLOCK_EVERY: Vector2 = Vector2(22.0, 45.0)
## Откуда прилетают: так далеко от центра поля и так высоко, чтобы за краем кадра.
const OFFSCREEN_RADIUS: float = 42.0
const OFFSCREEN_HEIGHT: float = 16.0
const FIELD_CENTER: Vector3 = Vector3(9.0, 0.0, -10.0)
## Медвежонок спугивает ворон на земле ближе этого, м.
const SCARE_DISTANCE: float = 3.0
const GROUND_SPOTS: int = 10

var _leaf_process: ParticleProcessMaterial
var _gust_leaves: GPUParticles3D
var _gust_process: ParticleProcessMaterial
var _dust_process: ParticleProcessMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Места посадки ворон: столбы частокола (от двора) и земля опушки; у каждого — признак «земля».
var _fence_spots: Array[Transform3D] = []
var _ground_spots: Array[Transform3D] = []
var _taken: Dictionary[int, ArenaCrow3D] = {}
var _stay: Dictionary[ArenaCrow3D, float] = {}
var _crow_in: float = 2.5
var _flock_in: float = 14.0
var _bear: ArenaBearCub3D
var _battle: bool = false


## yard — прямоугольник двора (x, z): светлячки и пыль над полем боя гаснут.
func setup(yard: Rect2) -> void:
	_build_leaves()
	_build_gust_leaves()
	_build_fireflies(yard)
	_build_dust(yard)
	_build_ground_catch()


func _process(delta: float) -> void:
	NoirWind.update(delta)
	_update_crows(delta)
	var wind: float = NoirWind.strength
	var push: Vector3 = NoirWind.DIRECTION * lerpf(LEAF_DRIFT_CALM, LEAF_DRIFT_GUST, wind)
	if _leaf_process != null:
		_leaf_process.gravity = Vector3(0.0, -0.07, 0.0) + push
	if _dust_process != null:
		_dust_process.gravity = push * 0.6
	if _gust_leaves != null:
		# порыв поднимает листву с земли: выпуск растёт с силой ветра
		_gust_leaves.amount_ratio = smoothstep(0.15, 0.8, wind)


## Листья кружат с высоты над всей видимой землёй и ложатся на неё, потом тают.
func _build_leaves() -> void:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(VIEW_AREA.size.x * 0.5, 2.0, VIEW_AREA.size.y * 0.5)
	process.direction = Vector3(0, -1, 0)
	process.spread = 25.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.7
	process.gravity = Vector3(0, -0.07, 0)
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -110.0
	process.angular_velocity_max = 110.0
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.anim_offset_max = 1.0
	_add_turbulence(process, 1.4, 0.06, 0.16)
	_ground_collision(process)
	_leaf_process = process
	var leaves: GPUParticles3D = _particles("FallingLeaves", LEAF_COUNT, LEAF_LIFE, process, _leaf_mesh(LEAF_SIZE))
	# центр источника — против ветра от видимой земли, чтобы снос приносил листья в кадр
	var center: Vector2 = VIEW_AREA.get_center() - Vector2(NoirWind.DIRECTION.x, NoirWind.DIRECTION.z) * 5.0
	leaves.position = Vector3(center.x, LEAF_HEIGHT, center.y)
	leaves.preprocess = LEAF_LIFE
	add_child(leaves)


## В порыв у земли проносятся листья — ветер видно по низу кадра.
func _build_gust_leaves() -> void:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(VIEW_AREA.size.x * 0.5, 0.6, VIEW_AREA.size.y * 0.5)
	process.direction = NoirWind.DIRECTION + Vector3(0, 0.25, 0)
	process.spread = 18.0
	process.initial_velocity_min = 2.2
	process.initial_velocity_max = 3.8
	process.gravity = Vector3(0, -0.6, 0)
	process.damping_min = 0.3
	process.damping_max = 0.6
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -300.0
	process.angular_velocity_max = 300.0
	process.scale_min = 0.6
	process.scale_max = 1.1
	process.anim_offset_max = 1.0
	_add_turbulence(process, 2.5, 0.2, 0.35)
	_ground_collision(process)
	_gust_process = process
	_gust_leaves = _particles("GustLeaves", GUST_LEAF_COUNT, 5.0, process, _leaf_mesh(LEAF_SIZE * 0.9))
	var center: Vector2 = VIEW_AREA.get_center()
	_gust_leaves.position = Vector3(center.x, 0.9, center.y)
	_gust_leaves.amount_ratio = 0.0
	add_child(_gust_leaves)


## Светлячки — у земли на опушке, мигают; над двором гаснут.
func _build_fireflies(yard: Rect2) -> void:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(VIEW_AREA.size.x * 0.45, 0.9, VIEW_AREA.size.y * 0.45)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.2
	_add_turbulence(process, 1.2, 0.25, 0.4)
	var material: ShaderMaterial = _mote_material(Color(0.82, 1.0, 0.42), Color(0.55, 0.95, 0.3), 4.5, 1.0, yard)
	var flies: GPUParticles3D = _particles("Fireflies", FIREFLY_COUNT, 9.0, process, _quad(0.3, material))
	var center: Vector2 = VIEW_AREA.get_center()
	flies.position = Vector3(center.x, 1.3, center.y)
	flies.preprocess = 9.0
	add_child(flies)


## Лунная пыль: едва видные холодные пылинки в воздухе, летят по ветру.
func _build_dust(yard: Rect2) -> void:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(VIEW_AREA.size.x * 0.5, 3.0, VIEW_AREA.size.y * 0.5)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.12
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.0
	_add_turbulence(process, 0.8, 0.1, 0.2)
	_dust_process = process
	var material: ShaderMaterial = _mote_material(Color(0.7, 0.86, 0.95), Color(0.5, 0.65, 0.8), 0.55, 0.0,
			yard.grow(-1.5))
	var dust: GPUParticles3D = _particles("MoonDust", DUST_COUNT, 12.0, process, _quad(0.1, material))
	var center: Vector2 = VIEW_AREA.get_center()
	dust.position = Vector3(center.x, 3.6, center.y)
	dust.preprocess = 12.0
	add_child(dust)


## Земля ловит листья: они ложатся и лежат до конца жизни.
func _build_ground_catch() -> void:
	var ground: GPUParticlesCollisionBox3D = GPUParticlesCollisionBox3D.new()
	ground.name = "LeafGround"
	ground.size = Vector3(VIEW_AREA.size.x + 40.0, 2.0, VIEW_AREA.size.y + 40.0)
	var center: Vector2 = VIEW_AREA.get_center()
	ground.position = Vector3(center.x, -1.0, center.y)
	add_child(ground)


## Медвежонок и места для ворон на земле. zone — где бродить; blocked — двор; obstacles — (x, z, радиус);
## stream — середина русла.
func setup_wildlife(zone: Rect2, blocked: Rect2, obstacles: PackedVector3Array, stream: PackedVector2Array) -> void:
	_rng.seed = 4242 + get_instance_id() % 997
	_bear = ArenaBearCub3D.new()
	_bear.name = "BearCub"
	add_child(_bear)
	_bear.setup(_rng.randi(), zone, blocked, obstacles, stream)
	for k: int in GROUND_SPOTS * 4:
		if _ground_spots.size() >= GROUND_SPOTS:
			break
		var spot: Vector2 = Vector2(_rng.randf_range(zone.position.x, zone.end.x), _rng.randf_range(zone.position.y, zone.end.y))
		var free: bool = not blocked.grow(0.4).has_point(spot)
		for obstacle: Vector3 in obstacles:
			free = free and spot.distance_to(Vector2(obstacle.x, obstacle.y)) > obstacle.z + 0.5
		if free:
			_ground_spots.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(spot.x, 0.0, spot.y)))


## Бой во дворе: сидящие на частоколе вороны с карканьем улетают, новые садятся только на землю.
func set_battle(active: bool) -> void:
	if active == _battle:
		return
	_battle = active
	if not active:
		return
	for index: int in _taken.keys():
		if index < _fence_spots.size():
			_leave(_taken[index], false)


## Верх столбов частокола — меняется с ростом двора: сидящие там вороны улетают.
func set_perches(spots: Array[Transform3D]) -> void:
	for index: int in _taken.keys():
		if index < _fence_spots.size():
			_leave(_taken[index], false)
	_fence_spots = spots


func _spot(index: int) -> Transform3D:
	return _fence_spots[index] if index < _fence_spots.size() else _ground_spots[index - _fence_spots.size()]


func _update_crows(delta: float) -> void:
	_crow_in -= delta
	if _crow_in <= 0.0:
		_crow_in = _rng.randf_range(CROW_EVERY.x, CROW_EVERY.y)
		if _taken.size() < MAX_PERCHED:
			_arrive(_offscreen())
	_flock_in -= delta
	if _flock_in <= 0.0:
		_flock_in = _rng.randf_range(FLOCK_EVERY.x, FLOCK_EVERY.y)
		_fly_over()
	for crow: ArenaCrow3D in _stay.keys():
		if crow.is_flying:
			continue
		_stay[crow] -= delta
		var scared: bool = crow.on_ground and _bear != null \
				and _bear.ground_position().distance_to(Vector2(crow.position.x, crow.position.z)) < SCARE_DISTANCE
		if _stay[crow] <= 0.0 or scared:
			_leave(crow, not scared and _rng.randf() < 0.35)


## Ворона прилетает из-за кадра на свободное место.
func _arrive(from: Vector3, crow: ArenaCrow3D = null) -> void:
	var total: int = _fence_spots.size() + _ground_spots.size()
	if total == 0:
		return
	var index: int = -1
	for attempt: int in 12:
		var pick: int = _rng.randi() % total
		# на столбы чаще: там их видно на фоне двора; в бой — только на землю
		if pick >= _fence_spots.size() and _rng.randf() < 0.4 and not _fence_spots.is_empty():
			pick = _rng.randi() % _fence_spots.size()
		if _battle and pick < _fence_spots.size():
			if _ground_spots.is_empty():
				continue
			pick = _fence_spots.size() + _rng.randi() % _ground_spots.size()
		if not _taken.has(pick):
			index = pick
			break
	if index < 0:
		if crow != null:
			_leave(crow, false)
		return
	if crow == null:
		crow = ArenaCrow3D.new(_rng.randi())
		crow.name = "Crow"
		add_child(crow)
		crow.finished.connect(_on_crow_finished)
	var spot: Transform3D = _spot(index)
	var ground: bool = index >= _fence_spots.size()
	crow.perch_index = index
	_taken[index] = crow
	_stay[crow] = _rng.randf_range(CROW_STAY.x, CROW_STAY.y)
	crow.fly(from, spot.origin, true, spot.basis.get_euler().y, ground)


## Улетает: на другое место (hop) или за кадр.
func _leave(crow: ArenaCrow3D, hop: bool) -> void:
	if crow.perch_index >= 0 and _taken.get(crow.perch_index) == crow:
		_taken.erase(crow.perch_index)
	crow.perch_index = -1
	var from: Vector3 = crow.position
	if hop:
		_arrive(from, crow)
		return
	_stay.erase(crow)
	crow.fly(from, _offscreen(), false)


## Стайка из 2–4 ворон пролетает над лесом, не садясь.
func _fly_over() -> void:
	var start: Vector3 = _offscreen()
	var finish: Vector3 = FIELD_CENTER * 2.0 - start
	finish.y = OFFSCREEN_HEIGHT
	var lane: Vector3 = (finish - start).normalized().cross(Vector3.UP)
	for k: int in _rng.randi_range(2, 4):
		var crow: ArenaCrow3D = ArenaCrow3D.new(_rng.randi())
		crow.name = "FlockCrow"
		add_child(crow)
		crow.finished.connect(_on_crow_finished)
		var shift: Vector3 = lane * _rng.randf_range(-3.0, 3.0) + Vector3.UP * _rng.randf_range(-4.0, -1.0) \
				- (finish - start).normalized() * k * _rng.randf_range(1.5, 3.0)
		crow.fly(start + shift, finish + shift, false)


func _on_crow_finished(crow: ArenaCrow3D) -> void:
	_stay.erase(crow)


func _offscreen() -> Vector3:
	var direction: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
	return FIELD_CENTER + Vector3(direction.x, 0.0, direction.y) * OFFSCREEN_RADIUS + Vector3.UP * OFFSCREEN_HEIGHT


## Искры и тонкий дым над огнём чаши; узел ставит вызывающий (во двор — уходит вместе с ним).
static func make_fire_fx(height: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "FireFx"
	var sparks: ParticleProcessMaterial = ParticleProcessMaterial.new()
	sparks.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.18 * height
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 20.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.2
	sparks.gravity = Vector3(0, 0.25, 0) + NoirWind.DIRECTION * 0.6
	sparks.damping_min = 0.4
	sparks.damping_max = 0.9
	sparks.scale_min = 0.6
	sparks.scale_max = 1.2
	_add_turbulence(sparks, 1.6, 0.25, 0.45)
	var spark_material: ShaderMaterial = _mote_material(Color(1.0, 0.75, 0.32), Color(0.9, 0.18, 0.04), 3.2, 0.0,
			Rect2())
	var spark_fx: GPUParticles3D = _particles("Sparks", 22, 1.8, sparks, _quad(0.13, spark_material))
	spark_fx.position = Vector3(0, height * 0.55, 0)
	root.add_child(spark_fx)
	var smoke: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smoke.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.12 * height
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0, 0.05, 0) + NoirWind.DIRECTION * 0.35
	smoke.scale_min = 0.8
	smoke.scale_max = 1.3
	_add_turbulence(smoke, 0.7, 0.05, 0.12)
	var smoke_material: ShaderMaterial = ShaderMaterial.new()
	smoke_material.shader = SMOKE_SHADER
	var smoke_fx: GPUParticles3D = _particles("Smoke", 7, 4.2, smoke, _quad(0.9 * height, smoke_material))
	smoke_fx.position = Vector3(0, height * 0.9, 0)
	smoke_fx.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	root.add_child(smoke_fx)
	return root


static func _add_turbulence(process: ParticleProcessMaterial, scale: float, low: float, high: float) -> void:
	process.turbulence_enabled = true
	process.turbulence_noise_scale = scale
	process.turbulence_noise_strength = 1.0
	process.turbulence_noise_speed_random = 0.4
	process.turbulence_influence_min = low
	process.turbulence_influence_max = high


static func _ground_collision(process: ParticleProcessMaterial) -> void:
	process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process.collision_friction = 1.0
	process.collision_bounce = 0.0


static func _particles(id: String, amount: int, life: float, process: ParticleProcessMaterial,
		mesh: Mesh) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = id
	particles.amount = amount
	particles.lifetime = life
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.collision_base_size = 0.04
	# частицы улетают далеко от узла: рамка видимости на всю арену
	particles.visibility_aabb = AABB(Vector3(-40, -12, -40), Vector3(80, 30, 80))
	particles.randomness = 1.0
	return particles


static func _quad(size: float, material: Material) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	return quad


func _leaf_mesh(size: float) -> QuadMesh:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LEAF_SHADER
	material.set_shader_parameter("atlas", LEAF_ATLAS)
	return _quad(size, material)


static func _mote_material(start: Color, finish: Color, energy: float, blink: float, hide: Rect2) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MOTE_SHADER
	material.set_shader_parameter("start_color", start)
	material.set_shader_parameter("end_color", finish)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("blink", blink)
	if hide.has_area():
		material.set_shader_parameter("hide_rect", Vector4(hide.position.x, hide.position.y, hide.end.x, hide.end.y))
	return material
