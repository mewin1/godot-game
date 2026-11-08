class_name BattleReserves
extends RefCounted
## Снимки удержанных отрядов по маршрутам. Призрак имеет отдельный приказ.

class Dispatch:
	extends RefCounted
	var sender: int
	var target: int
	var pack: Array[MobState] = []
	var released_tick: int = -1
	var automatic: bool = false

var dispatches: Array[Dispatch] = []
## Наблюдение: первый заход и подкрепление по отправителю, без нейтральной волны.
var breaches: Dictionary[int, Vector2i] = {}


func clear() -> void:
	dispatches.clear()
	breaches.clear()


func record_breach(mob: MobState) -> void:
	if mob.sender_index == -1 or mob.is_decoy:
		return
	var owner: int = MatchSim.GHOST if mob.sender_index == -2 else mob.sender_index
	var counts: Vector2i = breaches.get(owner, Vector2i.ZERO)
	if mob.is_reinforcement:
		counts.y += 1
	else:
		counts.x += 1
	breaches[owner] = counts


func snapshot(sender: int) -> Dictionary:
	var routes: Array[Dictionary] = []
	for dispatch: Dispatch in dispatches:
		if dispatch.sender == sender:
			routes.append({"target": dispatch.target, "count": dispatch.pack.size(),
					"tick": dispatch.released_tick, "automatic": dispatch.automatic})
	var counts: Vector2i = breaches.get(sender, Vector2i.ZERO)
	return {"routes": routes, "opening_breaches": counts.x, "reserve_breaches": counts.y}


## Создаёт независимый снимок для каждого поля, включая копии армии в осаде.
func opening(army: ArmyState, sender: int, target: int, round_number: int) -> Array[MobState]:
	var pack: Array[MobState] = army.build_pack(-2 if sender == MatchSim.GHOST else sender, round_number)
	var held: Array[int] = army.reserve_indices()
	var first: Array[MobState] = []
	var dispatch: Dispatch = Dispatch.new()
	dispatch.sender = sender
	dispatch.target = target
	for i: int in pack.size():
		if held.has(i):
			pack[i].is_reinforcement = true
			dispatch.pack.append(pack[i])
		else:
			first.append(pack[i])
	if not dispatch.pack.is_empty():
		dispatches.append(dispatch)
	return first


func pending_for(target: int) -> bool:
	for dispatch: Dispatch in dispatches:
		if dispatch.target == target and dispatch.released_tick < 0:
			return true
	return false


func pending_count(sender: int) -> int:
	# В осаде показываем размер одного отряда, а не сумму его копий.
	for dispatch: Dispatch in dispatches:
		if dispatch.sender == sender and dispatch.released_tick < 0:
			return dispatch.pack.size()
	return 0


func release(sim: MatchSim, sender: int, automatic: bool = false) -> String:
	if pending_count(sender) == 0:
		return "Подкрепление уже вышло или не назначено"
	for dispatch: Dispatch in dispatches:
		if dispatch.sender != sender or dispatch.released_tick >= 0:
			continue
		var field: FieldState = sim.ghost_field if dispatch.target == MatchSim.GHOST \
				else sim.players[dispatch.target].field
		if field == null:
			continue
		var settings: ActiveBattleConfig = sim.config.active_battle
		WaveBuilder._schedule_pack(field, dispatch.pack, settings.reserve_spawn_interval_ticks,
				field.wave_tick, sim.config.battle_real_ticks - 1)
		dispatch.released_tick = sim.phase_tick
		dispatch.automatic = automatic
	return ""


func tick(sim: MatchSim) -> void:
	var settings: ActiveBattleConfig = sim.config.active_battle
	for dispatch: Dispatch in dispatches:
		if dispatch.released_tick >= 0:
			continue
		var is_bot: bool = dispatch.sender == MatchSim.GHOST
		if not is_bot:
			is_bot = sim.players[dispatch.sender].is_bot
		if sim.phase_tick >= mini(settings.reserve_deadline_ticks,
				sim.config.battle_real_ticks - 1):
			release(sim, dispatch.sender, true)
		elif is_bot and sim.phase_tick >= settings.bot_release_ticks:
			release(sim, dispatch.sender)


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add(dispatches.size())
	for dispatch: Dispatch in dispatches:
		hasher.add_many([dispatch.sender, dispatch.target, dispatch.released_tick,
				int(dispatch.automatic), dispatch.pack.size()])
		# После выпуска мобов хэширует поле, до выпуска это неизменяемый снимок.
		if dispatch.released_tick >= 0:
			continue
		for mob: MobState in dispatch.pack:
			hasher.add_string(mob.data.id)
			hasher.add_string(mob.resist)
			hasher.add_many([mob.max_hp, mob.hp, mob.speed, mob.armor, mob.kill_reward,
					mob.breach_damage, mob.sender_index, mob.shield_left, mob.heal_cooldown,
					int(mob.is_angry)])
