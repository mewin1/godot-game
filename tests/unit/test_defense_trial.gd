extends GutTest
## Проба использует настоящую симуляцию, но не даёт менять исход/награды матча.


func test_trial_repeatable_and_does_not_change_match_hash_or_rewards() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sim: MatchSim = MatchSim.new(config, 713, 2, 2)
	sim.start()
	var before: int = sim.state_hash()
	var gold: int = sim.players[0].gold
	var hp: int = sim.players[0].hero_hp
	var first: DefenseTrial = DefenseTrial.run(sim, 0)
	var second: DefenseTrial = DefenseTrial.run(sim, 0)
	assert_eq(sim.state_hash(), before)
	assert_eq(sim.players[0].gold, gold)
	assert_eq(sim.players[0].hero_hp, hp)
	assert_eq(sim.phase, MatchSim.Phase.PREP)
	assert_eq(first.breached, config.wave_base_count)
	assert_eq(first.breached, second.breached)
	assert_eq(first.reactions, second.reactions)
	assert_eq(first.killed + first.breached + first.retreated, first.total)


func test_trial_copies_upgrades_idols_and_can_show_successful_defense() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sim: MatchSim = MatchSim.new(config, 713, 2, 2)
	sim.start()
	var tower: TowerData = load("res://data/towers/spark.tres") as TowerData
	var brain: BotBrain = BotBrain.new(0)
	for i: int in 3:
		var spot: Vector3i = brain.find_best_spot(sim.players[0].field, tower)
		sim.players[0].field.add_tower(tower, Vector2i(spot.x, spot.y), spot.z)
	var before: int = sim.state_hash()
	var result: DefenseTrial = DefenseTrial.run(sim, 0)
	assert_eq(result.breached, 0)
	assert_eq(result.killed, config.wave_base_count)
	assert_eq(sim.state_hash(), before)
