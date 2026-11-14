class_name RitualGates3D
extends Node3D
## Сторожка и ворота «Обряда» (docs/37 SCN-7, HER-1). Сторожка — арка над концом дороги у героя:
## вспыхивает красным на каждом прорыве, при малом здоровье тлеет. Ворота входов этой ночи
## в конце дня пульсируют красным — видно, откуда пойдёт нежить. Только вид.

const BREACH_SECONDS: float = 0.6
## За сколько тиков до ночи начинают гореть ворота её входов.
const WARN_TICKS: int = 220
const WARN_COLOR: Color = Color("ff4a3a")

var _gatehouse: Node3D
var _glow: StandardMaterial3D
var _gate_lights: Array[OmniLight3D] = []
var _gate_marks: Array[MeshInstance3D] = []
var _last_hp: int = -1
var _breach_age: float = BREACH_SECONDS
var _clock: float = 0.0


## Арка у конца главной дороги: два столба, перекладина и крыша, лицом вдоль дороги.
func build_gatehouse(at: Vector3, along: Vector3) -> void:
	_gatehouse = Node3D.new()
	_gatehouse.name = "Gatehouse"
	_gatehouse.position = at
	_gatehouse.rotation.y = atan2(along.x, along.z)
	add_child(_gatehouse)
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.WOOD.lightened(0.15))
	for side: float in [-1.15, 1.15]:
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(0.28, 2.6, 0.28)), wood,
			Vector3(side, 1.3, 0))
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(2.7, 0.26, 0.4)), wood, Vector3(0, 2.55, 0))
	# Двускатная крыша из двух тонких досок: сверху читается как навес, а не как плита.
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(2.9, 0.06, 0.5)),
			ArenaMaterials3D.solid(Color("7a5236")), Vector3(0, 2.86, side * 0.2), Vector3(side * 0.45, 0, 0))
	_glow = ArenaMaterials3D.glow(Color("ff3b2a"), 0.0)
	ArenaMaterials3D.part(_gatehouse, ArenaMaterials3D.box(Vector3(2.4, 0.08, 0.44)), _glow, Vector3(0, 2.4, 0))


## Ворота (точки входа дорог в мире): создаются по числу дорог, светятся по sync.
func set_gates(points: Array[Vector3]) -> void:
	for light: OmniLight3D in _gate_lights:
		light.queue_free()
	for mark: MeshInstance3D in _gate_marks:
		mark.queue_free()
	_gate_lights.clear()
	_gate_marks.clear()
	for point: Vector3 in points:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = WARN_COLOR
		light.omni_range = 6.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = point + Vector3(0, 1.6, 0)
		add_child(light)
		_gate_lights.append(light)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 1.1
		ring.outer_radius = 1.3
		var mark: MeshInstance3D = ArenaMaterials3D.part(self, ring, ArenaMaterials3D.glow(WARN_COLOR, 2.0),
			point + Vector3(0, 0.08, 0))
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		_gate_marks.append(mark)


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
		var lit: bool = warn and index < open_tonight.size() and open_tonight[index]
		_gate_lights[index].light_energy = 2.6 * pulse if lit else 0.0
		_gate_marks[index].visible = lit
