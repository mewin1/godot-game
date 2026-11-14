class_name RitualTrial
extends RefCounted
## «Обряд»: фиксированный тик, команды и полный независимый снимок.
## Прежний опыт — четыре суток по расписанию; бесконечный забег (settings.nights) — ночи генератора.

enum Phase { PREP, RUNNING, OVER }
enum ControlMode { OPEN, PASSIVE, ABILITIES, TRANSFERS }
## Припасы: смоляная полоса (замедляет на участке), дождевая чаша (мочит группу),
## оберег сторожки (гасит следующие прорывы).
enum Supply { TAR, RAIN, CHARM }
const SUPPLY_NAMES: Array[String] = ["Смоляная полоса", "Дождевая чаша", "Оберег сторожки"]
const SNAPSHOT_VERSION: int = 2

var rules_hash: int = 0
var settings: RitualTrialConfig
var field: RitualField
var phase: Phase = Phase.PREP
var control_mode: ControlMode = ControlMode.OPEN
var economy_frozen: bool = false
var tick_count: int = 0
var hp: int = 0
var gold: int = 0
var earned: int = 0
var spent: int = 0
var refunded: int = 0
var next_spawn: int = 0
var last_dawn: int = 0
var palisades: int = 0
var palisade_progress: int = -1
## Вход, на маршруте которого стоит частокол (общий отрезок дорог он перекрывает для всех).
var palisade_lane: int = 0
var palisade_ready: int = -1
var hero_ready: int = 0
var hero_due: int = -1
var hero_progress: int = 0
var hero_lane: int = 0
## Выбранный герой забега (индекс settings.heroes); у прежнего опыта героев нет — Илья из настроек.
var hero_index: int = 0
## Варево Яги: сколько следующих построек встанут сразу 2-го уровня.
var brew_charges: int = 0
## Запас припасов по видам Supply.
var supplies: Array[int] = [0, 0, 0]
## Действующая смола: вход, точка, до какого тика (-1 — нет).
var tar_lane: int = 0
var tar_progress: int = -1
var tar_until: int = -1
## Сколько ещё прорывов погасит оберег.
var charm_left: int = 0
## Где и когда пролилась чаша (для вспышки на поле).
var rain_lane: int = 0
var rain_progress: int = -1
var rain_tick: int = -1
var result: String = ""
var title: String = ""
var install_until: Dictionary[int, int] = {}
var move_origins: Dictionary[int, Vector2i] = {}
var move_rotations: Dictionary[int, int] = {}
var journal: Array[Dictionary] = []
var dawns: Array[Dictionary] = []
var commands: Array[Dictionary] = []
## Сид бесконечного забега: от него зависят все ночи (RitualNightPlan).
var run_seed: int = 0
var bosses_killed: int = 0
## Прилавок лавки с азартом: индексы построек каталога, -1 — купленное место.
var offers: Array[int] = []
## Заговоры на прилавке (индексы settings.rites), -1 — купленное место.
var rite_offers: Array[int] = []
var rerolls_today: int = 0
## Состояние генератора лавки (RandomNumberGenerator.state) — переживает снимок.
var market_rng_state: int = 0
## Дары за боссов: взятые (индексы settings.gifts) и текущий выбор; пока выбор не пуст — пауза.
var gifts_taken: Array[int] = []
var gift_choice: Array[int] = []
var gift_rng_state: int = 0
## До конца какой ночи ремонт бесплатен (дар «Плотники»).
var free_repair_until: int = 0
## Пристроенные улицы (docs/34 §3): для каждой — ночь, с которой открыт её вход.
## Места под дома открываются сразу при покупке.
var street_nights: Array[int] = []
## Усиления рассвета (docs/37 D4): что предложено сейчас (до ночи) и что взято за забег.
var boon_choice: Array[int] = []
var boons_taken: Array[int] = []
## Прорывов за текущую ночь; итог прошлой ночи и выплаченный за неё бонус чистой ночи (ECO-3).
var night_leaks: int = 0
var night_leaks_last: int = 0
var last_clean_bonus: int = 0
## Здоровье героя от усилений и скидка на улучшения до рассвета номер upgrade_discount_dawn.
var hero_hp_bonus: int = 0
var upgrade_discount_percent: int = 0
var upgrade_discount_dawn: int = -1
## Заваленные проулки-срезки (docs/37 ALY-1): номер проулка → завален ли.
var barricades: Array[bool] = []
var _plan: RitualNightPlan


func _init(rules: RitualTrialConfig, loadout_index: int = 0, seed_value: int = -1, hero_choice: int = 0) -> void:
	settings = rules
	hero_index = clampi(hero_choice, 0, maxi(0, rules.heroes.size() - 1))
	var hasher: StateHasher = StateHasher.new()
	RitualStateCodec.hash_value(hasher, RitualStateCodec.rules_state(rules))
	rules_hash = hasher.value
	barricades.resize(rules.alleys.size())
	field = RitualField.new(rules)
	field.mob_killed.connect(_on_killed)
	field.mob_breached.connect(_on_breached)
	field.trial_event.connect(_on_field_event)
	field.movement_completed.connect(_resolve_palisade)
	field.hit_observed.connect(_on_hit_observed)
	field.tower_fired.connect(_on_tower_fired)
	hp = max_hp()
	gold = rules.start_gold
	if rules.is_endless():
		# Забег начинается вечером сразу, без кнопки «Начать» (docs/34 §8).
		run_seed = seed_value if seed_value >= 0 else rules.nights.default_seed
		phase = Phase.RUNNING
		var gift_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		gift_rng.seed = run_seed * 31337 + 7
		gift_rng_state = gift_rng.state
		if rules.market_offers > 0:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = run_seed * 7777777 + 13
			market_rng_state = rng.state
			_roll_market()
		return
	if loadout_index >= 0 and loadout_index < settings.loadouts.size():
		_apply_loadout(settings.loadouts[loadout_index])
		if tick_count > 0:
			# Заполненная заготовка уже в бою; пауза UI не даёт бесплатной подготовки.
			phase = Phase.RUNNING


func _apply_loadout(loadout: RitualLoadout) -> void:
	title = loadout.title
	gold = loadout.capital
	for index: int in loadout.tower_indices.size():
		var error: String = _buy(loadout.tower_indices[index], loadout.positions[index],
				loadout.rotations[index])
		assert(error.is_empty(), error)
	for index: int in loadout.rite_indices:
		var error: String = _rite(index)
		assert(error.is_empty(), error)
	tick_count = loadout.start_tick
	last_dawn = tick_count / settings.cycle_ticks
	palisades = loadout.palisades
	while next_spawn < settings.spawns.size() and settings.spawns[next_spawn].at_tick < tick_count:
		next_spawn += 1
	field.prepare_tick(tick_count)
	journal.clear()


func execute(command: RitualCommand) -> String:
	if phase == Phase.OVER:
		return "Опыт завершён"
	if command.action == RitualCommand.Action.GIFT:
		var gift_error: String = _take_gift(command.item)
		if gift_error.is_empty():
			_record_command(command)
		return gift_error
	if command.action == RitualCommand.Action.START:
		if phase != Phase.PREP:
			return "Опыт уже запущен"
		phase = Phase.RUNNING
		_record_command(command)
		return ""
	if phase == Phase.RUNNING and control_mode == ControlMode.PASSIVE:
		return "Контроль: бой без команд"
	var economic: bool = command.action in [RitualCommand.Action.BUY,
		RitualCommand.Action.SELL, RitualCommand.Action.RITE, RitualCommand.Action.MERGE,
		RitualCommand.Action.ENCHANT, RitualCommand.Action.REPAIR, RitualCommand.Action.REROLL,
		RitualCommand.Action.REPAIR_HOUSE, RitualCommand.Action.STREET, RitualCommand.Action.BARRICADE,
		RitualCommand.Action.BUY_SUPPLY,
		RitualCommand.Action.UPGRADE, RitualCommand.Action.SPECIALISE]
	if phase == Phase.RUNNING and economic and (economy_frozen or control_mode != ControlMode.OPEN):
		return "В этой контрольной ветке состав зафиксирован"
	if command.action in [RitualCommand.Action.MOVE, RitualCommand.Action.CANCEL_MOVE] \
			and phase == Phase.RUNNING and control_mode == ControlMode.ABILITIES:
		return "Контроль: башни неподвижны"
	var error: String = "Неизвестная команда"
	match command.action:
		RitualCommand.Action.BUY:
			error = _buy(command.item, command.cell, command.rotation, command.tower_id)
		RitualCommand.Action.MOVE:
			error = _move(command.tower_id, command.cell, command.rotation)
		RitualCommand.Action.SELL:
			error = _sell(command.tower_id)
		RitualCommand.Action.RITE:
			error = _rite(command.item, command.tower_id)
		RitualCommand.Action.SKILL:
			error = _skill(command.item, command.progress)
		RitualCommand.Action.PALISADE:
			error = _palisade(command.item, command.progress)
		RitualCommand.Action.CANCEL_MOVE:
			error = _cancel_move(command.tower_id)
		RitualCommand.Action.MERGE:
			error = _merge(command.tower_id, command.item)
		RitualCommand.Action.ENCHANT:
			error = _enchant(command.item, command.tower_id)
		RitualCommand.Action.REPAIR:
			error = _repair()
		RitualCommand.Action.REROLL:
			error = _reroll()
		RitualCommand.Action.REPAIR_HOUSE:
			error = _repair_house(command.tower_id)
		RitualCommand.Action.STREET:
			error = _street()
		RitualCommand.Action.BARRICADE:
			error = _barricade(command.item)
		RitualCommand.Action.BOON:
			error = _take_boon(command.item)
		RitualCommand.Action.BUY_SUPPLY:
			error = _buy_supply(command.item)
		RitualCommand.Action.SUPPLY:
			error = _supply(command.rotation, command.item, command.progress)
		RitualCommand.Action.UPGRADE:
			error = _upgrade(command.tower_id)
		RitualCommand.Action.SPECIALISE:
			error = _upgrade(command.tower_id, command.item)
	if error.is_empty():
		_record_command(command)
	return error


