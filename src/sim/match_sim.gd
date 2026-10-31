class_name MatchSim
extends RefCounted
## Матч целиком: игроки, раунды (подготовка → волна → подсчёт), пары соперников, конец матча.
## Детерминирован: одинаковые сид, конфиг и команды по тикам дают одинаковый результат.

signal round_started(round_number: int)
signal phase_changed(phase: Phase)
signal command_failed(player_index: int, reason: String)
## Любая команда (и людей, и ботов) после выполнения: описание и "" или причина отказа. Для логов.
signal command_processed(player_index: int, description: Dictionary, error: String)
## Конец раунда: доход и награды уже начислены, выбывшие ещё не определены.
signal round_finished(round_number: int)
signal player_eliminated(player: PlayerState)
signal match_finished()
## Герой игрока что-то сделал (навык или пассивка): текст для игрока.
signal hero_event(player_index: int, message: String)

## HERO_SELECT — выбор героя перед первым раундом (новое значение в конце: не меняет старые хэши).
enum Phase { PREP, WAVE, OVER, HERO_SELECT }

## Соперник «призрак» у игрока без пары: копия поля и армии другого игрока.
const GHOST: int = -1
## Разброс стилей ботов: доля золота на армию (в процентах).
const BOT_MIN_ARMY_SHARE: int = 0
const BOT_MAX_ARMY_SHARE: int = 70
## Как часто (в тиках) боты думают во время волны — о навыках «в волну».
const BOT_WAVE_THINK_TICKS: int = 10

var active_gods: Array[StringName] = []
var config: GameConfig
var players: Array[PlayerState] = []
var round_number: int = 0
var phase: Phase = Phase.PREP
## Сколько тиков прошло в текущей фазе.
var phase_tick: int = 0
var tick_count: int = 0
## Чьё поле игрок видит как соперника в этом раунде (индекс игрока или GHOST).
var opponent_of: Array[int] = []
## Осада в этом раунде: индекс лидера (-1 — осады нет) и двух атакующих.
var siege_leader: int = -1
var siege_attackers: Array[int] = []
## Призрак в этом раунде: кто с ним воюет, чья это копия (-1 — призрака нет)
## и его поле (копия поля источника на начало волны, по нему идёт армия ghost_target).
var ghost_target: int = -1
var ghost_source: int = -1
var ghost_field: FieldState

## Маршруты армий в этом раунде: x — чья армия, y — на чьё поле идёт.
var _army_routes: Array[Vector2i] = []
## Осада: урон лидеру от мобов каждого атакующего и всё HP, которое лидер потерял за раунд.
var _siege_damage_by_attacker: Dictionary[int, int] = {}
var _siege_leader_hp_lost: int = 0
## Остаток урона по лидеру в сотых долях HP: уменьшенный урон копится, а не теряется при округлении.
var _siege_damage_remainder: int = 0
var _queue: Array[QueuedCommand] = []
var _bots: Array[BotBrain] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## player_count игроков, первые human_count — люди, остальные — боты.
func _init(game_config: GameConfig, match_seed: int, player_count: int = 2,
		human_count: int = 1) -> void:
	config = game_config
	_rng.seed = match_seed
	active_gods = PantheonDraft.draw(config, _rng)
	for i: int in player_count:
		var player: PlayerState = PlayerState.new(config, i, _rng.randi())
		player.shop.active_gods = active_gods.duplicate()
		player.is_bot = i >= human_count
		player.display_name = "Вы" if not player.is_bot else "Бот %d" % i
		players.append(player)
		var army_share: int = _rng.randi_range(BOT_MIN_ARMY_SHARE, BOT_MAX_ARMY_SHARE)
		_bots.append(BotBrain.new(army_share) if player.is_bot else null)


## Запускает первый раунд сразу, без героев (тесты старых правил).
func start() -> void:
	_start_round(1)


## Запускает матч с выбора героя: каждому — hero_offer_count разных героев на выбор.
## Боты выбирают сразу; раунд 1 начнётся, когда выберут все люди (или выйдет время).
func start_with_hero_select() -> void:
	if config.heroes.is_empty():
		start()
		return
	phase = Phase.HERO_SELECT
	phase_tick = 0
	for player: PlayerState in players:
		player.hero_offers = _roll_hero_offers()
	phase_changed.emit(phase)
	for player: PlayerState in players:
		if player.is_bot:
			choose_hero(player.index, _bots[player.index].pick_hero(player))


