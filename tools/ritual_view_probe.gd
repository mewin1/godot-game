extends SceneTree
## Проверка вида «Городища» в точном размере окна: окно без рамки и без изменения размера (иначе
## тайловый менеджер ужимает его, и обрезки интерфейса не видно). Кадр интерфейса, крупные планы
## (ворота, пруд, площадь, ручей, вид сверху) без интерфейса и дамп: щели частокола, пересечения
## идолов, трава на мостовой, интерфейс за краем экрана и наложения шапки, высота дока, кегли,
## герой и столбы сторожки. Повторяет все кадры разбора critique_3 одной командой.
## godot --path . --screen 1 -s res://tools/ritual_view_probe.gd -- --size=1920x1080 --level=1
##     --moment=day|evening|dawn|spawn|prespawn|dusk|night|nightN|boss [--night=N]
##     --state=heroes,idol,legend,place,select,alt,hover,tooltip,damaged,defeat,banner,tier2,tier3,live,half,toast
##     --shots=ui,game,top,gates,<камера> --out=<папка> --tag=x --empty --run=<сек> --dump
## Камеры: terem, idols, gatehouse, pier, bridge, trailend, enemy, enemy2, hero, pond, pondclose,
##     pondnight, plaza, plazatop, stream, spawn, shrine, machines, gatewest, northrow, wide, house,
##     westwall, south. mask — замер яркости крыш, окон и машин по маске (critique_4 п. 1, 3, 55).

const GATE_SHOTS: Array[String] = ["west", "north", "south"]

var _panel: RitualTrialPanel
var _out: String = "res://.godot/view_probe/"
var _size: Vector2i = Vector2i(1920, 1080)
var _level: int = 1
var _moment: String = "day"
var _shots: PackedStringArray = PackedStringArray(["ui"])
var _dump: bool = false
var _houses: bool = true
var _tag: String = ""
var _select: bool = false
var _states: PackedStringArray = PackedStringArray()
var _night: int = 0
var _run_seconds: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
			if not _out.begins_with("/") and not _out.begins_with("res://"):
				_out = "res://" + _out
			if not _out.ends_with("/"):
				_out += "/"
		elif argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").split("x")
			_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif argument.begins_with("--level="):
			_level = clampi(argument.trim_prefix("--level=").to_int(), 1, 4)
		elif argument.begins_with("--moment="):
			_moment = argument.trim_prefix("--moment=")
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=").split(",", false)
		elif argument.begins_with("--tag="):
			_tag = argument.trim_prefix("--tag=")
		elif argument == "--dump":
			_dump = true
		elif argument == "--empty":
			_houses = false
		elif argument == "--select":
			_select = true
		elif argument.begins_with("--state="):
			_states = argument.trim_prefix("--state=").split(",", false)
		elif argument.begins_with("--night="):
			_night = argument.trim_prefix("--night=").to_int()
		elif argument.begins_with("--roofs="):
			RitualTownHouse.roof_mode = argument.trim_prefix("--roofs=").to_int()
		elif argument.begins_with("--run="):
			_run_seconds = argument.trim_prefix("--run=").to_float()
	if _moment.begins_with("night") and _moment.length() > 5:
		_night = _moment.trim_prefix("night").to_int()
		_moment = "night"
	if _states.has("select"):
		_select = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# Точный размер: без рамки и без изменения размера окно не ужимается менеджером окон.
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.unresizable = true
	root.size = _size
	_panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(_panel)
	await process_frame
	var prefix: String = "l%d_%s_%dx%d%s%s" % [_level, _moment + (str(_night) if _night > 0 else ""),
			_size.x, _size.y, "_" + "-".join(_states) if not _states.is_empty() else "",
			"_" + _tag if not _tag.is_empty() else ""]
	if _states.has("heroes"):
		await _settle(30)
		if _dump:
			_dump_ui()
		for shot: String in _shots:
			if shot == "ui":
				await _save(prefix + "_ui")
		quit()
		return
	_panel._pick_hero(1)
	var trial: RitualTrial = _panel.trial
	trial.hp = 1000000
	trial.gold = 1000000
	for level: int in range(2, _level + 1):
		trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
	if _houses:
		_fill_plots(trial, _states.has("half"))
	_advance_to_moment(trial)
	if _states.has("damaged"):
		for tower: TowerState in trial.field.towers:
			if tower.id % 2 == 0 and tower.durability > 0:
				tower.durability = tower.durability / (5 if tower.id % 4 == 0 else 2)
	if _select and not trial.field.towers.is_empty():
		_panel.board.selected_id = trial.field.towers[trial.field.towers.size() - 1].id
	if _states.has("alt"):
		_panel.board.show_all_marks = true
	if _states.has("place"):
		_panel._choose_purchase(1)
		for cell: Vector2i in trial.field.get_buildable_cells():
			if trial.field.get_tower_at(cell) == null:
				_panel.board.hover_cell = cell
				break
	if _states.has("tier2"):
		_panel._dock.show_tier(2)
	if _states.has("tier3"):
		_panel._dock.show_tier(3)
	if _states.has("hover"):
		_panel._hover_building(0)
	await _settle()
	if _states.has("idol"):
		_panel._open_idol(1)
		await _settle(12)
	if _states.has("legend"):
		_panel._overlay.toggle_legend(_panel.settings)
		await _settle(6)
	if _states.has("defeat"):
		_panel._paused = false
		trial.hp = 1
		var guard: int = 0
		while trial.phase == RitualTrial.Phase.RUNNING and guard < 20000:
			trial.tick()
			guard += 1
		print("DEFEAT after ", guard, " ticks")
		await _settle(10)
	if _states.has("live"):
		_panel._paused = false
		var frames: int = int(_run_seconds * 60.0) if _run_seconds > 0.0 else 30
		for frame: int in frames:
			await process_frame
		_panel._paused = true
	if _states.has("tooltip"):
		await _tooltip_on_chip(0)
	if _dump:
		await _dump_all()
	for shot: String in _shots:
		match shot:
			"ui":
				await _capture_ui(prefix + "_ui")
			"top":
				await _capture_top(prefix + "_top")
			"gates":
				for gate: String in GATE_SHOTS:
					await _capture_gate(gate, prefix)
			_:
				await _capture_named(shot, prefix)
	quit()


