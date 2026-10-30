class_name PantheonDraft
extends RefCounted
## Общий драфт без повторений, случайность берётся только из RNG матча.

## Пустой каталог оставляет исторические конфиги без драфта.
static func draw(config: GameConfig, rng: RandomNumberGenerator) -> Array[StringName]:
	var pool: Array[StringName] = config.gods.duplicate()
	var result: Array[StringName] = []
	for i: int in mini(config.draft_count, pool.size()):
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return result
