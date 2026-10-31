extends GutTest
## Направленность, поглощение, щит и предел статусов на активном конфиге.

var _config: GameConfig
var _field: FieldState
var _mob: MobState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 3, 81)
	_mob = MobState.create(_config.army_mob)
	_mob.hp = 1000
	_mob.max_hp = 1000
	_field.mobs.append(_mob)


func _tower(id_value: String) -> TowerState:
	return _field.add_tower(load("res://data/towers/%s.tres" % id_value) as TowerData,
			Vector2i(2, 4), 0)


func test_steam_consumes_water_and_fire_without_reignition() -> void:
	_mob.wet_ticks_left = 60
	_mob.burn_ticks_left = 60
	DivineCombat.hit(_field, _tower("brazier"), _mob, 100)
	assert_eq(_mob.hp, 875)
	assert_eq(_mob.status_tags().size(), 0)


func test_reverse_water_on_fire_does_not_trigger_steam() -> void:
	_mob.burn_ticks_left = 60
	DivineCombat.hit(_field, _tower("water"), _mob, 4)
	assert_eq(_mob.hp, 996)
	assert_eq(_mob.status_tags().size(), 2)


func test_roast_consumes_burn_and_stuns_for_four_ticks() -> void:
	_mob.burn_ticks_left = 60
	DivineCombat.hit(_field, _tower("spark"), _mob, 100)
	assert_eq(_mob.hp, 875)
	assert_eq(_mob.burn_ticks_left, 0)
	for i: int in 4:
		assert_eq(_mob.current_speed(), 0)
		_mob.advance()
	assert_gt(_mob.current_speed(), 0)


func test_shield_blocks_reaction_and_preserves_statuses() -> void:
	_mob.wet_ticks_left = 60
	_mob.shield_left = 1
	DivineCombat.hit(_field, _tower("brazier"), _mob, 100)
	assert_eq(_mob.hp, 1000)
	assert_eq(_mob.wet_ticks_left, 60)
	assert_eq(_mob.burn_ticks_left, 0)


func test_third_status_rejected_but_existing_refresh_allowed() -> void:
	_mob.wet_ticks_left = 60
	_mob.charge_ticks_left = 60
	assert_false(_mob.can_apply_status(&"burn"))
	assert_true(_mob.can_apply_status(&"wet"))
	DivineCombat.hit(_field, _tower("brazier"), _mob, 100)
	assert_eq(_mob.status_tags().size(), 1, "пар освобождает слот мокроты")


func test_reaction_death_rewards_once_and_stun_changes_hash() -> void:
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	_mob.stun_ticks_left = 4
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_ne(before.value, after.value)
	_mob.hp = 1
	_mob.wet_ticks_left = 60
	var tower: TowerState = _tower("brazier")
	DivineCombat.hit(_field, tower, _mob, 100)
	DivineCombat.hit(_field, tower, _mob, 100)
	assert_eq(_field.pending_kill_gold, _mob.kill_reward)


func test_ice_alone_slows_and_charge_coexists_without_reaction() -> void:
	_mob.charge_ticks_left = 60
	DivineCombat.hit(_field, _tower("rime"), _mob, 100)
	assert_eq(_mob.hp, 900)
	assert_eq(_mob.cold_ticks_left, 60)
	assert_eq(_mob.current_speed(), _mob.speed * 80 / 100)
	assert_eq(_mob.status_tags().size(), 2)


func test_wet_ice_freezes_then_physical_shatters() -> void:
	_mob.wet_ticks_left = 60
	DivineCombat.hit(_field, _tower("rime"), _mob, 100)
	assert_eq(_mob.wet_ticks_left, 0)
	assert_eq(_mob.freeze_ticks_left, 30)
	assert_eq(_mob.current_speed(), 0)
	DivineCombat.hit(_field, _tower("bolt"), _mob, 100)
	assert_eq(_mob.hp, 750)
	assert_eq(_mob.freeze_ticks_left, 0)
	assert_eq(_mob.stun_ticks_left, 8)


func test_melt_consumes_burn_and_cold_without_new_status() -> void:
	_mob.burn_ticks_left = 60
	_mob.cold_ticks_left = 60
	DivineCombat.hit(_field, _tower("rime"), _mob, 100)
	assert_eq(_mob.hp, 850)
	assert_eq(_mob.status_tags().size(), 0)


func test_physical_bridges_charge_and_cold_but_single_status_has_no_bonus() -> void:
	_mob.charge_ticks_left = 60
	var tower: TowerState = _tower("bolt")
	DivineCombat.hit(_field, tower, _mob, 100)
	assert_eq(_mob.hp, 900)
	_mob.cold_ticks_left = 60
	DivineCombat.hit(_field, tower, _mob, 100)
	assert_eq(_mob.hp, 760)


