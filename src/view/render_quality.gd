class_name RenderQuality
extends RefCounted
## Профиль качества 3D-графики (только отображение, sim не трогает).
## HIGH — ПК: мягкое сглаживание TAA, тени леса и факелов, SSAO, объёмная дымка.
## MOBILE — телефоны и слабые видеокарты: 3D в 75 % разрешения + FXAA, тени только от солнца
## и только двора (лес и трава без теней), без SSAO, объёмной дымки и размытия дали, частиц вдвое меньше,
## травы меньше (60 % на поляне, 30 % под пологом), 30 FPS.
## Выбор: аргумент запуска `-- --quality=mobile` / `-- --quality=high`, иначе на телефоне — MOBILE.

enum Level { HIGH, MOBILE }

## Предел кадров в секунду (0 — без предела, только вертикальная синхронизация).
const HIGH_MAX_FPS: int = 0
const MOBILE_MAX_FPS: int = 30
const MOBILE_3D_SCALE: float = 0.75
## Дальность теней солнца на телефоне (м от камеры): только двор.
const MOBILE_SHADOW_DISTANCE: float = 80.0
const SHADOW_ATLAS: int = 2048

static var _level: Level = Level.HIGH
static var _chosen: bool = false


static func level() -> Level:
	if not _chosen:
		_chosen = true
		_level = Level.MOBILE if OS.has_feature("mobile") else Level.HIGH
		for arg: String in OS.get_cmdline_user_args():
			if arg == "--quality=mobile":
				_level = Level.MOBILE
			elif arg == "--quality=high":
				_level = Level.HIGH
	return _level


static func is_mobile() -> bool:
	return level() == Level.MOBILE


## Тени от леса, камней и травы (от солнца и луны).
static func env_shadows() -> bool:
	return not is_mobile()


## Тени от факелов у частокола.
static func torch_shadows() -> bool:
	return not is_mobile()


## Доля частиц (листья, светлячки, пыль, искры).
static func particle_ratio() -> float:
	return 0.5 if is_mobile() else 1.0


## Доля травы на поляне вокруг двора и под пологом леса (там днём тень, ночью почти не видно).
static func grass_keep_glade() -> float:
	return 0.6 if is_mobile() else 1.0


static func grass_keep_under_canopy() -> float:
	return 0.3 if is_mobile() else 0.5


## Участок леса и травы (м): копии одного вида в участке — одна отрисовка, невидимые участки отсекаются.
## На телефоне участки крупнее: меньше отрисовок (процессор слабее), отсечение чуть грубее.
static func env_chunk() -> float:
	return 32.0 if is_mobile() else 16.0


static func max_fps() -> int:
	return MOBILE_MAX_FPS if is_mobile() else HIGH_MAX_FPS


## Хвоя и листва с шумовой альфой (noir_canopy_hashed): её край сглаживает TAA, и MSAA не нужен.
## Без TAA (телефон) — срез с alpha-to-coverage (noir_canopy), иначе зерно.
static func hashed_foliage() -> bool:
	return not is_mobile()


## Сглаживание и разрешение 3D. TAA даёт мягкую картинку без мерцания травы, теней и тонких кольев.
## MSAA на ПК не нужен: хвоя — шумовая альфа под TAA (hashed_foliage). Раньше хвоя была срезом
## с alpha-to-coverage, и без MSAA кроны превращались в пятна; MSAA 2x стоил ~1,7 мс в 2560×1440.
static func setup_viewport(viewport: SubViewport) -> void:
	if is_mobile():
		# Compatibility (OpenGL) не умеет FXAA — там MSAA 2x (на телефонных GPU он дешёвый);
		# Mobile (Vulkan) — FXAA. Хвоя на телефоне — срез с alpha-to-coverage.
		var compatibility: bool = RenderingServer.get_current_rendering_method() == &"gl_compatibility"
		viewport.msaa_3d = Viewport.MSAA_2X if compatibility else Viewport.MSAA_DISABLED
		viewport.use_taa = false
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if compatibility else Viewport.SCREEN_SPACE_AA_FXAA
		viewport.scaling_3d_scale = MOBILE_3D_SCALE
	else:
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.use_taa = true
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.scaling_3d_scale = 1.0


## Окружение и солнце сцены арены (после постройки).
static func setup_world(world: Node3D) -> void:
	Engine.max_fps = max_fps()
	# Карта теней солнца 2048² вместо 4096²: тени и так размыты (blur 2), кадр дешевле на ~0,7 мс.
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS, true)
	if not is_mobile():
		return
	var world_env: WorldEnvironment = world.get_node("Environment") as WorldEnvironment
	var env: Environment = world_env.environment
	env.ssao_enabled = false
	env.volumetric_fog_enabled = false
	var attributes: CameraAttributesPractical = world_env.camera_attributes as CameraAttributesPractical
	if attributes != null:
		attributes.dof_blur_far_enabled = false
	var sun: DirectionalLight3D = world.get_node("Moon") as DirectionalLight3D
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = MOBILE_SHADOW_DISTANCE
	sun.light_angular_distance = 0.0  # без мягких теней PCSS
