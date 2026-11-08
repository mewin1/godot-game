class_name BattleHeroes
extends RefCounted
## Команды и время приёмов; применение эффектов вынесено в BattleHeroEffects.

var orders: Array[BattleHeroOrder] = []


func get_order(owner: int) -> BattleHeroOrder:
	for order: BattleHeroOrder in orders:
		if order.owner == owner:
			return order
	return null


func prepare(sim: MatchSim) -> void:
	orders.clear()
	for player: PlayerState in sim.get_alive_players():
		if player.hero != null:
			orders.append(BattleHeroOrder.new(player.index,
					sim.config.active_battle.skill_for(player.hero.id)))


func start(sim: MatchSim) -> void:
	for order: BattleHeroOrder in orders:
		_set_default(sim, order)
	if sim.ghost_field != null and sim.players[sim.ghost_source].hero != null:
		var ghost: BattleHeroOrder = BattleHeroOrder.new(MatchSim.GHOST,
				sim.config.active_battle.skill_for(sim.players[sim.ghost_source].hero.id))
		orders.append(ghost)
		_set_default(sim, ghost)


static func field_for(sim: MatchSim, index: int) -> FieldState:
	if index == MatchSim.GHOST:
		return sim.ghost_field
	if index < 0 or index >= sim.players.size():
		return null
	return sim.players[index].field


func aim(sim: MatchSim, owner: int, target: int, cell: Vector2i,
		tower_id: int, second_id: int) -> String:
	var order: BattleHeroOrder = get_order(owner)
	if order == null or order.skill == null:
		return "У героя нет боевого приёма"
	if sim.phase not in [MatchSim.Phase.PREP, MatchSim.Phase.WAVE] or order.used_tick >= 0:
		return "Прицел сейчас менять нельзя"
	if order.skill.requires_preparation() and sim.phase != MatchSim.Phase.PREP:
		return "Башни и площадки выбираются до боя"
	if not _valid_target(sim, order, target):
		return "Приём не действует на это поле"
	var field: FieldState = field_for(sim, target)
	if field == null or not field.layout.is_inside(cell):
		return "Выберите клетку поля"
	order.target = target
	order.cell = cell
	order.tower_id = tower_id
	order.second_id = second_id
	return ""


func check(sim: MatchSim, owner: int) -> String:
	var order: BattleHeroOrder = get_order(owner)
	if order == null or order.skill == null:
		return "У героя нет боевого приёма"
	if sim.phase != MatchSim.Phase.WAVE:
		return "Приём доступен в бою; цель можно подготовить сейчас"
	if owner >= 0 and sim.players[owner].hero_hp <= 0:
		return "Крепость разрушена"
	if owner == sim.resting_player and owner != MatchSim.GHOST:
		return "Раунд отдыха"
	if order.used_tick >= 0:
		return "Приём уже использован"
	if not _valid_target(sim, order, order.target):
		return "Выберите поле, куда идёт ваша армия"
	var field: FieldState = field_for(sim, order.target)
	if field == null:
		return "Нет поля цели"
	var tower: TowerState = field.get_tower(order.tower_id)
	match order.skill.kind:
		BattleSkillData.Kind.WALK:
			if tower == null or not field.can_place_tower_data(tower.data, order.cell, tower.rotation):
				return "Выберите башню и свободную площадку до боя"
		BattleSkillData.Kind.SWAP:
			if not SiegeTowerSwap.can_swap(field, tower, field.get_tower(order.second_id)):
				return "Выберите две башни, которые помещаются на местах друг друга"
		BattleSkillData.Kind.CHARGE:
			if tower == null or not tower.data.attacks:
				return "Выберите стреляющую башню до боя"
	return ""


func use_skill(sim: MatchSim, owner: int) -> String:
	var error: String = check(sim, owner)
	if error != "":
		return error
	var order: BattleHeroOrder = get_order(owner)
	order.used_tick = sim.phase_tick
	order.warning_left = order.skill.warning_ticks
	order.active_left = order.skill.duration_ticks
	BattleHeroEffects.begin(sim, order)
	if owner >= 0:
		sim.players[owner].is_skill_used_this_round = true
		sim.players[owner].skill_uses += 1
		sim.players[owner].hero_message = order.skill.title
		sim.hero_event.emit(owner, order.skill.title)
	return ""


