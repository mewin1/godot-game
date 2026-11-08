class_name WaveBuilder
extends RefCounted
## Базовая волна раунда: одинаковая для всех игроков, растёт по раундам.


## Мобы базовой волны раунда round_number. Число растёт линейно, HP — сложным процентом.
static func build_base_wave(config: GameConfig, round_number: int) -> Array[MobState]:
	var count: int = config.wave_base_count + config.wave_count_per_round * (round_number - 1)
	var hp_bonus: int = config.get_round_hp_percent(round_number, config.wave_hp_growth_percent) - 100
	var wave: Array[MobState] = []
	for i: int in count:
		wave.append(MobState.create(config.wave_mob, hp_bonus))
	for special: WaveSpecialData in config.wave_specials:
		if round_number < special.first_round:
			continue
		for i: int in special.count:
			wave.append(MobState.create(special.mob, hp_bonus))
	return wave


## Ставит базовую волну и армии соперников в очередь поля.
static func schedule_wave(config: GameConfig, field: FieldState, round_number: int,
		packs: Array[MobState]) -> void:
	var base_wave: Array[MobState] = build_base_wave(config, round_number)
	_schedule_pack(field, base_wave, config.wave_spawn_interval_ticks, 0, config.spawn_window_ticks)
	_schedule_pack(field, packs, config.army_spawn_interval_ticks, config.army_spawn_delay_ticks,
			config.spawn_window_ticks)


## Обычная пачка сохраняет интервал. В большой осаде несколько мобов могут выйти в один тик.
static func _schedule_pack(field: FieldState, pack: Array[MobState], interval: int,
		delay: int, window: int) -> void:
	var available: int = maxi(0, window - delay)
	var share_ticks: bool = interval > 0 and window > 0 and pack.size() > available + 1
	if window > 0 and pack.size() > 1:
		interval = mini(interval, available / (pack.size() - 1))
	for index: int in pack.size():
		var offset: int = index * interval
		if share_ticks:
			offset = index * available / (pack.size() - 1)
		field.schedule_spawn(pack[index], delay + offset)
