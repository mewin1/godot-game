extends SceneTree
## Реальная сцена забега с контрольной расстановкой домов на участках.
## -- fire | mixed | isolated | survey, опционально --quality=mobile. Кадры в .godot/town-review.

const OUT: String = "res://.godot/town-review/"
const FIRE: Array[StringName] = [&"brazier", &"furnace", &"cinder"]

var _panel: RitualTrialPanel
var _ids: Dictionary[StringName, TowerData] = {}
var _last_master_shot: int = -1
var _mode: String = "fire"
var _survey: Image
var _gpu_sample: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["fire", "mixed", "isolated", "survey"]:
			_mode = argument
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	assert(error == OK)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	_panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(_panel)
	await process_frame
	_panel._pick_hero(0)
	var trial: RitualTrial = RitualTrial.new(_panel.settings, 0, 915701, 0)
	_panel.trial = trial
	for street: int in (0 if _mode == "isolated" else trial.settings.streets.size()):
		trial.street_nights.append(1)
	trial.sync_streets()
	_panel._board_reset()
	_panel.set_process(false)
	_panel._paused = false
	RenderingServer.viewport_set_measure_render_time(_panel.board.stage._viewport.get_viewport_rid(), true)
	for data: TowerData in trial.settings.combat.towers:
		_ids[data.id] = data
	var cells: Array[Vector2i] = trial.field.get_buildable_cells()
	if _mode == "isolated":
		_place(_ids[&"cinder"], cells[4], 4)
	elif _mode == "fire":
		for index: int in 12:
			_place(_ids[FIRE[index % 3]], cells[index], 1 + index / 3)
	else:
		var ordered: Array[TowerData] = []
		for tier: int in range(1, 4):
			for data: TowerData in trial.settings.combat.towers:
				if data.tier == tier:
					ordered.append(data)
		for index: int in ordered.size():
			_place(ordered[index], cells[index * 5 % ordered.size()], 1 + index % 4)
	trial.field.mark_towers_changed()
	trial.field.tower_fired.connect(_on_shot)
	await _settle()
	if _mode == "survey":
		_survey = Image.create_empty(4 * 88, trial.field.towers.size() * 78, false, Image.FORMAT_RGB8)
		for level: int in range(1, 5):
			for tower: TowerState in trial.field.towers:
				tower.level = level
				tower.durability = trial.settings.max_durability(level)
				(tower as RitualTower).branch = tower.id % 2 if level >= 3 else -1
			trial.field.mark_towers_changed()
			await _settle()
			if not _check_models(level):
				quit(1)
				return
			await _capture("L%d" % level)
		assert(_survey.save_png(OUT + "survey.png") == OK)
	else:
		await _capture("day")
		if _mode == "isolated":
			var placed: TowerState = trial.field.towers[0]
			var crown: Vector2 = _panel.board.stage.tower_top(placed.id)
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = crown
			_panel.board._gui_input(click)
			if _panel.board.selected_id != placed.id:
				push_error("Clicking the visible fire crown missed the occupied plot.")
				quit(1)
				return
		if _mode != "isolated":
			var night: int = trial.settings.nights.night_start(1)
			while trial.tick_count < night - 40:
				trial.tick()
			await _settle()
			await _capture("dusk")
			while trial.tick_count < night + 230:
				trial.tick()
			await _settle()
			# Живучие ратники на главной улице позволяют увидеть залп прежде, чем
			# их убьют высокоуровневые соседи. Урон и попадания считает обычный бой.
			for step: int in range(1, trial.field.route(0).size() - 1, 3):
				var mob: RitualMob = trial.field.spawn_mob(0, 10000)
				mob.progress = step * 1000
			for tick: int in 80:
				trial.tick()
				if _last_master_shot >= trial.tick_count - 1:
					break
			assert(_last_master_shot >= trial.tick_count - 1)
			await process_frame
			await _capture("combat")
			print("Last tier III shot ", _last_master_shot, " at tick ", trial.tick_count)
			if _mode == "mixed":
				var tower: TowerState = trial.field.towers.back()
				tower.durability = 0
				_panel.board.selected_id = tower.id
				trial.field.towers[0].action_lock_ticks = 40
				await _settle()
				await _capture("wear")
				_panel._choose_purchase(0)
				_panel.board.hover_cell = cells.back()
				await _settle()
				await _capture("preview")
	_panel.queue_free()
	await process_frame
	quit()


func _check_models(level: int) -> bool:
	var stage: RitualStage3D = _panel.board.stage
	for tower: TowerState in _panel.trial.field.towers:
		var house: RitualTownHouse = stage._towers[tower.id] as RitualTownHouse if stage._towers.has(tower.id) else null
		if house == null or house._installation.scene_file_path.get_file() != "%s.glb" % tower.data.id:
			push_error("Wrong device for %s" % tower.data.id)
			return false
		if house._model.scene_file_path.get_file() != "house_%d.glb" % tower.data.tier \
				or house._model.get_node_or_null("Level%d" % level) == null:
			push_error("Wrong architecture for %s L%d" % [tower.data.id, level])
			return false
		var paint: ShaderMaterial = house._works.material_override as ShaderMaterial
		if paint == null or paint.get_shader_parameter(&"roof_column") != RitualTownHouse.PALETTES.find(tower.data.school):
			push_error("Wrong roof palette for %s" % tower.data.id)
			return false
		var bounds: AABB = ArenaTower3D._body_bounds(house._model)
		var half: float = stage.layout.cell_m * 0.5
		if bounds.position.x <= -half or bounds.position.z <= -half or bounds.end.x >= half or bounds.end.z >= half \
				or absf(bounds.position.y) > 0.002:
			push_error("Plot clearance or ground mismatch for %s: %s" % [tower.data.id, bounds])
			return false
		if stage.house_cell_at(stage.project(house.get_top())) != tower.anchor:
			push_error("Device pick misses %s" % tower.data.id)
			return false
	return true


func _place(data: TowerData, cell: Vector2i, level: int) -> void:
	var tower: RitualTower = _panel.trial.field.add_tower(data, cell, 0) as RitualTower
	tower.level = level
	tower.branch = tower.id % 2 if level >= 3 else -1
	tower.durability = _panel.settings.max_durability(level)


func _on_shot(tower: TowerState, _mob: MobState) -> void:
	if tower.data.tier == 3:
		_last_master_shot = _panel.trial.tick_count


func _settle() -> void:
	_panel._refresh()
	_gpu_sample.clear()
	for frame: int in 45:
		await process_frame
		if frame >= 15:
			_gpu_sample.append(RenderingServer.viewport_get_measured_render_time_gpu(
					_panel.board.stage._viewport.get_viewport_rid()))
	_gpu_sample.sort()
	await RenderingServer.frame_post_draw


func _capture(moment: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if _mode == "survey":
		for index: int in _panel.trial.field.towers.size():
			var house: TowerState = _panel.trial.field.towers[index]
			var base: Vector2 = _panel.board.stage.project_milli(Vector2(house.center_milli()))
			var screen: Vector2 = _panel.board.get_global_transform_with_canvas() * base
			var region: Rect2i = Rect2i(Vector2i(screen) - Vector2i(44, 59), Vector2i(88, 78))
			_survey.blit_rect(picture, region, Vector2i((house.level - 1) * 88, index * 78))
	var path: String = OUT + _mode + "_" + moment + ".jpg"
	var error: Error = picture.save_jpg(path, 0.95)
	assert(error == OK)
	print("TOWN ", path, " ", picture.get_size(), " draws ",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" settled viewport GPU median ms ", snappedf(_gpu_sample[_gpu_sample.size() / 2], 0.01))
