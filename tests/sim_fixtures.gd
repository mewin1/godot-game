class_name SimFixtures
extends RefCounted
## Общие заготовки для тестов симуляции.

const CONFIG_PATH: String = "res://data/game_config.tres"


## Копия настоящего конфига: тест может менять числа, не трогая файл.
static func make_config() -> GameConfig:
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	return config.duplicate() as GameConfig


static func find_tower(config: GameConfig, tower_id: StringName) -> TowerData:
	for data: TowerData in config.towers:
		if data.id == tower_id:
			return data
	return null


static func find_buff(config: GameConfig, buff_id: StringName) -> SendBuffData:
	for data: SendBuffData in config.send_buffs:
		if data.id == buff_id:
			return data
	return null


static func find_hero(config: GameConfig, hero_id: StringName) -> HeroData:
	for data: HeroData in config.heroes:
		if data.id == hero_id:
			return data
	return null


static func find_mob(mob_id: StringName) -> MobData:
	return load("res://data/mobs/%s.tres" % mob_id) as MobData


## Матч на 2 игрока (человек + бот) сразу в подготовке 1-го раунда, у человека — этот герой.
static func make_hero_match(config: GameConfig, hero_id: StringName, seed_value: int = 99) -> MatchSim:
	var sim: MatchSim = MatchSim.new(config, seed_value, 2, 1)
	sim.start_with_hero_select()
	sim.players[0].hero_offers[0] = find_hero(config, hero_id)
	sim.choose_hero(0, 0)
	sim.tick()
	return sim
