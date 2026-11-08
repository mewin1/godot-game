class_name ArmyState
extends RefCounted
## Армия игрока: каждый раунд сама идёт на поле соперника. Сила растёт от прокачки за золото
## (вкладка «Армия») и от бесплатных бафов после боя.

var buffs: Array[SendBuffData] = []
var hp_percent: int = 0
var speed_percent: int = 0
var extra_units: int = 0
var base_units: int = 0
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
## Индексы улучшений, видимые сейчас в лавке армии (казино — случайное подмножество).
var offers: Array[int] = []
## Подкрепление — часть приобретённых бойцов, базовые бойцы всегда идут сразу.
var reserve_kind: StringName = &""
var reserve_resist: StringName = &""
var reserve_count: int = 0

var _config: GameConfig


func _init(config: GameConfig) -> void:
	_config = config
	base_units = config.army_base_units
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


## Применяет купленное улучшение (проверки и оплата — у игрока). «Дух» получает выбранную стихию.
func apply_upgrade(index: int, element: StringName = &"") -> void:
	var upgrade: ArmyUpgradeData = get_upgrade(index)
	upgrade_counts[index] += 1
	if upgrade.choose_element and upgrade.mob != null:
		var mob: MobData = upgrade.mob.duplicate() as MobData
		mob.resist = element
		for i: int in upgrade.value:
			added_mobs.append(mob)
	else:
		_apply_effect(upgrade.kind, upgrade.value, upgrade.mob)


func get_total_upgrades() -> int:
	var total: int = 0
	for count: int in upgrade_counts:
		total += count
	return total


## Есть ли открытый боец, которого сейчас нельзя купить прямо с витрины.
func has_unoffered_upgrade(shop_level: int) -> bool:
	for index: int in _config.army_upgrades.size():
		if not offers.has(index) and check_upgrade_available(index, shop_level) == "":
			return true
	return false


## Казино армии: army_offer_count случайных открытых юнитов (0 — все открытые, прежние правила).
func roll_offers(shop_level: int, rng: RandomNumberGenerator) -> void:
	offers.clear()
	for i: int in _config.army_upgrades.size():
		if check_upgrade_available(i, shop_level) == "":
			offers.append(i)
	if _config.army_offer_count <= 0 or offers.size() <= _config.army_offer_count:
		return
	while offers.size() > _config.army_offer_count:
		offers.remove_at(rng.randi_range(0, offers.size() - 1))

#endregion


## Конец раунда: не дошли — злее, прорвались — успокоились.
func update_rage(damage_dealt: int) -> void:
	if damage_dealt > 0:
		rage_percent = 0
	else:
		rage_percent += _config.army_rage_percent


func get_unit_count() -> int:
	return base_units + extra_units + added_mobs.size()


func purchased_mobs() -> Array[MobData]:
	var result: Array[MobData] = []
	for i: int in extra_units:
		result.append(_config.army_mob)
	result.append_array(added_mobs)
	return result


func available_reserve_count(kind: StringName, resistance: StringName) -> int:
	var count: int = 0
	for data: MobData in purchased_mobs():
		if data.id == kind and data.resist == resistance:
			count += 1
	return count


func set_reserve(kind: StringName, resistance: StringName, count: int) -> String:
	if count < 0 or count > available_reserve_count(kind, resistance):
		return "В купленной армии нет столько бойцов этого типа"
	reserve_kind = kind if count > 0 else &""
	reserve_resist = resistance if count > 0 else &""
	reserve_count = count
	return ""


## Индексы снимка build_pack: базовые и временные бойцы сюда не попадают.
func reserve_indices() -> Array[int]:
	var result: Array[int] = []
	var purchased: Array[MobData] = purchased_mobs()
	for i: int in purchased.size():
		if result.size() >= reserve_count:
			break
		if purchased[i].id == reserve_kind and purchased[i].resist == reserve_resist:
			result.append(base_units + i)
	return result


## Армия на этот раунд: обычные юниты + добавленные, с бонусами HP и скорости.
## HP понемногу растёт по раундам сам (army_hp_growth_percent), остальное — от прокачки.
func build_pack(sender_index: int, round_number: int) -> Array[MobState]:
	var round_percent: int = _config.get_round_hp_percent(round_number,
			_config.army_hp_growth_percent)
	var hp_bonus: int = round_percent * (100 + hp_percent + rage_percent) / 100 - 100
	var pack: Array[MobState] = []
	for i: int in base_units + extra_units:
		pack.append(MobState.create(_config.army_mob, hp_bonus, speed_percent))
	for mob_data: MobData in added_mobs + temporary_mobs:
		pack.append(MobState.create(mob_data, hp_bonus, speed_percent))
	for mob: MobState in pack:
		if round_number <= _config.army_warmup_percent.size():
			mob.max_hp = maxi(1, mob.max_hp * _config.army_warmup_percent[round_number - 1] / 100)
			mob.hp = mob.max_hp
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
	hasher.add_string(reserve_kind)
	hasher.add_string(reserve_resist)
	hasher.add(reserve_count)
	hasher.add_many([base_units, hp_percent, speed_percent, extra_units, cost_discount, extra_income,
			added_mobs.size(), temporary_mobs.size(), rage_percent])
	hasher.add_many(upgrade_counts)
	hasher.add(offers.size())
	hasher.add_many(offers)
	for data: MobData in added_mobs + temporary_mobs:
		hasher.add_string(data.id)
		hasher.add_string(data.resist)
	for buff: SendBuffData in buffs:
		hasher.add_string(buff.id)


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
