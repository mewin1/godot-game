class_name DefenseTrial
extends RefCounted
## Бесплатная проба на отдельном поле. Не меняет деньги, HP и RNG настоящего матча.

var killed: int = 0
var breached: int = 0
var retreated: int = 0
var total: int = 0
var reactions: Dictionary[StringName, int] = {}
var battle_report: FieldBattleReport


## Текущие башни/пассивки против известной армии и базовой волны; без активных навыков.
static func run(sim: MatchSim, player_index: int) -> DefenseTrial:
	var result: DefenseTrial = DefenseTrial.new()
	var player: PlayerState = sim.players[player_index]
	var field: FieldState = FieldState.new(sim.config, player.shop.level)
	field.copy_towers_from(player.field)
	field.mob_killed.connect(func(_mob: MobState) -> void: result.killed += 1)
	field.mob_breached.connect(func(_mob: MobState) -> void: result.breached += 1)
	var incoming: Array[MobState] = sim.build_incoming_armies(player_index)
	field.start_wave()
	WaveBuilder.schedule_wave(sim.config, field, sim.round_number, incoming)
	_run_battle(sim.config, field)
	result.retreated = field.count_remaining_mobs()
	field.battle_report.retreated = result.retreated
	result.battle_report = field.battle_report
	result.total = result.killed + result.breached + result.retreated
	result.reactions = field.reaction_counts.duplicate()
	return result


static func _run_battle(config: GameConfig, field: FieldState) -> void:
	var limit: int = config.battle_real_ticks if config.synchronized_battle \
			else config.wave_max_ticks + config.wave_enrage_extra_ticks
	for real_tick: int in range(1, limit + 1):
		if not config.synchronized_battle and real_tick >= config.wave_max_ticks:
			field.enrage()
		for substep: int in config.get_battle_speed_at(real_tick):
			field.tick()
			if field.is_wave_done():
				return
	if not config.synchronized_battle:
		field.breach_all_remaining()
