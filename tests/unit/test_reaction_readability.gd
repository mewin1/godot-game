extends GutTest
## Подсказка выводится из реального драфта, счётчики отражают настоящие эффекты.

var _config: GameConfig


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig


func test_live_draft_explains_physical_bridge_and_wind_without_synergy() -> void:
	var gods: Array[StringName] = [&"perun", &"stribog", &"war", &"curse"]
	var hint: String = ReactionGuide.draft_text(_config, gods)
	assert_true(hint.contains("Перун + Чернобог → Бог войны: Добивание"))
	assert_true(hint.contains("Стрибог: только контроль"))
	assert_false(hint.contains("Пар ·"))
	assert_false(hint.contains("Таяние"))


func test_counters_register_damage_reaction_and_reset_at_next_wave() -> void:
	var field: FieldState = FieldState.new(_config, 3, 51)
	var tower: TowerState = field.add_tower(
			load("res://data/towers/brazier.tres") as TowerData, Vector2i(2, 4), 0)
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.hp = 1000
	mob.wet_ticks_left = 60
	DivineCombat.hit(field, tower, mob, 100)
	var steam_count: int = field.reaction_counts.get(&"steam", 0)
	assert_eq(steam_count, 1)
	assert_true(ReactionGuide.battle_report(_config, field.reaction_counts).contains("Пар ×1"))
	field.start_wave()
	assert_true(field.reaction_counts.is_empty())


func test_conservation_is_not_counted_repeatedly_after_first_amplification() -> void:
	var field: FieldState = FieldState.new(_config, 3, 51)
	var tower: TowerState = field.add_tower(
			load("res://data/towers/rime.tres") as TowerData, Vector2i(2, 4), 0)
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.hp = 1000
	mob.curse_ticks_left = 60
	mob.curse_damage = 20
	for i: int in 3:
		DivineCombat.hit(field, tower, mob, 8)
	var conserved_count: int = field.reaction_counts.get(&"conservation", 0)
	assert_eq(conserved_count, 1)



func test_water_ice_war_explains_shatter_instead_of_spending_nonexistent_second_mark() -> void:
	var gods: Array[StringName] = [&"water", &"ice", &"war", &"curse"]
	var hint: String = ReactionGuide.draft_text(_config, gods)
	assert_true(hint.contains("Вода → Лёд → Бог войны: Раскол"))
	assert_false(hint.contains("Вода + Лёд → Бог войны: Добивание"))
