extends GutTest
## Экономика и магазин: покупка, витрина, рерол, уровень магазина, слияние, продажа.

var _config: GameConfig
var _player: PlayerState


func before_each() -> void:
	_config = SimFixtures.make_config()
	_player = PlayerState.new(_config, 0, 12345)
	_player.start_prep(false)


func test_start_gold_and_income_from_config() -> void:
	assert_eq(_player.gold, _config.start_gold)
	assert_eq(_player.income, _config.base_income)


func test_tower_income_per_round_scales_with_tower_count() -> void:
	_config.tower_income_per_round = 2
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	_player.field.add_tower(data, Vector2i(0, 0), 0)
	_player.field.add_tower(data, Vector2i(0, 5), 0)
	assert_eq(_player.field.get_round_income(), 2 * 2)


func test_tower_income_disabled_by_default() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	_player.field.add_tower(data, Vector2i(0, 0), 0)
	assert_eq(_player.field.get_round_income(), 0)


func test_shop_shows_three_offers_on_level_one() -> void:
	assert_eq(_player.shop.offers.size(), 3)


func test_shop_upgrade_adds_offer_and_lengthens_path() -> void:
	var path_before: int = _player.field.path_length
	_player.gold = 100
	assert_eq(_player.upgrade_shop(), "")
	assert_eq(_player.shop.level, 2)
	assert_eq(_player.shop.offers.size(), 4)
	assert_gt(_player.field.path_length, path_before)


func test_shop_offers_only_open_tiers() -> void:
	for i: int in 30:
		_player.shop.roll(_player.rng)
		for data: TowerData in _player.shop.offers:
			assert_eq(data.tier, 1)


func test_upgrade_cost_drops_each_round_to_minimum() -> void:
	var shop: ShopState = _player.shop
	assert_eq(shop.upgrade_cost, _config.shop_upgrade_costs[0])
	for i: int in 10:
		shop.on_round_started()
	assert_eq(shop.upgrade_cost, _config.shop_upgrade_min_cost)


func test_upgrade_resets_cost_to_next_full_price() -> void:
	_player.gold = 100
	_player.shop.on_round_started()
	assert_eq(_player.upgrade_shop(), "")
	assert_eq(_player.shop.upgrade_cost, _config.shop_upgrade_costs[1])


func test_upgrade_without_gold_fails() -> void:
	_player.gold = 1
	assert_ne(_player.upgrade_shop(), "")
	assert_eq(_player.shop.level, 1)


func test_shop_max_level_is_four() -> void:
	_player.gold = 1000
	for i: int in 5:
		_player.upgrade_shop()
	assert_eq(_player.shop.level, 4)
	assert_eq(_player.shop.offers.size(), 6)


func test_buy_tower_spends_gold_and_empties_offer() -> void:
	assert_eq(_buy_at(0, Vector2i(2, 3)), "")
	assert_eq(_player.gold, _config.start_gold - _config.tower_cost)
	assert_null(_player.shop.get_offer(0))
	assert_eq(_player.field.towers.size(), 1)


func test_buy_same_offer_twice_fails() -> void:
	_buy_at(0, Vector2i(2, 3))
	assert_ne(_buy_at(0, Vector2i(2, 7)), "")


func test_buy_without_gold_fails() -> void:
	_player.gold = _config.tower_cost - 1
	assert_ne(_buy_at(0, Vector2i(2, 3)), "")
	assert_eq(_player.field.towers.size(), 0)


func test_buy_on_bad_cell_keeps_gold() -> void:
	assert_ne(_buy_at(0, Vector2i(1, 4)), "", "клетка пути")
	assert_eq(_player.gold, _config.start_gold)


func test_reroll_costs_gold_and_refills_offers() -> void:
	_buy_at(0, Vector2i(2, 3))
	var gold_before: int = _player.gold
	assert_eq(_player.reroll_shop(), "")
	assert_eq(_player.gold, gold_before - _config.reroll_cost)
	assert_not_null(_player.shop.get_offer(0))


func test_sell_in_same_phase_refunds_full_price() -> void:
	_buy_at(0, Vector2i(2, 3))
	var tower: TowerState = _player.field.towers[0]
	assert_eq(_player.sell_tower(tower.id), "")
	assert_eq(_player.gold, _config.start_gold)
	assert_true(_player.field.towers.is_empty())


func test_sell_after_phase_refunds_third() -> void:
	_buy_at(0, Vector2i(2, 3))
	_player.end_prep()
	var tower: TowerState = _player.field.towers[0]
	assert_eq(_player.get_sell_price(tower), _config.tower_cost / _config.sell_divisor)