func _record_command(command: RitualCommand) -> void:
	var entry: Dictionary[String, Variant] = command.record()
	entry["tick"] = tick_count
	commands.append(entry)


## into_id > 0 — купить копию прямо в эту башню 1-го уровня (слияние).
func _buy(index: int, cell: Vector2i, rotation: int, into_id: int = 0) -> String:
	if index < 0 or index >= settings.combat.towers.size():
		return "Нет такой постройки"
	var data: TowerData = settings.combat.towers[index]
	var unlock: String = building_unlock_error(index)
	if not unlock.is_empty():
		return unlock
	if settings.uses_plots() and (into_id > 0 or rotation != 0):
		return "На участке покупают отдельный дом без поворота"
	var slot: int = offers.find(index)
	if settings.market_offers > 0 and slot < 0:
		return "Этой постройки нет в лавке"
	var cost: int = building_cost(index)
	if gold < cost:
		return "Не хватает золота"
	if into_id > 0:
		var twin: TowerState = field.get_tower(into_id)
		if twin == null or twin.data != data:
			return "Сливается только с такой же постройкой"
		var error: String = _buy_into(twin, cost)
		if error.is_empty() and slot >= 0:
			offers[slot] = -1
		return error
	if settings.tower_limit > 0 and field.towers.size() >= settings.tower_limit:
		return "Все места заняты: замените постройку"
	if not field.can_place_tower_data(data, cell, rotation):
		return "Выберите свободный участок" if settings.uses_plots() else "Фигура не помещается на свободной площадке"
	var tower: TowerState = field.add_tower(data, cell, posmod(rotation, TowerState.ROTATIONS))
	if slot >= 0:
		offers[slot] = -1
	if settings.wear_ticks > 0:
		tower.durability = settings.max_durability(1)
	tower.invested_total = cost
	if tower is RitualTower:
		(tower as RitualTower).investments.append(Vector2i(cost, tick_count))
	gold -= tower.invested_total
	spent += tower.invested_total
	if brew_charges > 0 and settings.is_endless():
		# Варево Яги: постройка сразу каменная, как после слияния двух.
		brew_charges -= 1
		tower.level = 2
		if settings.wear_ticks > 0:
			tower.durability = settings.max_durability(2)
		field.mark_towers_changed()
	if phase == Phase.RUNNING:
		_lock(tower)
	return ""


## Покупка карточки прямо на башню 1-го уровня того же вида — слияние с новой копией.
func _buy_into(twin: TowerState, cost: int) -> String:
	if twin.level != 1:
		return "Новая копия сливается только с башней 1-го уровня"
	gold -= cost
	spent += cost
	twin.invested_total += cost
	if twin.durability >= 0:
		twin.durability += settings.max_durability(1)
	_raise_level(twin)
	return ""


## Цена постройки со скидкой своей стихии (docs/34 §7): чем больше заговоров на идоле
## этой стихии, тем дешевле, с пределом. Продажа вернёт половину реально заплаченного.
func building_cost(index: int) -> int:
	var price: int = discounted(settings.costs[index], settings.combat.towers[index].god)
	if settings.is_night(tick_count):
		price = price * settings.night_cost_percent / 100
	return price


func city_level() -> int:
	return 1 + street_nights.size()


func building_unlock_error(index: int) -> String:
	if index < 0 or index >= settings.combat.towers.size():
		return "Нет такой постройки"
	var tier: int = settings.combat.towers[index].tier
	if settings.uses_plots() and tier > city_level():
		return "Нужен город %d-го уровня" % tier
	return ""


func upgrade_cost(tower: TowerState) -> int:
	if tower == null or tower.level > settings.upgrade_cost_percent.size():
		return 0
	var index: int = settings.combat.towers.find(tower.data)
	if index < 0:
		return 0
	var price: int = discounted(settings.costs[index]
		* settings.upgrade_cost_percent[tower.level - 1] / 100, tower.data.god)
	if upgrade_discount_dawn > last_dawn:
		price = price * (100 - upgrade_discount_percent) / 100
	return price * settings.night_cost_percent / 100 if settings.is_night(tick_count) else price


func upgrade_error(tower: TowerState, branch: int = -1) -> String:
	if not settings.uses_plots() or tower == null:
		return "Выберите дом на участке"
	if tower.level >= settings.combat.max_tower_level:
		return "Уровень уже максимальный"
	if tower.is_action_blocked() or install_until.has(tower.id):
		return "Строительство еще идет"
	if tower.level > settings.upgrade_city_levels.size() \
			or city_level() < settings.upgrade_city_levels[tower.level - 1]:
		return "Сначала укрепите город"
	if tower.level == 2:
		var levels: RitualBuildingLevels = settings.levels_for(tower.data)
		if levels == null or branch < 0 or branch >= levels.branches.size():
			return "Выберите специализацию"
	elif branch >= 0:
		return "Специализация выбирается на третьем уровне"
	if gold < upgrade_cost(tower):
		return "Не хватает золота"
	return ""


func upgrade_preview(tower: TowerState, branch: int = -1) -> RitualTower:
	if not tower is RitualTower or tower.level >= settings.combat.max_tower_level:
		return null
	if tower.level == 2 and branch < 0:
		return null
	field.refresh_building_bonuses()
	var preview: RitualTower = RitualTower.new()
	preview.data = tower.data
	RitualStateCodec.apply(preview, RitualStateCodec.capture(tower))
	preview.level += 1
	if tower.level == 2:
		preview.branch = branch
	if preview.durability >= 0:
		preview.durability = tower.durability * settings.max_durability(preview.level) \
			/ maxi(1, settings.max_durability(tower.level))
	return preview


func _upgrade(tower_id: int, branch: int = -1) -> String:
	var tower: TowerState = field.get_tower(tower_id)
	var error: String = upgrade_error(tower, branch)
	if not error.is_empty():
		return error
	var house: RitualTower = tower as RitualTower
	if house == null:
		return "Выберите дом на участке"
	var cost: int = upgrade_cost(tower)
	var old_full: int = settings.max_durability(tower.level)
	var old_durability: int = tower.durability
	gold -= cost
	spent += cost
	tower.invested_total += cost
	house.investments.append(Vector2i(cost, tick_count))
	if tower.level == 2:
		house.branch = branch
	_raise_level(tower)
	if old_durability >= 0:
		tower.durability = old_durability * settings.max_durability(tower.level) / maxi(1, old_full)
	_event(&"upgrade", {"tower": tower.id, "level": tower.level, "branch": house.branch, "cost": cost})
	return ""


func sell_value(tower: TowerState) -> int:
	if tower == null:
		return 0
	var house: RitualTower = tower as RitualTower
	if house == null:
		return tower.invested_total if phase == Phase.PREP else tower.invested_total * settings.sell_percent / 100
	if not house.used:
		return house.invested_total
	var amount: int = 0
	for investment: Vector2i in house.investments:
		amount += investment.x if tick_count - investment.y <= settings.sell_undo_ticks \
			else investment.x * settings.plot_sell_percent / 100
	return amount