func _advance_to_moment(trial: RitualTrial) -> void:
	var nights: RitualNightRules = _panel.settings.nights
	var night: int = 1
	while nights.night_start(night) <= trial.tick_count:
		night += 1
	if _night > 0:
		night = _night
	match _moment:
		"evening":
			_advance(trial, maxi(trial.tick_count, 300))
		"night":
			_advance(trial, nights.night_start(night) + 450)
		"spawn":
			_advance(trial, nights.night_start(night) + 30)
		"prespawn":
			_advance(trial, nights.night_start(night) - 60)
		"dusk":
			_advance(trial, nights.night_start(night) - 40)
		"dawn":
			_advance(trial, nights.night_end(night) + 40)
		"boss":
			var boss: int = 1
			while not nights.is_boss_night(boss):
				boss += 1
			_advance(trial, nights.night_start(boss) + 500)
		_:
			_advance(trial, nights.night_end(night) + 220)


func _advance(trial: RitualTrial, until: int) -> void:
	while trial.tick_count < until:
		trial.hp = 1000000
		if not trial.gift_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
		# Рассветный выбор усиления: оставить открытым только для кадра рассвета.
		if not trial.boon_choice.is_empty() and trial.tick_count < until - 200:
			trial.execute(RitualCommand.new(RitualCommand.Action.BOON, trial.boon_choice[0]))
		trial.tick()


## Дом на каждом свободном участке (half - на каждом втором); тир дома - по уровню участка.
func _fill_plots(trial: RitualTrial, half: bool) -> void:
	var cells: Array[Vector2i] = trial.field.get_buildable_cells()
	for index: int in cells.size():
		if half and index % 2 == 1:
			continue
		if trial.field.get_tower_at(cells[index]) != null:
			continue
		var catalogue: int = (index * 3) % trial.settings.costs.size()
		while not trial.building_unlock_error(catalogue).is_empty():
			catalogue = (catalogue + 1) % trial.settings.costs.size()
		trial.execute(RitualCommand.new(RitualCommand.Action.BUY, catalogue, cells[index]))


