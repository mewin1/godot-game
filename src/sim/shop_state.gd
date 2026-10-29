class_name ShopState
extends RefCounted
## Магазин игрока: витрина башен, уровень магазина и цена его повышения.

var level: int = 1
## Текущая цена повышения (падает на 1 каждый раунд, пока не повысишь). 0 — уровень максимальный.
var upgrade_cost: int = 0
## Предложения витрины; null — место, где башню уже купили.
var offers: Array[TowerData] = []

var _config: GameConfig


func _init(config: GameConfig) -> void:
	_config = config
	upgrade_cost = config.get_shop_upgrade_cost(level)


func get_offer_count() -> int:
	return _config.shop_base_offers + level - 1


func can_upgrade() -> bool:
	return level < _config.max_shop_level


## Новая витрина целиком (начало раунда или рерол).
func roll(rng: RandomNumberGenerator) -> void:
	offers.clear()
	for i: int in get_offer_count():
		offers.append(_random_tower(rng))


## Убирает купленное предложение с витрины (место остаётся пустым до новой витрины).
func remove_offer(index: int) -> void:
	if index >= 0 and index < offers.size():
		offers[index] = null


func get_offer(index: int) -> TowerData:
	if index < 0 or index >= offers.size():
		return null
	return offers[index]


## Повышает уровень: цена следующего — полная, на витрине появляется ещё одно место.
func upgrade(rng: RandomNumberGenerator) -> void:
	level += 1
	upgrade_cost = _config.get_shop_upgrade_cost(level) if can_upgrade() else 0
	offers.append(_random_tower(rng))


## Начало нового раунда: повышение дешевеет на 1 (не ниже минимума).
func on_round_started() -> void:
	if can_upgrade():
		upgrade_cost = maxi(_config.shop_upgrade_min_cost, upgrade_cost - 1)


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add(level)
	hasher.add(upgrade_cost)
	for data: TowerData in offers:
		hasher.add_string(data.id if data != null else &"-")


## Случайная башня из открытых тиров (тир ≤ уровня магазина), все с равным шансом.
func _random_tower(rng: RandomNumberGenerator) -> TowerData:
	var pool: Array[TowerData] = []
	for data: TowerData in _config.towers:
		if data.tier <= level:
			pool.append(data)
	return pool[rng.randi_range(0, pool.size() - 1)]
