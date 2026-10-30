class_name ArmyState
extends RefCounted
## Армия игрока: каждый раунд сама идёт на поле соперника. Сила растёт от прокачки за золото
## (вкладка «Армия») и от бесплатных бафов после боя.

var buffs: Array[SendBuffData] = []
var hp_percent: int = 0
var speed_percent: int = 0
var extra_units: int = 0
## Скидка на прокачку и доход сверху за каждую прокачку (от бафов).
var cost_discount: int = 0
var extra_income: int = 0
var added_mobs: Array[MobData] = []
## Юниты только на ближайшую волну (навык героя); убираются в начале следующего раунда.
var temporary_mobs: Array[MobData] = []
## «Злость армии» в процентах HP (см. GameConfig.army_rage_percent).
var rage_percent: int = 0
## Сколько раз куплено каждое улучшение (по порядку config.army_upgrades).
var upgrade_counts: Array[int] = []

var _config: GameConfig


func _init(config: GameConfig) -> void:
	_config = config
	for i: int in config.army_upgrades.size():
		upgrade_counts.append(0)


func add_buff(buff: SendBuffData) -> void:
	buffs.append(buff)
	_apply_effect(buff.kind, buff.value, buff.mob)


#region Прокачка

func get_upgrade(index: int) -> ArmyUpgradeData:
	if index < 0 or index >= _config.army_upgrades.size():
		return null
	return _config.army_upgrades[index]


## Цена следующей покупки улучшения с учётом скидки от бафов (не ниже минимума).
func get_upgrade_cost(index: int) -> int:
	var upgrade: ArmyUpgradeData = get_upgrade(index)
	var cost: int = upgrade.base_cost + upgrade.cost_step * upgrade_counts[index] - cost_discount
	return maxi(_config.army_upgrade_min_cost, cost)


## Сколько дохода навсегда даст следующая покупка: процент от базовой цены (не меньше 1) + бафы.
## Первая покупка окупается за ~100 / army_income_percent раундов, повторные (дороже) — дольше.
func get_upgrade_income(index: int) -> int:
	var from_cost: int = get_upgrade(index).base_cost * _config.army_income_percent / 100
	return maxi(1, from_cost) + extra_income


## "" — можно купить (без учёта золота), иначе причина.
func check_upgrade_available(index: int, shop_level: int) -> String:
	var upgrade: ArmyUpgradeData = get_upgrade(index)
	if upgrade == null:
		return "Нет такого улучшения"
	if shop_level < upgrade.min_shop_level:
		return "нужен магазин ур. %d" % upgrade.min_shop_level
	if upgrade.max_purchases > 0 and upgrade_counts[index] >= upgrade.max_purchases:
		return "куплено максимум раз"
	return ""


## Применяет купленное улучшение (проверки и оплата — у игрока).
func apply_upgrade(index: int) -> void:
	var upgrade: ArmyUpgradeData = get_upgrade(index)
	upgrade_counts[index] += 1
	_apply_effect(upgrade.kind, upgrade.value, upgrade.mob)


func get_total_upgrades() -> int:
	var total: int = 0
	for count: int in upgrade_counts:
		total += count
	return total

#endregion


## Конец раунда: не дошли — злее, прорвались — успокоились.
func update_rage(damage_dealt: int) -> void:
	if damage_dealt > 0:
		rage_percent = 0
	else:
		rage_percent += _config.army_rage_percent


func get_unit_count() -> int:
	return _config.army_base_units + extra_units + added_mobs.size()


## Армия на этот раунд: обычные юниты + добавленные, с бонусами HP и скорости.
## HP понемногу растёт по раундам сам (army_hp_growth_percent), остальное — от прокачки.
func build_pack(sender_index: int, round_number: int) -> Array[MobState]:
	var round_percent: int = _config.get_round_hp_percent(round_number,
			_config.army_hp_growth_percent)
	var hp_bonus: int = round_percent * (100 + hp_percent + rage_percent) / 100 - 100
	var pack: Array[MobState] = []
	for i: int in _config.army_base_units + extra_units:
		pack.append(MobState.create(_config.army_mob, hp_bonus, speed_percent))
	for mob_data: MobData in added_mobs + temporary_mobs:
		pack.append(MobState.create(mob_data, hp_bonus, speed_percent))
	for mob: MobState in pack:
		mob.sender_index = sender_index
		mob.is_angry = rage_percent > 0
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
			added_mobs.size(), temporary_mobs.size(), rage_percent])
	hasher.add_many(upgrade_counts)


func _apply_effect(kind: SendBuffData.Kind, value: int, mob: MobData) -> void:
	match kind:
		SendBuffData.Kind.HP_PERCENT:
			hp_percent += value
		SendBuffData.Kind.SPEED_PERCENT:
			speed_percent += value
		SendBuffData.Kind.EXTRA_UNITS:
			extra_units += value
		SendBuffData.Kind.ADD_MOB:
			for i: int in value:
				added_mobs.append(mob)
		SendBuffData.Kind.COST_DISCOUNT:
			cost_discount += value
		SendBuffData.Kind.EXTRA_INCOME:
			extra_income += value


func _buff_pool(rare: bool, exclude: Array[SendBuffData]) -> Array[SendBuffData]:
	var pool: Array[SendBuffData] = []
	for buff: SendBuffData in _config.send_buffs:
		if buff.is_rare == rare and not exclude.has(buff):
			pool.append(buff)
	return pool
