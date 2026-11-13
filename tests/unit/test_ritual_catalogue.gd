extends GutTest
## Активная модель P2: постоянный каталог, участки и улучшения за золото.

var _settings: RitualTrialConfig
var _trial: RitualTrial
var _bench_damage: int = 0


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig
	_trial = RitualTrial.new(_settings, 0, 11)
	_trial.gold = 10000


func test_start_has_ten_separate_plots() -> void:
	var cells: Array[Vector2i] = _trial.field.get_buildable_cells()
	assert_eq(cells.size(), 10)
	for first: Vector2i in cells:
		for second: Vector2i in cells:
			if first != second:
				assert_true(maxi(absi(first.x - second.x), absi(first.y - second.y)) >= 2,
					"Между участками минимум одна клетка")


func test_rules_from_9b4f263_keep_legacy_curve_and_fingerprint() -> void:
	var rules: RitualTrialConfig = load("res://tests/fixtures/ritual_endless_9b4f263.tres") as RitualTrialConfig
	assert_eq(rules.nights.pressure_base, 0, "Старые правила не включают новую кривую")
	var trial: RitualTrial = RitualTrial.new(rules, 0, 915701, 1)
	assert_eq(trial.rules_hash, 999072436, "Отпечаток настоящей записи автора до переделки")
	for pack: RitualPack in trial.plan().packs(14):
		for index: int in pack.members.size():
			assert_eq(pack.elite[index], 0, "В старой записи нет элиты")
			assert_eq(pack.bounties[index], rules.enemies[pack.members[index]].kill_reward)


func test_catalogue_allows_repeated_purchase_without_reroll() -> void:
	var cells: Array[Vector2i] = _trial.field.get_buildable_cells()
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cells[0])), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cells[1])), "")
	assert_eq(_trial.field.towers.size(), 2)
	assert_true(_trial.offers.is_empty(), "Случайный прилавок построек не используется")


func test_gap_between_plots_cannot_hold_building() -> void:
	var cell: Vector2i = _trial.field.get_buildable_cells()[0] + Vector2i.RIGHT
	var gold: int = _trial.gold
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cell)), "")
	assert_eq(_trial.gold, gold)
	assert_true(_trial.field.towers.is_empty())


func test_plot_mode_rejects_copy_merging_without_mutation() -> void:
	var data: TowerData = _settings.combat.towers[0]
	var first: TowerState = _trial.field.add_tower(data, Vector2i(7, 8), 0)
	var second: TowerState = _trial.field.add_tower(data, Vector2i(9, 8), 0)
	var gold: int = _trial.gold
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.MERGE,
		second.id, Vector2i.ZERO, 0, first.id)), "")
	assert_eq(_trial.field.towers.size(), 2)
	assert_eq(second.level, 1)
	assert_eq(_trial.gold, gold)


func test_never_fired_building_refunds_full_price() -> void:
	var gold: int = _trial.gold
	var cell: Vector2i = _trial.field.get_buildable_cells()[0]
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cell)), "")
	assert_eq(_trial.field.towers.size(), 1)
	if _trial.field.towers.is_empty():
		return
	var tower: TowerState = _trial.field.towers[0]
	_trial.tick_count += 300
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.SELL,
		0, Vector2i.ZERO, 0, tower.id)), "")
	assert_eq(_trial.gold, gold)


func test_catalogue_has_three_tiers_for_each_god_in_separate_resources() -> void:
	var gods: Dictionary[StringName, Array] = {}
	for data: TowerData in _settings.combat.towers:
		assert_true(data.resource_path.begins_with("res://data/ritual/buildings/"))
		assert_eq(data.shape.size(), 1)
		if not gods.has(data.god):
			gods[data.god] = []
		gods[data.god].append(data.tier)
		var levels: RitualBuildingLevels = _settings.levels_for(data)
		assert_not_null(levels)
		if levels == null:
			continue
		assert_eq(levels.branches.size(), 2)
		assert_false(levels.role.is_empty())
		for branch: RitualSpecialisation in levels.branches:
			assert_false(branch.title.is_empty())
			assert_not_null(branch.at_level(3))
			assert_not_null(branch.at_level(4))
	assert_eq(gods.size(), 7)
	for god: StringName in gods:
		gods[god].sort()
		assert_eq(gods[god], [1, 2, 3], str(god))


