class_name RitualGiftData
extends Resource
## Дар за победу над боссом (docs/34 §13): сильный рывок силы игрока, выбор 1 из 3.

enum Effect { DAMAGE_ALL, DAMAGE_GOD, SPLASH_GOD, HERO_TWICE, FREE_REPAIR, DOUBLE_DISCOUNT,
		RANGE_ALL, RATE_ALL, HEAL_ILYA }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.DAMAGE_ALL
## Стихия (бог постройки) для даров одной стихии.
@export var god: StringName = &""
## Главная величина: проценты урона/темпа, радиус в тысячных клетки, ночи, HP.
@export var value: int = 0
## Вторая величина: доля урона по области в процентах.
@export var extra: int = 0
