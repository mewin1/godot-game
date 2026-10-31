extends SceneTree
## Парный опыт: одинаковые башни/площадь/цели/сиды, меняется только одна реакция.

const SEEDS: Array[int] = [19, 81, 419]
const CASES: Dictionary[StringName, Array] = {
	&"steam": ["water", "brazier", "brazier", "brazier"],
	&"roast": ["brazier", "spark", "brazier", "spark"],
	&"melt": ["brazier", "rime", "brazier", "rime"],
	&"freeze": ["water", "rime", "rime", "rime"],
	&"chain": ["water", "spark", "spark", "spark"],
	&"infection": ["water", "hex", "hex", "hex"],
	&"conservation": ["hex", "rime", "hex", "rime"],
	&"shatter": ["water", "rime", "war_engine", "bolt"],
	&"execute": ["hex", "spark", "war_engine", "bolt"],
	&"surge": ["water", "wind", "bolt", "bolt"],
	&"wildfire": ["brazier", "wind", "brazier", "brazier"],
	&"blizzard": ["rime", "wind", "bolt", "bolt"],
}
const SCENARIOS: Dictionary[StringName, Array] = {
	&"stationary": [2000000, 0, 3, 0, 240],
	&"dense": [120, 75, 12, 6, 800],
	&"fast": [240, 150, 8, 20, 800],
	&"sparse": [80, 100, 8, 40, 800],
}


func _initialize() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var rows: Array[Dictionary] = []
	for reaction: StringName in CASES:
		var layout: Array[TowerState] = _layout(config, CASES[reaction])
		for scenario: StringName in SCENARIOS:
			for seed_value: int in SEEDS:
				var with_rule: Dictionary = _fight(config, layout, SCENARIOS[scenario],
						seed_value, &"")
				var without: Dictionary = _fight(config, layout, SCENARIOS[scenario],
						seed_value, reaction)
				rows.append({"reaction": reaction, "scenario": scenario, "seed": seed_value,
						"with": with_rule, "without": without})
	var file: FileAccess = FileAccess.open("res://.godot/reaction-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seeds": SEEDS, "scenarios": SCENARIOS,
			"cases": CASES, "rows": rows}, "\t"))
	print("AUDIT: %d matched pairs; .godot/reaction-audit.json" % rows.size())
	quit()


func _layout(config: GameConfig, ids: Array) -> Array[TowerState]:
	var field: FieldState = FieldState.new(config, 2, 0)
	var brain: BotBrain = BotBrain.new(0)
	for value: Variant in ids:
		var id: String = value
		var data: TowerData = load("res://data/towers/%s.tres" % id) as TowerData
		var spot: Vector3i = brain.find_best_spot(field, data)
		assert(spot.z >= 0)
		field.add_tower(data, Vector2i(spot.x, spot.y), spot.z)
	return field.towers


func _fight(original: GameConfig, layout: Array[TowerState], scenario: Array,
		seed_value: int, disabled: StringName) -> Dictionary:
	var config: GameConfig = original.duplicate() as GameConfig
	var rules: Array[ReactionData] = []
	for rule: ReactionData in original.reactions:
		if rule.id != disabled:
			rules.append(rule)
	config.reactions = rules
	if disabled == &"chain":
		# Иначе исторический fallback сохраняет водный шанс даже без ресурса Цепи.
		config.wet_chain_chance_percent = config.chain_chance_percent
	var field: FieldState = FieldState.new(config, 2, seed_value)
	for tower: TowerState in layout:
		field.add_tower(tower.data, tower.anchor, tower.rotation)
	var data: MobData = original.wave_mob.duplicate() as MobData
	data.hp = scenario[0]
	data.speed_milli_per_tick = scenario[1]
	var count: int = scenario[2]
	var interval: int = scenario[3]
	var limit: int = scenario[4]
	for index: int in count:
		field.schedule_spawn(MobState.create(data), index * interval)
	field.start_wave()
	if data.speed_milli_per_tick == 0:
		field._spawn_due_mobs()
		for index: int in field.mobs.size():
			field.mobs[index].progress = 6000 + index * 250
	for index: int in limit:
		field.tick()
		if field.is_wave_done():
			break
	var damage: int = 0
	for value: int in field.battle_report.damage_by_kind.values():
		damage += value
	var breached: int = 0
	for value: int in field.battle_report.breach_counts.values():
		breached += value
	return {"damage": damage, "killed": field.battle_report.killed, "breached": breached,
			"remaining": field.count_remaining_mobs(), "reactions": field.reaction_counts,
			"curse_transfers": field.battle_report.curse_transfers}
