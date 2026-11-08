class_name SiegeTrial
extends RefCounted
## Изолированная дуэль на настоящих полях. Целые тики, команды, воспроизводимый бот.

enum Phase { PREP, BATTLE, OVER }
const YAGA: StringName = &"baba_yaga"
const GORYNYCH: StringName = &"gorynych"
const DOMOVOY: StringName = &"domovoy"
const MILLI: int = 1000

var settings: SiegeTrialConfig
var sides: Array[SiegeTrialSide] = []
var phase: Phase = Phase.PREP
var tick_count: int = 0
var seed_value: int
var bot_enabled: bool = true
var bot_release_at: int
var bot_defense_index: int = -1
var journal: PackedStringArray = []


func _init(config: SiegeTrialConfig, hero: StringName = YAGA, match_seed: int = 137) -> void:
	settings = config
	seed_value = match_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = match_seed
	bot_release_at = config.bot_release_ticks[rng.randi_range(0, config.bot_release_ticks.size() - 1)]
	var reserve_kind: int = rng.randi_range(0, config.reserve_plans.size() - 1)
	var bot_hero: StringName = YAGA if hero == GORYNYCH else GORYNYCH
	if rng.randi_range(0, 99) < config.bot_domovoy_chance:
		bot_hero = DOMOVOY
	if not config.bot_defenses.is_empty():
		bot_defense_index = rng.randi_range(0, config.bot_defenses.size() - 1)
	for index: int in 2:
		var positions: Array[Vector2i] = config.positions
		if index == 1 and bot_defense_index >= 0:
			positions = config.bot_defenses[bot_defense_index].positions
		sides.append(_create_side(index, hero if index == 0 else bot_hero, positions))
	sides[1].reserve_kind = reserve_kind
	for index: int in sides.size():
		if sides[index].hero != GORYNYCH:
			var error: String = _choose_hut(index, sides[index].walk_tower_id)
			assert(error.is_empty(), "Для героя нет допустимой подготовки: %s" % error)


func _create_side(index: int, hero: StringName, positions: Array[Vector2i]) -> SiegeTrialSide:
	var side: SiegeTrialSide = SiegeTrialSide.new()
	side.hero = hero
	side.hp = settings.hero_hp
	side.field = FieldState.new(settings.game, settings.shop_level, seed_value + index)
	side.destination = settings.walk_destination
	side.walk_origin = positions[0]
	side.target = settings.fire_target
	for slot: int in settings.towers.size():
		assert(side.field.can_place_tower_data(settings.towers[slot], positions[slot], 0), "Недопустимая расстановка дуэли")
		var tower: TowerState = side.field.add_tower(settings.towers[slot], positions[slot], 0)
		tower.level = settings.levels[slot]
	side.walk_tower_id = side.field.towers[0].id
	return side


func execute(command: SiegeTrialCommand) -> String:
	if command.side < 0 or command.side >= sides.size():
		return "Нет такого игрока"
	var side: SiegeTrialSide = sides[command.side]
	match command.action:
		SiegeTrialCommand.Action.START:
			if phase != Phase.PREP:
				return "Бой уже начался"
			_start()
		SiegeTrialCommand.Action.RESERVE:
			if phase != Phase.PREP or command.value < 0 or command.value >= settings.reserve_plans.size():
				return "Подкрепление выбирается до боя"
			side.reserve_kind = command.value
		SiegeTrialCommand.Action.TARGET:
			return _choose_target(command.side, command.cell)
		SiegeTrialCommand.Action.HUT:
			return _choose_hut(command.side, command.value)
		SiegeTrialCommand.Action.RELEASE:
			if phase != Phase.BATTLE or side.released:
				return "Подкрепление уже вышло или бой не идёт"
			_release(command.side)
		SiegeTrialCommand.Action.SKILL:
			if phase != Phase.BATTLE or side.skill_used:
				return "Приём уже потрачен или бой не идёт"
			_use_skill(command.side)
	return ""


func _choose_target(index: int, cell: Vector2i) -> String:
	var side: SiegeTrialSide = sides[index]
	if phase == Phase.OVER or side.skill_used:
		return "Приём уже потрачен"
	if side.hero == DOMOVOY:
		return _choose_swap_target(side, cell)
	if side.hero == YAGA:
		if phase != Phase.PREP:
			return "Место для избушки выбирается до боя"
		var tower: TowerState = side.walking_tower()
		if cell == tower.anchor or not side.field.can_place_tower_data(tower.data, cell, 0):
			return "Выберите свободную открытую площадку"
		side.destination = cell
	else:
		var target_field: FieldState = sides[1 - index].field
		if cell.x < 0 or cell.y < 0 or cell.x >= target_field.layout.width or cell.y >= target_field.layout.height:
			return "Выберите участок чужого поля"
		side.target = cell
	return ""