func test_city_unlocks_plots_and_catalogue_tiers() -> void:
	var second: int = _index(&"furnace")
	var third: int = _index(&"cinder")
	var cell: Vector2i = _trial.field.get_buildable_cells()[0]
	var gold: int = _trial.gold
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, second, cell)), "")
	assert_eq(_trial.gold, gold)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(_trial.city_level(), 2)
	assert_eq(_trial.field.get_buildable_cells().size(), 16)
	assert_eq(_trial.building_unlock_error(second), "")
	assert_ne(_trial.building_unlock_error(third), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(_trial.city_level(), 3)
	assert_eq(_trial.field.get_buildable_cells().size(), 22)
	assert_eq(_trial.building_unlock_error(third), "")


func test_unlocked_plots_stay_inside_visible_city_regions() -> void:
	for city: int in range(1, 4):
		if city > 1:
			assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
		for cell: Vector2i in _trial.field.get_buildable_cells():
			var inside: bool = false
			for region: Rect2i in _trial.field.open_regions():
				inside = inside or region.has_point(cell)
			assert_true(inside, "Город %d, участок %s" % [city, cell])


func test_upgrade_charges_gold_installs_and_keeps_condition_ratio() -> void:
	var house: RitualTower = _buy_house()
	_finish_build(house)
	house.durability = _settings.max_durability(1) / 2
	var cost: int = _trial.upgrade_cost(house)
	var gold: int = _trial.gold
	assert_eq(cost, _settings.costs[0] * 150 / 100)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(house.level, 2)
	assert_eq(_trial.gold, gold - cost)
	assert_eq(house.action_lock_ticks, _settings.install_ticks)
	assert_eq(house.durability, _settings.max_durability(2) / 2)
	assert_eq(house.invested_total, _settings.costs[0] + cost)
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")


func test_specialisation_requires_city_two_and_survives_snapshot() -> void:
	var house: RitualTower = _buy_house()
	_finish_build(house)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	_finish_build(house)
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.SPECIALISE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.SPECIALISE,
		1, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(house.level, 3)
	assert_eq(house.branch, 1)
	var state: Dictionary = _trial.snapshot()
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, state)
	assert_not_null(restored)
	if restored == null:
		return
	var copy: RitualTower = restored.field.get_tower(house.id) as RitualTower
	assert_not_null(copy)
	assert_eq(copy.branch, 1)
	assert_eq(copy.investments, house.investments)
	assert_eq(restored.state_hash(), _trial.state_hash())
	assert_string_contains(_settings.level_behavior(copy).note, "Бронебой")


func test_fourth_upgrade_requires_city_three_and_keeps_branch() -> void:
	var house: RitualTower = _buy_house()
	_finish_build(house)
	_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE, 0, Vector2i.ZERO, 0, house.id))
	_finish_build(house)
	_trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
	_trial.execute(RitualCommand.new(RitualCommand.Action.SPECIALISE, 0, Vector2i.ZERO, 0, house.id))
	_finish_build(house)
	assert_ne(_trial.upgrade_error(house), "")
	_trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(house.level, 4)
	assert_eq(house.branch, 0)
	assert_ne(_trial.upgrade_error(house), "")


func test_recent_upgrade_refunds_only_its_share_in_full() -> void:
	var house: RitualTower = _buy_house()
	_finish_build(house)
	_trial.field.spawn_mob(0).progress = 3000
	_trial.field.prepare_tick(_trial.tick_count)
	_trial.field.fire_trial_towers()
	assert_true(house.used, "Дом действительно выстрелил")
	_trial.tick_count = _settings.sell_undo_ticks + 1
	var old_share: int = _settings.costs[0] * _settings.plot_sell_percent / 100
	var upgrade: int = _trial.upgrade_cost(house)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(_trial.sell_value(house), old_share + upgrade)
	_trial.tick_count += _settings.sell_undo_ticks + 1
	assert_eq(_trial.sell_value(house), old_share + upgrade * _settings.plot_sell_percent / 100)


