extends SceneTree
## Равные вложения и площадь: желоб ур.2 против двух Искровиков ур.1.
## Общая основа — четыре Искровика ур.2 и три Грозовых столба ур.1, магазин 3.
## Контролируемые пачки проверяют роль сочетания; это не прогноз целого матча.

const SEEDS: Array[int] = [1401, 1402, 1403, 1404]
const CASES: Array[StringName] = [&"dense", &"shielded", &"sparse_fast"]


func _initialize() -> void:
	for hp: int in [300, 600, 1000]:
		for case_id: StringName in CASES:
			for wet: bool in [false, true]:
				var results: Array[Dictionary] = []
				for seed_value: int in SEEDS:
					results.append(_run(case_id, wet, seed_value, hp))
				print(JSON.stringify({"case": case_id, "hp": hp,
						"water": wet, "results": results}))
	quit()


func _run(case_id: StringName, wet: bool, seed_value: int, hp: int) -> Dictionary:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var field: FieldState = FieldState.new(config, 3, seed_value)
	var brain: BotBrain = BotBrain.new(0)
	for i: int in 4:
		_place(field, brain, &"spark", 2)
	for i: int in 3:
		_place(field, brain, &"thunder", 1)
	if wet:
		_place(field, brain, &"water", 2)
	else:
		for i: int in 2:
			_place(field, brain, &"spark", 1)
	_schedule_pack(field, case_id, hp)
	var result: Dictionary = _fight(field)
	result["seed"] = seed_value
	var invested: int = 0
	var cells: int = 0
	for tower: TowerState in field.towers:
		invested += tower.invested_total
		cells += tower.data.shape.size()
	result["invested"] = invested
	result["cells"] = cells
	return result


func _schedule_pack(field: FieldState, case_id: StringName, hp: int) -> void:
	var count: int = 8 if case_id == &"sparse_fast" else 24
	var interval: int = 28 if case_id == &"sparse_fast" else 8
	var mob_id: String = "knight" if case_id == &"shielded" else "send_unit"
	var data: MobData = load("res://data/mobs/%s.tres" % mob_id) as MobData
	for i: int in count:
		var mob: MobState = MobState.create(data)
		mob.max_hp = hp
		mob.hp = mob.max_hp
		mob.speed = 90 if case_id == &"sparse_fast" else 50
		field.schedule_spawn(mob, i * interval)


func _fight(field: FieldState) -> Dictionary:
	field.start_wave()
	var breaches: int = 0
	var remaining_hp: int = 0
	var config: GameConfig = field.config
	for real_tick: int in range(1, config.battle_real_ticks + 1):
		var speed: int = 1
		for threshold: int in config.battle_speed_thresholds:
			if real_tick > threshold:
				speed = config.battle_speeds[config.battle_speed_thresholds.find(threshold) + 1]
		for substep: int in speed:
			field.tick()
			breaches += field.pending_breaches.size()
			for mob: MobState in field.pending_breaches:
				remaining_hp += maxi(0, mob.hp)
			field.clear_pending()
		if field.is_wave_done():
			return {"breaches": breaches, "real_tick": real_tick, "remaining_hp": remaining_hp}
	return {"breaches": breaches, "retreat": field.count_alive_mobs()}


func _place(field: FieldState, brain: BotBrain, id_value: StringName, level: int) -> void:
	for data: TowerData in field.config.towers:
		if data.id != id_value:
			continue
		var spot: Vector3i = brain.find_best_spot(field, data)
		assert(spot.z >= 0, "Контрольная сборка должна помещаться на поле")
		var tower: TowerState = field.add_tower(data, Vector2i(spot.x, spot.y), spot.z)
		tower.level = level
		tower.invested_total = field.config.tower_cost * (1 << (level - 1))
		return
	assert(false, "Нет постройки: %s" % id_value)
