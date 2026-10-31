extends SceneTree
## Контроль равной цены/площади: четыре жаровни против трёх жаровен с водой.


var _slow_override: int = -1
var _ticks_override: int = -1


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--slow="):
			_slow_override = argument.trim_prefix("--slow=").to_int()
		if argument.begins_with("--ticks="):
			_ticks_override = argument.trim_prefix("--ticks=").to_int()
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	for hp_value: int in [30, 60]:
		for speed: int in [100, 150]:
			for interval: int in [6, 20]:
				var fire: int = _fight(config, hp_value, speed, interval, false, false)
				var old_pair: int = _fight(config, hp_value, speed, interval, true, false)
				var controlled: int = _fight(config, hp_value, speed, interval, true, true)
				print("HP%d speed%d interval%d | fire=%d old_pair=%d steam_control=%d kills/12" % [
						hp_value, speed, interval, fire, old_pair, controlled])
	quit()


func _fight(original: GameConfig, hp_value: int, speed: int, interval: int,
		with_water: bool, with_control: bool) -> int:
	var config: GameConfig = original.duplicate() as GameConfig
	var rules: Array[ReactionData] = []
	for source: ReactionData in original.reactions:
		var rule: ReactionData = source.duplicate() as ReactionData
		if with_control and rule.id == &"steam":
			if _slow_override >= 0:
				rule.slow_percent = _slow_override
			if _ticks_override >= 0:
				rule.slow_ticks = _ticks_override
		if not with_control and rule.id == &"steam":
			rule.slow_percent = 0
			rule.slow_ticks = 0
		rules.append(rule)
	config.reactions = rules
	var field: FieldState = FieldState.new(config, 2, 419)
	var brain: BotBrain = BotBrain.new(0)
	for index: int in 4:
		var id_value: String = "water" if with_water and index == 0 else "brazier"
		var data: TowerData = load("res://data/towers/%s.tres" % id_value) as TowerData
		var spot: Vector3i = brain.find_best_spot(field, data)
		assert(spot.z >= 0)
		field.add_tower(data, Vector2i(spot.x, spot.y), spot.z)
	var mob_data: MobData = config.wave_mob.duplicate() as MobData
	mob_data.hp = hp_value
	mob_data.speed_milli_per_tick = speed
	for index: int in 12:
		field.schedule_spawn(MobState.create(mob_data), index * interval)
	field.start_wave()
	for tick_index: int in 800:
		field.tick()
		if field.is_wave_done():
			break
	return field.pending_kill_gold
