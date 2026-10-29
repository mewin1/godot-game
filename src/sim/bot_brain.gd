class_name BotBrain
extends RefCounted
## Простой бот. Играет теми же командами, что и человек, случайность — только из ГСЧ игрока,
## поэтому бот тоже детерминирован. Действует один раз в начале каждой подготовки.

## Повышать магазин, только когда цена упала до этого значения (или раунд уже поздний).
const CHEAP_UPGRADE_COST: int = 4
const LATE_ROUND: int = 4
## Шанс отправить в раунде, если хватает золота (в процентах).
const SEND_CHANCE_PERCENT: int = 50


func play_prep(sim: MatchSim, player: PlayerState) -> void:
	_choose_buff(sim, player)
	_merge_all_pairs(sim, player)
	_maybe_upgrade_shop(sim, player)
	_maybe_send(sim, player)
	_buy_towers(sim, player)
	_merge_all_pairs(sim, player)


func _choose_buff(sim: MatchSim, player: PlayerState) -> void:
	if player.buff_offers.is_empty():
		return
	var choice: int = player.rng.randi_range(0, player.buff_offers.size() - 1)
	_execute(sim, player, ChooseBuffCommand.new(choice))


func _maybe_upgrade_shop(sim: MatchSim, player: PlayerState) -> void:
	if not player.shop.can_upgrade():
		return
	var is_cheap: bool = player.shop.upgrade_cost <= CHEAP_UPGRADE_COST
	if not is_cheap and sim.round_number < LATE_ROUND:
		return
	if player.gold >= player.shop.upgrade_cost + sim.config.tower_cost:
		_execute(sim, player, UpgradeShopCommand.new())


func _maybe_send(sim: MatchSim, player: PlayerState) -> void:
	if sim.round_number < 2:
		return
	if player.gold < sim.get_send_cost(player) + sim.config.tower_cost:
		return
	if player.rng.randi_range(1, 100) <= SEND_CHANCE_PERCENT:
		_execute(sim, player, SendUnitsCommand.new())


## Покупает, пока хватает золота: сначала копии для слияния, потом — на лучшее место.
func _buy_towers(sim: MatchSim, player: PlayerState) -> void:
	var bought: bool = true
	while bought and player.gold >= sim.config.tower_cost:
		bought = false
		for offer_index: int in player.shop.offers.size():
			var data: TowerData = player.shop.get_offer(offer_index)
			if data == null:
				continue
			if _buy_one(sim, player, offer_index, data):
				bought = true
				break


func _buy_one(sim: MatchSim, player: PlayerState, offer_index: int, data: TowerData) -> bool:
	for tower: TowerState in player.field.towers:
		if tower.data == data and tower.level == 1:
			return _run(sim, player, BuyIntoTowerCommand.new(offer_index, tower.id))
	var spot: Vector3i = _find_best_spot(player.field, data)
	if spot.z < 0:
		return false
	return _run(sim, player, BuyTowerCommand.new(offer_index, Vector2i(spot.x, spot.y), spot.z))


## Лучшее место: больше всего клеток пути в радиусе. Возвращает (x, y, поворот) или z = -1.
func _find_best_spot(field: FieldState, data: TowerData) -> Vector3i:
	var best: Vector3i = Vector3i(0, 0, -1)
	var best_score: int = 0
	for y: int in field.layout.height:
		for x: int in field.layout.width:
			for turns: int in TowerState.ROTATIONS:
				var cells: Array[Vector2i] = TowerState.shape_cells_at(data.shape,
						Vector2i(x, y), turns)
				if not field.can_place(cells):
					continue
				var score: int = field.count_path_cells_in_range(cells, data.range_milli)
				if score > best_score:
					best_score = score
					best = Vector3i(x, y, turns)
	return best


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
