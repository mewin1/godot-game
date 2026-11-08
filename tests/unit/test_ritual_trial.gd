extends GutTest
## Контракт отдельного сценария и пограничные случаи повторной критики.

var _settings: RitualTrialConfig
var _trial: RitualTrial


func before_each() -> void:
	_settings = load("res://data/ritual/trial.tres") as RitualTrialConfig
	_trial = RitualTrial.new(_settings, 3)


func _start() -> void:
	if _trial.phase == RitualTrial.Phase.PREP:
		assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.START)), "")
	_trial.next_spawn = _settings.spawns.size()


func _steps(count: int) -> void:
	for index: int in count:
		_trial.tick()


func _tower(index: int) -> TowerState:
	var tower: TowerState = TowerState.new()
	tower.id = 100 + index
	tower.data = _settings.combat.towers[index]
	return tower


func test_loadouts_preserve_budget_ids_and_geometry() -> void:
	var indices: Array[int] = [0, 1, 2, 4, 5]
	var gold_expected: Array[int] = [0, 0, 2, 18, 20]
	for index: int in indices:
		var trial: RitualTrial = RitualTrial.new(_settings, index)
		assert_eq(trial.gold, gold_expected[indices.find(index)])
		var occupied: Dictionary[Vector2i, bool] = {}
		for i: int in trial.field.towers.size():
			var tower: TowerState = trial.field.towers[i]
			assert_eq(tower.id, i + 1)
			for cell: Vector2i in tower.cells():
				assert_true(trial.field.is_buildable(cell))
				assert_false(occupied.has(cell))
				occupied[cell] = true
	assert_eq(_trial.field.get_path_end_progress(), 57000)


func test_schedule_rewards_and_same_time_spawn_order() -> void:
	var rewards: Array[int] = [0, 0, 0, 0]
	for spawn: RitualSpawn in _settings.spawns:
		rewards[spawn.at_tick / _settings.cycle_ticks] += _settings.enemies[spawn.mob_index].kill_reward
	assert_eq(rewards, [44, 58, 66, 74])
	var simultaneous: Array[int] = []
	for spawn: RitualSpawn in _settings.spawns:
		if spawn.at_tick == 6400:
			simultaneous.append(spawn.mob_index)
	assert_eq(simultaneous, [3, 5])


func test_aura_uses_fractional_remainder_and_dawn_removes_only_speed() -> void:
	var mob: RitualMob = _trial.field.spawn_mob(0)
	mob.aura_percent = 125
	for i: int in 20:
		mob.advance()
	assert_eq(mob.progress, 1250)
	mob.ward_hp = 37
	mob.hp = 42
	_trial.field.prepare_tick(1800)
	assert_eq(mob.aura_percent, 100)
	assert_eq(mob.hp, 42)
	assert_eq(mob.ward_hp, 37)


func test_ward_blocks_body_marks_and_ice_but_fire_and_physical_chip() -> void:
	var mob: RitualMob = _trial.field.spawn_mob(3)
	_trial.field._hit(mob, 8, _tower(1).data, _tower(1))
	assert_eq(mob.ward_hp, 104)
	assert_eq(mob.hp, 450)
	assert_eq(mob.burn_ticks_left, 0)
	_trial.field._hit(mob, 18, _tower(0).data, _tower(0))
	assert_eq(mob.ward_hp, 100)
	_trial.field._hit(mob, 8, _tower(5).data, _tower(5))
	assert_eq(mob.ward_hp, 100)
	assert_eq(mob.cold_ticks_left, 0)
	_trial.field._hit(mob, 0, _tower(4).data, _tower(4))
	assert_eq(mob.wet_ticks_left, 0)


func test_ward_break_has_no_overflow_or_reward_and_kill_pays_once() -> void:
	var mob: RitualMob = _trial.field.spawn_mob(3)
	mob.ward_hp = 1
	_trial.field._hit(mob, 30, _tower(2).data, _tower(2))
	assert_eq(mob.hp, 450)
	assert_eq(mob.stun_ticks_left, 20)
	assert_eq(_trial.earned, 0)
	_trial.field.deal_mob_damage(mob, 500)
	_trial.field.deal_mob_damage(mob, 500)
	assert_eq(_trial.earned, 6)


