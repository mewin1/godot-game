class_name MatchLogger
extends RefCounted
## Пишет лог матча в файл JSON Lines (одна строка — одно событие). Нужен для анализа баланса:
## и живых матчей, и прогонов ботов. Только читает симуляцию через её сигналы.
## Файл создаётся после первого законченного раунда: короткие запуски (проверки, сразу закрытая
## игра) логов не оставляют.
## События: match_start, round_start, command, wave_start, round_end, eliminated, match_end.

const LOG_VERSION: int = 8

var _started_msec: int = Time.get_ticks_msec()
var _sim: MatchSim
var _path: String = ""
var _file: FileAccess
## Строки до первого конца раунда — копятся в памяти, файла ещё нет.
var _pending_lines: PackedStringArray = []
var _is_closed: bool = false
## Счётчики текущего раунда по игрокам.
var _kills: Array[int] = []
var _kill_gold: Array[int] = []
var _leaks: Array[int] = []


## source — откуда матч ("live" — человек, "bots" — прогон ботов); extra — любые поля в match_start.
func _init(sim: MatchSim, file_path: String, source: String, extra: Dictionary = {}) -> void:
	_sim = sim
	_path = file_path
	for player: PlayerState in sim.players:
		_kills.append(0)
		_kill_gold.append(0)
		_leaks.append(0)
		player.field.mob_killed.connect(_on_field_mob_killed.bind(player.index))
		player.field.mob_breached.connect(_on_field_mob_breached.bind(player.index))
	sim.round_started.connect(_on_sim_round_started)
	sim.phase_changed.connect(_on_sim_phase_changed)
	sim.command_processed.connect(_on_sim_command_processed)
	sim.round_finished.connect(_on_sim_round_finished)
	sim.player_eliminated.connect(_on_sim_player_eliminated)
	sim.match_finished.connect(_on_sim_match_finished)
	_write_match_start(source, extra)


func is_open() -> bool:
	return not _is_closed


## Закрывает лог (матч закончился или игрок вышел посреди матча).
func close() -> void:
	_is_closed = true
	_pending_lines.clear()
	if _file != null:
		_file.close()
		_file = null


func _write(event: Dictionary) -> void:
	if _is_closed:
		return
	event["elapsed_msec"] = Time.get_ticks_msec() - _started_msec
	var line: String = JSON.stringify(event)
	if _file != null:
		_file.store_line(line)
	else:
		_pending_lines.append(line)


## Создаёт файл и сбрасывает в него накопленное. false — не получилось (лог выключается).
func _open_file() -> bool:
	var error: Error = DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Не удалось создать папку логов: %s" % _path.get_base_dir())
		close()
		return false
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		push_error("Не удалось открыть лог: %s" % _path)
		close()
		return false
	for line: String in _pending_lines:
		_file.store_line(line)
	_pending_lines.clear()
	return true


func _write_match_start(source: String, extra: Dictionary) -> void:
	var players: Array[Dictionary] = []
	for player: PlayerState in _sim.players:
		players.append({"index": player.index, "name": player.display_name, "bot": player.is_bot,
				"bot_army_share": _sim.get_bot_army_share(player.index)})
	var event: Dictionary = {"event": "match_start", "version": LOG_VERSION, "source": source,
			"players": players, "config": _config_numbers(),
			"active_gods": _sim.active_gods, "manual_preparation": _sim.config.prep_requires_ready,
			"config_path": _sim.config.resource_path, "bot_version": BotBrain.VERSION}
	event.merge(extra)
	_write(event)


## Все числовые настройки конфига — чтобы сравнивать логи до и после правок баланса.
func _config_numbers() -> Dictionary:
	var numbers: Dictionary = {}
	for property: Dictionary in _sim.config.get_property_list():
		var usage: int = property["usage"]
		var type: int = property["type"]
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		if type == TYPE_INT or type == TYPE_BOOL or type == TYPE_ARRAY:
			var property_name: String = property["name"]
			var value: Variant = _sim.config.get(property_name)
			if type == TYPE_INT or type == TYPE_BOOL or _is_int_array(value):
				numbers[property_name] = value
	return numbers


func _is_int_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	var array: Array = value
	return array.is_typed() and array.get_typed_builtin() == TYPE_INT


