extends GutTest
## Настоящий бой в отдельной песочнице: воспроизводимость, конфигурация и порядок реакций.

var _sandbox: CombatSandbox


func before_each() -> void:
	_sandbox = CombatSandbox.new(load("res://data/game_config.tres") as GameConfig)


func test_reset_restores_units_upgrades_and_rng_without_mutating_resources() -> void:
	var tower: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
	tower.tower = load("res://data/towers/spark.tres") as TowerData
	tower.cell = Vector2i(2, 5)
	tower.level = 3
	tower.enchantment = RiteData.Effect.ENCHANT_DAMAGE
	assert_eq(_sandbox.execute(tower), "")
	var mob: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
	mob.mob = _sandbox.config.army_mob
	mob.hp = 1000
	mob.progress = 3000
	assert_eq(_sandbox.execute(mob), "")
	var original_hp: int = mob.mob.hp
	var before: StateHasher = StateHasher.new()
	_sandbox.field.add_to_hash(before)
	var step: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STEP)
	step.ticks = 40
	_sandbox.execute(step)
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
	var after: StateHasher = StateHasher.new()
	_sandbox.field.add_to_hash(after)
	assert_eq(before.value, after.value)
	assert_eq(mob.mob.hp, original_hp)
	assert_eq(_sandbox.field.mobs[0].hp, 1000)
	assert_eq(_sandbox.field.mobs[0].speed, 0)
	assert_eq(_sandbox.field.towers[0].enchantment, int(RiteData.Effect.ENCHANT_DAMAGE))


func test_manual_hits_and_time_without_auto_fire_transfer_curse_to_wet_neighbor() -> void:
	for id: StringName in [&"water", &"hex"]:
		var tower: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
		tower.tower = load("res://data/towers/%s.tres" % id) as TowerData
		tower.cell = Vector2i(2, 5) if id == &"water" else Vector2i(0, 5)
		assert_eq(_sandbox.execute(tower), "")
	for index: int in 2:
		var mob: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
		mob.mob = _sandbox.config.training_mob
		mob.progress = 3000 + index * 500
		_sandbox.execute(mob)
	var hit: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STRIKE)
	hit.tower_id = 1
	for id: int in [1, 2]:
		hit.mob_id = id
		assert_eq(_sandbox.execute(hit), "")
	hit.tower_id = 2
	hit.mob_id = 1
	assert_eq(_sandbox.execute(hit), "")
	assert_true(_sandbox.find_mob(1).is_contagious)
	assert_eq(_sandbox.field.battle_report.curse_transfers, 0)
	var step: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STEP)
	step.ticks = 60
	step.automatic_fire = false
	_sandbox.execute(step)
	assert_gt(_sandbox.find_mob(2).curse_ticks_left, 0)
	assert_true(_sandbox.find_mob(2).is_contagious)
	assert_eq(_sandbox.field.battle_report.curse_transfers, 1)
	assert_lt(_sandbox.find_mob(1).hp, _sandbox.find_mob(1).max_hp)
	assert_true("\n".join(_sandbox.journal).contains("Перенос проклятия #1 → #2"))


func test_invalid_placement_does_not_add_tower_and_clear_removes_blueprints() -> void:
	var tower: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
	tower.tower = _sandbox.config.towers[0]
	tower.cell = Vector2i(-9, -9)
	assert_ne(_sandbox.execute(tower), "")
	assert_true(_sandbox.field.towers.is_empty())
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.CLEAR))
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
	assert_true(_sandbox.field.towers.is_empty())
	assert_true(_sandbox.field.mobs.is_empty())


func test_move_and_rotate_survive_restart_without_changing_tower_count() -> void:
	var add: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
	add.tower = load("res://data/towers/hex.tres") as TowerData
	add.cell = Vector2i(2, 5)
	assert_eq(_sandbox.execute(add), "")
	var move: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOVE)
	move.tower_id = _sandbox.field.towers[0].id
	move.cell = Vector2i(2, 4)
	move.rotation = 1
	assert_eq(_sandbox.execute(move), "")
	var rotate: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.ROTATE)
	rotate.tower_id = move.tower_id
	assert_eq(_sandbox.execute(rotate), "")
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
	assert_eq(_sandbox.field.towers.size(), 1)
	assert_eq(_sandbox.field.towers[0].anchor, Vector2i(2, 4))
	assert_eq(_sandbox.field.towers[0].rotation, 2)


func test_remove_mob_updates_restart_setup_and_stops_at_zero() -> void:
	var add: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
	add.mob = _sandbox.config.training_mob
	_sandbox.execute(add)
	_sandbox.execute(add)
	assert_eq(_sandbox.mob_count(), 2)
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.REMOVE_MOB))
	assert_eq(_sandbox.mob_count(), 1)
	assert_eq(_sandbox.field.mobs.size(), 1)
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.REMOVE_MOB))
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.REMOVE_MOB))
	_sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
	assert_eq(_sandbox.mob_count(), 0)
	assert_true(_sandbox.field.mobs.is_empty())
