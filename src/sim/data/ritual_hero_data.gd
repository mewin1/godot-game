class_name RitualHeroData
extends Resource
## Герой бесконечного «Обряда» (docs/36 §1): выбирается перед забегом, стоит в сторожке.
## Его HP — HP забега; активка — по точке дороги (удар, свист) или сразу (варево).

enum Skill { STRIKE, WHISTLE, BREW }

@export var id: StringName = &""
@export var display_name: String = ""
## Короткое имя для шапки («Илья · 50») и винительный падеж для кнопки лечения.
@export var short_name: String = ""
@export var accusative: String = ""
## Строка поражения: «Илья пал», «Баба-Яга пала».
@export var fallen_text: String = ""
@export var skill_name: String = ""
@export_multiline var passive_text: String = ""
@export_multiline var skill_text: String = ""
@export var portrait: String = ""
@export var model: String = ""
@export var hp: int = 50
@export var skill: Skill = Skill.STRIKE
@export var cooldown_ticks: int = 900
@export var warning_ticks: int = 20
@export var radius_milli: int = 2200
## Удар: доля текущего HP цели и предел урона.
@export var percent: int = 45
@export var cap: int = 500
## Свист: на сколько тысячных клетки назад по дороге и сколько тиков оглушения.
## Боссы отлетают вдвое меньше.
@export var knockback_milli: int = 0
@export var stun_ticks: int = 0
## Пассивки: частокол на каждом рассвете (до предела в запасе) и бесплатные обновления лавки в сутки.
@export var dawn_palisades: int = 0
@export var palisade_cap: int = 0
@export var free_rerolls: int = 0


func needs_spot() -> bool:
	return skill != Skill.BREW