## Выбор героя игроком (команда ChooseHeroCommand и боты). "" — получилось.
func choose_hero(player_index: int, offer_index: int) -> String:
	var player: PlayerState = players[player_index]
	if phase != Phase.HERO_SELECT:
		return "Герой уже выбран"
	if player.hero != null:
		return "Герой уже выбран"
	if offer_index < 0 or offer_index >= player.hero_offers.size():
		return "Нет такого героя"
	player.pick_hero(player.hero_offers[offer_index])
	return ""


## Поля, куда в этом раунде идёт армия игрока (для навыков вроде «Трёх голов»).
func get_army_target_fields(player_index: int) -> Array[FieldState]:
	var fields: Array[FieldState] = []
	for route: Vector2i in _army_routes:
		if route.x == player_index:
			fields.append(players[route.y].field)
	if player_index == ghost_target and ghost_field != null:
		fields.append(ghost_field)
	return fields


## Ставит команду в очередь: выполнится в начале следующего тика.
func queue_command(player_index: int, command: SimCommand) -> void:
	_queue.append(QueuedCommand.new(player_index, command))


## Выполняет команду сразу (боты и тесты). Возвращает "" или причину отказа.
func execute_command(player_index: int, command: SimCommand) -> String:
	var player: PlayerState = players[player_index]
	if not player.is_alive or phase == Phase.OVER:
		return "Игрок выбыл"
	if command.requires_prep() and phase == Phase.HERO_SELECT:
		return "Сначала выберите героя"
	if command.requires_prep() and phase != Phase.PREP:
		return "Сейчас идёт волна"
	var description: Dictionary = command.to_log(self, player)
	var error: String = command.execute(self, player)
	command_processed.emit(player_index, description, error)
	return error


## Один шаг симуляции (1/ticks_per_second секунды).
func tick() -> void:
	if phase == Phase.OVER:
		return
	_apply_queued_commands()
	match phase:
		Phase.HERO_SELECT:
			_tick_hero_select()
		Phase.PREP:
			_tick_prep()
		_:
			_tick_wave()
	tick_count += 1


func get_phase_ticks_left() -> int:
	var total: int = config.wave_max_ticks
	if phase == Phase.PREP:
		if config.prep_requires_ready:
			return 0
		total = get_prep_ticks()
	elif phase == Phase.HERO_SELECT:
		total = config.hero_select_ticks
	return maxi(0, total - phase_tick)


func get_alive_players() -> Array[PlayerState]:
	var alive: Array[PlayerState] = []
	for player: PlayerState in players:
		if player.is_alive:
			alive.append(player)
	return alive


## Победитель (место 1) или null, пока матч идёт.
func get_winner() -> PlayerState:
	for player: PlayerState in players:
		if player.place == 1:
			return player
	return null


## Доля золота на армию у бота (-1 — это человек). Для логов и анализа стилей.
func get_bot_army_share(player_index: int) -> int:
	var brain: BotBrain = _bots[player_index]
	return brain.army_share_percent if brain != null else -1


## Раунд осады: каждый siege_every_rounds-й, пока живых хватает.
func is_siege_round(number: int) -> bool:
	var enough_players: bool = get_alive_players().size() >= config.siege_min_players
	return number % config.siege_every_rounds == 0 and enough_players


func state_hash() -> int:
	var hasher: StateHasher = StateHasher.new()
	hasher.add_many([round_number, phase, phase_tick, tick_count, siege_leader])
	hasher.add_many(opponent_of)
	hasher.add(_rng.state)
	for god: StringName in active_gods:
		hasher.add_string(god)
	hasher.add_many([_siege_leader_hp_lost, _siege_damage_remainder])
	for attacker: int in siege_attackers:
		hasher.add_many([attacker, _siege_damage_by_attacker.get(attacker, 0)])
	for player: PlayerState in players:
		player.add_to_hash(hasher)
	hasher.add_many([ghost_target, ghost_source])
	if ghost_field != null:
		ghost_field.add_to_hash(hasher)
	return hasher.value


func _apply_queued_commands() -> void:
	var commands: Array[QueuedCommand] = _queue
	_queue = []
	for queued: QueuedCommand in commands:
		var error: String = execute_command(queued.player_index, queued.command)
		if error != "":
			command_failed.emit(queued.player_index, error)


## В ручном режиме герой ждёт осознанного выбора; в старых правилах есть таймаут.
func _tick_hero_select() -> void:
	phase_tick += 1
	var is_timeout: bool = not config.prep_requires_ready \
			and phase_tick >= config.hero_select_ticks
	for player: PlayerState in players:
		if player.hero == null and not is_timeout:
			return
	for player: PlayerState in players:
		if player.hero == null:
			choose_hero(player.index, 0)
	_start_round(1)


