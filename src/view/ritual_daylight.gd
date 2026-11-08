class_name RitualDaylight
extends RefCounted
## Сутки «Обряда» на сцене: солнце идёт по небу с утра до заката, на закате свет рыжеет и
## слабеет, затем синие сумерки и ночь с луной и светом PvP-двора; утром — рассвет.
## Только вид: время берётся из тика RitualTrial, состояние боя не меняется.

## Солнце: высота над горизонтом в полдень и путь по сторонам света (поворот света, градусы).
## Утром свет справа, в полдень — со стороны камеры, вечером — слева, от ручья.
const NOON_ELEVATION: float = 54.0
const SUN_YAW_MORNING: float = 70.0
const SUN_YAW_EVENING: float = -75.0
## Тени не длиннее, чем при солнце на этой высоте (у горизонта свет уже почти погас).
const SHADOW_MIN_ELEVATION: float = 7.0
## Путь солнца s: 0 — восход, 1 — ушло за горизонт. День идёт от утра (MORNING_S, ~24°, подготовка
## светлая) до DAY_END_S, закат — до 1. Утро после ночи выходит из рассвета (DAWN_TICKS).
const MORNING_S: float = 0.15
const DAY_END_S: float = 0.88
## Синие сумерки после начала ночи, тики: ночь сгущается постепенно.
const TWILIGHT_TICKS: int = 220
const DAWN_TICKS: int = 100

## День: светлый, чёткий, без молочной дымки.
const DAY_SUN: Color = Color("fff0d6")
const DAY_SUN_ENERGY: float = 2.1
const DAY_AMBIENT: Color = Color("b4c2c6")
const DAY_AMBIENT_ENERGY: float = 0.52
const DAY_SKY_TOP: Color = Color("6f90a6")
const DAY_SKY_HORIZON: Color = Color("bcc8c4")
const DAY_FOG: Color = Color("93a8a6")
const DAY_FOG_DENSITY: float = 0.07
const DAY_EXPOSURE: float = 1.06
const DAY_GLOW: float = 0.35
const DAY_BLOOM: float = 0.015
const DAY_SATURATION: float = 1.02
const DAY_SHADOW_OPACITY: float = 0.88
const DAY_SHADOW_BLUR: float = 1.0
## Закат: низкое рыжее солнце, розово-сизое небо.
const SUNSET_SUN: Color = Color("ffb07a")
const SUNSET_AMBIENT: Color = Color("ab9ea0")
const SUNSET_SKY_TOP: Color = Color("4f526b")
const SUNSET_SKY_HORIZON: Color = Color("df9566")
const SUNSET_FOG: Color = Color("9c8c86")
const SUNSET_WARM_KEY: float = 0.16
## Тени облаков: днём заметные пятна, на закате слабее, ночью нет.
const CLOUD_STRENGTH: float = 0.55

## Расстояние от камеры до двора — туман и размытие дальнего плана начинаются за двором.
var camera_distance: float = 80.0

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _warm: DirectionalLight3D
var _attributes: CameraAttributesPractical
var _clouds: CloudShadows3D
## Ночь — как настроена сцена PvP-двора.
var _night_ambient: Color
var _night_ambient_energy: float
var _night_fog: Color
var _night_fog_density: float
var _night_horizon: Color
var _night_ground: Color
var _night_top: Color
var _moon_basis: Basis
var _moon_color: Color
var _moon_energy: float
var _night_warm: float
var _night_exposure: float
var _night_glow: float
var _night_bloom: float
var _night_saturation: float
var _night_shadow_opacity: float
var _night_shadow_blur: float


func _init(world: Node3D, clouds: CloudShadows3D) -> void:
	var environment: WorldEnvironment = world.get_node("Environment") as WorldEnvironment
	_env = environment.environment
	_attributes = environment.camera_attributes as CameraAttributesPractical
	_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = world.get_node("Moon") as DirectionalLight3D
	_warm = world.get_node("WarmKey") as DirectionalLight3D
	_clouds = clouds
	_night_ambient = _env.ambient_light_color
	_night_ambient_energy = _env.ambient_light_energy
	_night_fog = _env.fog_light_color
	_night_fog_density = _env.fog_density
	_night_horizon = _sky.sky_horizon_color
	_night_ground = _sky.ground_horizon_color
	_night_top = _sky.sky_top_color
	_moon_basis = _sun.basis
	_moon_color = _sun.light_color
	_moon_energy = _sun.light_energy
	_night_warm = _warm.light_energy
	_night_exposure = _env.tonemap_exposure
	_night_glow = _env.glow_intensity
	_night_bloom = _env.glow_bloom
	_night_saturation = _env.adjustment_saturation
	_night_shadow_opacity = _sun.shadow_opacity
	_night_shadow_blur = _sun.shadow_blur


