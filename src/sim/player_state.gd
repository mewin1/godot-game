class_name PlayerState
extends RefCounted
## Игрок в матче: герой, золото, доход, магазин, поле и армия.
## Методы-действия возвращают "" при успехе или текст причины отказа (его показывает интерфейс).

## Сдвиги, которые пробует поворот, если на месте фигура не помещается (от ближних к дальним).
const ROTATE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2),
]

var index: int = 0
var display_name: String = ""
var is_bot: bool = false
## Выбранный герой (null — без героя: старые тесты и матч без выбора).
var hero: HeroData
## Три героя на выбор перед матчем (пусто — выбирать нечего).
var hero_offers: Array[HeroData] = []
var hero_hp: int = 0
## Стартовое HP героя — потолок лечения и точка отсчёта «половины» для Кощея.
var hero_max_hp: int = 0
## Сколько раз за матч нажат навык (от этого растёт цена) и нажат ли он в этом раунде.
var skill_uses: int = 0
var is_skill_used_this_round: bool = false
## Разовая пассивка героя уже сработала (Кощей).
var is_hero_triggered: bool = false
## Последнее сообщение героя для игрока (навык, пассивка).
var hero_message: String = ""
## Правила от героя: бесплатные обновления витрины в раунде, продажа за 100%,
## скидка на повышение магазина, «Варево» (следующая башня на N уровней выше).
var free_rerolls_per_round: int = 0
var free_rerolls_left: int = 0
var has_full_refund: bool = false
var shop_upgrade_discount: int = 0
var next_tower_bonus_levels: int = 0
## «Тройка → открытие»: постройки на выбор (пусто — выбирать нечего) и подарки, ждущие места.
var discover_offers: Array[TowerData] = []
var gift_towers: Array[TowerData] = []
var gold: int = 0
var income: int = 0
var is_alive: bool = true
## Итоговое место (1–5); 0 — пока в игре.
var place: int = 0
## Тик, на котором HP героя впервые упало до 0 (-1 — ещё стоит). Если несколько героев падают
## в одном раунде, выше место у того, кто продержался дольше.
var fell_tick: int = -1
## Сколько HP сняла армия игрока у соперников в текущем раунде (для сводки после волны и логов).
var army_damage_dealt: int = 0
var is_ready: bool = false
## Бафы на выбор (пусто — выбирать нечего).
var buff_offers: Array[SendBuffData] = []
var shop: ShopState
var field: FieldState
var army: ArmyState
var rng: RandomNumberGenerator

var _config: GameConfig


func _init(config: GameConfig, player_index: int, seed_value: int) -> void:
	_config = config
	index = player_index
	hero_hp = config.hero_hp
	hero_max_hp = config.hero_hp
	gold = config.start_gold
	income = config.base_income
	shop = ShopState.new(config)
	field = FieldState.new(config, shop.level)
	army = ArmyState.new(config)
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


#region Башни

func buy_tower(offer_index: int, anchor: Vector2i, rotation: int) -> String:
	var data: TowerData = shop.get_offer(offer_index)
	var error: String = _check_can_buy(data)
	if error != "":
		return error
	if not field.can_place_tower_data(data, anchor, rotation):
		return "Сюда не встанет"
	_pay_for_offer(offer_index)
	var tower: TowerState = field.add_tower(data, anchor, rotation)
	_add_investment(tower, _config.tower_cost)
	_apply_brew(tower, 0)
	return ""


## Покупка копии прямо в башню того же вида 1-го уровня — сразу слияние.
func buy_tower_into(offer_index: int, target_id: int) -> String:
	var data: TowerData = shop.get_offer(offer_index)
	var error: String = _check_can_buy(data)
	if error != "":
		return error
	var target: TowerState = field.get_tower(target_id)
	if target == null or target.data != data or target.level != 1:
		return "Слить можно только с такой же башней 1-го уровня"
	_pay_for_offer(offer_index)
	_add_investment(target, _config.tower_cost)
	_apply_brew(target, 1)
	return ""


func move_tower(tower_id: int, anchor: Vector2i, rotation: int) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Нет такой башни"
	if not field.move_tower(tower, anchor, rotation):
		return "Сюда не встанет"
	return ""


## Поворот на 90° по часовой. Сначала пробует то же место, потом ближайшие сдвиги
## (порядок перебора фиксированный — детерминизм).
func rotate_tower(tower_id: int) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Нет такой башни"
	var turns: int = (tower.rotation + 1) % TowerState.ROTATIONS
	for offset: Vector2i in ROTATE_OFFSETS:
		if field.move_tower(tower, tower.anchor + offset, turns):
			return ""
	return "Повёрнутая башня здесь не помещается"


