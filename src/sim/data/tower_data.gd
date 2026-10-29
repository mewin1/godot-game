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
## Цвет квадратиков в прототипе. Симуляция его не использует.
@export var color: Color = Color.WHITE
