class_name ShopState
extends RefCounted
## Магазин игрока: витрина башен, уровень магазина и цена его повышения.

var active_gods: Array[StringName] = []
var level: int = 1
## Текущая цена повышения (падает на 1 каждый раунд, пока не повысишь). 0 — уровень максимальный.
var upgrade_cost: int = 0
## Предложения витрины; null — место, где башню уже купили.
var offers: Array[TowerData] = []
## Заговор занимает то же место витрины: в offers на этом месте null.
var rite_offers: Array[RiteData] = []
## Мест на витрине сверх обычного (герой).
var extra_offers: int = 0
## Витрина заморожена: в следующем раунде не обновится, докупятся только пустые места.
var is_frozen: bool = false

var _config: GameConfig


func _init(config: GameConfig) -> void:
	_config = config
	upgrade_cost = config.get_shop_upgrade_cost(level)


func get_offer_count() -> int:
	return _config.shop_base_offers + level - 1 + extra_offers


func can_upgrade() -> bool:
	return level < _config.max_shop_level


## Новая витрина целиком (начало раунда или рерол).
func roll(rng: RandomNumberGenerator) -> void:
	offers.clear()
	rite_offers.clear()
	for i: int in get_offer_count():
		_append_offer(rng, i)


## Начало раунда у замороженной витрины: остальное остаётся, пустые места заполняются.
func thaw(rng: RandomNumberGenerator) -> void:
	is_frozen = false
	for i: int in offers.size():
		if offers[i] == null and get_rite(i) == null:
			offers[i] = _random_tower(rng, i < 2)
	while offers.size() < get_offer_count():
		_append_offer(rng, offers.size())


## Убирает купленное предложение с витрины (место остаётся пустым до новой витрины).
func remove_offer(index: int) -> void:
	if index >= 0 and index < offers.size():
		offers[index] = null
		if index < rite_offers.size():
			rite_offers[index] = null


func get_offer(index: int) -> TowerData:
	if index < 0 or index >= offers.size():
		return null
	return offers[index]


## Повышает уровень: цена следующего — полная, на витрине появляется ещё одно место.
func upgrade(rng: RandomNumberGenerator) -> void:
	level += 1
	upgrade_cost = _config.get_shop_upgrade_cost(level) if can_upgrade() else 0
	_append_offer(rng, offers.size())


## Начало нового раунда: повышение дешевеет на 1 (не ниже минимума).
func on_round_started() -> void:
	if can_upgrade():
		upgrade_cost = maxi(_config.shop_upgrade_min_cost, upgrade_cost - 1)


## Заговор в месте витрины или null.
func get_rite(index: int) -> RiteData:
	if index < 0 or index >= rite_offers.size():
		return null
	return rite_offers[index]


func _append_offer(rng: RandomNumberGenerator, index: int) -> void:
	var pool: Array[RiteData] = []
	for rite: RiteData in _config.rites:
		if rite.tier <= level and is_god_active(rite.god):
			pool.append(rite)
	var rite: RiteData = null
	if index >= 2 and not pool.is_empty() and rng.randi_range(1, 100) <= _config.rite_offer_percent:
		rite = pool[rng.randi_range(0, pool.size() - 1)]
	rite_offers.append(rite)
	offers.append(_random_tower(rng, index < 2) if rite == null else null)


func add_to_hash(hasher: StateHasher) -> void:
	for god: StringName in active_gods:
		hasher.add_string(god)
	hasher.add(level)
	hasher.add(upgrade_cost)
	hasher.add(int(is_frozen))
	for data: TowerData in offers:
		hasher.add_string(data.id if data != null else &"-")
	for rite: RiteData in rite_offers:
		hasher.add_string(rite.id if rite != null else &"-")


## Случайная башня из открытых тиров (тир ≤ уровня магазина) с учётом веса shop_weight.
func _random_tower(rng: RandomNumberGenerator, shooter_only: bool = false) -> TowerData:
	var total: int = 0
	for data: TowerData in _config.towers:
		if data.tier <= level and is_god_active(data.god) \
				and (not shooter_only or (data.attacks and data.damage > 0)):
			total += data.shop_weight
	if total <= 0:
		return null
	var pick: int = rng.randi_range(1, total)
	for data: TowerData in _config.towers:
		if data.tier > level or not is_god_active(data.god) \
				or (shooter_only and (not data.attacks or data.damage <= 0)):
			continue
		pick -= data.shop_weight
		if pick <= 0:
			return data
	return null


## Нейтральные чары разрешены при любом драфте; пустой список — старые правила.
func is_god_active(god: StringName) -> bool:
	return god == &"" or active_gods.is_empty() or active_gods.has(god)