## Разные герои из общего списка (у разных игроков могут совпадать).
func _roll_hero_offers() -> Array[HeroData]:
	var pool: Array[HeroData] = []
	for hero: HeroData in config.heroes:
		if hero.affinity_god == &"" or active_gods.is_empty() \
				or active_gods.has(hero.affinity_god):
			pool.append(hero)
	var offers: Array[HeroData] = []
	for i: int in mini(config.hero_offer_count, pool.size()):
		var pick: int = _rng.randi_range(0, pool.size() - 1)
		offers.append(pool[pick])
		pool.remove_at(pick)
	return offers


## Подготовка имеет собственное время и не зависит от ускорения боя.
func get_prep_ticks() -> int:
	if round_number <= config.early_prep_rounds:
		return mini(config.prep_ticks, config.early_prep_ticks)
	return config.prep_ticks


func _tick_prep() -> void:
	phase_tick += 1
	var has_timed_out: bool = not config.prep_requires_ready and phase_tick >= get_prep_ticks()
	if has_timed_out or _are_all_humans_ready():
		_start_wave()


func _are_all_humans_ready() -> bool:
	for player: PlayerState in get_alive_players():
		if not player.is_bot and not player.is_ready:
			return false
	return true


func _start_round(number: int) -> void:
	round_number = number
	phase = Phase.PREP
	phase_tick = 0
	_plan_pairs()
	for player: PlayerState in get_alive_players():
		player.field.calm_down()

		player.army_damage_dealt = 0
		player.hp_lost_this_round = 0
		player.raw_breach_damage = 0
		player.limited_breach_damage = 0
		player.army.temporary_mobs.clear()
		if number > 1:
			player.shop.on_round_started()
		player.start_prep(number > 1)
	round_started.emit(round_number)
	phase_changed.emit(phase)
	for player: PlayerState in get_alive_players():
		if player.is_bot:
			_bots[player.index].play_prep(self, player)


func _start_wave() -> void:
	phase = Phase.WAVE
	phase_tick = 0
	var alive: Array[PlayerState] = get_alive_players()
	for player: PlayerState in alive:
		player.end_prep()
	for player: PlayerState in alive:
		player.field.start_wave()
		WaveBuilder.schedule_wave(config, player.field, round_number, build_incoming_armies(player.index))
	_start_ghost_wave()
	phase_changed.emit(phase)


## Снимок входящих армий для боя и предпросмотра, без изменения состояния или RNG.
func build_incoming_armies(receiver_index: int) -> Array[MobState]:
	var armies: Array[MobState] = []
	if round_number < config.army_first_round:
		return armies
	for route: Vector2i in _army_routes:
		if route.y == receiver_index:
			armies.append_array(players[route.x].army.build_pack(route.x, round_number))
	if receiver_index == ghost_target:
		armies.append_array(players[ghost_source].army.build_pack(GHOST, round_number))
	return armies


## Поле призрака — копия поля источника на начало волны: базовая волна + армия ghost_target.
func _start_ghost_wave() -> void:
	ghost_field = null
	if ghost_target < 0:
		return
	var source: PlayerState = players[ghost_source]
	ghost_field = FieldState.new(config, source.shop.level)
	ghost_field.path_length = source.field.path_length
	ghost_field.copy_towers_from(source.field)
	ghost_field.start_wave()
	var army: Array[MobState] = []
	if round_number >= config.army_first_round:
		army = players[ghost_target].army.build_pack(ghost_target, round_number)
	WaveBuilder.schedule_wave(config, ghost_field, round_number, army)


func _tick_wave() -> void:
	if config.synchronized_battle:
		_tick_synchronized_wave()
		return
	phase_tick += 1
	var is_overtime: bool = phase_tick >= config.wave_max_ticks
	var timed_out: bool = phase_tick >= config.wave_max_ticks + config.wave_enrage_extra_ticks
	var all_done: bool = true
	if phase_tick % BOT_WAVE_THINK_TICKS == 0:
		_let_bots_play_wave()
	for player: PlayerState in get_alive_players():
		if is_overtime and not player.field.is_enraged:
			player.field.enrage()
		player.field.tick()
		if timed_out:
			player.field.breach_all_remaining()
		_collect_field_results(player)
		all_done = all_done and player.field.is_wave_done()
	if ghost_field != null:
		if is_overtime and not ghost_field.is_enraged:
			ghost_field.enrage()
		all_done = _tick_ghost_field(timed_out) and all_done
	if all_done:
		_finish_round()