func test_night_upgrade_uses_surcharge_and_night_install() -> void:
	var house: RitualTower = _buy_house()
	_finish_build(house)
	var day_cost: int = _trial.upgrade_cost(house)
	_trial.tick_count = _settings.nights.night_start(1)
	assert_eq(_trial.upgrade_cost(house), day_cost * _settings.night_cost_percent / 100)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	assert_eq(house.action_lock_ticks, _settings.night_install_ticks)


func test_inspecting_supported_house_does_not_change_state_hash() -> void:
	var house: RitualTower = _buy_house()
	_trial.field.add_tower(_settings.combat.towers[_index(&"dew")], Vector2i(9, 8), 0)
	var before: int = _trial.state_hash()
	_trial.field.get_tower_damage(house)
	_trial.field.get_tower_cooldown(house)
	_trial.field.get_tower_targets(house)
	assert_eq(_trial.state_hash(), before)


func test_same_catalogue_commands_replay_to_the_same_hash() -> void:
	var settings: RitualTrialConfig = _settings.duplicate(true) as RitualTrialConfig
	settings.start_gold = 10000
	var trial: RitualTrial = RitualTrial.new(settings, 0, 11)
	var cell: Vector2i = trial.field.get_buildable_cells()[0]
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cell)), "")
	var house: TowerState = trial.field.towers[0]
	while house.action_lock_ticks > 0:
		trial.tick()
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.UPGRADE,
		0, Vector2i.ZERO, 0, house.id)), "")
	while house.action_lock_ticks > 0:
		trial.tick()
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SPECIALISE,
		0, Vector2i.ZERO, 0, house.id)), "")
	var report: Dictionary = JSON.parse_string(JSON.stringify(RitualTrialRecord.build_report(trial)))
	var replay: RitualTrial = RitualTrialRecord.replay(report, settings)
	assert_not_null(replay)
	if replay != null:
		assert_eq(replay.state_hash(), trial.state_hash())


func test_duplicate_rules_and_loaded_rules_have_identical_state_hash() -> void:
	var copy: RitualTrialConfig = _settings.duplicate(true) as RitualTrialConfig
	var trial: RitualTrial = RitualTrial.new(copy, 0, 17)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0,
		trial.field.get_buildable_cells()[0])), "")
	for tick: int in 30:
		trial.tick()
	var report: Dictionary = JSON.parse_string(JSON.stringify(RitualTrialRecord.build_report(trial)))
	var replay: RitualTrial = RitualTrialRecord.replay(report, _settings)
	assert_not_null(replay)
	if replay != null:
		assert_eq(replay.rules_hash, trial.rules_hash)
		assert_eq(replay.state_hash(), trial.state_hash(), "Путь ресурса не является состоянием симуляции")


func test_branch_changes_role_and_upgrade_discount_uses_idol() -> void:
	var house: RitualTower = _buy_house()
	house.level = 3
	house.branch = 0
	var volley: int = _trial.field.get_tower_targets(house)
	house.branch = 1
	assert_true(_trial.field.get_tower_targets(house) < volley)
	assert_true(_settings.level_behavior(house).armor_pierce > 0)
	house.level = 1
	house.branch = -1
	var full_cost: int = _trial.upgrade_cost(house)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0)), "")
	assert_true(_trial.upgrade_cost(house) < full_cost)


