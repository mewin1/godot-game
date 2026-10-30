class_name BotBrain
extends RefCounted
## Простой бот. Играет теми же командами, что и человек, случайность — только из ГСЧ игрока,
## поэтому бот тоже детерминирован. Действует один раз в начале каждой подготовки.

## Повышать магазин, только когда цена упала до этого значения (или раунд уже поздний).
const VERSION: int = 4
const CHEAP_UPGRADE_COST: int = 5
const LATE_ROUND: int = 4
## Пока стреляющих башен меньше — бот берёт только стрелков (усилители и лавки потом).
const MIN_SHOOTERS_BEFORE_SUPPORT: int = 3
## Стиль бота: какую долю золота в начале подготовки он тратит на армию (остальное — башни).
var army_share_percent: int = 30


func _init(army_share: int) -> void:
	army_share_percent = army_share


## Герой — случайный из предложенных: так прогоны ботов честно меряют силу каждого героя.
func pick_hero(player: PlayerState) -> int:
	return player.rng.randi_range(0, player.hero_offers.size() - 1)


func play_prep(sim: MatchSim, player: PlayerState) -> void:
	_take_gifts(sim, player)
	_choose_buff(sim, player)
	_merge_all_pairs(sim, player)
	_maybe_use_skill(sim, player, HeroSkillData.Timing.PREP)
	_use_free_rerolls(sim, player)
	_maybe_upgrade_shop(sim, player)
	_buy_army_with_budget(sim, player, player.gold * army_share_percent / 100)
	_buy_rites(sim, player)
	_buy_towers(sim, player)
	_merge_all_pairs(sim, player)
	_buy_towers(sim, player)
	_take_gifts(sim, player)
	_spend_rest_on_army(sim, player)


## В волну бот смотрит только на навык «в волну» (или «когда угодно»).
func play_wave(sim: MatchSim, player: PlayerState) -> void:
	_maybe_use_skill(sim, player, HeroSkillData.Timing.WAVE)


## Жмёт навык, если он для этой фазы, хватает золота и эффект говорит «пора».
func _maybe_use_skill(sim: MatchSim, player: PlayerState, timing: HeroSkillData.Timing) -> void:
	if player.hero == null or player.hero.skill == null:
		return
	var skill: HeroSkillData = player.hero.skill
	if skill.timing != timing and skill.timing != HeroSkillData.Timing.ANY:
		return
	if player.check_skill_available(sim.phase) != "" or player.gold < player.get_skill_cost():
		return
	if skill.effect.bot_wants_to_use(sim, player):
		_execute(sim, player, UseHeroSkillCommand.new())


## «Тройка»: случайный подарок и сразу на лучшее место (если есть).
func _take_gifts(sim: MatchSim, player: PlayerState) -> void:
	if not player.discover_offers.is_empty():
		var choice: int = player.rng.randi_range(0, player.discover_offers.size() - 1)
		_execute(sim, player, ChooseDiscoverCommand.new(choice))
	var index: int = player.gift_towers.size() - 1
	while index >= 0:
		var spot: Vector3i = find_best_spot(player.field, player.gift_towers[index])
		if spot.z >= 0:
			_execute(sim, player, PlaceGiftCommand.new(index, Vector2i(spot.x, spot.y), spot.z))
		index -= 1


func _use_free_rerolls(sim: MatchSim, player: PlayerState) -> void:
	while player.free_rerolls_left > 0:
		if not _run(sim, player, RerollShopCommand.new()):
			return


func _choose_buff(sim: MatchSim, player: PlayerState) -> void:
	if player.buff_offers.is_empty():
		return
	var choice: int = player.rng.randi_range(0, player.buff_offers.size() - 1)
	_execute(sim, player, ChooseBuffCommand.new(choice))


func _maybe_upgrade_shop(sim: MatchSim, player: PlayerState) -> void:
	if not player.shop.can_upgrade():
		return
	var price: int = player.get_shop_upgrade_price()
	var is_cheap: bool = price <= CHEAP_UPGRADE_COST
	if not is_cheap and sim.round_number < LATE_ROUND:
		return
	if player.gold >= price + sim.config.tower_cost:
		_execute(sim, player, UpgradeShopCommand.new())