## Общая перемотка исполняет обычные тики боя: одинаково для всех полей и эффектов.
func _tick_synchronized_wave() -> void:
	phase_tick += 1
	var speed: int = get_battle_speed()
	if phase_tick % BOT_WAVE_THINK_TICKS == 0:
		_let_bots_play_wave()
	for player: PlayerState in get_alive_players():
		player.field.begin_visual_step()
	if ghost_field != null:
		ghost_field.begin_visual_step()
	for substep: int in speed:
		var all_done: bool = true
		for player: PlayerState in get_alive_players():
			player.field.tick()
			_collect_field_results(player)
			all_done = all_done and player.field.is_wave_done()
		if ghost_field != null:
			ghost_field.tick()
			ghost_field.clear_pending()
			all_done = all_done and ghost_field.is_wave_done()
		if all_done:
			_finish_round()
			return
	for player: PlayerState in get_alive_players():
		player.field.end_visual_step()
	if ghost_field != null:
		ghost_field.end_visual_step()
	if phase_tick >= config.battle_real_ticks:
		for player: PlayerState in get_alive_players():
			player.field.retreat_remaining()
		if ghost_field != null:
			ghost_field.retreat_remaining()
		_finish_round()


func _let_bots_play_wave() -> void:
	for player: PlayerState in get_alive_players():
		if player.is_bot:
			_bots[player.index].play_wave(self, player)


## Поле призрака ничего не даёт и не отнимает: бой на нём только для честности и зрелища.
## Возвращает true, когда волна на нём закончилась.
func _tick_ghost_field(timed_out: bool) -> bool:
	ghost_field.tick()
	if timed_out:
		ghost_field.breach_all_remaining()
	ghost_field.clear_pending()
	return ghost_field.is_wave_done()


## Забирает с поля золото за убийства и снимает HP героя за прорывы.
func _collect_field_results(player: PlayerState) -> void:
	var field: FieldState = player.field
	player.gold += field.pending_kill_gold
	var hp_before: int = player.hero_hp
	for mob: MobState in field.pending_breaches:
		_apply_breach(player, mob)
	field.clear_pending()
	if player.hero_hp < hp_before:
		player.notify_hp_lost(self)
	if player.hero_hp <= 0 and player.fell_tick < 0:
		player.fell_tick = player.field.wave_tick if config.synchronized_battle else tick_count


func _apply_breach(player: PlayerState, mob: MobState) -> void:
	var damage: int = mob.breach_damage * config.get_breach_multiplier(round_number)
	if player.index == siege_leader and siege_attackers.has(mob.sender_index):
		damage = _reduce_siege_damage(damage)
	player.raw_breach_damage += damage
	var limit: int = config.get_breach_limit(round_number)
	if limit > 0:
		damage = mini(damage, maxi(0, limit - player.limited_breach_damage))
	player.limited_breach_damage += damage
	# Отрицательный остаток нужен тай-брейку, но за HP после смерти не платим.
	var actual_damage: int = mini(maxi(0, player.hero_hp), damage)
	player.hero_hp -= damage
	player.hp_lost_this_round += actual_damage
	player.field.battle_report.record_hp_loss(mob, actual_damage)
	player.field.breach_resolved.emit(mob, actual_damage)
	if mob.sender_index >= 0 and actual_damage > 0:
		var sender: PlayerState = players[mob.sender_index]
		sender.gold += actual_damage * config.army_gold_per_hp + mob.data.breach_gold_to_sender
		sender.army_damage_dealt += actual_damage
	if player.index == siege_leader:
		_record_siege_damage(mob.sender_index, actual_damage)


## Урон армии атакующего по лидеру осады: siege_leader_damage_percent от полного.
func _reduce_siege_damage(damage: int) -> int:
	var hundredths: int = damage * config.siege_leader_damage_percent + _siege_damage_remainder
	_siege_damage_remainder = hundredths % 100
	return hundredths / 100


func _record_siege_damage(sender_index: int, damage: int) -> void:
	_siege_leader_hp_lost += damage
	if siege_attackers.has(sender_index):
		_siege_damage_by_attacker[sender_index] += damage


func _finish_round() -> void:
	var alive: Array[PlayerState] = get_alive_players()
	_pay_siege_rewards()
	for player: PlayerState in alive:
		player.gold += player.get_total_income()
		# Против призрака урон не засчитывается — злость не копится и не сбрасывается.
		if player.index != ghost_target:
			player.army.update_rage(player.army_damage_dealt)
	round_finished.emit(round_number)
	_eliminate_dead(alive)
	var survivors: Array[PlayerState] = get_alive_players()
	if survivors.size() <= 1:
		_finish_match(survivors)
		return
	_start_round(round_number + 1)