## docs/37 UI-3: весь каталог в нижнем доке сразу (7 богов × 3 тира), покупка его не меняет.
func test_dock_shows_whole_catalogue_and_keeps_cards_after_purchase() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._pick_hero(0)
	panel._paused = true
	assert_eq(RitualStateCodec.integer(panel.shop_report()["cards"]), 21)
	assert_false(RitualStateCodec.boolean(panel.shop_report()["reroll"]))
	panel._choose_purchase(0)
	panel._on_cell(panel.trial.field.get_buildable_cells()[0], false)
	assert_eq(panel.trial.field.towers.size(), 1)
	assert_eq(RitualStateCodec.integer(panel.shop_report()["cards"]), 21)


func test_panel_exposes_upgrade_branches_and_night_price_explanation() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._pick_hero(0)
	panel._paused = true
	panel.trial.gold = 10000
	var cell: Vector2i = panel.trial.field.get_buildable_cells()[0]
	panel._choose_purchase(0)
	panel._on_cell(cell, false)
	panel._on_cell(cell, false)
	while panel.trial.field.towers[0].action_lock_ticks > 0:
		panel.trial.tick()
	panel._refresh()
	var upgrade: Button = _button_in(panel, "UpgradeHouse")
	assert_true(upgrade.visible)
	assert_false(upgrade.disabled)
	upgrade.pressed.emit()
	assert_eq(panel.trial.field.towers[0].level, 2)
	panel._refresh()
	assert_true(_button_in(panel, "SpecialiseHouse0").visible)
	assert_true(_button_in(panel, "SpecialiseHouse1").visible)
	assert_true(_button_in(panel, "SpecialiseHouse0").disabled, "Город 1 еще не открывает специализацию")
	panel.trial.tick_count = _settings.nights.night_start(1)
	panel._refresh()
	var night: int = 0
	for node: Node in panel.find_children("CatalogueChip_*", "", true, false):
		var chip: RitualBuildChip = node as RitualBuildChip
		if chip.locked_text.is_empty():
			night += int(chip.at_night)
			assert_string_contains(chip.tooltip_text, "Ночной вызов")
			assert_string_contains(chip.tooltip_text, "+50%")
	assert_eq(night, 7, "Ночная цена у всех открытых домов первого тира")
	var upgrade_badge: Label = panel.find_child("UpgradeNightSurcharge", true, false) as Label
	assert_not_null(upgrade_badge, "Наценка видна и возле улучшений")
	if upgrade_badge != null:
		assert_true(upgrade_badge.is_visible_in_tree())
		assert_string_contains(upgrade_badge.tooltip_text, "Ночной вызов")


func test_right_click_on_catalogue_card_cancels_without_rotation() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._pick_hero(0)
	panel._paused = true
	panel._choose_purchase(0)
	var card: Control = panel.find_child("CatalogueChip_bolt", true, false) as Control
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	card.call("_gui_input", event)
	assert_eq(panel.board.preview_rotation, 0)
	assert_eq(panel.board.action, &"")


func test_dawn_announces_houses_needing_repair() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._pick_hero(0)
	panel._paused = true
	panel._choose_purchase(0)
	panel._on_cell(panel.trial.field.get_buildable_cells()[0], false)
	var house: TowerState = panel.trial.field.towers[0]
	house.durability = _settings.max_durability(house.level) / 2
	house.action_lock_ticks = 0
	assert_string_contains(panel._selection_text(house), "урон %d%%" % _settings.worn_damage_percent)
	panel.trial.field.towers[0].durability = 0
	panel.trial.tick_count = _settings.nights.night_end(1)
	panel.trial.tick()
	panel._refresh()
	assert_string_contains(panel._message.text, "ремонт")