## Тратит на армию не больше budget золота (случайные доступные улучшения).
func _buy_army_with_budget(sim: MatchSim, player: PlayerState, budget: int) -> void:
	var spent: int = 0
	var index: int = _pick_affordable_upgrade(player, player.gold - (budget - spent))
	while index >= 0:
		var cost: int = player.army.get_upgrade_cost(index)
		if not _run(sim, player, BuyArmyUpgradeCommand.new(index)):
			return
		spent += cost
		index = _pick_affordable_upgrade(player, player.gold - (budget - spent))


## Остаток золота после башен — в армию (если на башни уже нет места или золота).
func _spend_rest_on_army(sim: MatchSim, player: PlayerState) -> void:
	var index: int = _pick_affordable_upgrade(player, 0)
	while index >= 0 and _run(sim, player, BuyArmyUpgradeCommand.new(index)):
		index = _pick_affordable_upgrade(player, 0)


## Случайное доступное улучшение, на которое хватает золота с запасом reserve; -1 — нет такого.
func _pick_affordable_upgrade(player: PlayerState, reserve: int) -> int:
	var choices: Array[int] = []
	for index: int in player.army.upgrade_counts.size():
		if player.army.check_upgrade_available(index, player.shop.level) != "":
			continue
		if player.gold >= player.army.get_upgrade_cost(index) + reserve:
			choices.append(index)
	if choices.is_empty():
		return -1
	return choices[player.rng.randi_range(0, choices.size() - 1)]


## Покупает, пока хватает золота: сначала копии для слияния, потом — на лучшее место.
func _buy_towers(sim: MatchSim, player: PlayerState) -> void:
	var bought: bool = true
	var rerolled: bool = false
	while player.gold >= sim.config.tower_cost:
		bought = false
		for offer_index: int in player.shop.offers.size():
			var data: TowerData = player.shop.get_offer(offer_index)
			if data == null or not _wants_tower(player, data):
				continue
			if _buy_one(sim, player, offer_index, data):
				bought = true
				break
		if bought:
			continue
		# Нечего брать — один раз обновить витрину, если стрелков мало и золота хватает.
		var can_reroll: bool = player.gold >= player.get_reroll_price() + sim.config.tower_cost
		if rerolled or not can_reroll or _count_shooters(player) >= MIN_SHOOTERS_BEFORE_SUPPORT:
			return
		rerolled = _run(sim, player, RerollShopCommand.new())


func _wants_tower(player: PlayerState, data: TowerData) -> bool:
	if data.wet_ticks > 0:
		var partners: int = 0
		var water: int = 0
		var can_merge: bool = false
		for tower: TowerState in player.field.towers:
			partners += 1 if _uses_wet(tower.data) else 0
			water += 1 if tower.data.wet_ticks > 0 else 0
			can_merge = can_merge or (tower.data == data and tower.level == 1)
		return partners >= 2 and (can_merge or water < maxi(1, partners / 4))
	return data.attacks or _count_shooters(player) >= MIN_SHOOTERS_BEFORE_SUPPORT


func _count_shooters(player: PlayerState) -> int:
	var count: int = 0
	for tower: TowerState in player.field.towers:
		if tower.data.attacks and tower.data.damage > 0:
			count += 1
	return count


func _buy_one(sim: MatchSim, player: PlayerState, offer_index: int, data: TowerData) -> bool:
	for tower: TowerState in player.field.towers:
		if tower.data == data and tower.level == 1:
			return _run(sim, player, BuyIntoTowerCommand.new(offer_index, tower.id))
	var spot: Vector3i = find_best_spot(player.field, data)
	if spot.z < 0:
		return false
	return _run(sim, player, BuyTowerCommand.new(offer_index, Vector2i(spot.x, spot.y), spot.z))


## Лучшее место: больше всего клеток пути в радиусе. Возвращает (x, y, поворот) или z = -1.
func find_best_spot(field: FieldState, data: TowerData) -> Vector3i:
	var best: Vector3i = Vector3i(0, 0, -1)
	var best_score: int = 0
	for y: int in field.layout.height:
		for x: int in field.layout.width:
			for turns: int in TowerState.ROTATIONS:
				var cells: Array[Vector2i] = TowerState.shape_cells_at(data.shape,
						Vector2i(x, y), turns)
				if not field.can_place(cells):
					continue
				var score: int = _score_spot(field, data, cells)
				if data.wind_length_milli > 0:
					score = _score_wind(field, data, Vector2i(x, y), turns)
				if score > best_score:
					best_score = score
					best = Vector3i(x, y, turns)
	return best


