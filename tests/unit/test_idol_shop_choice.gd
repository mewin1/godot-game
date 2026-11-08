extends GutTest
## Бесплатные идолы: очередь выбора, заполненные основы, редкие бафы и команды ботов.

var _config: GameConfig
var _player: PlayerState


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig
	_player = PlayerState.new(_config, 0, 771)
	_player.shop.active_gods.assign([&"ice", &"perun", &"water", &"stribog"])
	_player.start_prep(false)
	_player.gold = 1000


func test_upgrade_grants_choice_and_dedication_applies_free_base() -> void:
	assert_eq(_player.upgrade_shop(), "")
	assert_eq(_player.idol_choices_left, 1)
	var gold_before: int = _player.gold
	assert_eq(_player.choose_idol(&"ice", 2), "")
	assert_eq(_player.field.idols[2].god, &"ice")
	assert_eq(_player.field.idols[2].damage_percent, 10)
	assert_true(_player.field.idols[2].purchases.is_empty())
	assert_eq(_player.gold, gold_before)
	assert_eq(_player.idol_choices_left, 0)
	assert_ne(_player.choose_idol(&"ice", 2), "")


func test_choices_accumulate_and_can_be_declined() -> void:
	for i: int in 3:
		assert_eq(_player.upgrade_shop(), "")
	assert_eq(_player.idol_choices_left, 3)
	assert_eq(_player.choose_idol(&"", -1), "")
	assert_eq(_player.idol_choices_left, 2)
	assert_eq(_player.choose_idol(&"ice", 0), "")
	assert_eq(_player.choose_idol(&"ice", 0), "")
	assert_eq(_player.field.idols[0].damage_percent, 20)
	assert_eq(_player.idol_choices_left, 0)


func test_unavailable_god_wrong_slot_and_duplicate_are_transactional() -> void:
	_player.upgrade_shop()
	assert_ne(_player.choose_idol(&"svarog", 0), "")
	assert_ne(_player.choose_idol(&"ice", 3), "")
	assert_ne(_player.choose_idol(&"ice", -1), "")
	assert_eq(_player.idol_choices_left, 1)
	_player.choose_idol(&"ice", 0)
	_player.upgrade_shop()
	assert_ne(_player.choose_idol(&"ice", 1), "")
	assert_ne(_player.choose_idol(&"water", 0), "")
	assert_eq(_player.idol_choices_left, 1)
	assert_eq(_player.field.idols[1].god, &"")


func test_full_bases_keep_rare_upgrades_and_allow_repeat_only() -> void:
	var rare: RiteData = load("res://data/rites/ice_power.tres") as RiteData
	_player.field.idols[0].apply_rite(rare)
	_player.field.idols[1].god = &"perun"
	_player.field.idols[2].god = &"water"
	_player.upgrade_shop()
	for slot: int in 3:
		assert_ne(_player.choose_idol(&"stribog", slot), "")
	assert_eq(_player.choose_idol(&"ice", 0), "")
	assert_eq(_player.field.idols[0].damage_percent, 20)
	assert_eq(_player.field.idols[0].purchases[rare.id], 1)
	assert_eq(_player.field.idols[0].check_rite(rare), "")
	var ghost: FieldState = FieldState.new(_config, _player.shop.level, 19)
	ghost.copy_towers_from(_player.field)
	assert_eq(ghost.idols[0].damage_percent, 20)
	ghost.idols[0].damage_percent += 1
	assert_eq(_player.field.idols[0].damage_percent, 20)


func test_failed_shop_upgrade_does_not_grant_choice() -> void:
	_player.gold = 0
	assert_ne(_player.upgrade_shop(), "")
	assert_eq(_player.idol_choices_left, 0)


func test_pending_choice_survives_preparation_and_affects_hash() -> void:
	_player.upgrade_shop()
	_player.end_prep()
	_player.start_prep(true)
	assert_eq(_player.idol_choices_left, 1)
	var before: StateHasher = StateHasher.new()
	_player.add_to_hash(before)
	_player.idol_choices_left = 0
	var after: StateHasher = StateHasher.new()
	_player.add_to_hash(after)
	assert_ne(before.value, after.value)


func test_identical_choice_commands_keep_hash_and_wave_rejects_choice() -> void:
	var left: MatchSim = MatchSim.new(_config, 93, 2, 2)
	var right: MatchSim = MatchSim.new(_config, 93, 2, 2)
	left.start()
	right.start()
	for sim: MatchSim in [left, right]:
		var player: PlayerState = sim.players[0]
		player.gold = 1000
		assert_eq(sim.execute_command(0, UpgradeShopCommand.new()), "")
		var rite: RiteData = player.get_idol_base_rites()[0]
		assert_eq(sim.execute_command(0, ChooseIdolCommand.new(rite.god, 0)), "")
	assert_eq(left.state_hash(), right.state_hash())
	left.phase = MatchSim.Phase.WAVE
	left.players[0].idol_choices_left = 1
	assert_ne(left.execute_command(0, ChooseIdolCommand.new()), "")
	assert_eq(left.players[0].idol_choices_left, 1)


func test_bot_chooses_its_built_force_and_consumes_queue() -> void:
	var sim: MatchSim = MatchSim.new(_config, 93, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	var rite: RiteData = player.get_idol_base_rites()[0]
	for tower: TowerData in _config.towers:
		if tower.god == rite.god:
			player.field.add_tower(tower, Vector2i(0, 0), 0)
			break
	player.idol_choices_left = 3
	var brain: BotBrain = BotBrain.new(30)
	brain._choose_idols(sim, player)
	assert_eq(player.idol_choices_left, 0)
	assert_not_null(player.field.get_idol(rite.god))
	assert_true(player.field.idols[0].purchases.is_empty())
