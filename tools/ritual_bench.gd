extends SceneTree
## Стенд построек бесконечного "Обряда" (docs/37 P0, приложение E): постройки по одной и парами у главной
## дороги против одинаковых потоков врагов, урон на вложенное золото по уровням. Стенд - ориентир:
## баланс проверяет автор живой игрой.
## godot --headless --path . -s res://tools/ritual_bench.gd [-- --rules=res://...tres]
## Цена уровня: вложенные покупки и улучшения; для прежних правил - копии слияния.

const TICKS: int = 1500
## Места у главной дороги: первое - для одиночки и первой из пары, второе - для соседа.
const SPOTS: Array[Vector2i] = [Vector2i(12, 9), Vector2i(14, 9)]
## Запас здоровья x200 не ограничивает тяжелые удары новых построек четвертого уровня.
const HP_PERCENT: int = 20000
## Пары с реакцией (docs/37 §2.7 F2) и пара без реакции (ветер отбрасывает от жаровни).
const PAIRS: PackedStringArray = ["water+spark", "water+rime", "brazier+rime", "brazier+spark",
	"hex+rime", "water+brazier", "water+hex", "wind+brazier"]


class Scenario:
	var title: String
	var enemy: StringName
	var count: int
	var spacing: int

	func _init(name: String, enemy_id: StringName, total: int, ticks_apart: int) -> void:
		title = name
		enemy = enemy_id
		count = total
		spacing = ticks_apart


class Placement:
	var id: StringName
	var level: int
	var spot: Vector2i
	var branch: int

	func _init(tower_id: StringName, tower_level: int, cell: Vector2i, specialisation: int = -1) -> void:
		id = tower_id
		level = tower_level
		spot = cell
		branch = specialisation


var _scenarios: Array[Scenario] = [Scenario.new("stream", &"mertvyak", 30, 20),
	Scenario.new("clump", &"mertvyak", 30, 4), Scenario.new("armor4", &"latnik", 20, 20),
	Scenario.new("ward", &"navi_shield", 20, 20)]
var _settings: RitualTrialConfig
var _base_tick: int = 0
var _damage: int = 0


func _initialize() -> void:
	var rules_path: String = "res://data/ritual/endless.tres"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rules="):
			rules_path = argument.trim_prefix("--rules=")
	_settings = (load(rules_path) as RitualTrialConfig).duplicate(true)
	# Эталонная прямая дорога: числа стенда не зависят от раскладки города (docs/37 P3).
	_settings.combat.board = load("res://data/ritual/board_city.tres") as BoardLayout
	_settings.alleys = []
	_settings.streets = []
	# Ночь, которая длиннее стенда: враги идут с ночной скоростью все время.
	var night: int = 1
	while _settings.nights.night_length(night) < TICKS:
		night += 1
	_base_tick = _settings.nights.night_start(night)
	_print_solo()
	_print_pairs()
	_print_support()
	quit()


func _print_solo() -> void:
	print("Урон на золото по уровням 1 / 2 / 3 / 4 (одна постройка, место %s):" % _spot(0))
	for data: TowerData in _settings.combat.towers:
		var branches: Array[int] = [-1]
		if _settings.uses_plots():
			branches.assign([0, 1])
		for branch: int in branches:
			var line: PackedStringArray = []
			for scenario: Scenario in _scenarios:
				var values: PackedStringArray = []
				for level: int in range(1, 5):
					var damage: int = _run([Placement.new(data.id, level, _spot(0), branch)], scenario)
					values.append(str(damage / _gold(data.id, level)))
				line.append("%s %s" % [scenario.title, " / ".join(values)])
			print("  %-12s %s" % ["%s/%d" % [data.id, branch], " | ".join(line)])


func _print_pairs() -> void:
	print("Пары 1-го уровня: урон пары к сумме одиночек на тех же местах, % (stream | clump):")
	for pair: String in PAIRS:
		var ids: PackedStringArray = pair.split("+")
		var line: PackedStringArray = []
		for scenario: Scenario in [_scenarios[0], _scenarios[1]]:
			var first: Placement = Placement.new(StringName(ids[0]), 1, _spot(0))
			var second: Placement = Placement.new(StringName(ids[1]), 1, _spot(1))
			var alone: int = _run([first], scenario) + _run([second], scenario)
			var both: int = _run([first, second], scenario)
			line.append("%+d%%" % (both * 100 / maxi(1, alone) - 100))
		print("  %-16s %s" % [pair, " | ".join(line)])