func discounted(price: int, god: StringName) -> int:
	return price * (10000 - discount_bp(god)) / 10000


## Скидка стихии в базисных пунктах: от всех заговоров на идоле этого бога.
func discount_bp(god: StringName) -> int:
	if settings.discount_cap_bp <= 0:
		return 0
	var idol: IdolState = field.get_idol(god) if god != &"" else null
	if idol == null:
		return 0
	var count: int = 0
	for rite_id: StringName in idol.purchases:
		count += idol.purchases[rite_id]
	var discount: int = RitualRiteCurve.decay(settings.discount_cap_bp, settings.discount_step_bp, count)
	return discount << gift_count(RitualGiftData.Effect.DOUBLE_DISCOUNT)


## Цена следующего обновления прилавка в эти сутки.
func reroll_cost() -> int:
	var free: int = hero().free_rerolls if hero() != null else 0
	if rerolls_today < free:
		return 0
	return settings.reroll_cost + settings.reroll_cost_step * (rerolls_today - free)


func _reroll() -> String:
	if settings.uses_plots():
		return "Каталог не требует обновления"
	if settings.market_offers <= 0:
		return "В этом режиме лавка не обновляется"
	var cost: int = reroll_cost()
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	spent += cost
	rerolls_today += 1
	_roll_market()
	return ""


## Новый прилавок: веса лавки PvP (shop_weight), первые места — стреляющие постройки.
func _roll_market() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = market_rng_state
	offers.clear()
	for slot: int in settings.market_offers:
		offers.append(_random_building(rng, slot < settings.market_shooter_slots))
	rite_offers.clear()
	for slot: int in settings.market_rite_slots:
		rite_offers.append(_random_rite(rng))
	market_rng_state = rng.state


## Стихии лавки: все боги построек, в порядке каталога.
func market_gods() -> Array[StringName]:
	var gods: Array[StringName] = []
	for data: TowerData in settings.combat.towers:
		if not gods.has(data.god):
			gods.append(data.god)
	return gods


## Равновероятная стихия, затем равновероятный вариант из candidates (индексы с богом god_of).
static func _by_element(rng: RandomNumberGenerator, gods: Array[StringName], candidates: Array[int],
		god_of: Callable) -> int:
	var god: StringName = gods[rng.randi_range(0, gods.size() - 1)]
	var own: Array[int] = []
	for index: int in candidates:
		if god_of.call(index) == god:
			own.append(index)
	if own.is_empty():
		own = candidates
	return own[rng.randi_range(0, own.size() - 1)]


func _random_rite(rng: RandomNumberGenerator) -> int:
	var all: Array[int] = []
	var gods: Array[StringName] = []
	for index: int in settings.rites.size():
		all.append(index)
		if not gods.has(settings.rites[index].god):
			gods.append(settings.rites[index].god)
	return _by_element(rng, gods, all, func(index: int) -> StringName: return settings.rites[index].god)


func _random_building(rng: RandomNumberGenerator, shooter_only: bool) -> int:
	if settings.market_by_element and not shooter_only:
		var all: Array[int] = []
		for index: int in settings.combat.towers.size():
			all.append(index)
		return _by_element(rng, market_gods(), all,
				func(index: int) -> StringName: return settings.combat.towers[index].god)
	var total: int = 0
	for data: TowerData in settings.combat.towers:
		if not shooter_only or (data.attacks and data.damage > 0):
			total += data.shop_weight
	var pick: int = rng.randi_range(1, maxi(1, total))
	for index: int in settings.combat.towers.size():
		var data: TowerData = settings.combat.towers[index]
		if shooter_only and not (data.attacks and data.damage > 0):
			continue
		pick -= data.shop_weight
		if pick <= 0:
			return index
	return 0


func _merge(source_id: int, target_id: int) -> String:
	if settings.uses_plots():
		return "Дом улучшается за золото при выборе"
	var source: TowerState = field.get_tower(source_id)
	var target: TowerState = field.get_tower(target_id)
	if source == null or target == null or source == target:
		return "Выберите две башни"
	if source.data != target.data or source.level != target.level:
		return "Сливаются только одинаковые башни одного уровня"
	if target.level >= settings.combat.max_tower_level:
		return "Уровень уже максимальный"
	target.invested_total += source.invested_total
	if target.durability >= 0 and source.durability >= 0:
		# Прочность складывается, а не восстанавливается: слияние — не бесплатный ремонт.
		target.durability += source.durability
	for effect: int in source.enchantments:
		if not target.has_enchantment(effect):
			target.enchantments.append(effect)
	field.remove_tower(source)
	install_until.erase(source_id)
	move_origins.erase(source_id)
	move_rotations.erase(source_id)
	_raise_level(target)
	_event(&"merge", {"source": source_id, "target": target_id, "level": target.level})
	return ""


func _raise_level(tower: TowerState) -> void:
	if tower.level >= settings.combat.max_tower_level:
		return
	tower.level += 1
	if tower.durability >= 0:
		tower.durability = mini(tower.durability, settings.max_durability(tower.level))
	# Перестройка в бою стоит обычной установки; незавершённый перенос становится окончательным.
	move_origins.erase(tower.id)
	move_rotations.erase(tower.id)
	if phase == Phase.RUNNING:
		_lock(tower)
	field.mark_towers_changed()


## Установка/перестройка: ночью дольше (night_install_ticks), перенос ночью — ещё дольше.
func _lock(tower: TowerState, moving: bool = false) -> void:
	var ticks: int = settings.install_ticks
	if settings.is_night(tick_count):
		var night: int = settings.night_move_ticks if moving else settings.night_install_ticks
		ticks = maxi(ticks, night)
	install_until[tower.id] = tick_count + ticks
	tower.action_lock_ticks = ticks
	field.mark_towers_changed()


func _move(id: int, cell: Vector2i, rotation: int) -> String:
	if settings.uses_plots() and rotation != 0:
		return "Дома на участках не поворачиваются"
	var tower: TowerState = field.get_tower(id)
	if tower == null:
		return "Выберите башню"
	if install_until.has(id):
		return "Установка ещё не завершена"
	if tower.anchor == cell and tower.rotation == posmod(rotation, TowerState.ROTATIONS):
		return "Башня уже здесь"
	if tower.anchor == cell and tower.data.wind_length_milli == 0 \
			and _same_cells(tower.cells(), TowerState.shape_cells_at(tower.data.shape, cell, rotation)):
		# Поворот симметричной фигуры ничего не меняет — не выключаем башню на установку.
		return "Поворот ничего не меняет"
	var origin: Vector2i = tower.anchor
	var old_rotation: int = tower.rotation
	if not field.move_tower(tower, cell, posmod(rotation, TowerState.ROTATIONS)):
		return "Участок недоступен или занят" if settings.uses_plots() else "Фигура не помещается"
	if phase == Phase.RUNNING:
		move_origins[id] = origin
		move_rotations[id] = old_rotation
		_lock(tower, true)
		_event(&"move", {"id": id, "from": origin, "to": cell})
	return ""


static func _same_cells(first: Array[Vector2i], second: Array[Vector2i]) -> bool:
	if first.size() != second.size():
		return false
	for cell: Vector2i in first:
		if not second.has(cell):
			return false
	return true


func _cancel_move(id: int) -> String:
	var tower: TowerState = field.get_tower(id)
	if tower == null or not move_origins.has(id):
		return "Нет незавершённого переноса"
	if not field.move_tower(tower, move_origins[id], move_rotations[id]):
		return "Исходное место уже занято"
	# Уже потраченное время не возвращается: старый срок блокировки остаётся.
	move_origins.erase(id)
	move_rotations.erase(id)
	return ""


func _sell(id: int) -> String:
	var tower: TowerState = field.get_tower(id)
	if tower == null:
		return "Выберите башню"
	var amount: int = sell_value(tower)
	gold += amount
	refunded += amount
	field.remove_tower(tower)
	install_until.erase(id)
	move_origins.erase(id)
	move_rotations.erase(id)
	return ""


