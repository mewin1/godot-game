class_name RitualGates3D
extends Node3D
## Сторожка и ворота «Обряда» (docs/37 SCN-7, HER-1). Сторожка — арка над концом дороги у героя:
## вспыхивает красным на каждом прорыве, при малом здоровье тлеет. Ворота входов этой ночи
## в конце дня пульсируют красным — видно, откуда пойдёт нежить. Только вид.

const BREACH_SECONDS: float = 0.6
## За сколько тиков до ночи начинают гореть ворота её входов.
const WARN_TICKS: int = 220
const WARN_COLOR: Color = Color("ff4a3a")
const LANTERN_ENERGY: float = 0.9

var _gatehouse: Node3D
var _glow: StandardMaterial3D
var _gate_lights: Array[OmniLight3D] = []
## Фонари на столбах ворот снаружи (critique_3 п. 14): ворота читаются с игровой камеры;
## перед ночью краснеют вместе с дымкой (п. 10) — без «обруча» на плитке.
var _lanterns: Array[StandardMaterial3D] = []
var _hazes: Array[FogVolume] = []
const LANTERN_COLOR: Color = Color("ffb35c")
var _last_hp: int = -1
var _breach_age: float = BREACH_SECONDS
var _clock: float = 0.0


## Сторожка у конца главной дороги (critique_4 п. 10, 54, SCN-7): проезд вдоль дороги под низкой
## двускатной крышей — конёк вдоль дороги, фронтоны со светлыми причелинами смотрят навстречу нежити.
## Сторона к камере открыта (без полустенки), с дальней — низкая жердь. Фонарь висит у западного проёма:
## вспыхивает на прорыве, тлеет при малом здоровье. Герой стоит перед проёмом (RitualStage3D).
## Местные оси: +z — вдоль дороги к терему, +x — от камеры.
const GATE_HALF_WIDTH: float = 1.25
const GATE_HALF_DEPTH: float = 1.2
const GATE_POST_HEIGHT: float = 2.05


func build_gatehouse(at: Vector3, along: Vector3) -> void:
	_gatehouse = Node3D.new()
	_gatehouse.name = "Gatehouse"
	_gatehouse.position = at
	_gatehouse.rotation.y = atan2(along.x, along.z)
	add_child(_gatehouse)
	var logs: StandardMaterial3D = ArenaMaterials3D.wood(0.95)
	var dark: StandardMaterial3D = ArenaMaterials3D.wood(0.6)
	var shingle: StandardMaterial3D = ArenaMaterials3D.wood(0.55, true)
	var trim: StandardMaterial3D = ArenaMaterials3D.wood(1.35)
	var w: float = GATE_HALF_WIDTH
	var d: float = GATE_HALF_DEPTH
	var top: float = GATE_POST_HEIGHT
	for side: float in [-w, w]:
		for depth: float in [-d, d]:
			ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.11, 0.13, top, 8), logs,
				Vector3(side, top * 0.5, depth))
		# Брус-обвязка вдоль проезда.
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(0.16, 0.16, d * 2.0 + 0.4)), dark,
			Vector3(side, top, 0.0))
	for depth: float in [-d, d]:
		# Перекладины проёмов поперёк дороги.
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.1, 0.1, w * 2.0 + 0.4, 7), dark,
			Vector3(0.0, top + 0.1, depth), Vector3(0.0, 0.0, PI * 0.5))
	# Низкая жердь только с дальней стороны: проезд и герой открыты с игровой камеры.
	for height: float in [0.42, 0.82]:
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.06, 0.06, d * 2.0, 6), logs,
			Vector3(w, height, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	# Шатёр: четыре ската к навершию — с игровой камеры не «доска», а башенка ворот.
	var eave: Vector2 = Vector2(w + 0.32, d + 0.32)
	var rise: float = 1.35
	var roof: MeshInstance3D = ArenaMaterials3D.part(_gatehouse, _tent_mesh(eave, rise), shingle,
		Vector3(0.0, top + 0.18, 0.0))
	roof.name = "TentRoof"
	# Светлая обвязка по свесу (причелины) и навершие — силуэт читается и ночью.
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(0.07, 0.13, eave.y * 2.0 + 0.07)), trim,
			Vector3(side * eave.x, top + 0.2, 0.0))
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(eave.x * 2.0 + 0.07, 0.13, 0.07)), trim,
			Vector3(0.0, top + 0.2, side * eave.y))
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.05, 0.09, 0.42, 6), trim,
		Vector3(0.0, top + 0.18 + rise + 0.12, 0.0))
	# Фонарь у западного проёма (навстречу нежити): тлеет при малом здоровье, вспыхивает на прорыве.
	_glow = ArenaMaterials3D.glow(Color("ff5a2e"), 0.0)
	var lantern: Vector3 = Vector3(0.0, top - 0.32, -d)
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.012, 0.012, 0.3, 4), dark, lantern + Vector3(0, 0.27, 0))
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.11, 0.13, 0.05, 6), dark, lantern + Vector3(0, 0.15, 0))
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.09, 0.09, 0.22, 6), _glow, lantern)
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.cylinder(0.12, 0.1, 0.04, 6), dark, lantern - Vector3(0, 0.13, 0))