func tick(sim: MatchSim) -> void:
	for order: BattleHeroOrder in orders:
		if order.skill == null:
			continue
		if order.used_tick < 0:
			_bot_tick(sim, order)
		if order.used_tick < 0 or order.resolved:
			continue
		if order.warning_left > 0:
			order.warning_left -= 1
			if order.warning_left > 0:
				continue
		BattleHeroEffects.tick(sim, order)


func _valid_target(sim: MatchSim, order: BattleHeroOrder, target: int) -> bool:
	if not order.skill.offensive:
		return target == order.owner
	if order.owner == MatchSim.GHOST:
		return target == sim.ghost_target
	if target == MatchSim.GHOST:
		return order.owner == sim.ghost_target
	for route: Vector2i in sim._army_routes:
		if route == Vector2i(order.owner, target):
			return true
	return false


func _set_default(sim: MatchSim, order: BattleHeroOrder) -> void:
	if order.skill == null:
		return
	if order.skill.offensive:
		if order.owner == MatchSim.GHOST:
			order.target = sim.ghost_target
		elif not _valid_target(sim, order, order.target):
			order.target = sim.opponent_of[order.owner]
	var field: FieldState = field_for(sim, order.target)
	if field == null:
		return
	if order.cell == Vector2i(-1, -1):
		order.cell = field.layout.path_cells[field.path_length / 2]
	if not order.skill.requires_preparation() or order.tower_id != 0:
		return
	for tower: TowerState in field.towers:
		if order.skill.kind == BattleSkillData.Kind.CHARGE and tower.data.attacks:
			order.tower_id = tower.id
			return
		if order.skill.kind == BattleSkillData.Kind.SWAP:
			for other: TowerState in field.towers:
				if SiegeTowerSwap.can_swap(field, tower, other):
					order.tower_id = tower.id
					order.second_id = other.id
					return
		if order.skill.kind == BattleSkillData.Kind.WALK:
			for y: int in field.layout.height:
				for x: int in field.layout.width:
					var destination: Vector2i = Vector2i(x, y)
					if field.can_place_tower_data(tower.data, destination, tower.rotation):
						order.tower_id = tower.id
						order.cell = destination
						return


func _bot_tick(sim: MatchSim, order: BattleHeroOrder) -> void:
	if order.owner >= 0 and not sim.players[order.owner].is_bot:
		return
	if order.owner >= 0 and not sim.players[order.owner].is_alive:
		return
	var settings: ActiveBattleConfig = sim.config.active_battle
	var ready: bool = sim.phase_tick >= settings.bot_skill_ticks
	var field: FieldState = field_for(sim, order.target)
	if field == null:
		return
	if order.skill.kind == BattleSkillData.Kind.WARD:
		ready = false
	elif order.skill.offensive:
		var sender: int = -2 if order.owner == MatchSim.GHOST else order.owner
		ready = ready and field.count_alive_mobs_of(sender) > 0
	else:
		ready = ready and field.count_alive_mobs() > 0
	if order.skill.kind in [BattleSkillData.Kind.WARD, BattleSkillData.Kind.WALK, BattleSkillData.Kind.SWAP]:
		for other: BattleHeroOrder in orders:
			if other.skill == null or other.skill.kind != BattleSkillData.Kind.SUPPRESS:
				continue
			if other.target == order.owner and other.used_tick >= 0 and not other.resolved \
					and sim.phase_tick >= other.used_tick + settings.bot_reaction_ticks:
				ready = true
				if order.skill.kind == BattleSkillData.Kind.WARD:
					order.cell = other.cell
	if ready:
		if order.skill.kind == BattleSkillData.Kind.SUPPRESS and not field.towers.is_empty():
			var best: TowerState = field.towers[0]
			for tower: TowerState in field.towers:
				if tower.level > best.level:
					best = tower
			order.cell = best.anchor
		elif order.skill.kind == BattleSkillData.Kind.STRIKE and not field.mobs.is_empty():
			order.cell = field.get_mob_position(field.mobs[0]) / FieldState.MILLI
		use_skill(sim, order.owner)


func snapshot(owner: int) -> Dictionary:
	var order: BattleHeroOrder = get_order(owner)
	if order == null or order.skill == null:
		return {}
	return {"hero": order.skill.hero_id, "tick": order.used_tick, "target": order.target,
			"cell": [order.cell.x, order.cell.y], "tower": order.tower_id, "second": order.second_id}


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add(orders.size())
	for order: BattleHeroOrder in orders:
		order.add_to_hash(hasher)