## idol_slot: 0 — свой или первый свободный идол (прежние записи), N — идол N-1 (docs/37 IDL-2).
func _rite(index: int, idol_slot: int = 0) -> String:
	if index < 0 or index >= settings.rites.size():
		return "Нет такого заговора"
	var slot: int = rite_offers.find(index)
	if settings.market_rite_slots > 0 and slot < 0:
		return "Этого заговора нет в лавке"
	var data: RiteData = settings.rites[index]
	if settings.rite_purchase_limit and rite_count(index) >= data.max_purchases:
		return "Этот заговор уже усилен до предела"
	var cost: int = rite_cost(index)
	if gold < cost:
		return "Не хватает золота"
	var idol: IdolState = field.get_idol(data.god)
	if idol_slot > 0:
		if idol_slot > field.idols.size():
			return "Нет такого идола"
		var chosen: IdolState = field.idols[idol_slot - 1]
		if idol != null and idol != chosen:
			return "Этот бог уже живёт в другом идоле"
		if chosen.god != &"" and chosen.god != data.god:
			return "Идол посвящён другому богу"
		idol = chosen
	if idol == null:
		for candidate: IdolState in field.idols:
			if candidate.god == &"":
				idol = candidate
				break
	if idol == null:
		return "Все идолы посвящены"
	var curve: RitualRiteCurve = settings.rite_curve(data.id)
	if curve != null and curve.cap > 0:
		# Затухание: идол получает не постоянную прибавку, а разницу бонус(n+1) − бонус(n),
		# поэтому весь общий боевой код читает уже затухший итог.
		var applied: RiteData = data.duplicate() as RiteData
		var count: int = rite_count(index)
		applied.value = curve.bonus(count + 1) - curve.bonus(count)
		idol.apply_rite(applied)
	else:
		idol.apply_rite(data)
	_grant_milestones(idol)
	gold -= cost
	spent += cost
	if slot >= 0:
		rite_offers[slot] = -1
	field.mark_towers_changed()
	return ""


## Веха, порог которой ровно достигнут этим заговором, даёт свой эффект бесплатно (docs/37 IDL-4).
func _grant_milestones(idol: IdolState) -> void:
	var count: int = idol_rites(idol)
	for milestone: RitualIdolMilestone in settings.milestones_for(idol.god):
		if milestone.rites == count:
			idol.apply_rite(milestone.as_rite(), false)
			_event(&"milestone", {"god": String(idol.god), "rites": count})


## Сколько заговоров оплачено у идола (вехи не считаются).
func idol_rites(idol: IdolState) -> int:
	var count: int = 0
	if idol == null:
		return count
	for rite_id: StringName in idol.purchases:
		count += idol.purchases[rite_id]
	return count


## Следующая веха идола (null — все пройдены или вех нет).
func next_milestone(idol: IdolState) -> RitualIdolMilestone:
	if idol == null or idol.god == &"":
		return null
	var count: int = idol_rites(idol)
	for milestone: RitualIdolMilestone in settings.milestones_for(idol.god):
		if milestone.rites > count:
			return milestone
	return null


## Есть ли идол под заговор: свой бог или ещё не посвящённый.
func has_idol_for(index: int) -> bool:
	var god: StringName = settings.rites[index].god
	for idol: IdolState in field.idols:
		if idol.god == god or idol.god == &"":
			return true
	return false


## Сколько раз уже куплен заговор (по его идолу).
func rite_count(index: int) -> int:
	var data: RiteData = settings.rites[index]
	var idol: IdolState = field.get_idol(data.god)
	return 0 if idol == null else idol.purchases.get(data.id, 0)


func rite_cost(index: int) -> int:
	var curve: RitualRiteCurve = settings.rite_curve(settings.rites[index].id)
	if curve != null:
		return curve.cost(settings.rites[index].cost, rite_count(index))
	return settings.rites[index].cost + settings.rite_cost_step * rite_count(index)


## Почему чару нельзя наложить на башню (пусто — можно). Цена здесь не проверяется.
func enchant_error(index: int, tower_id: int) -> String:
	if settings.enchants.is_empty():
		return "В этом режиме чар нет"
	if index < 0 or index >= settings.enchants.size():
		return "Нет такой чары"
	var tower: TowerState = field.get_tower(tower_id)
	if tower == null:
		return "Выберите башню"
	var rite: RiteData = settings.enchants[index]
	if not tower.data.attacks:
		return "Эта поддержка усиливается слиянием"
	if rite.effect == RiteData.Effect.TARGETS and tower.data.hits_all_in_range:
		return "Постройка уже охватывает все цели"
	if rite.effect == RiteData.Effect.ENCHANT_DAMAGE and tower.data.damage == 0:
		return "У этой постройки нет урона для усиления"
	if tower.has_enchantment(rite.effect):
		return "Эта чара уже есть на башне"
	return ""


func _enchant(index: int, tower_id: int) -> String:
	var error: String = enchant_error(index, tower_id)
	if not error.is_empty():
		return error
	var cost: int = settings.enchant_costs[index]
	if gold < cost:
		return "Не хватает золота"
	var tower: TowerState = field.get_tower(tower_id)
	tower.enchantments.append(settings.enchants[index].effect)
	tower.invested_total += cost
	gold -= cost
	spent += cost
	field.mark_towers_changed()
	return ""


## Цена ремонта дома: доля цены постройки его уровня за недостающую прочность, со скидкой стихии.
func repair_cost(tower: TowerState) -> int:
	if tower.durability < 0 or current_night() <= free_repair_until:
		return 0
	var full: int = settings.max_durability(tower.level)
	var missing: int = full - tower.durability
	if missing <= 0:
		return 0
	var index: int = settings.combat.towers.find(tower.data)
	var value: int = discounted(settings.costs[index] << (tower.level - 1), tower.data.god)
	if settings.uses_plots():
		var base: int = settings.costs[index]
		for level: int in range(tower.level - 1):
			base += settings.costs[index] * settings.upgrade_cost_percent[level] / 100
		value = discounted(base, tower.data.god)
	return maxi(1, value * settings.repair_percent * missing / (100 * full))


func repair_all_cost() -> int:
	var total: int = 0
	for tower: TowerState in field.towers:
		total += repair_cost(tower)
	return total


func _repair_house(tower_id: int) -> String:
	var targets: Array[TowerState] = []
	if tower_id == 0:
		targets = field.towers.duplicate()
	else:
		var tower: TowerState = field.get_tower(tower_id)
		if tower == null:
			return "Выберите дом"
		targets.append(tower)
	var cost: int = 0
	var worn: bool = false
	for tower: TowerState in targets:
		cost += repair_cost(tower)
		worn = worn or (tower.durability >= 0 and tower.durability < settings.max_durability(tower.level))
	if not worn:
		return "Дом цел" if tower_id != 0 else "Все дома целы"
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	spent += cost
	for tower: TowerState in targets:
		if tower.durability >= 0:
			tower.durability = settings.max_durability(tower.level)
	_event(&"repair_house", {"tower": tower_id, "cost": cost})
	return ""


func _repair() -> String:
	if phase != Phase.RUNNING:
		return "Чинить можно только в бою"
	if hp >= max_hp():
		# В бесконечном забеге HP — у Ильи в сторожке; «починка терема» стала лечением Ильи.
		return "Илья здоров" if settings.is_endless() else "Терем цел"
	if gold < settings.repair_cost:
		return "Не хватает золота"
	gold -= settings.repair_cost
	spent += settings.repair_cost
	hp = mini(max_hp(), hp + settings.repair_hp)
	_event(&"repair", {"hp": hp})
	return ""


#region Улицы (docs/34 §3)

## Цена следующей улицы; 0 — пристраивать больше нечего.
func street_cost() -> int:
	return settings.streets[street_nights.size()].cost if can_grow() else 0


func can_grow() -> bool:
	return street_nights.size() < settings.streets.size()


## Новая улица: места под дома — сразу, вход — с ближайшей ещё не начавшейся ночи.
func _street() -> String:
	if not can_grow():
		return "Дальше — проклятая земля"
	var cost: int = street_cost()
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	spent += cost
	var night: int = current_night() + (1 if settings.is_night(tick_count) else 0)
	street_nights.append(night)
	sync_streets()
	_event(&"street", {"street": street_nights.size(), "night": night, "cost": cost})
	return ""


#region Проулки-срезки (docs/37 ALY-1)

## Проулок открыт для врагов: город дорос до него и он не завален.
func alley_open(index: int) -> bool:
	return index >= 0 and index < settings.alleys.size() and city_level() >= settings.alleys[index].city_level \
		and not (index < barricades.size() and barricades[index])


## Завал проулка за золото или разбор завала (бесплатно, без возврата).
func _barricade(index: int) -> String:
	if index < 0 or index >= settings.alleys.size():
		return "Нет такого проулка"
	var alley: RitualAlley = settings.alleys[index]
	if city_level() < alley.city_level:
		return "Проулок ещё за пределами города"
	if barricades.size() != settings.alleys.size():
		barricades.resize(settings.alleys.size())
	if barricades[index]:
		barricades[index] = false
		_event(&"barricade", {"alley": index, "closed": false})
		return ""
	if gold < alley.barricade_cost:
		return "Не хватает золота"
	gold -= alley.barricade_cost
	spent += alley.barricade_cost
	barricades[index] = true
	_event(&"barricade", {"alley": index, "closed": true, "cost": alley.barricade_cost})
	return ""