## Две одинаковые башни одного уровня → одна (target) уровнем выше. Клетки source освобождаются.
func merge_towers(source_id: int, target_id: int) -> String:
	var source: TowerState = field.get_tower(source_id)
	var target: TowerState = field.get_tower(target_id)
	if source == null or target == null or source == target:
		return "Нет такой башни"
	if source.data != target.data or source.level != target.level:
		return "Сливаются только одинаковые башни одного уровня"
	if target.level >= _config.max_tower_level:
		return "Уровень уже максимальный"
	target.level += 1
	target.invested_total += source.invested_total
	target.invested_this_phase += source.invested_this_phase
	field.remove_tower(source)
	field.mark_towers_changed()
	_check_discover(target)
	return ""


## Купленное в эту фазу возвращается полностью, остальное — на треть (округление вниз).
func get_sell_price(tower: TowerState) -> int:
	if has_full_refund:
		return tower.invested_total
	var old_part: int = tower.invested_total - tower.invested_this_phase
	return tower.invested_this_phase + old_part / _config.sell_divisor


func sell_tower(tower_id: int) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Нет такой башни"
	gold += get_sell_price(tower)
	field.remove_tower(tower)
	return ""


## Доход за раунд: свой + от построек на поле (лавки).
func get_total_income() -> int:
	return income + field.get_round_income()


## Сколько клеток занимают все башни (для логов и анализа).
func get_cells_used() -> int:
	var cells: int = 0
	for tower: TowerState in field.towers:
		cells += tower.data.shape.size()
	return cells


#endregion


#region Магазин

## Цена обновления витрины сейчас (0 — есть бесплатное от героя).
func get_reroll_price() -> int:
	return 0 if free_rerolls_left > 0 else _config.reroll_cost


func reroll_shop() -> String:
	var price: int = get_reroll_price()
	if gold < price:
		return "Не хватает золота"
	gold -= price
	if price == 0:
		free_rerolls_left -= 1
	shop.roll(rng)
	return ""


## Цена повышения магазина с учётом скидки героя (скидка не опускает цену ниже минимума).
func get_shop_upgrade_price() -> int:
	if shop_upgrade_discount <= 0:
		return shop.upgrade_cost
	return maxi(_config.shop_upgrade_discounted_min_cost, shop.upgrade_cost - shop_upgrade_discount)


func upgrade_shop() -> String:
	if not shop.can_upgrade():
		return "Магазин уже максимального уровня"
	var price: int = get_shop_upgrade_price()
	if gold < price:
		return "Не хватает золота"
	gold -= price
	shop.upgrade(rng)
	field.set_shop_level(shop.level)
	return ""

#endregion


#region Армия

## Купить улучшение армии: действует до конца матча и навсегда добавляет доход.
func buy_army_upgrade(upgrade_index: int) -> String:
	var error: String = army.check_upgrade_available(upgrade_index, shop.level)
	if error != "":
		return error
	var cost: int = army.get_upgrade_cost(upgrade_index)
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	income += army.get_upgrade_income(upgrade_index)
	army.apply_upgrade(upgrade_index)
	return ""


## Выбрать подарок «тройки»: он ждёт в меню, пока его не поставят на поле.
func choose_discover(offer_index: int) -> String:
	if offer_index < 0 or offer_index >= discover_offers.size():
		return "Нет такого подарка"
	gift_towers.append(discover_offers[offer_index])
	discover_offers.clear()
	return ""


## Поставить подарок бесплатно. Стоит как обычная покупка (для продажи — как купленная раньше).
func place_gift(gift_index: int, anchor: Vector2i, rotation: int) -> String:
	if gift_index < 0 or gift_index >= gift_towers.size():
		return "Нет такого подарка"
	var data: TowerData = gift_towers[gift_index]
	if not field.can_place_tower_data(data, anchor, rotation):
		return "Сюда не встанет"
	gift_towers.remove_at(gift_index)
	var tower: TowerState = field.add_tower(data, anchor, rotation)
	tower.invested_total = _config.tower_cost
	return ""


func choose_buff(offer_index: int) -> String:
	if offer_index < 0 or offer_index >= buff_offers.size():
		return "Нет такого бафа"
	_take_buff(offer_index)
	return ""

#endregion


#region Герой

## Применяет выбранного героя: HP, пассивки.
func pick_hero(hero_data: HeroData) -> void:
	hero = hero_data
	hero_offers.clear()
	hero_hp = hero_data.hp
	hero_max_hp = hero_data.hp
	for effect: HeroEffect in hero_data.passives:
		effect.on_picked(self)