func test_hero_uses_body_hp_then_ward_and_never_interrupts_boss() -> void:
	_start()
	var shielded: RitualMob = _trial.field.spawn_mob(3)
	assert_eq(_trial.hero_damage(shielded), 50)
	var boss: RitualMob = _trial.field.spawn_mob(5)
	boss.progress = 10000
	boss.boss_phase = RitualMob.BossPhase.RUSH
	assert_eq(_trial.hero_damage(boss), 500)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0,
		Vector2i.ZERO, 0, 0, 10000)), "")
	assert_eq(_trial.hero_ready, 900)
	_trial.hero_due = 0
	_trial._resolve_hero()
	assert_eq(boss.hp, 1300)
	assert_eq(boss.boss_phase, RitualMob.BossPhase.RUSH)


func test_banner_protects_other_bodies_not_self_or_ward() -> void:
	var banner: RitualMob = _trial.field.spawn_mob(4)
	var mob: RitualMob = _trial.field.spawn_mob(0)
	assert_eq(_trial.field.body_damage(mob, 100), 70)
	assert_eq(_trial.field.body_damage(banner, 100), 100)
	_trial.field.deal_mob_damage(banner, 200)
	assert_eq(_trial.field.body_damage(mob, 100), 100)


func test_freeze_interrupt_is_preserved_but_subsequent_shatter_stun_is_blocked() -> void:
	var boss: RitualMob = _trial.field.spawn_mob(5)
	boss.boss_phase = RitualMob.BossPhase.RUSH
	boss.wet_ticks_left = 60
	_trial.field._hit(boss, 8, _tower(5).data, _tower(5))
	assert_eq(boss.boss_phase, RitualMob.BossPhase.SPENT)
	assert_eq(boss.freeze_ticks_left, 30)
	assert_eq(boss.immune_until, 160)
	_trial.field._hit(boss, 18, _tower(0).data, _tower(0))
	assert_eq(boss.freeze_ticks_left, 0, "Раскол потребляет заморозку")
	assert_eq(boss.stun_ticks_left, 0, "Новый стан не обходит иммунитет")
	boss.wet_ticks_left = 60
	_trial.field._hit(boss, 8, _tower(5).data, _tower(5))
	assert_eq(boss.freeze_ticks_left, 0)


func test_palisade_is_consumed_without_stopping_immune_boss() -> void:
	var boss: RitualMob = _trial.field.spawn_mob(5)
	boss.boss_phase = RitualMob.BossPhase.SPENT
	boss.immune_until = 160
	boss.previous_progress = 4900
	boss.progress = 5100
	_trial.palisade_progress = 5000
	_trial.palisade_ready = 0
	_trial._on_mob_moved(boss)
	assert_eq(_trial.palisade_progress, -1)
	assert_eq(boss.progress, 5100)
	assert_eq(boss.stun_ticks_left, 0)


func test_palisade_stops_warded_body_and_before_path_end_breach() -> void:
	_start()
	var mob: RitualMob = _trial.field.spawn_mob(3)
	mob.progress = 56990
	_trial.palisade_progress = 56995
	_trial.palisade_ready = 0
	_trial.field.finish_tick()
	assert_eq(mob.progress, 56995)
	assert_eq(mob.stun_ticks_left, 60)
	assert_false(mob.is_breached)
	assert_eq(_trial.hp, 50)


func test_boss_warning_and_rush_follow_exact_fixed_time() -> void:
	_start()
	_trial.tick_count = 6400
	var boss: RitualMob = _trial.field.spawn_mob(5)
	_steps(192)
	assert_eq(boss.progress, 12000)
	_trial.tick()
	assert_eq(boss.boss_phase, RitualMob.BossPhase.WARNING)
	assert_eq(boss.warning_until, 6632)
	_steps(39)
	assert_eq(boss.progress, 12000)
	_steps(64)
	assert_eq(boss.progress, 32000)
	assert_eq(boss.boss_phase, RitualMob.BossPhase.SPENT)


