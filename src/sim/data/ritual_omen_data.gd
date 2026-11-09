class_name RitualOmenData
extends Resource
## Примета ночи (docs/36 §2): у ночи своя задача — орда, тяжёлые, быстрые, обереги.
## Видна в разведке заранее; меняет только состав пачек и их число, не правила боя.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## С какой ночи примета может выпасть (её враги к этой ночи уже открыты).
@export var first_night: int = 3
## Любимые враги приметы (индексы settings.enemies): их вес в пачке умножается на favor_multiplier,
## и они могут и вести пачку, и идти в ней рядовыми.
@export var favored: Array[int] = []
@export var favor_multiplier: int = 4
## Сколько пачек добавить (или убрать) к обычному числу пачек ночи.
@export var packs_add: int = 0