## Цена навыка сейчас (0 — навыка нет).
func get_skill_cost() -> int:
	if hero == null or hero.skill == null:
		return 0
	return hero.skill.get_cost(skill_uses)


## "" — навык можно нажать в эту фазу (без учёта золота), иначе причина.
func check_skill_available(phase: MatchSim.Phase) -> String:
	if hero == null or hero.skill == null:
		return "У героя нет навыка"
	if is_skill_used_this_round:
		return "Навык уже был в этом раунде"
	var timing: HeroSkillData.Timing = hero.skill.timing
	if phase != MatchSim.Phase.PREP and phase != MatchSim.Phase.WAVE:
		return "Сейчас навык не нажать"
	if timing == HeroSkillData.Timing.PREP and phase != MatchSim.Phase.PREP:
		return "Навык — только в подготовку"
	if timing == HeroSkillData.Timing.WAVE and phase != MatchSim.Phase.WAVE:
		return "Навык — только в волну"
	return ""


## Нажать навык: проверки, действие, оплата. "" — получилось.
func use_hero_skill(sim: MatchSim) -> String:
	var error: String = check_skill_available(sim.phase)
	if error != "":
		return error
	var cost: int = get_skill_cost()
	if gold < cost:
		return "Не хватает золота"
	error = hero.skill.effect.activate(sim, self)
	if error != "":
		return error
	gold -= cost
	skill_uses += 1
	is_skill_used_this_round = true
	sim.hero_event.emit(index, hero_message)
	return ""


## Сообщает пассивкам героя, что HP упало (вызывает MatchSim).
func notify_hp_lost(sim: MatchSim) -> void:
	if hero == null:
		return
	for effect: HeroEffect in hero.passives:
		effect.on_hp_lost(sim, self)

#endregion


#region Фазы

## Начало подготовки: новая витрина, сброс флагов. offer_buffs — после битвы есть выбор бафа.
func start_prep(offer_buffs: bool) -> void:
	is_ready = false
	is_skill_used_this_round = false
	free_rerolls_left = free_rerolls_per_round
	if shop.is_frozen:
		shop.thaw(rng)
	else:
		shop.roll(rng)
	if offer_buffs:
		buff_offers = army.roll_buff_offers(shop.level, rng)


## Конец подготовки: невыбранный баф выбирается сам (первый), чтобы не потерять его.
func end_prep() -> void:
	if not buff_offers.is_empty():
		_take_buff(0)
	if not discover_offers.is_empty():
		choose_discover(0)
	for tower: TowerState in field.towers:
		tower.invested_this_phase = 0


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_many([index, hero_hp, gold, income, int(is_alive), place, fell_tick,
			army_damage_dealt, buff_offers.size(), skill_uses, int(is_skill_used_this_round),
			int(is_hero_triggered), free_rerolls_left, next_tower_bonus_levels,
			discover_offers.size(), gift_towers.size()])
	hasher.add_string(String(hero.id) if hero != null else "-")
	shop.add_to_hash(hasher)
	army.add_to_hash(hasher)
	field.add_to_hash(hasher)

#endregion


func _check_can_buy(data: TowerData) -> String:
	if data == null:
		return "Этого предложения уже нет"
	if gold < _config.tower_cost:
		return "Не хватает золота"
	return ""


func _pay_for_offer(offer_index: int) -> void:
	gold -= _config.tower_cost
	shop.remove_offer(offer_index)


## «Варево»: башня сразу на несколько уровней выше. already_gained — уровни от самой покупки.
func _apply_brew(tower: TowerState, already_gained: int) -> void:
	var gained: int = already_gained + next_tower_bonus_levels
	next_tower_bonus_levels = 0
	tower.level = mini(tower.level + gained, _config.max_tower_level)
	field.mark_towers_changed()
	if gained > 0:
		_check_discover(tower)


## Постройка дошла до максимального уровня — выбор подарка из следующего тира.
func _check_discover(tower: TowerState) -> void:
	if tower.level < _config.max_tower_level or not discover_offers.is_empty():
		return
	var max_tier: int = 1
	for data: TowerData in _config.towers:
		max_tier = maxi(max_tier, data.tier)
	var tier: int = mini(shop.level + _config.discover_tier_offset, max_tier)
	var pool: Array[TowerData] = []
	for data: TowerData in _config.towers:
		if data.tier == tier:
			pool.append(data)
	for i: int in mini(_config.discover_offer_count, pool.size()):
		discover_offers.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


func _take_buff(offer_index: int) -> void:
	army.add_buff(buff_offers[offer_index])
	buff_offers.clear()


func _add_investment(tower: TowerState, amount: int) -> void:
	tower.invested_total += amount
	tower.invested_this_phase += amount