func test_merge_two_same_towers_raises_level_and_frees_cells() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var first: TowerState = _player.field.add_tower(data, Vector2i(0, 0), 0)
	var second: TowerState = _player.field.add_tower(data, Vector2i(0, 5), 0)
	first.invested_total = 6
	second.invested_total = 6
	assert_eq(_player.merge_towers(second.id, first.id), "")
	assert_eq(first.level, 2)
	assert_eq(first.invested_total, 12)
	assert_null(_player.field.get_tower_at(Vector2i(0, 5)))
	assert_eq(_player.field.towers.size(), 1)


func test_merge_different_levels_fails() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var first: TowerState = _player.field.add_tower(data, Vector2i(0, 0), 0)
	var second: TowerState = _player.field.add_tower(data, Vector2i(0, 5), 0)
	first.level = 2
	assert_ne(_player.merge_towers(second.id, first.id), "")


func test_merge_different_towers_fails() -> void:
	var first: TowerState = _player.field.add_tower(
			SimFixtures.find_tower(_config, &"ice_1"), Vector2i(0, 0), 0)
	var second: TowerState = _player.field.add_tower(
			SimFixtures.find_tower(_config, &"fire_1"), Vector2i(0, 5), 1)
	assert_ne(_player.merge_towers(second.id, first.id), "")


func test_merge_above_max_level_fails() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var first: TowerState = _player.field.add_tower(data, Vector2i(0, 0), 0)
	var second: TowerState = _player.field.add_tower(data, Vector2i(0, 5), 0)
	first.level = 3
	second.level = 3
	assert_ne(_player.merge_towers(second.id, first.id), "")


func test_buy_into_same_tower_merges_without_new_cells() -> void:
	var data: TowerData = _player.shop.get_offer(0)
	var tower: TowerState = _player.field.add_tower(data, Vector2i(0, 0), 1)
	assert_eq(_player.buy_tower_into(0, tower.id), "")
	assert_eq(tower.level, 2)
	assert_eq(_player.field.towers.size(), 1)
	assert_eq(_player.gold, _config.start_gold - _config.tower_cost)


func test_merged_tower_sells_for_third_of_all_copies() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var tower: TowerState = _player.field.add_tower(data, Vector2i(0, 0), 0)
	tower.level = 3
	tower.invested_total = 24
	assert_eq(_player.get_sell_price(tower), 8)


func test_tower_level_raises_damage() -> void:
	assert_eq(_config.get_level_damage(10, 1), 10)
	assert_gt(_config.get_level_damage(10, 2), _config.get_level_damage(10, 1))
	assert_gt(_config.get_level_damage(10, 3), _config.get_level_damage(10, 2))


func _buy_at(offer_index: int, anchor: Vector2i) -> String:
	# Ищем поворот, при котором фигура встаёт: формы предложений случайные.
	var data: TowerData = _player.shop.get_offer(offer_index)
	if data != null:
		for turns: int in TowerState.ROTATIONS:
			if _player.field.can_place_tower_data(data, anchor, turns):
				return _player.buy_tower(offer_index, anchor, turns)
	return _player.buy_tower(offer_index, anchor, 0)


func test_rotate_tower_in_place_when_fits() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"fire_1")
	var tower: TowerState = _player.field.add_tower(data, Vector2i(2, 4), 1)
	assert_eq(_player.rotate_tower(tower.id), "")
	assert_eq(tower.rotation, 2)
	assert_eq(tower.anchor, Vector2i(2, 4))


func test_rotate_tower_shifts_when_blocked() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"fire_1")
	var tower: TowerState = _player.field.add_tower(data, Vector2i(0, 4), 1)
	assert_eq(_player.rotate_tower(tower.id), "", "горизонтально у края не влезает на месте")
	assert_eq(tower.rotation, 2)
	assert_true(_player.field.can_place(tower.cells(), tower.id))


func test_rotate_tower_fails_without_space() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_2")
	var tower: TowerState = _player.field.add_tower(data, Vector2i(0, 3), 1)
	assert_ne(_player.rotate_tower(tower.id), "", "горизонтальная тройка в столбце 0 не помещается")
	assert_eq(tower.rotation, 1)


func test_merge_frees_cells() -> void:
	var data: TowerData = SimFixtures.find_tower(_config, &"fire_1")
	var first: TowerState = _player.field.add_tower(data, Vector2i(2, 2), 0)
	var second: TowerState = _player.field.add_tower(data, Vector2i(2, 6), 0)
	assert_eq(_player.get_cells_used(), 4)
	_player.merge_towers(second.id, first.id)
	assert_eq(_player.get_cells_used(), 2)