func test_invalid_commands_do_not_spend_gold_or_skill() -> void:
	var before: int = _trial.gold
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(1, 2))), "")
	assert_eq(_trial.gold, before)
	_start()
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0,
		Vector2i.ZERO, 0, 0, 58000)), "")
	assert_eq(_trial.hero_ready, 0)


func test_move_keeps_cooldown_reserves_destination_and_costs_time() -> void:
	_trial = RitualTrial.new(_settings, 0)
	_start()
	var tower: TowerState = _trial.field.towers[0]
	tower.cooldown_left = 13
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0,
		Vector2i(9, 8), 0, tower.id)), "")
	assert_eq(tower.cooldown_left, 13)
	assert_true(tower.is_action_blocked())
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(9, 8))), "")
	_steps(60)
	assert_true(tower.is_action_blocked())
	_trial.tick()
	assert_false(tower.is_action_blocked())
	assert_eq(tower.id, 1)


func test_cancel_move_does_not_return_instant_fire() -> void:
	_trial = RitualTrial.new(_settings, 0)
	_start()
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, Vector2i(9, 8), 0, 1)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.CANCEL_MOVE, 0,
		Vector2i.ZERO, 0, 1)), "")
	assert_eq(_trial.field.get_tower(1).anchor, Vector2i(10, 3))
	assert_true(_trial.field.get_tower(1).is_action_blocked())


func test_snapshot_copies_pending_actions_and_continuation_deterministically() -> void:
	_trial = RitualTrial.new(_settings, 0)
	_start()
	_trial.palisades = 1
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, Vector2i(9, 8), 0, 1)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0,
		Vector2i.ZERO, 0, 0, 10000)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, 0,
		Vector2i.ZERO, 0, 0, 20000)), "")
	var boss: RitualMob = _trial.field.spawn_mob(5)
	boss.progress = 10000
	_steps(5)
	var expected_saved_size: int = _trial.journal.size()
	var state: Dictionary = _trial.snapshot()
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, state)
	assert_not_null(copy)
	assert_eq(copy.state_hash(), _trial.state_hash())
	for index: int in 100:
		_trial.tick()
		copy.tick()
	assert_eq(copy.state_hash(), _trial.state_hash())
	copy.journal.append({"branch_only": true})
	assert_ne(copy.journal.size(), _trial.journal.size())
	var saved_trial: Dictionary = state["trial"]
	var saved_journal: Array = saved_trial["journal"]
	assert_eq(saved_journal.size(), expected_saved_size)


func test_dawn_snapshot_does_not_repeat_grant_or_spawn_event() -> void:
	_start()
	_trial.tick_count = 1799
	_trial.last_dawn = 0
	_trial.tick()
	assert_eq(_trial.palisades, 1)
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, _trial.snapshot())
	copy.tick()
	assert_eq(copy.palisades, 1)
	assert_eq(copy.dawns.size(), 1)
	var filled: RitualTrial = RitualTrial.new(_settings, 4)
	assert_eq(filled.palisades, 1)
	assert_eq(filled.field.towers[5].wind_cycle_ticks, 40)
	assert_eq(filled.phase, RitualTrial.Phase.RUNNING)
	filled.tick()
	assert_eq(filled.field.mobs.size(), 1)
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, filled.snapshot())
	restored.tick()
	assert_eq(restored.field.mobs.size(), 1)


func test_control_branches_restrict_commands_but_keep_prepared_palisade() -> void:
	_trial = RitualTrial.new(_settings, 4)
	_start()
	_trial.palisade_progress = 5000
	_trial.palisade_ready = _trial.tick_count
	var passive: RitualTrial = _trial.fork_control(RitualTrial.ControlMode.PASSIVE)
	assert_eq(passive.palisade_progress, 5000)
	assert_ne(passive.execute(RitualCommand.new(RitualCommand.Action.SKILL)), "")
	var abilities: RitualTrial = _trial.fork_control(RitualTrial.ControlMode.ABILITIES)
	assert_ne(abilities.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, Vector2i(9, 8), 0, 1)), "")
	assert_ne(abilities.execute(RitualCommand.new(RitualCommand.Action.SELL, 0,
		Vector2i.ZERO, 0, 1)), "")
	assert_eq(abilities.execute(RitualCommand.new(RitualCommand.Action.SKILL)), "")