## Пойдёт ли враг этого вида проулком сразу (быстрые — всегда, когда проулок открыт).
func takes_alley(index: int, enemy: MobData) -> bool:
	return alley_open(index) and enemy.speed_milli_per_tick >= settings.alleys[index].fast_speed_milli


## Проулок для врага, вошедшего по дороге lane: быстрый сворачивает в первый открытый.
func _alley_for_spawn(lane: int, enemy: MobData) -> int:
	for index: int in settings.alleys.size():
		if settings.alleys[index].lane == lane and takes_alley(index, enemy):
			return field.alley_route(index)
	return lane


## Медленный враг у развилки сворачивает в проулок, если впереди на срезаемом отрезке
## стоит частокол или разлита смола (docs/37 ALY-1). Общий отрезок до развилки одинаков,
## поэтому прогресс сохраняется.
func _reroute_at_forks() -> void:
	for index: int in settings.alleys.size():
		if not alley_open(index):
			continue
		var alley: RitualAlley = settings.alleys[index]
		var fork: int = field.alley_fork(index)
		var join: int = field.alley_join(index)
		var blocked: bool = (palisade_progress >= 0 and palisade_lane == alley.lane
				and palisade_progress > fork and palisade_progress < join) \
			or (tar_until > tick_count and tar_lane == alley.lane and tar_progress > fork and tar_progress < join)
		if not blocked:
			continue
		for base: MobState in field.mobs:
			var mob: RitualMob = base as RitualMob
			if mob.is_alive() and mob.lane == alley.lane and mob.progress >= fork - FieldState.MILLI \
					and mob.progress <= fork:
				mob.lane = field.alley_route(index)

#endregion


#region Припасы
## Рассвет приносит один случайный припас (сид забега и номер рассвета), если запас не полон.
func _grant_supply(dawn: int) -> void:
	if settings.supply_cap <= 0:
		return
	var total: int = 0
	for count: int in supplies:
		total += count
	if total >= settings.supply_cap:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed * 1000117 + dawn * 3571
	var kind: int = rng.randi_range(0, supplies.size() - 1)
	supplies[kind] += 1
	_event(&"supply_gained", {"kind": kind, "dawn": dawn})


func supply_radius(kind: int) -> int:
	match kind:
		Supply.TAR:
			return settings.tar_radius_milli
		Supply.RAIN:
			return settings.rain_radius_milli
	return 0


func _supply(kind: int, lane: int, progress: int) -> String:
	if phase != Phase.RUNNING or kind < 0 or kind >= supplies.size():
		return "Нет такого припаса"
	if supplies[kind] <= 0:
		return "Припаса «%s» нет в запасе" % SUPPLY_NAMES[kind]
	match kind:
		Supply.TAR:
			if not valid_spot(lane, progress):
				return "Выберите точку дороги"
			tar_lane = lane
			tar_progress = progress
			tar_until = tick_count + settings.tar_ticks
		Supply.RAIN:
			if not valid_spot(lane, progress):
				return "Выберите точку дороги"
			rain_lane = lane
			rain_progress = progress
			rain_tick = tick_count
			var point: Vector2i = field.lane_point(lane, progress)
			for mob: MobState in field.mobs:
				if mob.is_alive() and field._is_in_range(point, field.get_mob_position(mob), settings.rain_radius_milli) \
						and mob.can_apply_status(&"wet"):
					mob.wet_ticks_left = maxi(mob.wet_ticks_left, settings.rain_wet_ticks)
		Supply.CHARM:
			charm_left += settings.charm_blocks
	supplies[kind] -= 1
	_event(&"supply", {"kind": kind, "lane": lane, "progress": progress})
	return ""


## Смола: враги на участке замедлены, пока полоса не высохла.
func _apply_tar() -> void:
	if tar_until < 0:
		return
	if tick_count >= tar_until:
		tar_until = -1
		tar_progress = -1
		return
	var point: Vector2i = field.lane_point(tar_lane, tar_progress)
	for mob: MobState in field.mobs:
		if mob.is_alive() and field._is_in_range(point, field.get_mob_position(mob), settings.tar_radius_milli):
			mob.apply_slow(settings.tar_slow_percent, 10)
#endregion


## Подать с улиц: платит улица, чей вход был открыт в прошедшую ночь (пережили — получили).
func _collect_tribute(dawn: int) -> void:
	var total: int = tribute_due(dawn)
	if total > 0:
		gold += total
		earned += total
		_event(&"tribute", {"gold": total, "dawn": dawn})


func tribute_due(dawn: int) -> int:
	var total: int = 0
	for index: int in street_nights.size():
		if street_nights[index] <= dawn:
			total += settings.streets[index].tribute
	return total


## Поле видит пристроенные улицы (после снимка — из street_nights).
func sync_streets() -> void:
	field.open_streets = street_nights.size()
	var idols: int = field.config.idol_slots
	for index: int in mini(street_nights.size(), settings.streets.size()):
		idols += int(settings.streets[index].extra_idol)
	while field.idols.size() < idols:
		field.idols.append(IdolState.new())
	if barricades.size() != settings.alleys.size():
		barricades.resize(settings.alleys.size())
	field.mark_towers_changed()


## Сколько входов открыто к этой ночи.
func entrances(night: int) -> int:
	var count: int = 1
	for index: int in street_nights.size():
		count += int(street_nights[index] <= night and not settings.streets[index].path_cells.is_empty())
	return count


## Вход пачки: 0 — главная дорога, N — улица N.
func pack_lane(pack: RitualPack) -> int:
	return pack.lane_for(entrances(pack.night))


## Маршруты пачки: прямо по своему входу и в каждый открытый к её ночи проулок.
## Бойцы пачки идут по ним по очереди: первый прямо, второй в проулок и т. д.
func pack_routes(pack: RitualPack) -> Array[int]:
	var entrance: int = pack_lane(pack)
	var routes: Array[int] = [entrance]
	for index: int in street_nights.size():
		if street_nights[index] > pack.night:
			continue
		var street: int = index + 1
		if entrance == 0 or entrance == street:
			var branch: int = field.branch_route(entrance, street)
			if branch >= 0:
				routes.append(branch)
	return routes


## Маршрут бойца пачки по его месту в строю.
func member_route(pack: RitualPack, slot: int) -> int:
	var routes: Array[int] = pack_routes(pack)
	return routes[slot % routes.size()]


## Прогресс точки (вход from_lane, progress) на маршруте врага; -1 — его дорога здесь не идёт.
## Общий отрезок дорог у сторожки один для всех входов.
func spot_on_route(from_lane: int, progress: int, mob: MobState) -> int:
	var lane: int = RitualField.lane_of(mob)
	if lane == from_lane:
		return progress
	var cells: Array[Vector2i] = field.route(from_lane)
	var cell: Vector2i = cells[clampi(progress / FieldState.MILLI, 0, cells.size() - 1)]
	var at: int = field.progress_on(lane, cell)
	return at + progress % FieldState.MILLI if at >= 0 else -1


## Где частокол на маршруте врага (-1 — нет частокола или его дорога мимо).
func palisade_at(mob: MobState) -> int:
	return spot_on_route(palisade_lane, palisade_progress, mob) if palisade_progress >= 0 else -1

#endregion


func _skill(lane: int, progress: int) -> String:
	if phase != Phase.RUNNING or tick_count < hero_ready or hero_due >= 0:
		if hero() != null and not hero().needs_spot():
			return "%s ещё не готово" % hero().skill_name
		return "%s не готов" % hero_name()
	var data: RitualHeroData = hero()
	if data != null and data.skill == RitualHeroData.Skill.BREW:
		brew_charges += 1 + gift_count(RitualGiftData.Effect.HERO_TWICE)
		hero_ready = tick_count + data.cooldown_ticks
		_event(&"brew", {"charges": brew_charges})
		return ""
	if not valid_spot(lane, progress):
		return "Выберите точку дороги"
	hero_lane = lane
	hero_progress = progress
	hero_due = tick_count + (data.warning_ticks if data != null else settings.hero_warning)
	hero_ready = tick_count + (data.cooldown_ticks if data != null else settings.hero_cooldown)
	return ""


