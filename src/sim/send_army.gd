class_name SendArmy
extends RefCounted
## «Армия» игрока: собранные бафы отправки и сборка пачки юнитов для скилла отправки.

var buffs: Array[SendBuffData] = []
var hp_percent: int = 0
var speed_percent: int = 0
var extra_units: int = 0
var cost_discount: int = 0
var extra_income: int = 0
var added_mobs: Array[MobData] = []
var sends_done: int = 0

var _config: GameConfig


func _init(config: GameConfig) -> void:
	_config = config


func add_buff(buff: SendBuffData) -> void:
	buffs.append(buff)
	match buff.kind:
		SendBuffData.Kind.HP_PERCENT:
			hp_percent += buff.value
		SendBuffData.Kind.SPEED_PERCENT:
			speed_percent += buff.value
		SendBuffData.Kind.EXTRA_UNITS:
			extra_units += buff.value
		SendBuffData.Kind.ADD_MOB:
			for i: int in buff.value:
				added_mobs.append(buff.mob)
		SendBuffData.Kind.COST_DISCOUNT:
			cost_discount += buff.value
		SendBuffData.Kind.EXTRA_INCOME:
			extra_income += buff.value


func get_send_cost(round_number: int) -> int:
	return maxi(_config.send_min_cost, _config.get_send_cost(round_number) - cost_discount)


func get_income_gain() -> int:
	return _config.send_income_bonus + extra_income


func get_pack_size() -> int:
	return _config.send_pack_size + extra_units + added_mobs.size()


## Пачка юнитов с бафами; HP растёт по раундам, как у базовой волны.
## Награда защитнику за всю пачку — процент от цены, делится поровну.
func build_pack(sender_index: int, paid_cost: int, round_number: int) -> Array[MobState]:
	var hp_bonus: int = _config.get_round_hp_percent(round_number) * (100 + hp_percent) / 100 - 100
	var pack: Array[MobState] = []
	for i: int in _config.send_pack_size + extra_units:
		pack.append(MobState.create(_config.send_mob, hp_bonus, speed_percent))
	for mob_data: MobData in added_mobs:
		pack.append(MobState.create(mob_data, hp_bonus, speed_percent))
	var reward_total: int = paid_cost * _config.send_reward_percent / 100
	for i: int in pack.size():
		pack[i].sender_index = sender_index
		pack[i].kill_reward = reward_total / pack.size()
		if i < reward_total % pack.size():
			pack[i].kill_reward += 1
	return pack


## 3 случайных бафа (без повторов). Шанс редкого в каждом слоте зависит от уровня магазина.
func roll_buff_offers(shop_level: int, rng: RandomNumberGenerator) -> Array[SendBuffData]:
	var chances: Array[int] = _config.rare_buff_chance_by_level
	var rare_chance: int = chances[clampi(shop_level, 1, chances.size()) - 1]
	var result: Array[SendBuffData] = []
	for i: int in _config.buff_offer_count:
		var want_rare: bool = rng.randi_range(1, 100) <= rare_chance
		var pool: Array[SendBuffData] = _buff_pool(want_rare, result)
		if pool.is_empty():
			pool = _buff_pool(not want_rare, result)
		if pool.is_empty():
			break
		result.append(pool[rng.randi_range(0, pool.size() - 1)])
	return result


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_many([hp_percent, speed_percent, extra_units, cost_discount, extra_income,
			added_mobs.size(), sends_done])


func _buff_pool(rare: bool, exclude: Array[SendBuffData]) -> Array[SendBuffData]:
	var pool: Array[SendBuffData] = []
	for buff: SendBuffData in _config.send_buffs:
		if buff.is_rare == rare and not exclude.has(buff):
			pool.append(buff)
	return pool
