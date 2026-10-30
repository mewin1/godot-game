extends GutTest
## Драфт, фильтры всего пути получения контента и покрытие 35 четвёрок.

var _config: GameConfig


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig


func test_seeded_shared_draft_exists_before_hero_selection() -> void:
	var first: MatchSim = MatchSim.new(_config, 741, 5, 5)
	var second: MatchSim = MatchSim.new(_config, 741, 5, 5)
	assert_eq(first.active_gods, second.active_gods)
	assert_eq(first.active_gods.size(), 4)
	for player: PlayerState in first.players:
		assert_eq(player.shop.active_gods, first.active_gods)
	first.start_with_hero_select()
	for player: PlayerState in first.players:
		assert_eq(player.hero_offers.size(), 3)
		for hero: HeroData in player.hero_offers:
			assert_true(player.shop.is_god_active(hero.affinity_god))


func test_each_god_has_three_distinct_active_towers_and_starter() -> void:
	for god: StringName in _config.gods:
		var count: int = 0
		var starters: int = 0
		for tower: TowerData in _config.towers:
			if tower.god == god:
				count += 1
				starters += 1 if tower.tier == 1 else 0
		assert_eq(count, 3, String(god))
		assert_gt(starters, 0, String(god))


func test_all_35_drafts_have_reaction_and_shop_never_leaks_inactive_gods() -> void:
	var checked: int = 0
	for a: int in 4:
		for b: int in range(a + 1, 5):
			for c: int in range(b + 1, 6):
				for d: int in range(c + 1, 7):
					var gods: Array[StringName] = [_config.gods[a], _config.gods[b],
							_config.gods[c], _config.gods[d]]
					_check_draft(gods)
					checked += 1
	assert_eq(checked, 35)


func _check_draft(gods: Array[StringName]) -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 1441)
	player.shop.active_gods = gods
	var has_reaction: bool = false
	var available_statuses: Array[StringName] = []
	for tower: TowerData in _config.towers:
		if not gods.has(tower.god):
			continue
		for status: StringName in _statuses(tower):
			if not available_statuses.has(status):
				available_statuses.append(status)
		for source: TowerData in _config.towers:
			if source.god == tower.god or not gods.has(source.god):
				continue
			for tag: StringName in tower.tags:
				var rule: ReactionData = ReactionResolver.resolve(tag, _statuses(source),
						_config.reactions)
				has_reaction = has_reaction or rule != null
	if gods.has(&"war"):
		has_reaction = has_reaction or ReactionResolver.resolve(&"physical",
				available_statuses, _config.reactions) != null
	assert_true(has_reaction, "четвёрка имеет направленную реакцию: %s" % str(gods))
	for level: int in range(1, 5):
		player.shop.level = level
		for roll_index: int in 10:
			player.shop.roll(player.rng)
			for tower: TowerData in player.shop.offers:
				if tower != null:
					assert_true(gods.has(tower.god))
			for rite: RiteData in player.shop.rite_offers:
				if rite != null:
					assert_true(player.shop.is_god_active(rite.god))
	var max_tower: TowerState = TowerState.new()
	max_tower.level = _config.max_tower_level
	player._check_discover(max_tower)
	assert_gt(player.discover_offers.size(), 0)
	for gift: TowerData in player.discover_offers:
		assert_true(gods.has(gift.god))


func _statuses(tower: TowerData) -> Array[StringName]:
	var result: Array[StringName] = []
	if tower.wet_ticks > 0:
		result.append(&"wet")
	if tower.burn_percent > 0:
		result.append(&"burn")
	if tower.cold_ticks > 0:
		result.append(&"cold")
	if tower.charge_ticks > 0:
		result.append(&"charge")
	if tower.curse_ticks > 0:
		result.append(&"curse")
	return result


func test_affinity_grants_active_starter_and_no_inactive_gift() -> void:
	var hero: HeroData = load("res://data/heroes/babushka.tres") as HeroData
	var player: PlayerState = PlayerState.new(_config, 0, 1)
	player.shop.active_gods = [&"water", &"ice", &"war", &"curse"]
	player.pick_hero(hero)
	assert_true(player.gift_towers.has(hero.affinity_gift))
	var excluded: PlayerState = PlayerState.new(_config, 0, 1)
	excluded.shop.active_gods = [&"svarog", &"perun", &"stribog", &"war"]
	excluded.pick_hero(hero)
	assert_false(excluded.gift_towers.has(hero.affinity_gift))


func test_physics_bridges_charge_and_curse_without_direct_reaction() -> void:
	var statuses: Array[StringName] = [&"charge", &"curse"]
	assert_null(ReactionResolver.resolve(&"lightning", [&"curse"], _config.reactions))
	assert_null(ReactionResolver.resolve(&"curse", [&"charge"], _config.reactions))
	var rule: ReactionData = ReactionResolver.resolve(&"physical", statuses, _config.reactions)
	assert_not_null(rule)
	assert_eq(rule.id, &"execute")


func test_every_draft_can_defend_first_wave_with_three_starter_shooters() -> void:
	var brain: BotBrain = BotBrain.new(0)
	for a: int in 4:
		for b: int in range(a + 1, 5):
			for c: int in range(b + 1, 6):
				for d: int in range(c + 1, 7):
					var gods: Array[StringName] = [_config.gods[a], _config.gods[b],
							_config.gods[c], _config.gods[d]]
					var field: FieldState = FieldState.new(_config, 1, 811)
					var starter: TowerData = null
					for tower: TowerData in _config.towers:
						if gods.has(tower.god) and tower.tier == 1 and tower.damage > 0:
							starter = tower
							break
					assert_not_null(starter)
					for copy_index: int in 3:
						var spot: Vector3i = brain.find_best_spot(field, starter)
						assert_gte(spot.z, 0)
						field.add_tower(starter, Vector2i(spot.x, spot.y), spot.z)
					WaveBuilder.schedule_wave(_config, field, 1, [])
					for tick_index: int in _config.battle_real_ticks:
						field.tick()
						if field.is_wave_done():
							break
					assert_true(field.is_wave_done(), str(gods))
					assert_eq(field.pending_breaches.size(), 0, str(gods))