func _settle(frames: int = 40) -> void:
	_panel._paused = true
	for frame: int in frames:
		_panel._process(1.0 / 60.0)
		await process_frame


func _save(title: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(_out + title + ".jpg"), 0.9)
	print("VIEW: ", title, " ", image.get_size())


func _capture_ui(title: String) -> void:
	await _settle(10)
	if not _states.has("toast"):
		_panel._toast.visible = false
	await _save(title)


func _stage() -> RitualStage3D:
	return _panel.board.stage as RitualStage3D


func _arena() -> RitualArena3D:
	return _stage()._world.get_node("Arena") as RitualArena3D


## Свой кадр без интерфейса: панель прячет всё, кроме карты, камера ставится своя.
func _with_camera(camera: Camera3D, title: String) -> void:
	_hide_ui(true)
	_stage()._world.add_child(camera)
	camera.make_current()
	await _settle(24)
	await _save(title)
	_stage()._camera.make_current()
	camera.queue_free()
	_hide_ui(false)


## Интерфейс прозрачный (панель сама включает свои окна каждый кадр — скрывать бесполезно).
func _hide_ui(hide: bool) -> void:
	for child: Node in _panel.get_children():
		if child is CanvasItem and child != _panel.board:
			(child as CanvasItem).modulate.a = 0.0 if hide else 1.0
	for child: Node in _panel.board.get_children():
		if child is CanvasItem and child != _panel.board.stage:
			(child as CanvasItem).modulate.a = 0.0 if hide else 1.0


func _look(from: Vector3, to: Vector3, fov: float = 40.0) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	camera.fov = fov
	camera.near = 0.1
	camera.far = 300.0
	camera.position = from
	camera.look_at_from_position(from, to, Vector3.UP)
	return camera


func _capture_top(title: String) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 44.0
	camera.near = 0.1
	camera.far = 200.0
	camera.look_at_from_position(Vector3(25.0, 80.0, 0.5), Vector3(25.0, 0.0, 0.5), Vector3(0, 0, -1))
	await _with_camera(camera, title)


## Точка ворот входа в мире: вход дороги на поле (road_point 0).
func _gate_point(gate: String) -> Vector3:
	var lanes: Array[ArenaLayout3D] = _stage()._lanes
	var index: int = GATE_SHOTS.find(gate)
	if index < 0 or index >= lanes.size():
		return Vector3.INF
	return lanes[index].road_point(0.0)


func _capture_gate(gate: String, prefix: String) -> void:
	var point: Vector3 = _gate_point(gate)
	if point == Vector3.INF or gate_index_closed(GATE_SHOTS.find(gate)):
		return
	# С юго-запада сверху, как игровая камера, но близко.
	await _with_camera(_look(point + Vector3(-3.0, 7.5, 9.0), point + Vector3(0.0, 0.6, 0.0), 42.0),
			"%s_gate_%s" % [prefix, gate])


func gate_index_closed(index: int) -> bool:
	var ritual: RitualField = _panel.trial.field
	return index > ritual.open_streets and index > 0


