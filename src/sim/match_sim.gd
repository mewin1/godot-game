class_name MatchSim
extends RefCounted
## Матч целиком: игроки, раунды (подготовка → волна → подсчёт), пары соперников, конец матча.
## Детерминирован: одинаковые сид, конфиг и команды по тикам дают одинаковый результат.

signal round_started(round_number: int)
signal phase_changed(phase: Phase)
signal command_failed(player_index: int, reason: String)
signal player_eliminated(player: PlayerState)
signal match_finished()

enum Phase { PREP, WAVE, OVER }

## Соперник «призрак»: у игрока без пары.
const GHOST: int = -1

var config: GameConfig
var players: Array[PlayerState] = []
var round_number: int = 0
var phase: Phase = Phase.PREP
## Сколько тиков прошло в текущей фазе.
var phase_tick: int = 0
var tick_count: int = 0
## Чьё поле игрок видит как соперника в этом раунде (индекс игрока или GHOST).
var opponent_of: Array[int] = []

## Маршруты отправок в этом раунде: x — кто отправляет, y — на чьё поле.
var _send_routes: Array[Vector2i] = []
var _queue: Array[QueuedCommand] = []
var _bots: Array[BotBrain] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## player_count игроков, первые human_count — люди, остальные — боты.
func _init(game_config: GameConfig, match_seed: int, player_count: int = 2,
		human_count: int = 1) -> void:
	config = game_config
	_rng.seed = match_seed
	for i: int in player_count:
		var player: PlayerState = PlayerState.new(config, i, _rng.randi())
		player.is_bot = i >= human_count
		player.display_name = "Вы" if not player.is_bot else "Бот %d" % i
		players.append(player)
		_bots.append(BotBrain.new() if player.is_bot else null)


## Запускает первый раунд.
func start() -> void:
	_start_round(1)


## Ставит команду в очередь: выполнится в начале следующего тика.
func queue_command(player_index: int, command: SimCommand) -> void:
	_queue.append(QueuedCommand.new(player_index, command))


## Выполняет команду сразу (боты и тесты). Возвращает "" или причину отказа.
func execute_command(player_index: int, command: SimCommand) -> String:
	var player: PlayerState = players[player_index]
	if not player.is_alive or phase == Phase.OVER:
		return "Игрок выбыл"
	if command.requires_prep() and phase != Phase.PREP:
		return "Сейчас идёт волна"
	return command.execute(self, player)


## Один шаг симуляции (1/ticks_per_second секунды).
func tick() -> void:
	if phase == Phase.OVER:
		return
	_apply_queued_commands()
	if phase == Phase.PREP:
		_tick_prep()
	else:
		_tick_wave()
	tick_count += 1


func get_phase_ticks_left() -> int:
	var total: int = config.prep_ticks if phase == Phase.PREP else config.wave_max_ticks
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


func get_send_cost(player: PlayerState) -> int:
	return player.army.get_send_cost(round_number)


func state_hash() -> int:
	var hasher: StateHasher = StateHasher.new()
	hasher.add_many([round_number, phase, phase_tick, tick_count])
	for player: PlayerState in players:
		player.add_to_hash(hasher)
	return hasher.value


func _apply_queued_commands() -> void:
	var commands: Array[QueuedCommand] = _queue
	_queue = []
	for queued: QueuedCommand in commands:
		var error: String = execute_command(queued.player_index, queued.command)
		if error != "":
			command_failed.emit(queued.player_index, error)


func _tick_prep() -> void:
	phase_tick += 1
	if phase_tick >= config.prep_ticks or _are_all_humans_ready():
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
		if number > 1:
			player.shop.on_round_started()
		player.start_prep(number > 1)
	for player: PlayerState in get_alive_players():
		if player.is_bot:
			_bots[player.index].play_prep(self, player)
	round_started.emit(round_number)
	phase_changed.emit(phase)


func _start_wave() -> void:
	phase = Phase.WAVE
	phase_tick = 0
	var alive: Array[PlayerState] = get_alive_players()
	for player: PlayerState in alive:
		player.end_prep()
	for player: PlayerState in alive:
		player.field.start_wave()
		WaveBuilder.schedule_wave(config, player.field, round_number, _collect_packs(player))
	for player: PlayerState in alive:
		player.pending_pack.clear()
	phase_changed.emit(phase)


## Пачки, которые придут на поле игрока: копии отправок его соперников.
func _collect_packs(player: PlayerState) -> Array[MobState]:
	var packs: Array[MobState] = []
	for route: Vector2i in _send_routes:
		if route.y != player.index:
			continue
		for mob: MobState in players[route.x].pending_pack:
			packs.append(mob.copy_fresh())
	return packs


func _tick_wave() -> void:
	phase_tick += 1
	var timed_out: bool = phase_tick >= config.wave_max_ticks
	var all_done: bool = true
	for player: PlayerState in get_alive_players():
		player.field.tick()
		if timed_out:
			player.field.breach_all_remaining()
		_collect_field_results(player)
		all_done = all_done and player.field.is_wave_done()
	if all_done:
		_finish_round()


## Забирает с поля золото за убийства и снимает HP героя за прорывы.
func _collect_field_results(player: PlayerState) -> void:
	var field: FieldState = player.field
	player.gold += field.pending_kill_gold
	var multiplier: int = config.get_breach_multiplier(round_number)
	for mob: MobState in field.pending_breaches:
		player.hero_hp -= mob.breach_damage * multiplier
	field.clear_pending()


func _finish_round() -> void:
	var alive: Array[PlayerState] = get_alive_players()
	for player: PlayerState in alive:
		player.gold += player.income
	_eliminate_dead(alive)
	var survivors: Array[PlayerState] = get_alive_players()
	if survivors.size() <= 1:
		_finish_match(survivors)
		return
	_start_round(round_number + 1)


## Выбывшие в одном раунде получают места по оставшемуся HP (меньше HP — хуже место).
func _eliminate_dead(alive: Array[PlayerState]) -> void:
	var dead: Array[PlayerState] = []
	for player: PlayerState in alive:
		if player.hero_hp <= 0:
			dead.append(player)
	dead.sort_custom(_is_worse_player)
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


func _finish_match(survivors: Array[PlayerState]) -> void:
	for player: PlayerState in survivors:
		player.place = 1
	phase = Phase.OVER
	phase_changed.emit(phase)
	match_finished.emit()


## Пары соперников на раунд. Пока — простое разбиение живых по кругу.
func _plan_pairs() -> void:
	opponent_of.clear()
	_send_routes.clear()
	for i: int in players.size():
		opponent_of.append(GHOST)
	var alive: Array[PlayerState] = get_alive_players()
	for i: int in range(0, alive.size() - 1, 2):
		_pair(alive[i].index, alive[i + 1].index)


func _pair(first: int, second: int) -> void:
	opponent_of[first] = second
	opponent_of[second] = first
	_send_routes.append(Vector2i(first, second))
	_send_routes.append(Vector2i(second, first))