#region Герой
## Герой забега; null — прежний опыт без списка героев (Илья из общих настроек).
func hero() -> RitualHeroData:
	return settings.heroes[hero_index] if hero_index < settings.heroes.size() else null


func max_hp() -> int:
	var bonus: int = 0
	for index: int in mini(street_nights.size(), settings.streets.size()):
		bonus += settings.streets[index].hero_hp
	return (hero().hp if hero() != null else settings.hero_hp) + bonus + hero_hp_bonus


func hero_name() -> String:
	return hero().short_name if hero() != null else "Илья"


func skill_radius() -> int:
	return hero().radius_milli if hero() != null else settings.hero_radius


func _hero_percent() -> int:
	return hero().percent if hero() != null else settings.hero_percent


func _hero_cap() -> int:
	return hero_cap()


## Предел удара героя; с ростом (docs/37 HER-3) — на cap_growth_percent за каждую ночь после первой.
func hero_cap() -> int:
	if hero() == null:
		return settings.hero_cap
	var cap: int = hero().cap
	if hero().cap_growth_percent > 0 and settings.is_endless():
		for night: int in mini(current_night() - 1, 60):
			cap = cap * (100 + hero().cap_growth_percent) / 100
	return cap


## Свист: враги в круге отлетают назад по своей дороге и оглушены; боссы — вдвое ближе.
func _whistle() -> void:
	var data: RitualHeroData = hero()
	var point: Vector2i = field.lane_point(hero_lane, hero_progress)
	for mob: MobState in field.mobs:
		if not mob.is_alive() or not field._is_in_range(point, field.get_mob_position(mob), data.radius_milli):
			continue
		var push: int = data.knockback_milli
		if mob.data.tags.has(settings.boss_tag):
			push /= 2
		mob.progress = maxi(0, mob.progress - push)
		mob.previous_progress = mob.progress
		mob.stun_ticks_left = maxi(mob.stun_ticks_left, data.stun_ticks)
		_event(&"whistle_hit", {"mob": mob.id, "push": push})
#endregion


func _palisade(lane: int, progress: int) -> String:
	if phase != Phase.RUNNING or palisades <= 0 or palisade_progress >= 0:
		return "Нет свободного частокола"
	if not valid_spot(lane, progress):
		return "Выберите точку дороги"
	for base: MobState in field.mobs:
		if base.is_alive() and eligible_for_palisade(base) and base.progress == spot_on_route(lane, progress, base):
			return "Нельзя ставить частокол поверх тяжёлого врага"
	palisades -= 1
	palisade_lane = lane
	palisade_progress = progress
	palisade_ready = tick_count + settings.palisade_install
	return ""


## Точка на открытой дороге: главной или пристроенной улицы (до сторожки, не на ней).
func valid_spot(lane: int, progress: int) -> bool:
	return field.is_route_open(lane) and progress >= 0 and progress < field.lane_end_progress(lane)


func eligible_for_palisade(mob: MobState) -> bool:
	return mob.data.tags.has(settings.heavy_tag) or mob.data.tags.has(settings.boss_tag)


func hero_damage(mob: RitualMob) -> int:
	var raw: int = mini(_hero_cap(), mob.hp * _hero_percent() / 100)
	return maxi(1, raw * settings.ward_physical_percent / 100) if mob.ward_hp > 0 \
			else field.body_damage(mob, raw)


func _resolve_hero() -> void:
	if hero_due < 0 or tick_count < hero_due:
		return
	hero_due = -1
	for strike: int in 1 + gift_count(RitualGiftData.Effect.HERO_TWICE):
		if hero() != null and hero().skill == RitualHeroData.Skill.WHISTLE:
			_whistle()
		else:
			_hero_strike()


func _hero_strike() -> void:
	var point: Vector2i = field.lane_point(hero_lane, hero_progress)
	for mob: MobState in field.mobs:
		if mob.is_alive() and field._is_in_range(point, field.get_mob_position(mob), skill_radius()):
			var raw: int = mini(_hero_cap(), mob.hp * _hero_percent() / 100)
			var before_hp: int = mob.hp
			var target: RitualMob = mob as RitualMob
			var before_ward: int = target.ward_hp
			var sources: Array[int] = []
			if before_ward == 0:
				sources = field.banner_sources(mob)
			field.deal_mob_damage(mob, raw, 0, &"hero")
			_event(&"hero_hit", {"mob": mob.id, "raw": raw,
				"hp_damage": before_hp - maxi(0, mob.hp),
				"ward_damage": before_ward - target.ward_hp, "protected_by": sources})


func tick() -> void:
	if phase != Phase.RUNNING or not gift_choice.is_empty():
		return
	_boundaries()
	if not boon_choice.is_empty() and settings.is_night(tick_count):
		# Невыбранное усиление сгорает к ночи: выбор — дело дня.
		_event(&"boon_expired", {"choice": boon_choice.duplicate()})
		boon_choice.clear()
	_spawn_due()
	field.prepare_tick(tick_count)
	_finish_installations()
	_resolve_hero()
	_apply_tar()
	if not settings.alleys.is_empty():
		_reroute_at_forks()
	field.fire_trial_towers()
	field.finish_tick()
	field.pending_kill_gold = 0
	field.pending_breaches.clear()
	tick_count += 1
	field.wave_tick = tick_count
	_early_dawn()
	_boundaries()
	if phase == Phase.RUNNING and not settings.is_endless() and tick_count >= settings.end_tick:
		phase = Phase.OVER
		result = "Зачистка завершена" if field.count_alive_mobs() == 0 else "Зачистка не завершена"


func _spawn_due() -> void:
	if settings.is_endless():
		for pack: RitualPack in plan().spawns_at(tick_count):
			spawn_from_pack(pack, (tick_count - pack.at_tick) / pack.spacing)
		return
	while next_spawn < settings.spawns.size() and settings.spawns[next_spawn].at_tick <= tick_count:
		field.spawn_mob(settings.spawns[next_spawn].mob_index)
		next_spawn += 1


## Враг пачки на своем месте: здоровье и награда по кривым ночи, элита с короной.
func spawn_from_pack(pack: RitualPack, slot: int) -> RitualMob:
	var lane: int = member_route(pack, slot)
	if not settings.alleys.is_empty():
		lane = _alley_for_spawn(lane, settings.enemies[pack.members[slot]])
	var mob: RitualMob = field.spawn_mob(pack.members[slot], pack.hp_at(slot, settings.nights.boss_enemy),
			pack.resist, lane)
	mob.kill_reward = pack.bounties[slot]
	mob.elite_rank = pack.elite[slot]
	return mob


## План ночей этого сида (после снимка пересоздаётся по восстановленному сиду).
func plan() -> RitualNightPlan:
	if _plan == null or _plan.run_seed != run_seed:
		_plan = RitualNightPlan.new(settings, run_seed)
	return _plan


## Очередь разведки (плейтест автора): вся ближайшая ночь — днём следующая целиком,
## ночью ещё не вышедшие пачки этой ночи.
func night_queue() -> Array[RitualPack]:
	var queue: Array[RitualPack] = []
	for pack: RitualPack in plan().packs(current_night()):
		if pack.at_tick >= tick_count:
			queue.append(pack)
	return queue


## Босс в следующие warn_nights ночей (не в ближайшей — та видна в очереди), чтобы успеть
## собрать стихию против его неуязвимости. null — босса впереди не видно.
func boss_warning() -> RitualPack:
	var night: int = current_night()
	for index: int in range(night + 1, night + settings.nights.warn_nights + 1):
		for pack: RitualPack in plan().packs(index):
			if pack.boss:
				return pack
	return null


## Сколько ночей пережито (рассветов). У прежнего опыта — пройденные сутки.
func nights_survived() -> int:
	return last_dawn


## Номер текущей или ближайшей ночи бесконечного забега.
func current_night() -> int:
	return settings.nights.night_index_at(tick_count) if settings.is_endless() else last_dawn + 1


## Ночь отбита раньше срока: все пачки этой ночи вышли и вся нежить мертва — время сразу
## перематывается к рассвету (календарь ночей при этом прежний: следующие ночи по своим тикам).
func _early_dawn() -> void:
	if not settings.early_dawn or not settings.is_endless() or not settings.is_night(tick_count) \
			or field.count_alive_mobs() > 0:
		return
	var night: int = current_night()
	for pack: RitualPack in plan().packs(night):
		if pack.last_tick() >= tick_count:
			return
	var dawn: int = settings.nights.night_end(night)
	_event(&"early_dawn", {"night": night, "skipped": dawn - tick_count})
	tick_count = dawn
	field.wave_tick = tick_count


