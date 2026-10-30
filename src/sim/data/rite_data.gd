class_name RiteData
extends Resource
## Заговор из лавки: постоянное усиление идола или одной постройки.

enum Target { IDOL, TOWER }
enum Effect { DAMAGE, CHAIN_HITS, CHAIN_TARGETS, BURN, WIND_POWER, WIND_LENGTH,
		ENCHANT_DAMAGE, ENCHANT_RATE, ENCHANT_RANGE, AWAKEN_WIDE, AWAKEN_FOCUS,
		CHAIN_CHANCE, WET_DURATION, STATUS_DURATION, TARGETS }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var god: StringName = &""
@export var target: Target = Target.IDOL
@export var effect: Effect = Effect.DAMAGE
## Величина эффекта идола; общие эффекты чар башен настраиваются в GameConfig.
@export var value: int = 10
@export var cost: int = 6
@export var tier: int = 1
@export var max_purchases: int = 5