func test_fsr2_default_is_scoped_to_new_ritual_profile() -> void:
	assert_eq(RenderQuality.ritual_antialias(), RenderQuality.Antialias.FSR2)
	assert_eq(RenderQuality.antialias(), RenderQuality.Antialias.TAA_SHARP)
	assert_eq(RenderQuality.sharpen_amount(true), 0.0)
	var viewport: SubViewport = SubViewport.new()
	add_child_autofree(viewport)
	RenderQuality.setup_viewport(viewport, true)
	assert_eq(viewport.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
	RenderQuality.setup_viewport(viewport, false)
	assert_eq(viewport.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)


func test_combat_damage_per_invested_gold_stays_in_upgrade_band() -> void:
	for index: int in _settings.combat.towers.size():
		var data: TowerData = _settings.combat.towers[index]
		if data.damage <= 0:
			continue
		for branch: int in 2:
			var spacing: int = 4 if branch == 0 or data.splash_radius_milli > 0 else 20
			var base_damage: int = _fight_damage(data, 1, branch, spacing)
			var previous_damage: int = base_damage
			var invested: int = _settings.costs[index]
			for level: int in range(2, 5):
				invested += _settings.costs[index] * _settings.upgrade_cost_percent[level - 2] / 100
				var damage: int = _fight_damage(data, level, branch, spacing)
				var ratio: int = damage * _settings.costs[index] * 10000 / (base_damage * invested)
				assert_between(ratio, 8000, 10000, "%s, ветка %d, уровень %d" % [data.id, branch, level])
				assert_gt(damage, previous_damage)
				previous_damage = damage


## Стенд меряет на эталонной прямой дороге (board_city.tres), а не на карте города: так числа
## BLD-10/12 не зависят от раскладки улиц и проулков (docs/37 P3).
func _bench_rules() -> RitualTrialConfig:
	var rules: RitualTrialConfig = _settings.duplicate() as RitualTrialConfig
	rules.combat = _settings.combat.duplicate() as GameConfig
	rules.combat.board = load("res://data/ritual/board_city.tres") as BoardLayout
	rules.alleys = []
	rules.streets = []
	return rules


func _fight_damage(data: TowerData, level: int, branch: int, spacing: int) -> int:
	var field: RitualField = RitualField.new(_bench_rules())
	var house: RitualTower = field.add_tower(data, Vector2i(12, 8), 0) as RitualTower
	house.level = level
	house.branch = branch if level >= 3 else -1
	field.mark_towers_changed()
	return _run_bench_field(field, spacing)


func test_support_of_two_same_tier_houses_matches_damage_investment() -> void:
	var attackers: PackedStringArray = ["bolt", "war_engine", "porok"]
	for id: StringName in [&"wind", &"gale", &"vortex", &"dew", &"water", &"rain"]:
		var support: TowerData = _settings.combat.towers[_index(id)]
		var attacker: TowerData = _settings.combat.towers[_index(StringName(attackers[support.tier - 1]))]
		var support_cost: int = _settings.costs[_index(id)]
		var attacker_cost: int = _settings.costs[_index(attacker.id)]
		for level: int in range(1, 5):
			var base: int = _support_damage(attacker, level)
			var extra: int = _support_damage(attacker, level, attacker) - base
			for branch: int in (2 if level >= 3 else 1):
				var gain: int = _support_damage(attacker, level, support, branch) - base
				var ratio: int = gain * attacker_cost * 100 / maxi(1, extra * support_cost)
				assert_between(ratio, 70, 130, "%s, ветка %d, уровень %d" % [id, branch, level])


func _support_damage(attacker: TowerData, level: int, support: TowerData = null, branch: int = -1) -> int:
	var field: RitualField = RitualField.new(_bench_rules())
	for cell: Vector2i in [Vector2i(12, 8), Vector2i(16, 8)]:
		var house: RitualTower = field.add_tower(attacker, cell, 0) as RitualTower
		house.level = level
		house.branch = 0 if level >= 3 else -1
	if support != null:
		var house: RitualTower = field.add_tower(support, Vector2i(14, 8), 0) as RitualTower
		house.level = level
		house.branch = maxi(0, branch) if level >= 3 else -1
	field.mark_towers_changed()
	return _run_bench_field(field, 20)


func _run_bench_field(field: RitualField, spacing: int) -> int:
	_bench_damage = 0
	field.hit_observed.connect(_count_bench_hit)
	var night: int = 1
	while _settings.nights.night_length(night) < 1500:
		night += 1
	var start: int = _settings.nights.night_start(night)
	var spawned: int = 0
	for tick: int in 1500:
		if spawned < 30 and tick % spacing == 0:
			field.wave_tick = start + tick
			field.spawn_mob(0, 20000)
			spawned += 1
		field.prepare_tick(start + tick)
		field.fire_trial_towers()
		field.finish_tick()
	return _bench_damage


func _count_bench_hit(details: Dictionary) -> void:
	_bench_damage += RitualStateCodec.integer(details.get("hp_damage")) \
		+ RitualStateCodec.integer(details.get("ward_damage"))


func _button_in(panel: Control, control_name: String) -> Button:
	return panel.find_child(control_name, true, false) as Button


func _panel() -> RitualTrialPanel:
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	add_child_autofree(panel)
	return panel


func _index(id: StringName) -> int:
	for index: int in _settings.combat.towers.size():
		if _settings.combat.towers[index].id == id:
			return index
	return -1


func _buy_house() -> RitualTower:
	var cell: Vector2i = _trial.field.get_buildable_cells()[0]
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cell)), "")
	return _trial.field.get_tower_at(cell) as RitualTower


