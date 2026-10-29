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
var hero_hp: int = 0
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


## Сколько клеток занимают все башни (для логов и анализа).
func get_cells_used() -> int:
	var cells: int = 0
	for tower: TowerState in field.towers:
		cells += tower.data.shape.size()
	return cells


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
	hasher.add_many([index, hero_hp, gold, income, int(is_alive), place, fell_tick,
			army_damage_dealt, buff_offers.size()])
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
