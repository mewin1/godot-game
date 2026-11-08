extends SceneTree
## Наблюдение за местом после подготовки ботов; не меняет правила, RNG или расстановку.
## --matches=8 --players=6 --seed=1401 --max-ticks=200000 --out=res://.godot/space.json
## Позиции считаются по уникальным наборам клеток, симметричные повороты не дублируются.

const SHAPES: Dictionary[String, Array] = {
	"single": [Vector2i(0, 0)],
	"domino": [Vector2i(0, 0), Vector2i(1, 0)],
	"L3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"O4_probe": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"I4_probe": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	"T4_probe": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}
var _config: GameConfig
var _results: Array[Dictionary] = []
var _player_count: int = 6
var _max_ticks: int = 200000


func _initialize() -> void:
	var args: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_config = load("res://data/game_config.tres") as GameConfig
	_player_count = _arg_int(args, "players", 6)
	_max_ticks = _arg_int(args, "max-ticks", 200000)
	var count: int = _arg_int(args, "matches", 8)
	var first_seed: int = _arg_int(args, "seed", 1401)
	_results.resize(count)
	var task: int = WorkerThreadPool.add_group_task(_run_one.bind(first_seed), count, 4)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var geometry: Array[Dictionary] = []
	for level: int in range(1, 5):
		var field: FieldState = FieldState.new(_config, level)
		geometry.append({"level": level, "path": field.path_length,
			"buildable": field.get_buildable_cells().size(), "placements": _placements(field)})
	var result: Dictionary = {"bot_version": BotBrain.VERSION, "players": _player_count,
		"geometry": geometry, "matches": _results}
	var out_path: String = args.get("out", "res://.godot/space.json")
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать замер: %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	print("Замер: %s, матчей: %d" % [out_path, count])
	quit()


func _run_one(index: int, first_seed: int) -> void:
	var sim: MatchSim = MatchSim.new(_config, first_seed + index, _player_count, 0)
	sim.start_with_hero_select()
	var samples: Array[Dictionary] = []
	var last_round: int = 0
	while sim.phase != MatchSim.Phase.OVER and sim.tick_count < _max_ticks:
		# PREP уже обработана ботами; следующий тик только запускает волну.
		if sim.phase == MatchSim.Phase.PREP and last_round != sim.round_number:
			last_round = sim.round_number
			for player: PlayerState in sim.get_alive_players():
				samples.append(_sample(sim, player))
		sim.tick()
	_results[index] = {"seed": first_seed + index, "rounds": sim.round_number,
		"ticks": sim.tick_count, "finished": sim.phase == MatchSim.Phase.OVER,
		"hash": sim.state_hash(), "samples": samples}
	print("seed %d: раунд %d, завершён %s" % [first_seed + index, sim.round_number,
		str(sim.phase == MatchSim.Phase.OVER)])


func _sample(sim: MatchSim, player: PlayerState) -> Dictionary:
	var buildable: int = player.field.get_buildable_cells().size()
	var used: int = player.get_cells_used()
	return {"round": sim.round_number, "player": player.index,
		"army_share": sim.get_bot_army_share(player.index), "shop": player.shop.level,
		"buildable": buildable, "used": used, "free": buildable - used,
		"towers": player.field.towers.size(), "reserve": player.reserve.size(),
		"reserve_capacity": player.get_reserve_capacity(), "gifts": player.gift_towers.size(),
		"placements": _placements(player.field)}


func _placements(field: FieldState) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for shape_name: String in SHAPES:
		var shape: Array[Vector2i] = []
		shape.assign(SHAPES[shape_name])
		var unique: Dictionary[String, bool] = {}
		for y: int in field.layout.height:
			for x: int in field.layout.width:
				for turns: int in TowerState.ROTATIONS:
					var cells: Array[Vector2i] = TowerState.shape_cells_at(
						shape, Vector2i(x, y), turns)
					if not field.can_place(cells):
						continue
					var keys: Array[int] = []
					for cell: Vector2i in cells:
						keys.append(cell.y * field.layout.width + cell.x)
					keys.sort()
					unique[str(keys)] = true
		result[shape_name] = unique.size()
	return result


func _arg_int(args: Dictionary[String, String], key: String, fallback: int) -> int:
	if args.has(key):
		return args[key].to_int()
	return fallback
