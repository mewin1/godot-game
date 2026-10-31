extends SceneTree
## Изолированный опыт прицеливания зачинщиков. Активные правила не меняются.


func _initialize() -> void:
	var original: GameConfig = load("res://data/game_config.tres") as GameConfig
	var rows: Array[Dictionary] = []
	for ids: Array in [["water", "hex", "hex", "hex"],
			["water", "spark", "spark", "spark"], ["water", "rime", "war_engine", "bolt"]]:
		var layout: FieldState = FieldState.new(original, 2, 0)
		var brain: BotBrain = BotBrain.new(0)
		for value: Variant in ids:
			var id: String = value
			var data: TowerData = load("res://data/towers/%s.tres" % id) as TowerData
			var spot: Vector3i = brain.find_best_spot(layout, data)
			assert(spot.z >= 0)
			layout.add_tower(data, Vector2i(spot.x, spot.y), spot.z)
		for scenario: Array in [[60, 75, 6], [120, 75, 6], [240, 150, 20]]:
			for seed_value: int in [19, 81, 419]:
				rows.append({"towers": ids, "scenario": scenario, "seed": seed_value,
						"current": _fight(original, layout.towers, scenario, seed_value, false),
						"prepare": _fight(original, layout.towers, scenario, seed_value, true)})
	var file: FileAccess = FileAccess.open("res://.godot/preparation-target.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	print("TARGET: %d matched pairs; .godot/preparation-target.json" % rows.size())
	quit()


func _fight(config: GameConfig, layout: Array[TowerState], scenario: Array,
		seed_value: int, use_preparation: bool) -> Dictionary:
	var field: FieldState = PreparationField.new(config, 2, seed_value) if use_preparation \
			else FieldState.new(config, 2, seed_value)
	for tower: TowerState in layout:
		field.add_tower(tower.data, tower.anchor, tower.rotation)
	var data: MobData = config.wave_mob.duplicate() as MobData
	data.hp = scenario[0]
	data.speed_milli_per_tick = scenario[1]
	var interval: int = scenario[2]
	for index: int in 12:
		field.schedule_spawn(MobState.create(data), index * interval)
	field.start_wave()
	for index: int in 800:
		field.tick()
		if field.is_wave_done():
			break
	var damage: int = 0
	for amount: int in field.battle_report.damage_by_kind.values():
		damage += amount
	return {"damage": damage, "killed": field.battle_report.killed,
			"transfers": field.battle_report.curse_transfers, "reactions": field.reaction_counts}


class PreparationField extends FieldState:
	func _target_priority(tower: TowerState, mob: MobState) -> int:
		if tower.data.god != &"water" and tower.data.god != &"curse":
			return super._target_priority(tower, mob)
		if mob.progress >= get_path_end_progress() - config.reaction_target_emergency_milli:
			return 2
		if mob.shield_left > 0:
			return 0
		var is_fresh: bool = mob.wet_ticks_left <= 0 if tower.data.god == &"water" \
				else mob.curse_ticks_left <= 0
		return 1 if is_fresh else 0