## Где солнце (0 — восход, 1 — ушло за горизонт) и насколько ночь (0..1) в этот тик.
static func sun_phase(trial: RitualTrial) -> Vector2:
	var settings: RitualTrialConfig = trial.settings
	if trial.tick_count >= settings.cycle_ticks * settings.cycles:
		return Vector2(0.5, 0.0)  # обряд окончен — светлый день
	var local: int = trial.tick_count % settings.cycle_ticks
	if local < settings.dusk_tick:
		var s: float = lerpf(MORNING_S, DAY_END_S, float(local) / settings.dusk_tick)
		var dawn: float = 0.0
		if trial.tick_count >= settings.cycle_ticks and local < DAWN_TICKS:
			dawn = 1.0 - smoothstep(0.0, 1.0, float(local) / DAWN_TICKS)
		return Vector2(s, dawn)
	if local < settings.night_tick:
		var dusk: float = float(local - settings.dusk_tick) / (settings.night_tick - settings.dusk_tick)
		return Vector2(lerpf(DAY_END_S, 1.0, dusk), 0.45 * smoothstep(0.0, 1.0, dusk))
	var twilight: float = clampf(float(local - settings.night_tick) / TWILIGHT_TICKS, 0.0, 1.0)
	return Vector2(1.0, lerpf(0.45, 1.0, smoothstep(0.0, 1.0, twilight)))


func apply(trial: RitualTrial) -> void:
	var phase: Vector2 = sun_phase(trial)
	var s: float = phase.x
	var night: float = phase.y
	var elevation: float = NOON_ELEVATION * sin(PI * clampf(s, 0.0, 1.0))
	# низкое солнце рыжеет (и утром, и вечером), ниже 2° почти не светит
	var warmth: float = 1.0 - smoothstep(2.0, 24.0, elevation)
	var up: float = smoothstep(-1.0, 9.0, elevation)
	# закатные краски воздуха и неба гаснут, как только солнце ушло: сумерки синие, не бурые
	var afterglow: float = warmth * (1.0 - smoothstep(0.15, 0.55, night))
	var sun_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-maxf(elevation, SHADOW_MIN_ELEVATION)),
		deg_to_rad(lerpf(SUN_YAW_MORNING, SUN_YAW_EVENING, s)), 0.0))
	# к ночи свет плавно переходит на луну (пока он слабый, поворот не заметен)
	var to_moon: float = smoothstep(0.15, 0.6, night)
	_sun.basis = sun_basis.slerp(_moon_basis, to_moon).orthonormalized()
	var sun_color: Color = DAY_SUN.lerp(SUNSET_SUN, warmth)
	_sun.light_color = sun_color.lerp(_moon_color, to_moon)
	var sun_energy: float = DAY_SUN_ENERGY * up * lerpf(1.0, 0.7, warmth)
	# луна поднимается, пока гаснет закат: сумерки не темнее ночи
	_sun.light_energy = sun_energy * (1.0 - night) + _moon_energy * smoothstep(0.2, 0.75, night)
	_sun.shadow_opacity = lerpf(DAY_SHADOW_OPACITY, _night_shadow_opacity, night)
	_sun.shadow_blur = lerpf(DAY_SHADOW_BLUR, _night_shadow_blur, night)
	_sun.directional_shadow_max_distance = camera_distance + 70.0
	_warm.light_energy = lerpf(SUNSET_WARM_KEY * afterglow, _night_warm, night)
	_env.ambient_light_color = DAY_AMBIENT.lerp(SUNSET_AMBIENT, afterglow).lerp(_night_ambient, night)
	_env.ambient_light_energy = lerpf(DAY_AMBIENT_ENERGY, _night_ambient_energy, night)
	_env.fog_light_color = DAY_FOG.lerp(SUNSET_FOG, afterglow).lerp(_night_fog, night)
	_env.fog_density = lerpf(DAY_FOG_DENSITY, _night_fog_density, night)
	_env.fog_depth_begin = camera_distance + 20.0
	_env.fog_depth_end = camera_distance + 110.0
	_env.tonemap_exposure = lerpf(DAY_EXPOSURE, _night_exposure, night)
	_env.glow_intensity = lerpf(DAY_GLOW, _night_glow, night)
	_env.glow_bloom = lerpf(DAY_BLOOM, _night_bloom, night)
	_env.adjustment_saturation = lerpf(DAY_SATURATION, _night_saturation, night)
	var horizon: Color = DAY_SKY_HORIZON.lerp(SUNSET_SKY_HORIZON, afterglow).lerp(_night_horizon, night)
	if not _sky.sky_horizon_color.is_equal_approx(horizon):
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon.lerp(_night_ground, night)
		_sky.sky_top_color = DAY_SKY_TOP.lerp(SUNSET_SKY_TOP, afterglow).lerp(_night_top, night)
	if _attributes != null:
		_attributes.dof_blur_far_distance = camera_distance + 40.0
	_clouds.set_strength(CLOUD_STRENGTH * up * lerpf(1.0, 0.55, warmth) * (1.0 - night))