func test_same_commands_produce_same_hash_and_mode_does_not_touch_main_config() -> void:
	var main: GameConfig = load("res://data/game_config.tres") as GameConfig
	var old_board: BoardLayout = main.board
	var old_cost: int = main.tower_cost
	var a: RitualTrial = RitualTrial.new(_settings, 1)
	var b: RitualTrial = RitualTrial.new(_settings, 1)
	assert_eq(a.execute(RitualCommand.new(RitualCommand.Action.START)), "")
	assert_eq(b.execute(RitualCommand.new(RitualCommand.Action.START)), "")
	for index: int in 200:
		a.tick()
		b.tick()
	assert_eq(a.state_hash(), b.state_hash())
	assert_same(main.board, old_board)
	assert_eq(main.tower_cost, old_cost)


func test_expired_immunity_accepts_new_freeze_without_rearming_rush() -> void:
	var boss: RitualMob = _trial.field.spawn_mob(5)
	boss.boss_phase = RitualMob.BossPhase.SPENT
	boss.immune_until = 160
	boss.clock_tick = 160
	_trial.field.wave_tick = 160
	boss.wet_ticks_left = 60
	_trial.field._hit(boss, 8, _tower(5).data, _tower(5))
	assert_eq(boss.freeze_ticks_left, 30)
	assert_eq(boss.boss_phase, RitualMob.BossPhase.SPENT)
	assert_eq(boss.immune_until, 160)


func test_passive_branch_finishes_pending_hero_without_new_order() -> void:
	_start()
	_trial.hero_progress = 10000
	_trial.hero_due = 1
	_trial.hero_ready = 900
	var mob: RitualMob = _trial.field.spawn_mob(2)
	mob.progress = 10000
	var branch: RitualTrial = _trial.fork_control(RitualTrial.ControlMode.PASSIVE)
	branch.tick()
	branch.tick()
	assert_lt(branch.field.mobs[0].hp, mob.hp)
	assert_eq(branch.hero_due, -1)
	assert_eq(_trial.hero_due, 1)


func test_rules_change_rejects_checkpoint_and_branch_mutations_are_independent() -> void:
	var state: Dictionary = _trial.snapshot()
	var modified: RitualTrialConfig = _settings.duplicate() as RitualTrialConfig
	modified.hero_cooldown += 1
	assert_null(RitualTrial.from_snapshot(modified, state))
	assert_null(RitualTrial.from_snapshot(_settings, {"version": 1}))
	var first: RitualTrial = RitualTrial.from_snapshot(_settings, state)
	var second: RitualTrial = RitualTrial.from_snapshot(_settings, state)
	first.commands.append({"only_first": true})
	assert_eq(second.commands.size(), 0)


func test_filled_start_has_no_free_preparation_window() -> void:
	_trial = RitualTrial.new(_settings, 4)
	assert_eq(_trial.phase, RitualTrial.Phase.RUNNING)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0,
		Vector2i(9, 8), 0, 1)), "")
	assert_true(_trial.field.get_tower(1).is_action_blocked())
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.SELL, 0,
		Vector2i.ZERO, 0, 2)), "")
	assert_eq(_trial.gold, 24, "Продажа даёт 6, а не полный возврат 12")


func _burn_at_banner_boundary(banner_first: bool, banner_position: int, victim_position: int) -> int:
	var trial: RitualTrial = RitualTrial.new(_settings, 3)
	var first: RitualMob = trial.field.spawn_mob(4 if banner_first else 0)
	var second: RitualMob = trial.field.spawn_mob(0 if banner_first else 4)
	var banner: RitualMob = first if banner_first else second
	var victim: RitualMob = second if banner_first else first
	banner.progress = banner_position
	victim.progress = victim_position
	victim.burn_damage = 10
	victim.burn_ticks_left = 20
	victim.burn_cooldown = 0
	trial.field.finish_tick()
	return victim.max_hp - victim.hp


func test_periodic_damage_uses_pre_movement_banner_positions_for_all_ids() -> void:
	assert_eq(_burn_at_banner_boundary(true, 0, 4001), 10)
	assert_eq(_burn_at_banner_boundary(false, 0, 4001), 10)
	assert_eq(_burn_at_banner_boundary(true, 3990, 0), 7)
	assert_eq(_burn_at_banner_boundary(false, 3990, 0), 7)