## Оценка места: стрелкам — сколько клеток пути в радиусе; усилителям — сколько стреляющих
## соседей будет рядом (×10, чтобы ставились в кучу); лавке — любое место (подальше от пути).
func _score_spot(field: FieldState, data: TowerData, cells: Array[Vector2i]) -> int:
	if data.wet_ticks > 0:
		return _score_water(field, data, cells)
	if data.attacks:
		return field.count_path_cells_in_range(cells, data.range_milli)
	if data.income_per_round > 0:
		return 1
	var neighbors: Array[int] = []
	for cell: Vector2i in cells:
		for side: Vector2i in FieldState.NEIGHBOR_SIDES:
			var tower: TowerState = field.get_tower_at(cell + side)
			if tower != null and tower.data.attacks and not neighbors.has(tower.id):
				neighbors.append(tower.id)
	return neighbors.size() * 10


func _merge_all_pairs(sim: MatchSim, player: PlayerState) -> void:
	var merged: bool = true
	while merged:
		merged = false
		var towers: Array[TowerState] = player.field.towers
		for i: int in towers.size():
			for j: int in range(i + 1, towers.size()):
				if _can_merge(sim, towers[i], towers[j]):
					merged = _run(sim, player, MergeTowersCommand.new(towers[j].id, towers[i].id))
					break
			if merged:
				break


func _can_merge(sim: MatchSim, a: TowerState, b: TowerState) -> bool:
	return a.data == b.data and a.level == b.level and a.level < sim.config.max_tower_level


func _run(sim: MatchSim, player: PlayerState, command: SimCommand) -> bool:
	return sim.execute_command(player.index, command) == ""


## То же, что _run, когда результат не нужен: отказ для бота не ошибка, а просто «не вышло».
func _execute(sim: MatchSim, player: PlayerState, command: SimCommand) -> void:
	if not _run(sim, player, command):
		return


## Вода должна накрывать общий участок с башнями, использующими мокроту.
func _score_water(field: FieldState, data: TowerData, cells: Array[Vector2i]) -> int:
	var center: Vector2i = TowerState.center_of(cells)
	var score: int = 0
	for point: Vector2i in field.get_active_path():
		var position: Vector2i = point * FieldState.MILLI + Vector2i(500, 500)
		var offset: Vector2i = position - center
		if offset.x * offset.x + offset.y * offset.y > data.range_milli * data.range_milli:
			continue
		score += 1
		for tower: TowerState in field.towers:
			if not _uses_wet(tower.data):
				continue
			var reach: int = field.get_tower_range(tower)
			var distance: Vector2i = position - tower.center_milli()
			if distance.x * distance.x + distance.y * distance.y <= reach * reach:
				score += 2
	return score


func _score_wind(field: FieldState, data: TowerData, anchor: Vector2i, turns: int) -> int:
	var tower: TowerState = TowerState.new()
	tower.data = data
	tower.anchor = anchor
	tower.rotation = turns
	var direction: Vector2i = DivineCombat.wind_direction(tower)
	var score: int = 0
	var path: Array[Vector2i] = field.get_active_path()
	for i: int in range(path.size() - 1):
		var point: Vector2i = path[i] * FieldState.MILLI + Vector2i(500, 500)
		if not DivineCombat.is_in_wind(field, tower, point):
			continue
		var movement: Vector2i = path[i + 1] - path[i]
		var alignment: int = movement.x * direction.x + movement.y * direction.y
		score += 3 if alignment < 0 else (-4 if alignment > 0 else 1)
	return score


func _buy_rites(sim: MatchSim, player: PlayerState) -> void:
	if _count_shooters(player) < MIN_SHOOTERS_BEFORE_SUPPORT:
		return
	for i: int in player.shop.offers.size():
		var rite: RiteData = player.shop.get_rite(i)
		if rite == null or player.gold < rite.cost + sim.config.tower_cost:
			continue
		if rite.target == RiteData.Target.IDOL:
			var has_god: bool = false
			for tower: TowerState in player.field.towers:
				has_god = has_god or tower.data.god == rite.god
			if not has_god:
				continue
			for slot: int in player.field.idols.size():
				if _run(sim, player, BuyRiteCommand.new(i, slot)):
					break
		else:
			for tower: TowerState in player.field.towers:
				if _run(sim, player, BuyRiteCommand.new(i, tower.id)):
					break


func _uses_wet(data: TowerData) -> bool:
	return data.tags.has(&"lightning") or data.tags.has(&"ice") \
			or data.tags.has(&"curse") or data.tags.has(&"fire") or data.god == &"perun"
