extends GutTest
## docs/37 P4: реакции забега — перезарядки (RX-1..3), ни одна пара не снижает урон (RX-9),
## изменения только в копиях забега (RX-12).

const PAIRS: PackedStringArray = ["water+spark", "water+rime", "brazier+rime", "brazier+spark", "hex+rime",
	"water+brazier", "water+hex"]
const SPOTS: Array[Vector2i] = [Vector2i(12, 8), Vector2i(14, 8)]

var _settings: RitualTrialConfig
var _damage: int = 0


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


## Эталонная прямая дорога, как у стенда (tools/ritual_bench.gd).
func _bench_rules() -> RitualTrialConfig:
	var rules: RitualTrialConfig = _settings.duplicate() as RitualTrialConfig
	rules.combat = _settings.combat.duplicate() as GameConfig
	rules.combat.board = load("res://data/ritual/board_city.tres") as BoardLayout
	rules.alleys = []
	rules.streets = []
	return rules


func _data(id: String) -> TowerData:
	for data: TowerData in _settings.combat.towers:
		if String(data.id) == id:
			return data
	return null


## Урон домов 1-го уровня на местах SPOTS по 30 мертвякам (spacing — тики между ними).
func _fight(ids: PackedStringArray, slots: Array[int], spacing: int) -> int:
	var field: RitualField = RitualField.new(_bench_rules())
	for index: int in ids.size():
		field.add_tower(_data(ids[index]), SPOTS[slots[index]], 0)
	field.mark_towers_changed()
	_damage = 0
	field.hit_observed.connect(_count)
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
	return _damage


func _count(details: Dictionary) -> void:
	_damage += RitualStateCodec.integer(details.get("hp_damage")) + RitualStateCodec.integer(details.get("ward_damage"))


## RX-9: каждая пара с реакцией даёт не меньше +10% к сумме одиночек (цепочкой и толпой).
func test_every_reaction_pair_adds_damage() -> void:
	for text: String in PAIRS:
		var pair: PackedStringArray = text.split("+")
		for spacing: int in [20, 4]:
			var alone: int = _fight(PackedStringArray([pair[0]]), [0], spacing) \
				+ _fight(PackedStringArray([pair[1]]), [1], spacing)
			var both: int = _fight(pair, [0, 1], spacing)
			assert_true(both * 100 >= alone * 110, "%s+%s, шаг %d: %d против %d" % [
				pair[0], pair[1], spacing, both, alone])


## RX-12: забег берёт свои копии реакций, общие файлы PvP и опыта не изменены.
func test_endless_uses_own_reaction_copies() -> void:
	for reaction: ReactionData in _settings.combat.reactions:
		assert_true(reaction.resource_path.begins_with("res://data/ritual/reactions/"), reaction.resource_path)
	var shared: ReactionData = load("res://data/reactions/steam.tres") as ReactionData
	assert_eq(shared.cooldown_ticks, 0)
	assert_true(shared.suppress_status)
	var pvp: GameConfig = load("res://data/game_config.tres") as GameConfig
	assert_eq(pvp.reaction_gate_ticks, 0)


## RX-2: одна и та же реакция на враге не срабатывает, пока не прошла перезарядка.
func test_reaction_cooldown_blocks_repeat_on_same_enemy() -> void:
	var field: RitualField = RitualField.new(_bench_rules())
	var spark: TowerState = field.add_tower(_data("spark"), SPOTS[0], 0)
	var mob: MobState = field.spawn_mob(0, 100000)
	var chain: ReactionData = null
	for reaction: ReactionData in _settings.combat.reactions:
		if reaction.id == &"chain":
			chain = reaction
	assert_true(chain.cooldown_ticks > 0)
	field.wave_tick = 1000
	mob.wet_ticks_left = 200
	DivineCombat.hit(field, spark, mob, 10)
	var ready: int = mob.reaction_ready.get(&"chain", 0)
	assert_true(ready > field.wave_tick, "Перезарядка цепи началась")
	mob.wet_ticks_left = 200
	assert_true(DivineCombat.is_reaction_blocked(field, mob, chain), "Сразу повторить нельзя")
	field.wave_tick += chain.cooldown_ticks
	assert_false(DivineCombat.is_reaction_blocked(field, mob, chain), "После перезарядки — можно")


## RX-3: после любой реакции на враге — общий короткий запрет.
func test_reaction_gate_blocks_any_reaction_briefly() -> void:
	var field: RitualField = RitualField.new(_bench_rules())
	var mob: MobState = field.spawn_mob(0, 100000)
	var steam: ReactionData = null
	for reaction: ReactionData in _settings.combat.reactions:
		if reaction.id == &"steam":
			steam = reaction
	assert_true(_settings.combat.reaction_gate_ticks > 0)
	field.wave_tick = 500
	mob.reaction_gate_until = 505
	assert_true(DivineCombat.is_reaction_blocked(field, mob, steam))
	field.wave_tick = 505
	assert_false(DivineCombat.is_reaction_blocked(field, mob, steam))


## RX-1: дом ставит свой статус одному врагу не чаще раза за перезарядку, а урон — всегда.
func test_status_cooldown_limits_reapplication() -> void:
	var field: RitualField = RitualField.new(_bench_rules())
	var water: TowerState = field.add_tower(_data("water"), SPOTS[0], 0)
	var mob: MobState = field.spawn_mob(0, 100000)
	assert_true(water.data.status_apply_cooldown_ticks > 0)
	field.wave_tick = 100
	DivineCombat.hit(field, water, mob, 5)
	assert_true(mob.wet_ticks_left > 0)
	mob.wet_ticks_left = 0
	field.wave_tick = 101
	var hp: int = mob.hp
	DivineCombat.hit(field, water, mob, 5)
	assert_eq(mob.wet_ticks_left, 0, "Статус на перезарядке")
	assert_true(mob.hp < hp, "Урон проходит")
	field.wave_tick = 100 + water.data.status_apply_cooldown_ticks
	DivineCombat.hit(field, water, mob, 5)
	assert_true(mob.wet_ticks_left > 0, "После перезарядки статус снова ставится")