func _print_support() -> void:
	if _settings.uses_plots():
		_print_plot_support()
		return
	print("Поддержка рядом с самострелом 1-го уровня (stream): прибавка урона на золото поддержки по уровням")
	var stream: Scenario = _scenarios[0]
	var first: Placement = Placement.new(&"bolt", 1, _spot(0))
	var bolt: int = _run([first], stream)
	var second_bolt: int = _run([first, Placement.new(&"bolt", 1, _spot(1))], stream)
	print("  второй самострел: %d" % ((second_bolt - bolt) / _gold(&"bolt", 1)))
	for support: StringName in [&"wind", &"water"]:
		var values: PackedStringArray = []
		for level: int in range(1, 5):
			var both: int = _run([first, Placement.new(support, level, _spot(1))], stream)
			values.append("%d (%+d%%)" % [(both - bolt) / _gold(support, level), both * 100 / maxi(1, bolt) - 100])
		print("  %-8s %s" % [support, " / ".join(values)])


func _print_plot_support() -> void:
	print("Поддержка двух домов своего тира: эффективность к третьему атакующему дому, % (L1 / L2 / L3 / L4):")
	var attackers: PackedStringArray = ["bolt", "war_engine", "porok"]
	for id: StringName in [&"wind", &"gale", &"vortex", &"dew", &"water", &"rain"]:
		var data: TowerData = _tower_data(id)
		var attacker: StringName = StringName(attackers[data.tier - 1])
		var values: PackedStringArray = []
		for level: int in range(1, 5):
			var pair: Array[Placement] = [Placement.new(attacker, level, Vector2i(12, 8)),
				Placement.new(attacker, level, Vector2i(16, 8))]
			var base: int = _run(pair, _scenarios[0])
			pair.append(Placement.new(attacker, level, Vector2i(14, 8)))
			var extra: int = _run(pair, _scenarios[0]) - base
			pair[2] = Placement.new(id, level, Vector2i(14, 8), 1)
			var gain: int = _run(pair, _scenarios[0]) - base
			values.append(str(gain * _gold(attacker, level) * 100 / maxi(1, extra * _gold(id, level))))
		print("  %-8s %s" % [id, " / ".join(values)])


## Урон построек за TICKS тиков против сценария.
func _run(placements: Array[Placement], scenario: Scenario) -> int:
	var field: RitualField = RitualField.new(_settings)
	_damage = 0
	field.hit_observed.connect(_on_hit)
	for placement: Placement in placements:
		var tower: TowerState = field.add_tower(_tower_data(placement.id), placement.spot, 0)
		tower.level = placement.level
		if tower is RitualTower and tower.level >= 3:
			(tower as RitualTower).branch = maxi(0, placement.branch)
	field.mark_towers_changed()
	var enemy: int = _enemy_index(scenario.enemy)
	var spawned: int = 0
	for step: int in TICKS:
		var at_tick: int = _base_tick + step
		if spawned < scenario.count and step % scenario.spacing == 0:
			field.wave_tick = at_tick
			field.spawn_mob(enemy, HP_PERCENT)
			spawned += 1
		field.prepare_tick(at_tick)
		field.fire_trial_towers()
		field.finish_tick()
		field.pending_kill_gold = 0
		field.pending_breaches.clear()
	return _damage


func _on_hit(details: Dictionary) -> void:
	_damage += RitualStateCodec.integer(details.get("hp_damage")) + RitualStateCodec.integer(details.get("ward_damage"))


func _gold(id: StringName, level: int) -> int:
	for index: int in _settings.combat.towers.size():
		if _settings.combat.towers[index].id == id:
			if not _settings.uses_plots():
				return _settings.costs[index] << (level - 1)
			var cost: int = _settings.costs[index]
			for step: int in range(level - 1):
				cost += _settings.costs[index] * _settings.upgrade_cost_percent[step] / 100
			return cost
	return 1


func _spot(index: int) -> Vector2i:
	return Vector2i(12 + 2 * index, 8) if _settings.uses_plots() else SPOTS[index]


func _tower_data(id: StringName) -> TowerData:
	for data: TowerData in _settings.combat.towers:
		if data.id == id:
			return data
	return null


func _enemy_index(id: StringName) -> int:
	for index: int in _settings.enemies.size():
		if _settings.enemies[index].id == id:
			return index
	return 0