func _finish_installations() -> void:
	var finished: Array[int] = []
	for id: int in install_until:
		var tower: TowerState = field.get_tower(id)
		if tower == null or tick_count >= install_until[id]:
			finished.append(id)
			if tower != null:
				tower.action_lock_ticks = 0
		else:
			tower.action_lock_ticks = install_until[id] - tick_count
	for id: int in finished:
		install_until.erase(id)
		move_origins.erase(id)
		move_rotations.erase(id)
	if not finished.is_empty():
		field.mark_towers_changed()


func _resolve_palisade() -> void:
	if palisade_progress < 0 or tick_count < palisade_ready:
		return
	var first: RitualMob = null
	var first_distance: int = 0
	var first_step: int = 1
	for base: MobState in field.mobs:
		var mob: RitualMob = base as RitualMob
		var mark: int = palisade_at(mob)
		if not mob.is_alive() or not eligible_for_palisade(mob) or mark < 0 \
				or mob.previous_progress > mark or mob.progress < mark:
			continue
		var distance: int = mark - mob.previous_progress
		var step: int = maxi(1, mob.step_distance)
		# Сравниваем доли целочисленного шага без float. Равенство — меньший ID.
		var earlier: bool = distance * first_step < first_distance * step
		var equal: bool = distance * first_step == first_distance * step
		if first == null or earlier or (equal and mob.id < first.id):
			first = mob
			first_distance = distance
			first_step = step
	if first != null:
		_on_mob_moved(first)


func _on_mob_moved(mob: RitualMob) -> void:
	if palisade_progress < 0 or tick_count < palisade_ready:
		return
	var mark: int = palisade_at(mob)
	if mob.is_alive() and eligible_for_palisade(mob) and mark >= 0 \
			and mob.previous_progress <= mark and mob.progress >= mark:
		var affected: bool = mob.immune_until <= tick_count
		if affected:
			mob.progress = mark
			affected = field.stop_mob(mob, settings.palisade_stun)
		_event(&"palisade", {"mob": mob.id, "affected": affected, "progress": palisade_progress,
			"crossing_distance": mark - mob.previous_progress, "step": mob.step_distance})
		palisade_progress = -1
		palisade_ready = -1


func _boundaries() -> void:
	var dawn: int = settings.nights.completed_nights(tick_count) if settings.is_endless() \
			else mini(settings.cycles, tick_count / settings.cycle_ticks)
	if dawn <= last_dawn:
		return
	last_dawn = dawn
	if settings.is_endless():
		# Частокол против тяжёлых — к ночи босса (решено в сессии, decisions.md).
		if settings.nights.is_boss_night(dawn + 1):
			palisades += 1
		_collect_tribute(dawn)
		_grant_supply(dawn)
		_clean_night_bonus(dawn)
		_offer_boons(dawn)
		# Соловей: засеки — частокол каждый рассвет, пока запас не полон.
		if hero() != null and hero().dawn_palisades > 0:
			palisades = maxi(palisades, mini(hero().palisade_cap, palisades + hero().dawn_palisades))
		# Рассвет: новый прилавок бесплатно, обновление снова дешёвое.
		if settings.market_offers > 0:
			rerolls_today = 0
			_roll_market()
	elif dawn == 1:
		palisades += 1
	var record: Dictionary[String, Variant] = summary()
	record["dawn"] = dawn
	record["roster"] = roster()
	record["idols"] = idol_report()
	record["remaining"] = remaining_report()
	dawns.append(record)
	_event(&"dawn", {"number": dawn})


func _on_killed(mob: MobState) -> void:
	if mob.data.tags.has(settings.boss_tag):
		bosses_killed += 1
		_offer_gifts()
	gold += mob.kill_reward
	earned += mob.kill_reward
	_event(&"killed", {"mob": mob.id, "kind": String(mob.data.id), "reward": mob.kill_reward})


## Победа над боссом: выбор из gift_choices даров без повторов (взятые не предлагаются).
## Выбор дара сейчас (для проверок и инструментов): то же, что после босса.
func offer_gifts_now() -> void:
	_offer_gifts()


func _offer_gifts() -> void:
	var pool: Array[int] = []
	var spare: Array[int] = []
	for index: int in settings.gifts.size():
		if gifts_taken.has(index):
			continue
		if settings.gift_relevance and not _gift_fits(settings.gifts[index], 2):
			spare.append(index)
		else:
			pool.append(index)
	# Подходящих мало — добираем остальными, чтобы выбор был полным.
	while pool.size() < settings.gift_choices and not spare.is_empty():
		pool.append(spare.pop_front())
	if pool.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = gift_rng_state
	gift_choice.clear()
	while gift_choice.size() < settings.gift_choices and not pool.is_empty():
		gift_choice.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	gift_rng_state = rng.state
	_event(&"gift_offer", {"choice": gift_choice.duplicate()})


func _take_gift(index: int) -> String:
	if not gift_choice.has(index):
		return "Этого дара нет в выборе"
	gift_choice.clear()
	gifts_taken.append(index)
	var gift: RitualGiftData = settings.gifts[index]
	match gift.effect:
		RitualGiftData.Effect.FREE_REPAIR:
			free_repair_until = current_night() + gift.value - 1
		RitualGiftData.Effect.HEAL_ILYA:
			hp = maxi(hp, max_hp() + gift.value)
	sync_gifts()
	_event(&"gift", {"gift": String(gift.id)})
	return ""


## Поле видит взятые дары (после снимка восстанавливаются из индексов).
func sync_gifts() -> void:
	field.gifts.clear()
	for index: int in gifts_taken:
		field.gifts.append(settings.gifts[index])
	# Усиления рассвета с постоянным действием считаются полем так же, как дары.
	for index: int in boons_taken:
		if settings.boons[index].effect in [RitualGiftData.Effect.DAMAGE_ALL, RitualGiftData.Effect.DAMAGE_GOD,
				RitualGiftData.Effect.SPLASH_GOD, RitualGiftData.Effect.RANGE_ALL, RitualGiftData.Effect.RATE_ALL]:
			field.gifts.append(settings.boons[index])
	field.mark_towers_changed()


## Дар или усиление стихии подходит городу: у этой стихии не меньше need домов или есть её идол.
func _gift_fits(gift: RitualGiftData, need: int) -> bool:
	if not gift.effect in [RitualGiftData.Effect.DAMAGE_GOD, RitualGiftData.Effect.SPLASH_GOD]:
		return true
	var houses: int = 0
	for tower: TowerState in field.towers:
		houses += int(tower.data.god == gift.god)
	return houses >= need or (need > 1 and field.get_idol(gift.god) != null)


#region Рассвет: чистая ночь, усиления, припасы за золото (docs/37 ECO-3, D4, SUP-2)

func _clean_night_bonus(dawn: int) -> void:
	night_leaks_last = night_leaks
	night_leaks = 0
	last_clean_bonus = 0
	if settings.clean_night_gold <= 0 or night_leaks_last > 0:
		return
	last_clean_bonus = settings.clean_night_gold + settings.clean_night_gold_per_night * dawn
	gold += last_clean_bonus
	earned += last_clean_bonus
	_event(&"clean_night", {"dawn": dawn, "gold": last_clean_bonus})


