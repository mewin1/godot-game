class_name WaveBuilder
extends RefCounted
## Базовая волна раунда: одинаковая для всех игроков, растёт по раундам.


## Мобы базовой волны раунда round_number. Число растёт линейно, HP — сложным процентом.
static func build_base_wave(config: GameConfig, round_number: int) -> Array[MobState]:
	var count: int = config.wave_base_count + config.wave_count_per_round * (round_number - 1)
	var hp_bonus: int = config.get_round_hp_percent(round_number) - 100
	var wave: Array[MobState] = []
	for i: int in count:
		wave.append(MobState.create(config.wave_mob, hp_bonus))
	return wave


## Ставит базовую волну и армии соперников в очередь поля.
static func schedule_wave(config: GameConfig, field: FieldState, round_number: int,
		packs: Array[MobState]) -> void:
	var base_wave: Array[MobState] = build_base_wave(config, round_number)
	for i: int in base_wave.size():
		field.schedule_spawn(base_wave[i], i * config.wave_spawn_interval_ticks)
	for i: int in packs.size():
		var spawn_tick: int = config.army_spawn_delay_ticks + i * config.army_spawn_interval_ticks
		field.schedule_spawn(packs[i], spawn_tick)