func _capture_named(shot: String, prefix: String) -> void:
	var camera: Camera3D = null
	match shot:
		"pond":
			camera = _look(Vector3(19.0, 13.0, 15.0), Vector3(21.0, 0.0, 0.0), 45.0)
		"pondclose":
			camera = _look(Vector3(18.0, 5.0, 9.0), Vector3(20.0, 0.0, 1.0), 50.0)
		"plaza":
			camera = _look(Vector3(37.0, 12.0, 14.0), Vector3(40.0, 0.5, 1.0), 45.0)
		"plazatop":
			camera = Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 14.0
			camera.far = 200.0
			camera.look_at_from_position(Vector3(43.0, 60.0, 1.0), Vector3(43.0, 0.0, 1.0), Vector3(0, 0, -1))
		"stream":
			camera = _look(Vector3(0.0, 12.0, 14.0), Vector3(2.0, 0.0, -1.0), 45.0)
		"spawn":
			var point: Vector3 = _gate_point("west")
			camera = _look(point + Vector3(-14.0, 14.0, 16.0), point + Vector3(-8.0, 0.0, 0.0), 45.0)
		"game":
			_hide_ui(true)
			await _settle(10)
			await _save(prefix + "_game")
			_hide_ui(false)
			return
		"mask":
			await _mask_stats()
			return
		"terem":
			camera = _look(Vector3(37.5, 6.0, 9.0), Vector3(43.0, 1.8, 1.0), 45.0)
		"idols":
			camera = _look(Vector3(43.5, 3.2, 6.5), Vector3(47.6, 1.0, 1.0), 45.0)
		"gatehouse":
			camera = _look(Vector3(38.8, 3.4, 6.2), Vector3(36.4, 1.1, 1.2), 45.0)
		"shrine":
			camera = _look(Vector3(23.0, 4.5, -4.5), Vector3(21.0, 0.4, -11.0), 45.0)
		"machines":
			camera = _look(Vector3(20.0, 6.5, -2.0), Vector3(20.0, 1.5, -9.0), 50.0)
		"pondnight":
			camera = _look(Vector3(16.0, 6.0, 9.0), Vector3(21.0, 0.0, 0.0), 50.0)
		"gatewest":
			camera = _look(Vector3(2.0, 5.0, 13.0), Vector3(7.0, 1.0, 6.5), 45.0)
		"northrow":
			camera = _look(Vector3(22.0, 7.0, 1.0), Vector3(22.0, 0.5, -9.0), 50.0)
		"pier":
			camera = _look(Vector3(21.5, 2.6, 6.5), Vector3(24.6, 0.0, 2.5), 50.0)
		"bridge":
			camera = _look(Vector3(-3.0, 5.0, 16.0), Vector3(-6.8, 0.0, 10.7), 50.0)
		"wide":
			camera = _look(Vector3(25.0, 40.0, 45.0), Vector3(25.0, 0.0, 0.0), 60.0)
		"house":
			camera = _look(Vector3(13.0, 4.0, 2.0), Vector3(16.5, 1.0, -3.0), 45.0)
		"westwall":
			camera = _look(Vector3(4.0, 3.0, 12.0), Vector3(8.0, 1.0, 6.0), 50.0)
		"south":
			camera = _look(Vector3(28.0, 6.0, 20.0), Vector3(28.0, 0.5, 10.0), 50.0)
		"trailend":
			var trails: Array[PackedVector2Array] = _arena().trails
			if trails.is_empty() or trails[0].is_empty():
				return
			var end: Vector2 = trails[0][trails[0].size() - 1]
			camera = _look(Vector3(end.x + 6.0, 9.0, end.y + 9.0), Vector3(end.x + 2.0, 0.0, end.y), 50.0)
		"enemy", "enemy2":
			var units: Array[ArenaUnit3D] = _stage()._units.values()
			if units.is_empty():
				print("no units")
				return
			var best: Node3D = units[units.size() / 2]
			if shot == "enemy":
				best = units[0]
				for unit: ArenaUnit3D in units:
					if unit != null and unit.global_position.x > best.global_position.x and unit.global_position.x < 30.0:
						best = unit
			var at: Vector3 = best.global_position
			if shot == "enemy":
				camera = _look(at + Vector3(-1.5, 3.2, 4.5), at + Vector3(0.0, 0.5, 0.0), 40.0)
			else:
				camera = _look(at + Vector3(-2.0, 4.5, 6.0), at + Vector3(0.0, 0.4, 0.0), 38.0)
		"hero":
			var hero: Node3D = _stage()._hero
			camera = _look(hero.global_position + Vector3(0.8, 2.6, 3.6), hero.global_position + Vector3(0, 0.7, 0), 40.0)
	if camera != null:
		await _with_camera(camera, "%s_%s" % [prefix, shot])


# --- Дамп -------------------------------------------------------------------------------------

func _world_box(node: Node3D) -> AABB:
	return node.global_transform * _arena()._bounds(node)