## Выбор из boon_choices усилений по сиду забега и номеру рассвета; неподходящие городу не идут.
func _offer_boons(dawn: int) -> void:
	boon_choice.clear()
	if settings.boons.is_empty() or settings.boon_choices <= 0:
		return
	var pool: Array[int] = []
	for index: int in settings.boons.size():
		if _boon_fits(settings.boons[index]):
			pool.append(index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + dawn * 104729
	while boon_choice.size() < settings.boon_choices and not pool.is_empty():
		boon_choice.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	_event(&"boon_offer", {"dawn": dawn, "choice": boon_choice.duplicate()})


func _boon_fits(boon: RitualGiftData) -> bool:
	match boon.effect:
		RitualGiftData.Effect.SUPPLY:
			var total: int = 0
			for count: int in supplies:
				total += count
			return settings.supply_cap > 0 and total < settings.supply_cap
		RitualGiftData.Effect.FREE_REPAIR:
			return repair_all_cost() > 0
		RitualGiftData.Effect.UPGRADE_DISCOUNT:
			for tower: TowerState in field.towers:
				if tower.level < settings.combat.max_tower_level:
					return true
			return false
	return _gift_fits(boon, 1)


func _take_boon(index: int) -> String:
	if not boon_choice.has(index):
		return "Этого усиления нет в выборе"
	boon_choice.clear()
	boons_taken.append(index)
	var boon: RitualGiftData = settings.boons[index]
	match boon.effect:
		RitualGiftData.Effect.GOLD:
			var amount: int = boon.value + boon.extra * current_night()
			gold += amount
			earned += amount
		RitualGiftData.Effect.SUPPLY:
			supplies[clampi(boon.value, 0, supplies.size() - 1)] += 1
		RitualGiftData.Effect.PALISADE:
			palisades += boon.value
		RitualGiftData.Effect.UPGRADE_DISCOUNT:
			upgrade_discount_percent = boon.value
			upgrade_discount_dawn = last_dawn + 1
		RitualGiftData.Effect.HERO_HP:
			hero_hp_bonus += boon.value
			hp = mini(max_hp(), hp + boon.value)
		RitualGiftData.Effect.FREE_REPAIR:
			for tower: TowerState in field.towers:
				if tower.durability >= 0:
					tower.durability = settings.max_durability(tower.level)
	sync_gifts()
	_event(&"boon", {"boon": String(boon.id)})
	return ""


func _buy_supply(kind: int) -> String:
	if kind < 0 or kind >= mini(supplies.size(), settings.supply_costs.size()):
		return "Этот припас не продаётся"
	if settings.is_night(tick_count):
		return "Ночью мастера спят: припасы — днём"
	var total: int = 0
	for count: int in supplies:
		total += count
	if total >= settings.supply_cap:
		return "Запас полон (%d)" % settings.supply_cap
	var cost: int = settings.supply_costs[kind]
	if gold < cost:
		return "Не хватает золота"
	gold -= cost
	spent += cost
	supplies[kind] += 1
	_event(&"supply_bought", {"kind": kind, "cost": cost})
	return ""

#endregion


func gift_count(effect: RitualGiftData.Effect) -> int:
	var count: int = 0
	for index: int in gifts_taken:
		count += int(settings.gifts[index].effect == effect)
	return count


func _on_breached(mob: MobState) -> void:
	night_leaks += 1
	if charm_left > 0:
		charm_left -= 1
		_event(&"charm", {"mob": mob.id, "left": charm_left})
		return
	hp = maxi(0, hp - mob.breach_damage)
	_event(&"breach", {"mob": mob.id, "kind": String(mob.data.id), "damage": mob.breach_damage})
	# Вид показывает прорыв (вспышка, урон у сторожки, звук), как в PvP.
	field.breach_resolved.emit(mob, mob.breach_damage)
	if hp == 0:
		phase = Phase.OVER
		# Забег: враг дошёл до сторожки — удар по Илье; Илья погиб — сразу поражение.
		result = (hero().fallen_text if hero() != null else "Илья пал") if settings.is_endless() else "Терем пал"
		field.stopped = true


func _on_hit_observed(details: Dictionary) -> void:
	_event(&"damage", details)


func _on_tower_fired(tower: TowerState, _target: MobState) -> void:
	var house: RitualTower = tower as RitualTower
	if house == null:
		return
	house.used = true
	for support: TowerState in field.get_neighbors(tower):
		if support.data.is_support():
			field.use_support(support)


func _on_field_event(kind: StringName, mob: RitualMob, amount: int) -> void:
	_event(kind, {"mob": mob.id, "amount": amount})


func _event(kind: StringName, details: Dictionary) -> void:
	var record: Dictionary = details.duplicate(true)
	record["tick"] = tick_count
	record["event"] = String(kind)
	journal.append(record)


func roster() -> Array[Dictionary]:
	var result_roster: Array[Dictionary] = []
	for tower: TowerState in field.towers:
		result_roster.append({"id": tower.id, "kind": String(tower.data.id),
			"anchor": tower.anchor, "rotation": tower.rotation})
	return result_roster


func idol_report() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for idol: IdolState in field.idols:
		records.append(RitualStateCodec.capture(idol))
	return records


func remaining_report() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for base: MobState in field.mobs:
		var mob: RitualMob = base as RitualMob
		if mob.is_alive():
			records.append({"id": mob.id, "kind": String(mob.data.id), "hp": mob.hp,
				"max_hp": mob.max_hp, "ward_hp": mob.ward_hp, "progress": mob.progress,
				"statuses": mob.status_tags(), "protected_by": field.banner_sources(mob),
				"boss_phase": int(mob.boss_phase), "immune_until": mob.immune_until})
	return records


func summary() -> Dictionary[String, Variant]:
	return {"simulation_version": SNAPSHOT_VERSION, "rules_hash": rules_hash,
		"tick": tick_count, "hp": hp, "gold": gold, "earned": earned,
		"spent": spent, "refunded": refunded, "alive": field.count_alive_mobs(),
		"result": result, "title": title, "nights": nights_survived(), "bosses": bosses_killed,
		"seed": run_seed}


func snapshot() -> Dictionary[String, Variant]:
	if settings.uses_plots():
		field.refresh_building_bonuses()
	var entities: Array[Dictionary] = []
	for mob: MobState in field.mobs:
		entities.append({"data": String(mob.data.id), "state": RitualStateCodec.capture(mob)})
	var buildings: Array[Dictionary] = []
	for tower: TowerState in field.towers:
		buildings.append({"data": String(tower.data.id), "state": RitualStateCodec.capture(tower)})
	var idols: Array[Dictionary] = []
	for idol: IdolState in field.idols:
		idols.append(RitualStateCodec.capture(idol))
	return {"version": SNAPSHOT_VERSION, "rules": settings.resource_path, "rules_hash": rules_hash,
		"trial": RitualStateCodec.capture(self), "mobs": entities, "towers": buildings,
		"idols": idols, "counters": field.counters(), "stopped": field.stopped,
		"reactions": field.reaction_counts.duplicate(),
		"report": RitualStateCodec.capture(field.battle_report)}


static func from_snapshot(rules: RitualTrialConfig, state: Dictionary) -> RitualTrial:
	if RitualStateCodec.integer(state.get("version", -1), -1) != SNAPSHOT_VERSION \
			or not state.has_all(["trial", "towers", "mobs", "idols", "counters", "stopped", "reactions", "report"]):
		return null
	var trial: RitualTrial = RitualTrial.new(rules, -1)
	if RitualStateCodec.integer(state.get("rules_hash", -1), -1) != trial.rules_hash:
		return null
	RitualStateCodec.apply(trial, RitualStateCodec.dictionary(state["trial"]))
	trial.sync_gifts()
	trial.sync_streets()
	for record: Dictionary in state["towers"]:
		var data: TowerData = null
		for candidate: TowerData in rules.combat.towers:
			if String(candidate.id) == RitualStateCodec.text(record["data"]):
				data = candidate
		if data == null:
			return null
		var tower: TowerState = RitualTower.new() if rules.uses_plots() else TowerState.new()
		tower.data = data
		RitualStateCodec.apply(tower, RitualStateCodec.dictionary(record["state"]))
		trial.field.attach_tower(tower)
	for record: Dictionary in state["mobs"]:
		var data: MobData = null
		for candidate: MobData in rules.enemies:
			if String(candidate.id) == RitualStateCodec.text(record["data"]):
				data = candidate
		if data == null:
			return null
		var mob: RitualMob = RitualMob.from_data(data, rules)
		RitualStateCodec.apply(mob, RitualStateCodec.dictionary(record["state"]))
		trial.field.mobs.append(mob)
	trial.field.idols.clear()
	for values: Dictionary in state["idols"]:
		var idol: IdolState = IdolState.new()
		RitualStateCodec.apply(idol, values)
		trial.field.idols.append(idol)
	trial.field.restore_counters(RitualStateCodec.array(state["counters"]))
	trial.field.stopped = RitualStateCodec.boolean(state["stopped"])
	trial.field.reaction_counts.assign(RitualStateCodec.dictionary(state["reactions"]))
	RitualStateCodec.apply(trial.field.battle_report, RitualStateCodec.dictionary(state["report"]))
	trial.field.wave_tick = trial.tick_count
	trial.field.mark_towers_changed()
	return trial


func fork_control(mode: ControlMode) -> RitualTrial:
	var branch: RitualTrial = from_snapshot(settings, snapshot())
	branch.control_mode = mode
	branch.economy_frozen = true
	return branch


func state_hash() -> int:
	var hasher: StateHasher = StateHasher.new()
	var state: Dictionary[String, Variant] = snapshot()
	# Равные правила могут быть загружены из файла или скопированы для стенда.
	# Их содержание уже проверяет rules_hash; путь не является состоянием игры.
	state.erase("rules")
	RitualStateCodec.hash_value(hasher, state)
	return hasher.value