## Выбывшие в одном раунде: кто пал раньше — тот хуже; пали одновременно — меньше HP хуже.
func _eliminate_dead(alive: Array[PlayerState]) -> void:
	var dead: Array[PlayerState] = []
	for player: PlayerState in alive:
		if player.hero_hp <= 0:
			dead.append(player)
	dead.sort_custom(_is_worse_fallen)
	var next_place: int = alive.size()
	for player: PlayerState in dead:
		player.is_alive = false
		player.place = next_place
		next_place -= 1
		player_eliminated.emit(player)


## Сортировка «хуже → лучше»: меньше HP хуже; при равенстве — больший индекс (стабильно).
func _is_worse_player(a: PlayerState, b: PlayerState) -> bool:
	if a.hero_hp != b.hero_hp:
		return a.hero_hp < b.hero_hp
	return a.index > b.index


func _is_worse_fallen(a: PlayerState, b: PlayerState) -> bool:
	if a.fell_tick != b.fell_tick:
		return a.fell_tick < b.fell_tick
	return _is_worse_player(a, b)


func _finish_match(survivors: Array[PlayerState]) -> void:
	for player: PlayerState in survivors:
		player.place = 1
	phase = Phase.OVER
	phase_changed.emit(phase)
	match_finished.emit()


## Пары соперников на раунд: в раунд осады сначала лидер и двое слабых,
## остальные — случайными парами; лишний игрок воюет с призраком.
func _plan_pairs() -> void:
	opponent_of.clear()
	_army_routes.clear()
	ghost_target = -1
	ghost_source = -1
	siege_leader = -1
	siege_attackers.clear()
	_siege_damage_by_attacker.clear()
	_siege_leader_hp_lost = 0
	_siege_damage_remainder = 0
	for i: int in players.size():
		opponent_of.append(GHOST)
	var pool: Array[PlayerState] = get_alive_players()
	if is_siege_round(round_number):
		_plan_siege(pool)
	_shuffle(pool)
	for i: int in range(0, pool.size() - 1, 2):
		_pair(pool[i].index, pool[i + 1].index)
	if pool.size() % 2 == 1:
		_plan_ghost(pool[pool.size() - 1].index)


## Призрак для игрока без пары — копия случайного другого живого игрока.
func _plan_ghost(target_index: int) -> void:
	var candidates: Array[int] = []
	for player: PlayerState in get_alive_players():
		if player.index != target_index:
			candidates.append(player.index)
	ghost_target = target_index
	ghost_source = candidates[_rng.randi_range(0, candidates.size() - 1)]


## Лидер — больше всех HP, атакующие — двое с наименьшим HP. Убирает их из pool.
## Армия лидера идёт к каждому атакующему (полная копия), к лидеру — армии обоих.
func _plan_siege(pool: Array[PlayerState]) -> void:
	var ranked: Array[PlayerState] = pool.duplicate()
	ranked.sort_custom(_is_worse_player)
	var leader: PlayerState = ranked[ranked.size() - 1]
	siege_leader = leader.index
	pool.erase(leader)
	for i: int in 2:
		var attacker: PlayerState = ranked[i]
		siege_attackers.append(attacker.index)
		_siege_damage_by_attacker[attacker.index] = 0
		pool.erase(attacker)
		opponent_of[attacker.index] = leader.index
		_army_routes.append(Vector2i(leader.index, attacker.index))
		_army_routes.append(Vector2i(attacker.index, leader.index))
	opponent_of[leader.index] = siege_attackers[0]


func _pay_siege_rewards() -> void:
	if siege_leader < 0:
		return
	var is_breached: bool = _siege_leader_hp_lost >= config.siege_breach_threshold
	for attacker_index: int in siege_attackers:
		var attacker: PlayerState = players[attacker_index]
		attacker.gold += _siege_damage_by_attacker[attacker_index] * config.siege_gold_per_hp
		if is_breached:
			attacker.gold += config.siege_attacker_bonus
	if not is_breached:
		players[siege_leader].gold += config.siege_leader_bonus


## Перемешивание Фишера — Йетса на ГСЧ матча (детерминированно).
func _shuffle(pool: Array[PlayerState]) -> void:
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: PlayerState = pool[i]
		pool[i] = pool[j]
		pool[j] = swap


func _pair(first: int, second: int) -> void:
	opponent_of[first] = second
	opponent_of[second] = first
	_army_routes.append(Vector2i(first, second))
	_army_routes.append(Vector2i(second, first))


## Скорость общей перемотки, без ручной кнопки ×2. Правила используют её же, что и HUD.
func get_battle_speed() -> int:
	if phase != Phase.WAVE or not config.synchronized_battle:
		return 1
	return config.get_battle_speed_at(phase_tick)
