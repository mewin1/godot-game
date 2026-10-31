extends GutTest
## Подсказки читают правила, не меняют состояние и различают заражение/перенос.

var _config: GameConfig
var _field: FieldState
var _mob: MobState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 4, 81)
	_mob = MobState.create(_config.training_mob)
	_mob.id = 1
	_mob.progress = 3000
	_field.mobs.append(_mob)


func test_preview_explains_shield_status_limit_and_curse_order_without_mutation() -> void:
	var tower: TowerState = _field.add_tower(
			load("res://data/towers/hex.tres") as TowerData, Vector2i(2, 5), 0)
	_mob.wet_ticks_left = 60
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	assert_true(ReactionInspector.hit_hint(_field, tower, _mob).contains("Зараза"))
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_eq(before.value, after.value)
	_mob.shield_left = 1
	assert_true(ReactionInspector.hit_hint(_field, tower, _mob).contains("щит"))
	_mob.shield_left = 0
	_mob.wet_ticks_left = 0
	_mob.charge_ticks_left = 60
	_mob.cold_ticks_left = 60
	assert_true(ReactionInspector.hit_hint(_field, tower, _mob).contains("два слота заняты"))
	_mob.cold_ticks_left = 0
	_mob.curse_ticks_left = 60
	assert_true(ReactionInspector.curse_hint(_field, _mob).contains("не заразно"))


func test_preview_warns_when_neighbor_water_expires_before_curse() -> void:
	_mob.curse_ticks_left = 60
	_mob.is_contagious = true
	assert_true(ReactionInspector.curse_hint(_field, _mob).contains("нет мокрого соседа"))
	var neighbor: MobState = MobState.create(_config.training_mob)
	neighbor.id = 2
	neighbor.progress = 3500
	neighbor.wet_ticks_left = 40
	_field.mobs.append(neighbor)
	var preview: String = ReactionInspector.curse_hint(_field, _mob)
	assert_true(preview.contains("#2"))
	assert_true(preview.contains("закончится раньше"))
	assert_eq(CurseCombat.find_wet_neighbor(_field, _mob), neighbor)
