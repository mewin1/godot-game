extends SceneTree
## Проверка вида «Городища» в точном размере окна: окно без рамки и без изменения размера (иначе
## тайловый менеджер ужимает его, и обрезки интерфейса не видно). Кадр интерфейса, крупные планы
## (ворота, пруд, площадь, ручей, вид сверху) без интерфейса и дамп: щели частокола, пересечения
## идолов, трава на мостовой, интерфейс за краем экрана и наложения шапки.
## godot --path . --screen 1 -s res://tools/ritual_view_probe.gd -- --size=1920x1080 --level=1
##     --moment=day|night|evening|dawn --shots=ui,top,gates,pond,plaza,stream,spawn --out=<папка> --dump

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# Точный размер: без рамки и без изменения размера окно не ужимается менеджером окон.
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.unresizable = true
	root.size = _size
	_panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(_panel)
	await process_frame
	_panel._pick_hero(1)
	var trial: RitualTrial = _panel.trial
	trial.hp = 1000000
	trial.gold = 1000000
	for level: int in range(2, _level + 1):
		trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
	if _houses:
		_fill_plots(trial)
	_advance_to_moment(trial)
	var prefix: String = "l%d_%s_%dx%d%s" % [_level, _moment, _size.x, _size.y, "_" + _tag if not _tag.is_empty() else ""]
	await _settle()
	if _dump:
		_dump_all()
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
	match _moment:
		"evening":
			_advance(trial, maxi(trial.tick_count, 300))
		"night":
			_advance(trial, nights.night_start(night) + 450)
		"spawn":
			_advance(trial, nights.night_start(night) + 30)
		"dawn":
			_advance(trial, nights.night_end(night) + 40)
		_:
			_advance(trial, nights.night_end(night) + 220)


func _advance(trial: RitualTrial, until: int) -> void:
	while trial.tick_count < until:
		trial.hp = 1000000
		if not trial.gift_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
		trial.tick()


## Дом на каждом свободном участке; тир дома - по уровню участка, чтобы в кадре были все три.
func _fill_plots(trial: RitualTrial) -> void:
	var cells: Array[Vector2i] = trial.field.get_buildable_cells()
	for index: int in cells.size():
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
	_dump_ui()


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
