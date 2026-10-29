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
@export var tags: Array[StringName] = []
## Цвет и размер квадратика в прототипе (размер в долях клетки). Симуляция их не использует.
@export var color: Color = Color.WHITE
@export var view_size: float = 0.4
