extends GutTest
## Отчёт считает факты после защиты, не меняет исход и сохраняет отдельный снимок волны.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 3, 42)


func test_damage_excludes_shield_armor_overkill_and_repeated_death() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.hp = 10
	mob.armor = 3
	mob.shield_left = 1
	_field.deal_mob_damage(mob, 8, 7, &"hit")
	assert_true(_field.battle_report.damage_by_tower.is_empty())
	_field.deal_mob_damage(mob, 8, 7, &"hit")
	assert_eq(_field.battle_report.damage_by_tower[7], 5)
	_field.deal_mob_damage(mob, 100, 7, &"hit")
	_field.deal_mob_damage(mob, 100, 7, &"hit")
	assert_eq(_field.battle_report.damage_by_tower[7], 10)
	assert_eq(_field.battle_report.killed, 1)


func test_chain_is_credited_to_tower_and_damage_kinds_do_not_overlap() -> void:
	var config: GameConfig = _config.duplicate() as GameConfig
	config.chain_chance_percent = 100
	var field: FieldState = FieldState.new(config, 3, 42)
	var tower: TowerState = field.add_tower(config.towers[0], Vector2i.ZERO, 0)
	field.start_wave()
	for index: int in 2:
		var mob: MobState = MobState.create(config.wave_mob)
		mob.hp = 100
		mob.id = index + 1
		field.mobs.append(mob)
	DivineCombat.hit(field, tower, field.mobs[0], 10)
	assert_eq(field.battle_report.damage_by_tower[tower.id], 14)
	assert_eq(field.battle_report.damage_by_kind[&"hit"], 10)
	assert_eq(field.battle_report.damage_by_kind[&"chain"], 4)


func test_burn_and_curse_are_reported_separately_from_tower_hits() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.hp = 100
	mob.burn_ticks_left = 40
	mob.burn_damage = 7
	mob.curse_ticks_left = 1
	mob.curse_damage = 20
	DivineCombat.tick_effects(_field, mob)
	assert_eq(_field.battle_report.damage_by_kind[&"curse"], 20)
	assert_eq(_field.battle_report.damage_by_kind[&"burn"], 7)
	assert_true(_field.battle_report.damage_by_tower.is_empty())


func test_shield_and_full_status_slots_do_not_grant_support_credit() -> void:
	var water: TowerData = load("res://data/towers/water.tres") as TowerData
	var tower: TowerState = _field.add_tower(water, Vector2i.ZERO, 0)
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.shield_left = 1
	DivineCombat.hit(_field, tower, mob, 0)
	mob.charge_ticks_left = 60
	mob.curse_ticks_left = 60
	DivineCombat.hit(_field, tower, mob, 0)
	assert_true(_field.battle_report.marks_by_tower.is_empty())
	mob.remove_status(&"charge")
	DivineCombat.hit(_field, tower, mob, 0)
	assert_eq(_field.battle_report.marks_by_tower[tower.id], 1)
	assert_true(_field.battle_report.damage_by_tower.is_empty())


func test_report_reset_does_not_change_hash_or_mutate_previous_wave_snapshot() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	_field.deal_mob_damage(mob, 10, 7, &"hit")
	var previous: FieldBattleReport = _field.battle_report
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	_field.battle_report = FieldBattleReport.new()
	_field.battle_report.curse_transfers = 9
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_eq(before.value, after.value)
	assert_eq(previous.damage_by_tower[7], 10)
	var snapshot: Dictionary = previous.snapshot()
	previous.record_damage(7, &"hit", 5)
	var saved: Dictionary = snapshot["damage_by_tower"]
	var saved_damage: int = saved[7]
	assert_eq(saved_damage, 10)


func test_leaks_count_every_unit_but_hp_loss_matches_match_limit_and_remaining_hp() -> void:
	var config: GameConfig = _config.duplicate() as GameConfig
	var sim: MatchSim = MatchSim.new(config, 713, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	player.hero_hp = 3
	for index: int in 3:
		var mob: MobState = MobState.create(config.army_mob)
		mob.breach_damage = 5
		player.field._breach(mob)
		player.field.pending_breaches.clear()
		sim._apply_breach(player, mob)
	assert_eq(player.field.battle_report.breach_counts[config.army_mob.id], 3)
	assert_eq(player.field.battle_report.hp_lost, 3)
	assert_eq(player.field.battle_report.breach_hp[config.army_mob.id], 3)
	assert_eq(player.field.battle_report.hp_lost, player.hp_lost_this_round)


func test_retreat_counts_pending_units_without_reporting_breaches() -> void:
	_field.mobs.append(MobState.create(_config.wave_mob))
	_field.schedule_spawn(MobState.create(_config.wave_mob), 200)
	_field.retreat_remaining()
	assert_eq(_field.battle_report.retreated, 2)
	assert_true(_field.battle_report.breach_counts.is_empty())
