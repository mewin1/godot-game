class_name IdolState
extends RefCounted
## Одна из трёх пустых основ. Первый заговор посвящает её божеству; следующие усиливают.

var god: StringName = &""
var damage_percent: int = 0
var chain_reduction: int = 0
var chain_chance_bonus: int = 0
var wet_ticks: int = 0
var chain_targets: int = 0
var burn_percent: int = 0
var wind_power: int = 0
var wind_length_milli: int = 0
var purchases: Dictionary[StringName, int] = {}


## Проверяет посвящение и предел конкретного заговора.
func check_rite(rite: RiteData) -> String:
	if god != &"" and god != rite.god:
		return "Этот идол посвящён другому божеству"
	if purchases.get(rite.id, 0) >= rite.max_purchases:
		return "Этот заговор уже усилен до предела"
	return ""


## Применяет уже проверенный заговор, без оплаты.
func apply_rite(rite: RiteData) -> void:
	god = rite.god
	purchases[rite.id] = purchases.get(rite.id, 0) + 1
	match rite.effect:
		RiteData.Effect.DAMAGE:
			damage_percent += rite.value
		RiteData.Effect.CHAIN_CHANCE:
			chain_chance_bonus += rite.value
		RiteData.Effect.WET_DURATION:
			wet_ticks += rite.value
		RiteData.Effect.CHAIN_HITS:
			chain_reduction += rite.value
		RiteData.Effect.CHAIN_TARGETS:
			chain_targets += rite.value
		RiteData.Effect.BURN:
			burn_percent += rite.value
		RiteData.Effect.WIND_POWER:
			wind_power += rite.value
		RiteData.Effect.WIND_LENGTH:
			wind_length_milli += rite.value


## Все эффекты и счётчики влияют на детерминизм.
func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_string(god)
	hasher.add_many([damage_percent, chain_reduction, chain_chance_bonus, wet_ticks,
			chain_targets, burn_percent,
			wind_power, wind_length_milli])
	var keys: Array[StringName] = purchases.keys()
	keys.sort()
	for key: StringName in keys:
		hasher.add_string(key)
		hasher.add(purchases[key])


## Независимый снимок для поля призрака.
func duplicate_state() -> IdolState:
	var result: IdolState = IdolState.new()
	result.god = god
	result.damage_percent = damage_percent
	result.chain_reduction = chain_reduction
	result.chain_chance_bonus = chain_chance_bonus
	result.wet_ticks = wet_ticks
	result.chain_targets = chain_targets
	result.burn_percent = burn_percent
	result.wind_power = wind_power
	result.wind_length_milli = wind_length_milli
	result.purchases = purchases.duplicate()
	return result
