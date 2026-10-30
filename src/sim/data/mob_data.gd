class_name MobData
extends Resource
## Описание вида моба. Конкретные мобы — в data/mobs/*.tres.
## Скорость — в тысячных долях клетки за тик (при 20 тиках/сек 50 = 1 клетка в секунду).

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: int = 30
@export var speed_milli_per_tick: int = 50
## Броня вычитается из каждого попадания (но урон не меньше 1).
@export var armor: int = 0
## Золото защитнику за убийство.
@export var kill_reward: int = 1
## Сколько HP героя снимает прорыв (до множителя раунда).
@export var breach_damage: int = 1
## Прорвался — хозяину армии столько золота сверху (разбойник).
@export var breach_gold_to_sender: int = 0
@export var tags: Array[StringName] = []
## Особенность одной фразой (для меню и презентации).
@export_multiline var description: String = ""
## Летает: постройки с can_hit_flying = false его не бьют.
@export var is_flying: bool = false
## Невидимка: башни видят его только ближе этого расстояния (0 — видно всегда).
@export var reveal_radius_milli: int = 0
## Щит: столько первых попаданий не наносят урона.
@export var shield_hits: int = 0
## Лекарь: раз в heal_interval_ticks лечит мобов в радиусе на heal_percent% их HP.
@export var heal_percent: int = 0
@export var heal_radius_milli: int = 0
@export var heal_interval_ticks: int = 20
## Деление: при смерти появляется split_count мобов split_into с split_hp_percent% HP родителя.
@export var split_into: MobData
@export var split_count: int = 0
@export var split_hp_percent: int = 35
## Рывок: после sprint_from_percent% пути бежит на sprint_speed_percent% быстрее.
@export var sprint_from_percent: int = 0
@export var sprint_speed_percent: int = 0
## Цвет и размер квадратика в прототипе (размер в долях клетки). Симуляция их не использует.
@export var color: Color = Color.WHITE
@export var view_size: float = 0.4
