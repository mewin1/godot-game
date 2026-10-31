extends SceneTree
## Локальные варианты Заразы. Активные ресурсы не изменяются; это не баланс матчей.

var _field: FieldState


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for variant: StringName in [&"current", &"water_plus_1sec", &"transfer_on_death"]:
		for water_lead: int in [0, 1, 20, 40, 60]:
			for kill_carrier: bool in [false, true]:
				rows.append(_run(variant, water_lead, kill_carrier))
	var file: FileAccess = FileAccess.open("res://.godot/infection-timing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	print("INFECTION: %d timing/death controls; .godot/infection-timing.json" % rows.size())
	quit()


func _run(variant: StringName, water_lead: int, kill_carrier: bool) -> Dictionary:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sandbox: CombatSandbox = CombatSandbox.new(config)
	for id: StringName in [&"water", &"hex"]:
		var tower: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
		tower.tower = load("res://data/towers/%s.tres" % id) as TowerData
		if variant == &"water_plus_1sec" and id == &"water":
			tower.tower = tower.tower.duplicate() as TowerData
			tower.tower.wet_ticks += config.ticks_per_second
		tower.cell = Vector2i(2, 5) if id == &"water" else Vector2i(0, 5)
		assert(sandbox.execute(tower) == "")
	for index: int in 2:
		var mob: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
		mob.mob = config.training_mob
		mob.progress = 3000 + index * 500
		assert(sandbox.execute(mob) == "")
	_field = sandbox.field
	if variant == &"transfer_on_death":
		_field.mob_killed.connect(_experimental_death_transfer)
	var hit: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STRIKE)
	hit.tower_id = 1
	hit.mob_id = 1
	assert(sandbox.execute(hit) == "")
	var step: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STEP)
	step.automatic_fire = false
	step.ticks = water_lead
	assert(sandbox.execute(step) == "")
	hit.tower_id = 2
	assert(sandbox.execute(hit) == "")
	step.ticks = 20
	assert(sandbox.execute(step) == "")
	if kill_carrier:
		_field.deal_mob_damage(sandbox.find_mob(1), config.training_mob.hp)
	step.ticks = 100
	assert(sandbox.execute(step) == "")
	var neighbor: MobState = sandbox.find_mob(2)
	return {"variant": variant, "water_lead_ticks": water_lead,
			"carrier_killed_early": kill_carrier,
			"neighbor_damage": neighbor.max_hp - neighbor.hp,
			"burst_transfers": _field.battle_report.curse_transfers}


func _experimental_death_transfer(source: MobState) -> void:
	if not source.is_contagious or source.curse_ticks_left <= 0:
		return
	var target: MobState = CurseCombat.find_wet_neighbor(_field, source)
	if target == null:
		return
	# Только опыт: переносим оставшийся заряд, не взрываем его ещё раз на мёртвом носителе.
	target.remove_status(&"wet")
	target.curse_damage = maxi(target.curse_damage, source.curse_damage)
	if target.curse_ticks_left <= 0:
		target.curse_ticks_left = source.curse_ticks_left
		target.curse_delay = source.curse_delay
	target.is_contagious = true