## Шатровая крыша: четыре треугольных ската с плоскими нормалями (половины свеса eave, высота rise).
static func _tent_mesh(eave: Vector2, rise: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var apex: Vector3 = Vector3(0.0, rise, 0.0)
	var corners: Array[Vector3] = [Vector3(-eave.x, 0.0, -eave.y), Vector3(eave.x, 0.0, -eave.y),
			Vector3(eave.x, 0.0, eave.y), Vector3(-eave.x, 0.0, eave.y)]
	for index: int in 4:
		var a: Vector3 = corners[index]
		var b: Vector3 = corners[(index + 1) % 4]
		for point: Vector3 in [b, apex, a]:
			tool.set_uv(Vector2(point.x + point.y * 0.7, point.z + point.y * 0.7) * 0.6)
			tool.add_vertex(point)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()


## Ворота (точки входа дорог в мире) и направление наружу: фонари на столбах, свет и дымка
## предупреждения. Создаются по числу дорог, светятся по sync.
func set_gates(points: Array[Vector3], outwards: Array[Vector3] = []) -> void:
	for light: OmniLight3D in _gate_lights:
		light.queue_free()
	for haze: FogVolume in _hazes:
		haze.queue_free()
	for child: Node in get_children():
		if child.name.begins_with("GateLantern"):
			child.queue_free()
	_gate_lights.clear()
	_hazes.clear()
	_lanterns.clear()
	for index: int in points.size():
		var point: Vector3 = points[index]
		var out: Vector3 = outwards[index] if index < outwards.size() else Vector3.ZERO
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = LANTERN_COLOR
		light.omni_range = 5.0
		light.light_energy = LANTERN_ENERGY
		light.light_specular = 0.2
		light.shadow_enabled = false
		light.position = point + out * 0.8 + Vector3(0, 2.0, 0)
		add_child(light)
		_gate_lights.append(light)
		var glow: StandardMaterial3D = ArenaMaterials3D.glow(LANTERN_COLOR, 2.2).duplicate() as StandardMaterial3D
		_lanterns.append(glow)
		if out != Vector3.ZERO:
			for flank: float in [-1.0, 1.0]:
				_lantern(point + side * flank * 2.15 + out * 0.35, glow, index)
			var haze: FogVolume = FogVolume.new()
			haze.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			haze.size = Vector3(5.0, 2.4, 5.0)
			haze.position = point + out * 3.2 + Vector3(0, 0.6, 0)
			var fog: FogMaterial = FogMaterial.new()
			fog.albedo = WARN_COLOR.darkened(0.35)
			fog.emission = WARN_COLOR.darkened(0.6)
			fog.density = 0.0
			fog.edge_fade = 0.8
			haze.material = fog
			add_child(haze)
			_hazes.append(haze)


## Фонарь на столбе ворот: столбик, колпак и светящийся короб (тёплый; перед ночью — красный).
func _lantern(at: Vector3, glow: StandardMaterial3D, gate: int) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "GateLantern%d" % gate
	holder.position = at
	add_child(holder)
	var post: StandardMaterial3D = ArenaMaterials3D.wood(0.5)
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.06, 0.07, 2.2, 6), post, Vector3(0, 1.1, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.13, 0.16, 0.06, 6), post, Vector3(0, 2.48, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.1, 0.1, 0.24, 6), glow, Vector3(0, 2.32, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.14, 0.11, 0.04, 6), post, Vector3(0, 2.18, 0))


## open_tonight[i] — вход i будет открыт в ближайшую ночь.
func sync(trial: RitualTrial, open_tonight: Array[bool], delta: float) -> void:
	_clock += delta
	_breach_age += delta
	if _last_hp >= 0 and trial.hp < _last_hp:
		_breach_age = 0.0
	_last_hp = trial.hp
	if _glow != null:
		var low: float = 1.0 - clampf(float(trial.hp) / maxf(1.0, float(trial.max_hp())) / 0.5, 0.0, 1.0)
		var flash: float = 1.0 - clampf(_breach_age / BREACH_SECONDS, 0.0, 1.0)
		_glow.emission_energy_multiplier = maxf(4.0 * flash, low * (1.2 + 0.8 * sin(_clock * 3.0)))
	var settings: RitualTrialConfig = trial.settings
	if not settings.is_endless():
		return
	var nights: RitualNightRules = settings.nights
	var night: int = trial.current_night()
	var left: int = nights.night_start(night) - trial.tick_count
	var warn: bool = not settings.is_night(trial.tick_count) and left >= 0 and left <= WARN_TICKS
	var pulse: float = 0.5 + 0.5 * sin(_clock * 5.0)
	for index: int in _gate_lights.size():
		var open: bool = index < open_tonight.size() and open_tonight[index]
		var lit: bool = warn and open
		_gate_lights[index].light_color = WARN_COLOR if lit else LANTERN_COLOR
		_gate_lights[index].light_energy = (1.4 + 1.6 * pulse) if lit else (LANTERN_ENERGY if open else 0.0)
		var glow: StandardMaterial3D = _lanterns[index]
		glow.emission = WARN_COLOR if lit else LANTERN_COLOR
		glow.albedo_color = glow.emission
		glow.emission_energy_multiplier = (2.0 + 2.0 * pulse) if lit else (2.2 if open else 0.3)
		if index < _hazes.size():
			(_hazes[index].material as FogMaterial).density = 0.9 * (0.6 + 0.4 * pulse) if lit else 0.0