func _finish_build(house: TowerState) -> void:
	while house.action_lock_ticks > 0:
		_trial.tick()


## docs/37 IDL-2: заговор покупают у выбранного идола; пустой идол посвящается богу заговора.
func test_rite_goes_to_chosen_idol() -> void:
	var rite: int = 0
	var god: StringName = _settings.rites[rite].god
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite, Vector2i.ZERO, 0, 3)), "")
	assert_eq(_trial.field.idols[2].god, god, "Посвящён третий идол, а не первый свободный")
	assert_eq(_trial.field.idols[0].god, &"", "Первый идол остался пустым")
	var other: int = -1
	for index: int in _settings.rites.size():
		if _settings.rites[index].god != god:
			other = index
			break
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, other, Vector2i.ZERO, 0, 3)), "",
		"Идол другого бога не берёт чужой заговор")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite, Vector2i.ZERO, 0, 1)), "",
		"Второй идол того же бога не посвятить: бог уже живёт в третьем")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite, Vector2i.ZERO, 0, 9)), "")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite, Vector2i.ZERO, 0, 3)), "")
	assert_eq(_trial.rite_count(rite), 2)


## docs/37 IDL-4 (D7): на 5/10/15 оплаченных заговорах идол бесплатно получает эффект своего бога.
func test_idol_milestones_grant_free_god_effect() -> void:
	assert_false(_settings.idol_milestones.is_empty(), "Вехи описаны в данных")
	var rite: int = 0
	var god: StringName = _settings.rites[rite].god
	var five: RitualIdolMilestone = null
	for milestone: RitualIdolMilestone in _settings.idol_milestones:
		if milestone.god == god and milestone.rites == 5:
			five = milestone
	assert_not_null(five, "У бога первого заговора есть веха 5")
	for index: int in 4:
		assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite)), "")
	var idol: IdolState = _trial.field.get_idol(god)
	var before: Dictionary = RitualStateCodec.capture(idol)
	assert_eq(_trial.idol_rites(idol), 4)
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite)), "")
	var after: Dictionary = RitualStateCodec.capture(idol)
	assert_eq(_trial.idol_rites(idol), 5, "Веха не считается оплаченным заговором")
	var probe: IdolState = IdolState.new()
	probe.apply_rite(five.as_rite(), false)
	var empty: Dictionary = RitualStateCodec.capture(IdolState.new())
	var granted: Dictionary = RitualStateCodec.capture(probe)
	var checked: int = 0
	for key: String in granted:
		if key in ["god", "purchases"] or str(granted[key]) == str(empty[key]):
			continue
		checked += 1
		assert_eq(RitualStateCodec.integer(after[key]) - RitualStateCodec.integer(before[key]),
			RitualStateCodec.integer(granted[key]), "Веха добавила %s" % key)
	assert_eq(checked, 1, "Веха меняет ровно одно свойство идола")
	assert_eq(_trial.next_milestone(idol).rites, 10)
