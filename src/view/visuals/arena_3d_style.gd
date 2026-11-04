class_name Arena3DStyle
extends Resource
## Как выглядят 3D-башни и 3D-юниты на лесной арене: цвета богов, модели и размеры мобов.
## Только отображение — симуляция об этих числах ничего не знает.

## Цвет «окрашиваемой» части башни по богу (TowerData.god). Пустой бог — нейтральный.
@export var god_colors: Dictionary[StringName, Color] = {}
## Светящийся акцент (кристалл/огонь) по богу.
@export var god_glow: Dictionary[StringName, Color] = {}
@export var neutral_color: Color = Color(0.55, 0.5, 0.42)
@export var neutral_glow: Color = Color(1.0, 0.8, 0.45)
## Высота модели башни по тиру (метры) — 1, 2, 3.
@export var tier_heights: PackedFloat32Array = PackedFloat32Array([1.5, 2.4, 3.4])
## Общий масштаб моделей башен (1 — модель «в метрах»).
@export var tower_scale: float = 1.3
## Насколько плитка под клеткой уходит от цвета бога к камню (0 — чистый цвет).
@export var tile_stone_mix: float = 0.45
## Прибавка размера за уровень слияния (доля на каждый уровень сверх первого).
@export var level_scale_step: float = 0.12

@export_group("Нуар")
## Плита под постройкой — фон, а не главное: её свечение и яркость фактуры (1 — как в модели).
@export var noir_plate_glow: float = 0.0
@export var noir_plate_tone: float = 0.32
## Свечение самой постройки (1,6 — как в модели).
@export var noir_model_glow: float = 0.9
## Яркость фактуры постройки (1 — как в модели; ночные фактуры тёмные) и лунный контур силуэта.
@export var noir_model_tone: float = 1.3
@export var noir_model_rim: float = 0.35
## Масштаб модели постройки «нуар» (плита не меняется).
@export var noir_model_scale: float = 1.7
## Цветной свет стихии вокруг постройки.
@export var noir_aura_energy: float = 2.4
@export var noir_aura_range: float = 5.5
## Яркость рамки цвета стихии вокруг постройки (различать соседей в тесноте).
@export var noir_frame_energy: float = 0.6
## Сдвиг уровня мип-карт картинки арены: меньше нуля — фактуры резче (слишком мало — рябь).
@export var mipmap_bias: float = -0.5

## Модель моба по id (&"walker", &"heavy", &"flyer", &"boss", &"blob"); нет записи — walker.
@export var mob_models: Dictionary[StringName, StringName] = {}
@export var mob_tints: Dictionary[StringName, Color] = {}
## Рост модели в метрах (клетка — 2 м).
@export var mob_heights: Dictionary[StringName, float] = {}
@export var default_mob_height: float = 1.0
## Общий масштаб юнитов: на виде сверху метровая фигурка слишком мелкая.
@export var unit_scale: float = 1.55
@export var default_mob_tint: Color = Color(0.55, 0.5, 0.45)
## Высота полёта летающих над дорогой, метры.
@export var fly_height: float = 1.3
## Шагов на метр пути: темп анимации берётся из настоящей скорости моба в симуляции.
@export var steps_per_meter: float = 0.9

## Скрытные мобы (как в 2D): непрозрачность модели.
@export var stealth_alpha: float = 0.45
## Кольцо ярости поля / злой армии под юнитом.
@export var rage_color: Color = Color(1.0, 0.25, 0.12)
## Огонь тотема героя в конце короткого пути.
@export var totem_fire: Color = Color(1.0, 0.55, 0.18)

## Каменные площадки мест: бока, плита и светлая кромка шва.
@export var platform_side: Color = Color(0.2, 0.2, 0.22)
@export var platform_top: Color = Color(0.34, 0.33, 0.31)
@export var platform_inlay: Color = Color(0.4, 0.38, 0.35)
## Разброс яркости плит, чтобы площадка не выглядела пластиковой.
@export var platform_variation: float = 0.035

## Жаровни по углам площадок: огонь и тёплый свет.
@export var brazier_fire: Color = Color(1.0, 0.5, 0.15)
@export var brazier_light_energy: float = 2.2
@export var brazier_light_range: float = 5.5

## Закрытые клетки и ещё не открытая дорога.
@export var fog_color: Color = Color(0.02, 0.04, 0.08, 0.66)
@export var fog_edge_color: Color = Color(0.45, 0.6, 0.8, 0.25)


func get_god_color(god: StringName) -> Color:
	return god_colors.get(god, neutral_color)


func get_god_glow(god: StringName) -> Color:
	return god_glow.get(god, neutral_glow)


func get_mob_model(mob_id: StringName) -> StringName:
	return mob_models.get(mob_id, &"walker")


func get_mob_tint(mob_id: StringName) -> Color:
	return mob_tints.get(mob_id, default_mob_tint)


func get_mob_height(mob_id: StringName) -> float:
	var height: float = mob_heights.get(mob_id, default_mob_height)
	return height * unit_scale
