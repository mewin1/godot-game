extends GutTest
## Приметы ночей (docs/36 §2): с 3-й обычной ночи у ночи своя задача, видна заранее,
## меняет состав пачек; ночь по-прежнему чистая функция сида.

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func _plain() -> RitualTrialConfig:
	var copy: RitualTrialConfig = _settings.duplicate() as RitualTrialConfig
	copy.nights = _settings.nights.duplicate() as RitualNightRules
	copy.nights.omens = []
	return copy


func _share(plan: RitualNightPlan, night: int, favored: Array[int]) -> float:
	var hits: int = 0
	var total: int = 0
	for pack: RitualPack in plan.packs(night):
		if pack.boss:
			continue
		for member: int in pack.members:
			total += 1
			hits += int(favored.has(member))
	return float(hits) / maxf(1.0, float(total))


func test_omens_start_on_third_night_skip_bosses_and_never_repeat() -> void:
	for run_seed: int in [1, 2, 3, 4]:
		var plan: RitualNightPlan = RitualNightPlan.new(_settings, run_seed)
		assert_null(plan.omen(1))
		assert_null(plan.omen(2))
		for night: int in range(3, 25):
			if _settings.nights.is_boss_night(night):
				assert_null(plan.omen(night), "Босс — без приметы")
				continue
			var omen: RitualOmenData = plan.omen(night)
			assert_not_null(omen, "Ночь %d с приметой" % night)
			assert_true(omen.first_night <= night)
			assert_ne(plan.omen_index(night), plan.omen_index(night - 1), "Примета не повторяется подряд")


func test_omen_is_seeded_and_early_nights_unchanged() -> void:
	var a: RitualNightPlan = RitualNightPlan.new(_settings, 9)
	var b: RitualNightPlan = RitualNightPlan.new(_settings, 9)
	var plain: RitualNightPlan = RitualNightPlan.new(_plain(), 9)
	for night: int in range(1, 12):
		assert_eq(a.omen_index(night), b.omen_index(night))
		assert_eq(a.describe(night), b.describe(night))
	assert_eq(a.describe(1), plain.describe(1), "Первые ночи приметы не трогают")
	assert_eq(a.describe(2), plain.describe(2))


func test_omen_changes_composition_towards_its_favorites() -> void:
	var plain: RitualNightPlan = RitualNightPlan.new(_plain(), 0)
	var checked: Dictionary[StringName, bool] = {}
	for run_seed: int in range(1, 30):
		var plan: RitualNightPlan = RitualNightPlan.new(_settings, run_seed)
		plain.run_seed = run_seed
		plain._cache.clear()
		for night: int in range(3, 12):
			var omen: RitualOmenData = plan.omen(night)
			if omen == null or checked.has(omen.id):
				continue
			checked[omen.id] = true
			assert_true(_share(plan, night, omen.favored) > _share(plain, night, omen.favored),
				"%s: любимцев больше, чем в обычной ночи" % omen.title)
			if omen.packs_add != 0:
				assert_eq(plan.packs(night).size() - plain.packs(night).size(), omen.packs_add,
					"%s меняет число пачек" % omen.title)
	assert_eq(checked.size(), _settings.nights.omens.size(), "Проверены все приметы")
