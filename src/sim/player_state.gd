class_name PlayerState
extends RefCounted
## Игрок в матче: герой, золото, доход, магазин, поле и армия отправки.
## Методы-действия возвращают "" при успехе или текст причины отказа (его показывает интерфейс).

var index: int = 0
var display_name: String = ""
var is_bot: bool = false
var hero_hp: int = 0
var gold: int = 0
var income: int = 0
var is_alive: bool = true
## Итоговое место (1–5); 0 — пока в игре.
var place: int = 0
var is_ready: bool = false
var has_sent_this_round: bool = false
## Пачка, отправленная в эту подготовку; уйдёт сопернику в начале волны.
var pending_pack: Array[MobState] = []
## Бафы на выбор (пусто — выбирать нечего).
var buff_offers: Array[SendBuffData] = []
var shop: ShopState
var field: FieldState
var army: SendArmy
var rng: RandomNumberGenerator

var _config: GameConfig


func _init(config: GameConfig, player_index: int, seed_value: int) -> void:
	_config = config
	index = player_index
	hero_hp = config.hero_hp
	gold = config.start_gold
	income = config.base_income
	shop = ShopState.new(config)
	field = FieldState.new(config, shop.level)
	army = SendArmy.new(config)
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
	target.level += 1
	return ""


func move_tower(tower_id: int, anchor: Vector2i, rotation: int) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Нет такой башни"
	if not field.move_tower(tower, anchor, rotation):
		return "Сюда не встанет"
	return ""


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
	return ""


## Купленное в эту фазу возвращается полностью, остальное — на треть (округление вниз).
func get_sell_price(tower: TowerState) -> int:
	var old_part: int = tower.invested_total - tower.invested_this_phase
	return tower.invested_this_phase + old_part / _config.sell_divisor


func sell_tower(tower_id: int) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Нет такой башни"
	gold += get_sell_price(tower)
	field.remove_tower(tower)
	return ""

#endregion


#region Магазин

func reroll_shop() -> String:
	if gold < _config.reroll_cost:
		return "Не хватает золота"
	gold -= _config.reroll_cost
	shop.roll(rng)
	return ""


func upgrade_shop() -> String:
	if not shop.can_upgrade():
		return "Магазин уже максимального уровня"
	if gold < shop.upgrade_cost:
		return "Не хватает золота"
	gold -= shop.upgrade_cost
	shop.upgrade(rng)
	field.set_shop_level(shop.level)
	return ""

#endregion


#region Отправка

func send_units(round_number: int) -> String:
	if has_sent_this_round:
		return "Отправка уже была в этом раунде"
	var cost: int = army.get_send_cost(round_number)
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	has_sent_this_round = true
	army.sends_done += 1
	income += army.get_income_gain()
	pending_pack = army.build_pack(index, cost, round_number)
	return ""


func choose_buff(offer_index: int) -> String:
	if offer_index < 0 or offer_index >= buff_offers.size():
		return "Нет такого бафа"
	_take_buff(offer_index)
	return ""

#endregion


#region Фазы

## Начало подготовки: новая витрина, сброс флагов. offer_buffs — после битвы есть выбор бафа.
func start_prep(offer_buffs: bool) -> void:
	is_ready = false
	has_sent_this_round = false
	pending_pack.clear()
	shop.roll(rng)
	if offer_buffs:
		buff_offers = army.roll_buff_offers(shop.level, rng)


## Конец подготовки: невыбранный баф выбирается сам (первый), чтобы не потерять его.
func end_prep() -> void:
	if not buff_offers.is_empty():
		_take_buff(0)
	for tower: TowerState in field.towers:
		tower.invested_this_phase = 0


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_many([index, hero_hp, gold, income, int(is_alive), place,
			int(has_sent_this_round), pending_pack.size(), buff_offers.size()])
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


func _take_buff(offer_index: int) -> void:
	army.add_buff(buff_offers[offer_index])
	buff_offers.clear()


func _add_investment(tower: TowerState, amount: int) -> void:
	tower.invested_total += amount
	tower.invested_this_phase += amount