func _choose_hut(index: int, tower_id: int) -> String:
	var side: SiegeTrialSide = sides[index]
	if phase != Phase.PREP or side.hero == GORYNYCH:
		return "Башня для приёма выбирается до боя"
	var tower: TowerState = side.field.get_tower(tower_id)
	if tower == null:
		return "Выберите свою башню"
	if side.hero == DOMOVOY:
		return _choose_swap_first(side, tower)
	var destination: Vector2i = side.destination
	if not side.field.can_place_tower_data(tower.data, destination, 0):
		destination = _free_destination(side.field, tower)
	if destination == Vector2i(-1, -1):
		return "Для этой башни нет свободной площадки"
	side.walk_tower_id = tower.id
	side.walk_origin = tower.anchor
	side.destination = destination
	return ""


func _choose_swap_first(side: SiegeTrialSide, tower: TowerState) -> String:
	var other: TowerState = side.field.get_tower(side.swap_tower_id)
	if not SiegeTowerSwap.can_swap(side.field, tower, other):
		other = null
		for candidate: TowerState in side.field.towers:
			if SiegeTowerSwap.can_swap(side.field, tower, candidate):
				other = candidate
				break
	if other == null:
		return "Для этой башни нет подходящей пары"
	side.walk_tower_id = tower.id
	side.swap_tower_id = other.id
	side.walk_origin = tower.anchor
	side.destination = other.anchor
	return ""


func _choose_swap_target(side: SiegeTrialSide, cell: Vector2i) -> String:
	if phase != Phase.PREP:
		return "Пара башен выбирается до боя"
	var other: TowerState = side.field.get_tower_at(cell)
	if not SiegeTowerSwap.can_swap(side.field, side.walking_tower(), other):
		return "Эти башни не помещаются на местах друг друга"
	side.swap_tower_id = other.id
	side.destination = other.anchor
	return ""


func _free_destination(field: FieldState, tower: TowerState) -> Vector2i:
	for y: int in field.layout.height:
		for x: int in field.layout.width:
			var cell: Vector2i = Vector2i(x, y)
			if field.can_place_tower_data(tower.data, cell, 0):
				return cell
	return Vector2i(-1, -1)


func _start() -> void:
	phase = Phase.BATTLE
	for side: SiegeTrialSide in sides:
		side.field.start_wave()
	for index: int in sides.size():
		_schedule(index, false)
	_note("Бой начался. Подкрепление ждёт вашего приказа")


func _schedule(sender: int, reserve: bool) -> void:
	var side: SiegeTrialSide = sides[sender]
	var plan: SiegeReservePlan = settings.reserve_plans[side.reserve_kind]
	var first: int = plan.opening_count if reserve else 0
	var last: int = plan.order.size() if reserve else plan.opening_count
	for index: int in range(first, last):
		_schedule_mob(sender, plan.order[index], tick_count + (index - first) * settings.spawn_interval, reserve)
	if not reserve:
		for index: int in settings.main_count:
			_schedule_mob(sender, -1, tick_count + (plan.opening_count + index) * settings.spawn_interval, false)


func _schedule_mob(sender: int, kind: int, at: int, held: bool) -> void:
	var reserve: bool = kind >= 0
	var data: MobData = settings.reserves[kind] if reserve else settings.main_mob
	var mob: MobState = MobState.create(data)
	mob.hp = settings.reserve_hp[kind] if reserve else settings.main_hp
	mob.max_hp = mob.hp
	mob.speed = settings.reserve_speed[kind] if reserve else settings.main_speed
	mob.sender_index = sender
	sides[1 - sender].field.schedule_spawn(mob, at)
	sides[sender].attack.record(mob, held, at)


func _release(index: int, automatic: bool = false) -> void:
	var side: SiegeTrialSide = sides[index]
	side.released = true
	side.released_tick = tick_count
	side.released_automatically = automatic
	_schedule(index, true)
	_note("%s: подкрепление вышло%s" % [side_name(index), " автоматически — срок истёк" if automatic else ""])


func _use_skill(index: int) -> void:
	var side: SiegeTrialSide = sides[index]
	side.skill_used = true
	side.skill_tick = tick_count
	if side.hero == YAGA:
		side.walk_left = settings.walk_ticks
		_note("%s: избушка шагает — пока не стреляет" % side_name(index))
	elif side.hero == DOMOVOY:
		side.swap_left = settings.swap_ticks
		_note("%s: Домовой меняет башни — обе пока не стреляют" % side_name(index))
	else:
		side.warning_left = settings.fire_warning_ticks
		_note("%s: Горыныч готовит налёт!" % side_name(index))


func tick() -> void:
	if phase != Phase.BATTLE:
		return
	if bot_enabled:
		_bot_turn()
	for index: int in sides.size():
		if not sides[index].released and tick_count >= settings.reserve_deadline:
			_release(index, true)
		_suppress_towers(index)
	for side: SiegeTrialSide in sides:
		side.field.tick()
		_collect_breaches(side)
	for index: int in sides.size():
		_advance_skill(index)
	tick_count += 1
	if tick_count >= settings.max_ticks:
		for side: SiegeTrialSide in sides:
			side.field.breach_all_remaining()
			_collect_breaches(side)
	if _is_finished():
		phase = Phase.OVER
		_note(result_text())


