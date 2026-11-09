class_name RitualEnemyRule
extends Resource
## Как враг попадает в пачки бесконечного «Обряда»: цена в бюджете ночи, с какой ночи, как часто.

## Индекс врага в RitualTrialConfig.enemies.
@export var enemy_index: int = 0
## Сколько очков бюджета ночи стоит один такой враг.
@export var threat: int = 1
## С какой ночи враг может появиться (1 — сразу).
@export var first_night: int = 1
## Частота выбора ведущим пачки (0 — не ведёт). Ведущий — самый сильный, иконка в очереди.
@export var lead_weight: int = 0
## Частота выбора простым бойцом пачки (0 — не идёт в свиту).
@export var fill_weight: int = 10


func weight(lead: bool) -> int:
	return lead_weight if lead else fill_weight
