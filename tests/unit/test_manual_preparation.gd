extends GutTest
## Тестовая игра ждёт человека, бои и боты сохраняют обычный ход.


func test_active_game_waits_past_old_deadline_until_ready() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sim: MatchSim = MatchSim.new(config, 521, 2, 1)
	sim.start()
	for i: int in config.prep_ticks + config.early_prep_ticks:
		sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.PREP)
	assert_eq(sim.round_number, 1)
	assert_eq(sim.execute_command(0, ReadyCommand.new()), "")
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)


func test_bot_only_match_does_not_wait_for_human_button() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sim: MatchSim = MatchSim.new(config, 521, 2, 0)
	sim.start()
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)