func test_frozen_refresh_does_not_use_third_slot() -> void:
	_mob.wet_ticks_left = 60
	_mob.charge_ticks_left = 60
	var tower: TowerState = _tower("rime")
	DivineCombat.hit(_field, tower, _mob, 100)
	DivineCombat.hit(_field, tower, _mob, 100)
	assert_eq(_mob.status_tags().size(), 2)
	assert_gt(_mob.freeze_ticks_left, 0)
	assert_gt(_mob.charge_ticks_left, 0)


func test_reactions_replay_with_same_seed_produces_same_hash() -> void:
	var other: FieldState = FieldState.new(_config, 3, 81)
	var target: MobState = MobState.create(_config.army_mob)
	target.hp = 1000
	target.max_hp = 1000
	other.mobs.append(target)
	for id_value: String in ["water", "rime", "bolt", "spark", "brazier"]:
		var tower: TowerState = _tower(id_value)
		var copy: TowerState = other.add_tower(tower.data, tower.anchor, 0)
		DivineCombat.hit(_field, tower, _mob, 25)
		DivineCombat.hit(other, copy, target, 25)
		var first: StateHasher = StateHasher.new()
		var second: StateHasher = StateHasher.new()
		_field.add_to_hash(first)
		other.add_to_hash(second)
		assert_eq(first.value, second.value)


func test_zero_damage_support_does_not_chip_armor_or_hp() -> void:
	_mob.take_damage(0)
	assert_eq(_mob.hp, 1000)
	_mob.armor = 100
	_mob.take_damage(0)
	assert_eq(_mob.hp, 1000)


func test_last_stun_tick_blocks_enraged_movement_too() -> void:
	_mob.progress = 3000
	_mob.stun_ticks_left = 1
	_field.is_enraged = true
	_field._move_mobs()
	assert_eq(_mob.progress, 3000)


func test_curse_explodes_on_deadline_and_repeated_hits_do_not_delay() -> void:
	var tower: TowerState = _tower("hex")
	DivineCombat.hit(_field, tower, _mob, 4)
	assert_eq(_mob.curse_ticks_left, 60)
	for i: int in 20:
		DivineCombat.tick_effects(_field, _mob)
	DivineCombat.hit(_field, tower, _mob, 4)
	assert_eq(_mob.curse_ticks_left, 40)
	for i: int in 39:
		DivineCombat.tick_effects(_field, _mob)
	assert_eq(_mob.hp, 992)
	DivineCombat.tick_effects(_field, _mob)
	assert_eq(_mob.hp, 984)
	assert_eq(_mob.curse_damage, 0)


func test_conservation_increases_delay_and_damage_only_once() -> void:
	DivineCombat.hit(_field, _tower("hex"), _mob, 4)
	var tower: TowerState = _tower("rime")
	DivineCombat.hit(_field, tower, _mob, 8)
	assert_eq(_mob.curse_ticks_left, 80)
	assert_eq(_mob.curse_damage, 12)
	DivineCombat.hit(_field, tower, _mob, 8)
	assert_eq(_mob.curse_ticks_left, 80)
	assert_eq(_mob.curse_damage, 12)
	assert_true(_mob.is_conserved)


func test_infection_transfers_to_nearest_wet_target_and_consumes_wetness() -> void:
	_mob.progress = 3000
	_mob.wet_ticks_left = 60
	var target: MobState = MobState.create(_config.army_mob)
	target.progress = 3500
	target.wet_ticks_left = 60
	_field.mobs.append(target)
	DivineCombat.hit(_field, _tower("hex"), _mob, 4)
	assert_true(_mob.is_contagious)
	_mob.curse_ticks_left = 1
	DivineCombat.tick_effects(_field, _mob)
	assert_eq(target.curse_ticks_left, 60)
	assert_eq(target.curse_damage, 8)
	assert_eq(target.wet_ticks_left, 0)
	assert_true(target.is_contagious)


func test_wind_spreads_without_recursive_same_tick_cascade() -> void:
	_mob.progress = 3000
	_mob.wet_ticks_left = 60
	_mob.is_in_wind = true
	var target: MobState = MobState.create(_config.army_mob)
	target.progress = 4000
	target.is_in_wind = true
	_field.mobs.append(target)
	var distant: MobState = MobState.create(_config.army_mob)
	distant.progress = 5000
	_field.mobs.append(distant)
	WindReactions.apply(_field, _mob)
	assert_eq(_mob.progress, 3250)
	assert_eq(target.wet_ticks_left, 30)
	WindReactions.apply(_field, target)
	assert_eq(distant.wet_ticks_left, 0)
	assert_eq(target.progress, 4000)


