extends GutTest
## Подсветка показывает реальное общее покрытие, а не обещает любую пару стихий.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 4, 331)


func _tower(id_value: String, anchor: Vector2i) -> TowerState:
	return _field.add_tower(load("res://data/towers/%s.tres" % id_value) as TowerData, anchor, 0)


func test_charge_and_curse_need_physical_finisher_in_same_zone() -> void:
	_tower("spark", Vector2i(0, 4))
	_tower("hex", Vector2i(2, 4))
	var war: TowerState = _tower("bolt", Vector2i(2, 5))
	assert_gt(CombatCoverage.reaction_cells(_field, war).size(), 0)
	assert_true(_field.move_tower(war, Vector2i(8, 0), 0))
	assert_true(CombatCoverage.reaction_cells(_field, war).is_empty())


func test_wind_and_lightning_do_not_promise_nonexistent_reaction() -> void:
	var spark: TowerState = _tower("spark", Vector2i(0, 4))
	var wind: TowerState = _tower("wind", Vector2i(2, 4))
	assert_true(CombatCoverage.reaction_cells(_field, wind).is_empty())
	assert_true(CombatCoverage.reaction_cells(_field, spark).is_empty())


func test_water_ice_and_physics_have_shared_shatter_zone() -> void:
	_tower("dew", Vector2i(0, 4))
	_tower("rime", Vector2i(2, 4))
	var war: TowerState = _tower("bolt", Vector2i(2, 5))
	assert_gt(CombatCoverage.reaction_cells(_field, war).size(), 0)
