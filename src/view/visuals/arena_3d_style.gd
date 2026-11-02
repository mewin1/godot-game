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
