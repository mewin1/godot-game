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
