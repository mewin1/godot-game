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