func _player_snapshot(player: PlayerState) -> Dictionary:
	var towers: Array[Array] = []
	var invested: int = 0
	for tower: TowerState in player.field.towers:
		towers.append([String(tower.data.id), tower.level])
		invested += tower.invested_total
	var buffs: Array[String] = []
	for buff: SendBuffData in player.army.buffs:
		buffs.append(String(buff.id))
	return {"player": player.index, "hero": String(player.hero.id) if player.hero != null else "",
			"placements": _placement_snapshot(player),
			"reserve": _reserve_snapshot(player), "idols": _idol_snapshot(player),
			"skill_uses": player.skill_uses, "building_income": player.field.get_round_income(),
			"alive": player.is_alive, "hp": player.hero_hp, "max_hp": player.hero_max_hp,
			"gold": player.gold, "income": player.income, "shop_level": player.shop.level,
			"towers": towers, "cells_used": player.get_cells_used(),
			"buildable_cells": player.field.get_buildable_cells().size(),
			"invested": invested, "army_units": player.army.get_unit_count(),
			"army_upgrades": player.army.upgrade_counts, "buffs": buffs}


func _alive_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for player: PlayerState in _sim.get_alive_players():
		snapshots.append(_player_snapshot(player))
	return snapshots


func _on_sim_round_started(round_number: int) -> void:
	for player: PlayerState in _sim.players:
		_kills[player.index] = 0
		_kill_gold[player.index] = 0
		_leaks[player.index] = 0
	_write({"event": "round_start", "round": round_number, "tick": _sim.tick_count,
			"opponents": _sim.opponent_of, "siege_leader": _sim.siege_leader,
			"siege_attackers": _sim.siege_attackers, "ghost_target": _sim.ghost_target,
			"ghost_source": _sim.ghost_source})


func _on_sim_phase_changed(phase: MatchSim.Phase) -> void:
	if phase != MatchSim.Phase.WAVE:
		return
	var wave: Array[MobState] = WaveBuilder.build_base_wave(_sim.config, _sim.round_number)
	_write({"event": "wave_start", "round": _sim.round_number, "tick": _sim.tick_count,
			"prep_ticks": _sim.get_prep_ticks(), "base_wave_count": wave.size(),
			"base_wave_hp": wave[0].max_hp, "players": _alive_snapshots()})


func _on_sim_command_processed(player_index: int, description: Dictionary, error: String) -> void:
	_write({"event": "command", "round": _sim.round_number, "tick": _sim.tick_count,
			"phase_tick": _sim.phase_tick, "player": player_index, "command": description,
			"error": error})


func _on_sim_round_finished(round_number: int) -> void:
	var players: Array[Dictionary] = _alive_snapshots()
	for snapshot: Dictionary in players:
		var index: int = snapshot["player"]
		snapshot["hp_lost"] = _sim.players[index].hp_lost_this_round
		snapshot["raw_breach_damage"] = _sim.players[index].raw_breach_damage
		snapshot["kills"] = _kills[index]
		snapshot["kill_gold"] = _kill_gold[index]
		snapshot["leaks"] = _leaks[index]
		snapshot["army_damage"] = _sim.players[index].army_damage_dealt
		snapshot["reactions"] = _sim.players[index].field.reaction_counts.duplicate()
		snapshot["battle_report"] = _sim.players[index].field.battle_report.snapshot()
	_write({"event": "round_end", "round": round_number, "tick": _sim.tick_count,
			"wave_ticks": _sim.phase_tick, "players": players})
	if _is_closed or (_file == null and not _open_file()):
		return
	_file.flush()


func _on_sim_player_eliminated(player: PlayerState) -> void:
	_write({"event": "eliminated", "round": _sim.round_number, "player": player.index,
			"place": player.place})


func _on_sim_match_finished() -> void:
	var places: Array[int] = []
	var heroes: Array[String] = []
	for player: PlayerState in _sim.players:
		places.append(player.place)
		heroes.append(String(player.hero.id) if player.hero != null else "")
	var winner: PlayerState = _sim.get_winner()
	_write({"event": "match_end", "round": _sim.round_number, "tick": _sim.tick_count,
			"places": places, "heroes": heroes, "winner": winner.index if winner != null else -1})
	if _file == null and not _is_closed:
		_open_file()
	close()


func _on_field_mob_killed(mob: MobState, player_index: int) -> void:
	_kills[player_index] += 1
	_kill_gold[player_index] += mob.kill_reward


func _on_field_mob_breached(_mob: MobState, player_index: int) -> void:
	_leaks[player_index] += 1


func _reserve_snapshot(player: PlayerState) -> Array[Array]:
	var result: Array[Array] = []
	for tower: TowerState in player.reserve:
		result.append([String(tower.data.id), tower.level, tower.enchantment, tower.awakening])
	return result


func _idol_snapshot(player: PlayerState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for idol: IdolState in player.field.idols:
		result.append({"god": String(idol.god), "rites": idol.purchases.duplicate()})
	return result


func _placement_snapshot(player: PlayerState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tower: TowerState in player.field.towers:
		result.append({"id": tower.id, "type": String(tower.data.id), "level": tower.level,
				"x": tower.anchor.x, "y": tower.anchor.y, "rotation": tower.rotation,
				"enchantment": tower.enchantment, "awakening": tower.awakening})
	return result
