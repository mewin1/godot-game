class_name HeroData
extends Resource
## Герой: HP терема, пассивки и навык. Конкретные герои — в data/heroes/*.tres.
## Портрет лежит по соглашению в res://assets/heroes/<id>.svg (симуляция о нём не знает).

@export var id: StringName = &""
@export var display_name: String = ""
## Образ одной строкой: кто это.
@export var epithet: String = ""
## Что делает — одна-две фразы для карточки выбора.
@export_multiline var description: String = ""
## Стиль игры одним-двумя словами («оборона», «экономика»…).
@export var style: String = ""
@export var hp: int = 40
## Пассивки: работают сами весь матч.
@export var passives: Array[HeroEffect] = []
## Навык за золото (null — навыка нет).
@export var skill: HeroSkillData
