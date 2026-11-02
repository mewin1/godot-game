extends GutTest
## Пробивание брони: башни с armor_pierce игнорируют часть брони моба.

var _config: GameConfig


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig


func _tower(id_value: StringName) -> TowerData:
	for data: TowerData in _config.towers:
		if data.id == id_value:
			return data
	return null


func _spawn(field: FieldState, data: MobData) -> MobState:
	var mob: MobState = MobState.create(data)
	field.schedule_spawn(mob, 0)
	field.start_wave()
	return mob


func test_pierce_values_in_data() -> void:
	assert_eq(_tower(&"thunder").armor_pierce, 3, "грозовой столб пробивает 3 брони")
	assert_eq(_tower(&"war_engine").armor_pierce, 2, "осадный станок пробивает 2 брони")
	assert_eq(_tower(&"bolt").armor_pierce, 0, "обычный самострел не пробивает")


func test_armor_pierce_reduces_effective_armor() -> void:
	var armored: MobState = MobState.create(SimFixtures.find_mob(&"armored"))
	var full_hp: int = armored.max_hp
	assert_false(armored.take_damage(10), "не умирает от 10 урона")
	assert_eq(armored.hp, full_hp - 6, "без пробивания: 10 - 4 брони = 6")

	var pierced: MobState = MobState.create(SimFixtures.find_mob(&"armored"))
	assert_false(pierced.take_damage(10, 3), "не умирает от 10 урона")
	assert_eq(pierced.hp, full_hp - 9, "пробивание 3: 10 - 1 брони = 9")


func test_thunder_pierces_armor_on_hit() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"thunder"), Vector2i(2, 8), 0)
	var armored: MobState = _spawn(field, SimFixtures.find_mob(&"armored"))
	field.tick()
	assert_eq(armored.hp, armored.max_hp - 45,
			"46 урона - (4 брони - 3 пробивания) = 45")


func test_bolt_does_not_pierce_armor() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"bolt"), Vector2i(2, 8), 0)
	var armored: MobState = _spawn(field, SimFixtures.find_mob(&"armored"))
	field.tick()
	assert_eq(armored.hp, armored.max_hp - 14, "18 урона - 4 брони = 14")