func test_frozen_wind_spreads_slow_and_respects_shield_and_status_limit() -> void:
	_mob.progress = 3000
	_mob.freeze_ticks_left = 30
	_mob.is_in_wind = true
	var target: MobState = MobState.create(_config.army_mob)
	target.progress = 3500
	target.shield_left = 1
	_field.mobs.append(target)
	WindReactions.apply(_field, _mob)
	assert_eq(target.cold_ticks_left, 0)
	target.shield_left = 0
	_mob.wind_reaction_cooldown = 0
	WindReactions.apply(_field, _mob)
	assert_eq(target.cold_slow_percent, 25)
	assert_gt(target.cold_ticks_left, 0)
	target.remove_status(&"cold")
	target.wet_ticks_left = 60
	target.charge_ticks_left = 60
	_mob.wind_reaction_cooldown = 0
	WindReactions.apply(_field, _mob)
	assert_eq(target.cold_ticks_left, 0)


func test_water_zero_damage_and_lightning_charge_are_active_content() -> void:
	DivineCombat.hit(_field, _tower("water"), _mob, 0)
	assert_eq(_mob.hp, 1000)
	assert_gt(_mob.wet_ticks_left, 0)
	DivineCombat.hit(_field, _tower("spark"), _mob, 12)
	assert_eq(_mob.status_tags().size(), 2)
	assert_gt(_mob.charge_ticks_left, 0)


func test_wildfire_spreads_burn_only_while_source_is_under_wind() -> void:
	_mob.progress = 3000
	_mob.burn_ticks_left = 60
	_mob.burn_damage = 8
	var target: MobState = MobState.create(_config.army_mob)
	target.progress = 3500
	_field.mobs.append(target)
	WindReactions.apply(_field, _mob)
	assert_eq(target.burn_ticks_left, 0)
	_mob.is_in_wind = true
	WindReactions.apply(_field, _mob)
	assert_eq(target.burn_ticks_left, 30)
	assert_eq(target.burn_damage, 8)
	var before: int = _mob.hp
	DivineCombat.tick_effects(_field, _mob)
	assert_eq(before - _mob.hp, 10)


func test_curse_burst_kill_reward_and_shield_are_resolved_once() -> void:
	DivineCombat.hit(_field, _tower("hex"), _mob, 4)
	_mob.curse_ticks_left = 1
	_mob.shield_left = 1
	DivineCombat.tick_effects(_field, _mob)
	assert_eq(_mob.hp, 996)
	assert_eq(_mob.shield_left, 0)
	DivineCombat.hit(_field, _tower("hex"), _mob, 4)
	_mob.hp = 1
	_mob.curse_ticks_left = 1
	DivineCombat.tick_effects(_field, _mob)
	DivineCombat.tick_effects(_field, _mob)
	assert_eq(_field.pending_kill_gold, _mob.kill_reward)


func test_curse_and_wind_future_state_change_hash() -> void:
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	_mob.curse_ticks_left = 20
	_mob.curse_damage = 40
	_mob.curse_delay = 60
	_mob.is_contagious = true
	_mob.is_conserved = true
	_mob.wind_reaction_cooldown = 10
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_ne(before.value, after.value)


func test_steam_controls_movement_without_adding_a_third_elemental_status() -> void:
	_mob.wet_ticks_left = 60
	var original_speed: int = _mob.speed
	DivineCombat.hit(_field, _tower("brazier"), _mob, 100)
	assert_eq(_mob.current_speed(), original_speed * 70 / 100)
	assert_eq(_mob.status_tags().size(), 0)
	assert_eq(_mob.stun_ticks_left, 0)
	for i: int in 20:
		_mob.advance()
	assert_eq(_mob.current_speed(), original_speed)


func test_cold_and_frozen_share_existing_slot_with_second_status() -> void:
	_mob.freeze_ticks_left = 30
	_mob.charge_ticks_left = 60
	assert_true(_mob.can_apply_status(&"cold"), "Холод обновляет тот же слот заморозки")
	assert_false(_mob.can_apply_status(&"burn"), "Настоящий третий статус запрещён")
	_mob.freeze_ticks_left = 0
	_mob.cold_ticks_left = 30
	assert_true(_mob.can_apply_status(&"frozen"), "Заморозка заменяет слот холода")


func test_wind_refreshes_cold_on_frozen_charged_neighbor_without_third_slot() -> void:
	_mob.cold_ticks_left = 60
	_mob.cold_slow_percent = 35
	_mob.is_in_wind = true
	_mob.progress = 3000
	var target: MobState = MobState.create(_config.army_mob)
	target.progress = 3500
	target.freeze_ticks_left = 30
	target.charge_ticks_left = 60
	_field.mobs.append(target)
	WindReactions.apply(_field, _mob)
	assert_gt(target.cold_ticks_left, 0)
	assert_eq(target.cold_slow_percent, 35)
	assert_eq(target.status_tags().size(), 2)