func _suppress_towers(index: int) -> void:
	var side: SiegeTrialSide = sides[index]
	if side.walk_left > 0:
		var tower: TowerState = side.walking_tower()
		tower.cooldown_left = maxi(1, tower.cooldown_left)
	if side.swap_left > 0:
		for tower_id: int in [side.walk_tower_id, side.swap_tower_id]:
			var tower: TowerState = side.field.get_tower(tower_id)
			tower.cooldown_left = maxi(1, tower.cooldown_left)
	if side.fire_left <= 0:
		return
	for tower: TowerState in sides[1 - index].field.towers:
		if in_fire_zone(index, tower):
			tower.cooldown_left = maxi(1, tower.cooldown_left)


func in_fire_zone(caster: int, tower: TowerState) -> bool:
	return _point_in_fire_zone(caster, tower.center_milli())


func _point_in_fire_zone(caster: int, point: Vector2i) -> bool:
	var center: Vector2i = sides[caster].target * MILLI + Vector2i(MILLI / 2, MILLI / 2)
	var offset: Vector2i = point - center
	return offset.length_squared() <= settings.fire_radius_milli * settings.fire_radius_milli


func _advance_skill(index: int) -> void:
	var side: SiegeTrialSide = sides[index]
	if side.swap_left > 0:
		side.swap_left -= 1
		if side.swap_left == 0:
			SiegeTowerSwap.apply(side.field, side.walking_tower(), side.field.get_tower(side.swap_tower_id))
			_note("%s: башни поменялись местами" % side_name(index))
	if side.walk_left > 0:
		side.walk_left -= 1
		if side.walk_left == 0:
			var moved: bool = side.field.move_tower(side.walking_tower(), side.destination, 0)
			assert(moved, "Зарезервированная позиция избушки должна быть свободна")
			side.field.mark_towers_changed()
			_note("%s: избушка на новой позиции" % side_name(index))
	if side.fire_left > 0:
		side.fire_left -= 1
	if side.warning_left > 0:
		side.warning_left -= 1
		if side.warning_left == 0:
			side.fire_left = settings.fire_ticks
			_note("%s: башни в круге налёта замолчали" % side_name(index))


func _collect_breaches(side: SiegeTrialSide) -> void:
	for mob: MobState in side.field.pending_breaches:
		side.breached_count += 1
		side.hp = maxi(0, side.hp - mob.data.breach_damage)
	side.field.clear_pending()


func _is_finished() -> bool:
	if tick_count >= settings.max_ticks or sides[0].hp <= 0 or sides[1].hp <= 0:
		return true
	for side: SiegeTrialSide in sides:
		if not side.released or not side.field.is_wave_done():
			return false
	return true


func _bot_turn() -> void:
	var bot: SiegeTrialSide = sides[1]
	var foe: SiegeTrialSide = sides[0]
	var reacted: bool = foe.skill_used and tick_count - foe.skill_tick >= settings.bot_reaction_ticks
	var defense_spent: bool = foe.hero != GORYNYCH and reacted
	if not bot.released and (tick_count >= bot_release_at or defense_spent):
		execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE, 1))
	if bot.skill_used:
		return
	if bot.hero != GORYNYCH and reacted and (foe.warning_left > 0 or foe.fire_left > 0):
		if _bot_can_escape_raid(bot):
			execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL, 1))
			return
	var observed: FieldState = sides[0].field if bot.hero == GORYNYCH else bot.field
	var progress: int = settings.bot_fire_progress if bot.hero == GORYNYCH else settings.bot_walk_progress
	for mob: MobState in observed.mobs:
		if mob.progress >= progress:
			execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL, 1))
			return


func _bot_can_escape_raid(bot: SiegeTrialSide) -> bool:
	var tower: TowerState = bot.walking_tower()
	if bot.hero == YAGA:
		var destination_center: Vector2i = tower.center_milli() + (bot.destination - tower.anchor) * MILLI
		return in_fire_zone(0, tower) and not _point_in_fire_zone(0, destination_center)
	var other: TowerState = bot.field.get_tower(bot.swap_tower_id)
	var first_damage: int = bot.field.get_tower_damage(tower)
	var second_damage: int = bot.field.get_tower_damage(other)
	if first_damage > second_damage:
		return in_fire_zone(0, tower) and not in_fire_zone(0, other)
	return second_damage > first_damage and in_fire_zone(0, other) and not in_fire_zone(0, tower)


func state_hash() -> int:
	var hasher: StateHasher = StateHasher.new()
	hasher.add_many([int(phase), tick_count, seed_value, int(bot_enabled), bot_release_at, bot_defense_index])
	for side: SiegeTrialSide in sides:
		side.add_to_hash(hasher)
	return hasher.value


func side_name(index: int) -> String:
	return "Вы" if index == 0 else "Соперник"


func result_text() -> String:
	if sides[0].hp == sides[1].hp:
		return "Ничья — обе заставы удержались одинаково"
	return "Победа — ваша застава крепче!" if sides[0].hp > sides[1].hp else "Поражение — попробуйте другой момент"


func _note(message: String) -> void:
	journal.append("%d с · %s" % [tick_count / settings.game.ticks_per_second, message])