func _props(suffix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in _arena()._yard.get_children():
		if node is Node3D and (node as Node3D).scene_file_path.ends_with(suffix):
			found.append(node as Node3D)
	return found


func _dump_all() -> void:
	print("DUMP: level ", _level, " size ", _size)
	_dump_walls()
	_dump_idols()
	_dump_plaza()
	_dump_grass()
	_dump_hero()
	_dump_wildlife()
	_dump_frame_share()
	_dump_ui()
	await _dump_fonts()
	await _dump_dock()


## Непокрытые отрезки каждого пробега частокола (панели и ворота вместе), > 0,2 м.
func _dump_walls() -> void:
	var arena: RitualArena3D = _arena()
	var fine: Dictionary[Vector2i, bool] = arena._fine_region(arena._open_now)
	var boxes: Array[AABB] = []
	for node: Node3D in _props("palisade.glb") + _props("gate.glb"):
		boxes.append(_world_box(node))
	var holes: int = 0
	for run: NoirArena3D.Run in arena._wall_runs(fine):
		var along_x: bool = absf(run.b.x - run.a.x) > absf(run.b.y - run.a.y)
		var lo: float = minf(run.a.x, run.b.x) if along_x else minf(run.a.y, run.b.y)
		var hi: float = maxf(run.a.x, run.b.x) if along_x else maxf(run.a.y, run.b.y)
		var line: float = run.a.y if along_x else run.a.x
		var spans: Array[Vector2] = []
		for box: AABB in boxes:
			var center: Vector3 = box.get_center()
			var across: float = center.z if along_x else center.x
			if absf(across - line) > 0.6:
				continue
			var start: float = box.position.x if along_x else box.position.z
			var stop: float = box.end.x if along_x else box.end.z
			if stop < lo or start > hi:
				continue
			spans.append(Vector2(start, stop))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var reach: float = lo
		for span: Vector2 in spans:
			if span.x - reach > 0.2:
				holes += 1
				print("  HOLE %s=%.2f  %.2f..%.2f (%.2f m)" % ["z" if along_x else "x", line, reach, span.x, span.x - reach])
			reach = maxf(reach, span.y)
		if hi - reach > 0.2:
			holes += 1
			print("  HOLE %s=%.2f  %.2f..%.2f (%.2f m) end" % ["z" if along_x else "x", line, reach, hi, hi - reach])
	print("WALLS: holes=", holes)
	for gate: Node3D in _props("gate.glb"):
		print("  GATE ", _world_box(gate))


## Плиты идолов против частокола и терема (зазор по XZ).
func _dump_idols() -> void:
	var idols: RitualIdols3D = _stage()._idols
	var walls: Array[AABB] = []
	for node: Node3D in _props("palisade.glb"):
		walls.append(_world_box(node))
	var terem: AABB = _arena().terem_bounds
	for index: int in idols.shown():
		var base: Node3D = idols.get_child(index) as Node3D
		var box: AABB = AABB()
		var first: bool = true
		for part: MeshInstance3D in NoirArena3D._mesh_parts(base):
			if not part.visible or part.mesh is QuadMesh or part.mesh is TorusMesh:
				continue
			var local: AABB = part.global_transform * part.get_aabb()
			box = local if first else box.merge(local)
			first = false
		var wall_gap: float = INF
		for wall: AABB in walls:
			wall_gap = minf(wall_gap, _xz_gap(box, wall))
		print("IDOL %d at %s box x %.2f..%.2f z %.2f..%.2f  gap wall %.2f terem %.2f  yaw %.2f" % [index,
				base.position, box.position.x, box.end.x, box.position.z, box.end.z, wall_gap, _xz_gap(box, terem),
				base.rotation.y])


## Что стоит на площади: терем, сторожка, герой, конец дороги, участки рядом.
func _dump_plaza() -> void:
	var stage: RitualStage3D = _stage()
	var end: float = stage.layout.road_end_length()
	print("PLAZA: rect ", Rect2(Vector2(RitualArena3D.PLAZA.position) * 2.0 + NoirArena3D.BOARD_MIN,
			Vector2(RitualArena3D.PLAZA.size) * 2.0), " terem ", _arena().terem_bounds)
	print("  road end ", stage.layout.road_point(end), " hero ", stage._hero.position if stage._hero != null else Vector3.ZERO)
	if stage._gates != null and stage._gates._gatehouse != null:
		print("  gatehouse ", stage._gates._gatehouse.position)
	var plots: Array[Vector2i] = []
	for cell: Vector2i in _panel.trial.field.get_buildable_cells():
		if cell.x >= 13:
			plots.append(cell)
	print("  plots x>=13: ", plots)


## Расстояние между прямоугольниками на земле (отрицательное — пересекаются).
static func _xz_gap(a: AABB, b: AABB) -> float:
	var dx: float = maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dz: float = maxf(b.position.z - a.end.z, a.position.z - b.end.z)
	if dx < 0.0 and dz < 0.0:
		return maxf(dx, dz)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


## Трава, папоротник и подлесок на открытых клетках города (мостовая, отступ 0,3 м от края клетки).
func _dump_grass() -> void:
	var arena: RitualArena3D = _arena()
	var count: int = 0
	var where: Dictionary[Vector2i, int] = {}
	for node: Node in arena.find_children("*", "MultiMeshInstance3D", true, false):
		var instance: MultiMeshInstance3D = node as MultiMeshInstance3D
		var title: String = String(instance.name).to_lower()
		if not (title.contains("fern") or title.contains("sedge") or title.contains("grass") \
				or title.contains("spruce") or title.contains("birch")):
			continue
		var mm: MultiMesh = instance.multimesh
		for index: int in mm.instance_count:
			var at: Vector3 = instance.global_transform * mm.get_instance_transform(index).origin
			var cell: Vector2i = Vector2i(floori(at.x / NoirArena3D.CELL),
					floori((at.z - NoirArena3D.BOARD_MIN.y) / NoirArena3D.CELL))
			if not arena._open_now.has(cell):
				continue
			var local: Vector2 = Vector2(at.x - cell.x * NoirArena3D.CELL,
					at.z - NoirArena3D.BOARD_MIN.y - cell.y * NoirArena3D.CELL)
			if local.x < 0.3 or local.y < 0.3 or local.x > 1.7 or local.y > 1.7:
				continue
			if RitualArena3D.POND.has_point(cell):
				continue
			count += 1
			where[cell] = where.get(cell, 0) + 1
	print("GRASS on paving: ", count, " cells ", where.keys().slice(0, 12))


## Кнопки и подписи за краем экрана, ширина корневого столбца, наложения шапки.
func _dump_ui() -> void:
	var screen: Rect2 = _panel.get_viewport_rect()
	var root_box: Control = _panel._hud.get_parent() as Control
	print("UI: screen ", screen.size, " root_box ", root_box.size, " dock min ",
			_panel._dock.get_combined_minimum_size() if _panel._dock != null else Vector2.ZERO)
	print("TOAST: visible %s rect %s text '%s' label %s" % [_panel._toast.visible, _panel._toast.get_global_rect(),
			_panel._message.text, _panel._message.size])
	if _panel._dock != null:
		for island: Node in _panel._dock.get_child(0).get_children():
			print("  DOCK part ", (island as Control).get_combined_minimum_size())
	var outside: int = 0
	for node: Node in _panel.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or not (control is Button or control is Label):
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if rect.end.x > screen.end.x + 1.0 or rect.position.x < -1.0 or rect.end.y > screen.end.y + 1.0:
			outside += 1
			print("  OUTSIDE %s '%s' %s" % [control.name, _text(control), rect])
	print("UI: outside=", outside)
	var header: Dictionary[String, Rect2] = {}
	header["phase"] = _panel._hud._phase_label.get_global_rect()
	header["round"] = _panel._hud._round_label.get_global_rect()
	if _panel._scout != null:
		header["scout"] = (_panel._scout.get_parent() as Control).get_global_rect()
	header["tools"] = _panel._hud._prep_tools.get_global_rect()
	var names: Array[String] = header.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = header[names[i]]
			var b: Rect2 = header[names[j]]
			if a.size.x > 0.0 and b.size.x > 0.0 and a.intersects(b):
				print("  OVERLAP %s %s / %s %s" % [names[i], a, names[j], b])
	for key: String in names:
		print("  HEADER %s %s" % [key, header[key]])


static func _text(control: Control) -> String:
	if control is Button:
		return (control as Button).text
	if control is Label:
		return (control as Label).text
	return ""


## Герой против столбов сторожки: расстояние по земле от центра героя до края ближайшего столба.
func _dump_hero() -> void:
	var stage: RitualStage3D = _stage()
	if stage._hero == null or stage._gates == null or stage._gates._gatehouse == null:
		return
	var hero: Vector3 = stage._hero.global_position
	var best: float = INF
	for part: MeshInstance3D in NoirArena3D._mesh_parts(stage._gates._gatehouse):
		var cylinder: CylinderMesh = part.mesh as CylinderMesh
		if cylinder == null or cylinder.height < 2.0 or absf(part.rotation.x) > 0.1 or absf(part.rotation.z) > 0.1:
			continue
		var post: Vector3 = part.global_position
		best = minf(best, Vector2(hero.x - post.x, hero.z - post.z).length() - cylinder.top_radius)
	print("HERO: to post %.2f m  hero %s" % [best, hero])


## Самый мелкий текст на экране: кегль x масштаб холста (нормы SCN-12 - не меньше 14 px на 1280x720).
func _dump_fonts() -> void:
	var smallest: float = INF
	var where: String = ""
	var small: int = 0
	for node: Node in _panel.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or not (control is Label or control is Button):
			continue
		if _text(control).strip_edges().is_empty():
			continue
		var scale: float = control.get_global_transform_with_canvas().get_scale().y \
				* root.get_final_transform().get_scale().y
		var size: float = float(control.get_theme_font_size("font_size")) * scale
		if size < 14.0 - 0.01:
			small += 1
			if small <= 40:
				print("  SMALL %.1f px %s '%s'" % [size, control.name, _text(control).left(30)])
		if size < smallest:
			smallest = size
			where = "%s '%s'" % [control.name, _text(control).left(30)]
	# И текст, нарисованный draw_string: сцена, карточки каталога, плитки (critique_4 п. 39).
	DuskTheme.drawn_text.clear()
	DuskTheme.track_drawn = true
	_panel.board.queue_redraw()
	if _panel._dock != null:
		for chip: RitualBuildChip in _panel._dock.chips:
			chip.queue_redraw()
	await _settle(3)
	DuskTheme.track_drawn = false
	var canvas: float = root.get_final_transform().get_scale().y
	for text: String in DuskTheme.drawn_text:
		var drawn: float = DuskTheme.drawn_text[text] * canvas
		if drawn < 14.0 - 0.01:
			small += 1
			if small <= 40:
				print("  SMALL %.1f px drawn '%s'" % [drawn, text.left(30)])
		if drawn < smallest:
			smallest = drawn
			where = "drawn '%s'" % text.left(30)
	print("FONTS: smallest %.1f px at %s  below14=%d (вместе с draw_string: %d надписей)" % [smallest, where, small,
			DuskTheme.drawn_text.size()])


## Высота дока без выбора и с выбранным домом (не должна меняться).
func _dump_dock() -> void:
	if _panel._dock == null or _panel.trial.field.towers.is_empty():
		return
	var keep: int = _panel.board.selected_id
	_panel.board.selected_id = 0
	await _settle(6)
	var plain: float = _panel._dock.size.y
	var top_plain: float = _panel._dock.get_global_rect().position.y
	_panel.board.selected_id = _panel.trial.field.towers[0].id
	await _settle(6)
	var chosen: float = _panel._dock.size.y
	var top_chosen: float = _panel._dock.get_global_rect().position.y
	print("DOCK: height plain %.1f selected %.1f  top %.1f / %.1f" % [plain, chosen, top_plain, top_chosen])
	if not is_equal_approx(plain, chosen):
		# Что растёт: высота рядов правой части дока.
		for node: Node in _panel._dock.house_actions.get_parent().get_children():
			var control: Control = node as Control
			if control != null and control.visible:
				print("  DOCK ROW %s %s min %s" % [control.name, control.size, control.get_combined_minimum_size()])
		for node: Node in _panel._dock.city_actions.get_children():
			var city: Control = node as Control
			if city != null and city.visible:
				print("  DOCK CITY %s %s min %s" % [city.name, city.size, city.get_combined_minimum_size()])
		for node: Node in _panel._dock.house_actions.get_children():
			var item: Control = node as Control
			if item != null and item.visible:
				print("  DOCK ITEM %s %s min %s" % [item.name, item.size, item.get_combined_minimum_size()])
	_panel.board.selected_id = keep
	await _settle(4)


## Подсказка карточки каталога: курсор над карточкой и показ её подсказки.
func _tooltip_on_chip(index: int) -> void:
	var chips: Array[RitualBuildChip] = _panel._dock.chips
	if chips.is_empty():
		return
	var chip: Control = chips[index]
	var center: Vector2 = chip.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = center * root.get_final_transform().get_scale()
	motion.global_position = motion.position
	motion.relative = Vector2(2, 2)
	root.push_input(motion)
	for frame: int in 70:
		await process_frame
	_panel._hover_building(index)


## Медвежонок не на открытых клетках города (critique_3 п. 35).
func _dump_wildlife() -> void:
	for node: Node in _arena().find_children("*", "ArenaBearCub3D", true, false):
		var bear: Node3D = node as Node3D
		var at: Vector3 = bear.global_position
		var cell: Vector2i = Vector2i(floori(at.x / NoirArena3D.CELL), floori((at.z - NoirArena3D.BOARD_MIN.y) / NoirArena3D.CELL))
		print("BEAR: at %s in_city=%s" % [at, _arena()._open_now.has(cell)])


## Доля ширины кадра под частоколом (critique_3 п. 2: SCN-1 — 0,65-0,75).
func _dump_frame_share() -> void:
	var low: float = INF
	var high: float = -INF
	for node: Node3D in _props("palisade.glb") + _props("palisade_post.glb"):
		var box: AABB = _world_box(node)
		for index: int in 8:
			var point: Vector2 = _stage().project(box.get_endpoint(index))
			low = minf(low, point.x)
			high = maxf(high, point.x)
	var width: float = _panel.get_viewport_rect().size.x
	print("FRAME: palisade share %.2f (%.0f..%.0f of %.0f)" % [(high - low) / width, low, high, width])


## Яркость крыш, окон и рабочих граней машин с игровой камеры (L 0..255, sRGB, Rec.709):
## второй кадр с маской (крыша — красный, окна — зелёный, машина — синий) выделяет пиксели.
func _mask_stats() -> void:
	_hide_ui(true)
	await _settle(10)
	await RenderingServer.frame_post_draw
	var plain: Image = root.get_texture().get_image()
	var environment: Environment = (_stage()._world.get_node("Environment") as WorldEnvironment).environment
	var glow: bool = environment.glow_enabled
	environment.glow_enabled = false
	RitualTownHouse.set_debug_mask(true)
	await _settle(4)
	await RenderingServer.frame_post_draw
	var mask: Image = root.get_texture().get_image()
	mask.save_jpg(ProjectSettings.globalize_path(_out + "mask.jpg"), 0.8)
	RitualTownHouse.set_debug_mask(false)
	environment.glow_enabled = glow
	_hide_ui(false)
	var values: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	for y: int in range(0, plain.get_height(), 2):
		for x: int in range(0, plain.get_width(), 2):
			var m: Color = mask.get_pixel(x, y)
			var channel: int = -1
			# Чистый канал: тональная кривая и туман разбавляют цвет маски, поэтому — по перевесу.
			if m.r > 0.2 and m.r > 2.2 * maxf(m.g, m.b):
				channel = 0
			elif m.g > 0.2 and m.g > 2.2 * maxf(m.r, m.b):
				channel = 1
			elif m.b > 0.2 and m.b > 2.2 * maxf(m.r, m.g):
				channel = 2
			if channel >= 0:
				var c: Color = plain.get_pixel(x, y)
				values[channel].append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	var names: Array[String] = ["roofs", "windows", "machines"]
	for index: int in 3:
		var list: PackedFloat32Array = values[index]
		if list.is_empty():
			print("MASK: %s none" % names[index])
			continue
		list.sort()
		var total: float = 0.0
		for value: float in list:
			total += value
		print("MASK: %-8s mean %5.1f  p95 %5.1f  px %d" % [names[index], total / list.size(),
				list[int(list.size() * 0.95)], list.size()])
