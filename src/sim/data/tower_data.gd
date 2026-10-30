class_name TowerData
extends Resource
## Описание вида башни: фигура, школа, тир и боевые статы. Конкретные башни — в data/towers/*.tres.
## Расстояния — в тысячных долях клетки (1000 = одна клетка), время — в тиках симуляции.

@export var id: StringName = &""
@export var display_name: String = ""
## Школа башни: &"fire", &"ice", &"mech".
@export var school: StringName = &""
## Тир 1–4: с какого уровня магазина башня может попасть на витрину.
@export var tier: int = 1
## Клетки фигуры относительно левого верхнего угла (без поворота).
@export var shape: Array[Vector2i] = [Vector2i.ZERO]
@export var damage: int = 10
@export var cooldown_ticks: int = 20
@export var range_milli: int = 2500
## Урон по площади вокруг цели: радиус и доля урона в процентах (0 — нет).
@export var splash_radius_milli: int = 0
@export var splash_percent: int = 0
## Замедление цели: на сколько процентов и сколько тиков (0 — нет).
@export var slow_percent: int = 0
@export var slow_ticks: int = 0
@export var tags: Array[StringName] = []
## Что делает — одной фразой (карточка витрины, меню).
@export_multiline var description: String = ""
## Стреляет ли постройка (усилители и лавка — нет).
@export var attacks: bool = true
## Бьёт всех мобов в радиусе разом (пар бани, сказки кота), а не одну цель.
@export var hits_all_in_range: bool = false
## Сколько разных целей за выстрел (панелька — 3).
@export var targets_per_shot: int = 1
## Как часто выпадает на витрине относительно других (стрелки 10, вспомогательные — реже).
@export var shop_weight: int = 10
## Достаёт ли летающих (капкан и богатырь — нет).
@export var can_hit_flying: bool = true

@export_group("Соседям и доход")
## Бонусы всем соседям (касаются стороной клетки). Растут с уровнем, как урон: ×1 / ×2 / ×4.
@export var neighbor_damage_percent: int = 0
@export var neighbor_fire_rate_percent: int = 0
@export var neighbor_range_milli: int = 0
## Доход в конце каждого раунда, пока постройка стоит (растёт с уровнем так же).
@export var income_per_round: int = 0


## Даёт ли что-то соседям.
func is_support() -> bool:
	return neighbor_damage_percent > 0 or neighbor_fire_rate_percent > 0 \
			or neighbor_range_milli > 0
## Цвет квадратиков в прототипе. Симуляция его не использует.
@export var color: Color = Color.WHITE
