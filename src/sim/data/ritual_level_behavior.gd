class_name RitualLevelBehavior
extends Resource
## Поведение постройки «Обряда» на одном уровне (материале): не только урон, но и цели, область,
## дальность, пробой брони и сила поддержки соседей (docs/34 §2).

## Короткое описание уровня для подсказки игроку.
@export var note: String = ""
## Урон в процентах от базового урона постройки (100 — как в данных).
@export var damage_percent: int = 100
## Плоская прибавка урона — для построек без своего урона (водяной дом).
@export var damage_add: int = 0
## Дополнительные цели за выстрел.
@export var extra_targets: int = 0
## Урон по области вокруг цели; -1 — как в данных постройки. Бьёт только врагов.
@export var splash_radius_milli: int = -1
@export var splash_percent: int = -1
@export var range_bonus_milli: int = 0
## Сколько брони врага игнорирует удар (сверх данных постройки).
@export var armor_pierce: int = 0
## Сила бонусов соседям в процентах от данных (100 — как в данных).
@export var support_percent: int = 100