func test_palisade_chooses_first_crossing_fraction_not_spawn_order() -> void:
	var heavy: RitualMob = _trial.field.spawn_mob(2)
	var boss: RitualMob = _trial.field.spawn_mob(5)
	heavy.progress = 4990
	boss.progress = 4999
	boss.boss_phase = RitualMob.BossPhase.RUSH
	_trial.palisade_progress = 5000
	_trial.palisade_ready = 0
	_trial.field.finish_tick()
	assert_eq(boss.progress, 5000)
	assert_eq(boss.stun_ticks_left, 60)
	assert_eq(boss.boss_phase, RitualMob.BossPhase.SPENT)
	assert_eq(heavy.progress, 5030)
	assert_eq(heavy.stun_ticks_left, 0)


func test_equal_palisade_crossing_uses_stable_id_even_if_array_order_changes() -> void:
	var heavy: RitualMob = _trial.field.spawn_mob(2)
	var boss: RitualMob = _trial.field.spawn_mob(5)
	heavy.progress = 4996
	boss.progress = 4975
	boss.boss_phase = RitualMob.BossPhase.RUSH
	_trial.field.mobs.reverse()
	_trial.palisade_progress = 5000
	_trial.palisade_ready = 0
	_trial.field.finish_tick()
	assert_eq(heavy.progress, 5000)
	assert_eq(heavy.stun_ticks_left, 60)
	assert_eq(boss.stun_ticks_left, 0)


func test_dawn_records_idols_and_each_remaining_enemy_health() -> void:
	_trial = RitualTrial.new(_settings, 0)
	_start()
	var survivor: RitualMob = _trial.field.spawn_mob(3)
	survivor.hp = 317
	survivor.ward_hp = 83
	_trial.tick_count = 1799
	_trial.tick()
	var dawn: Dictionary = _trial.dawns[0]
	assert_has(dawn, "idols")
	assert_has(dawn, "remaining")
	if not dawn.has_all(["idols", "remaining"]):
		return
	var idols: Array = RitualStateCodec.array(dawn["idols"])
	assert_eq(idols.size(), 3)
	var idol: Dictionary = RitualStateCodec.dictionary(idols[0])
	assert_eq(RitualStateCodec.integer(idol["damage_percent"]), 10)
	var remaining: Array = RitualStateCodec.array(dawn["remaining"])
	var enemy: Dictionary = RitualStateCodec.dictionary(remaining[0])
	assert_eq(RitualStateCodec.integer(enemy["hp"]), 317)
	assert_eq(RitualStateCodec.integer(enemy["ward_hp"]), 83)


func _journal_entry(event: String, id: int) -> Dictionary:
	for entry: Dictionary in _trial.journal:
		if entry.get("event", "") == event and RitualStateCodec.integer(entry.get("mob", -1), -1) == id:
			return entry
	return {}


func test_damage_journal_identifies_banner_and_actual_body_or_ward_loss() -> void:
	_start()
	var shielded: RitualMob = _trial.field.spawn_mob(3)
	var victim: RitualMob = _trial.field.spawn_mob(0)
	var banner: RitualMob = _trial.field.spawn_mob(4)
	_trial.hero_due = 0
	_trial.hero_progress = 0
	_trial._resolve_hero()
	var hit: Dictionary = _journal_entry("hero_hit", shielded.id)
	assert_has(hit, "ward_damage")
	assert_has(hit, "hp_damage")
	if not hit.has_all(["ward_damage", "hp_damage"]):
		return
	assert_eq(RitualStateCodec.integer(hit["ward_damage"]), 50)
	assert_eq(RitualStateCodec.integer(hit["hp_damage"]), 0)
	var damage: Dictionary = _journal_entry("damage", victim.id)
	assert_has(damage, "protected_by")
	assert_has(damage, "hp_damage")
	if not damage.has_all(["protected_by", "hp_damage"]):
		return
	assert_eq(RitualStateCodec.array(damage["protected_by"]), [banner.id])
	assert_eq(RitualStateCodec.integer(damage["hp_damage"]), 21)
