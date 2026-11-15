extends SceneTree
## Яркость «Обряда» по фазам суток (docs/37 SCN-2/3/13): кадры реальной панели и числа —
## средняя яркость поля, дороги и участков (0..255, sRGB, вес по зрению) и рамки за частоколом.
## godot --path . --screen 1 -s res://tools/ritual_light_probe.gd [-- --out=docs/reports/<папка>/]
## Цели SCN-3: первый вечер 80-100, день >= 100, сумерки 60-80, ночь 45-60 и дорога ярче участков
## на 20+, ночь босса 40-55; рамка (лес) ночью <= 30.

const PHASES: Array[String] = ["first_evening", "day", "dusk", "night", "boss_night"]

var _panel: RitualTrialPanel
var _out: String = "res://docs/reports/2026-11-14_p6/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
			if not _out.begins_with("/"):
				_out = "res://" + _out.trim_prefix("res://")
			if not _out.ends_with("/"):
				_out += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.mode = Window.MODE_WINDOWED
	# Без рамки и без изменения размера: тайловый менеджер не ужмёт окно (critique_2).
	root.borderless = true
	root.unresizable = true
	root.size = Vector2i(1920, 1080)
	_panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(_panel)
	await process_frame
	_panel._pick_hero(0)
	var trial: RitualTrial = _panel.trial
	trial.hp = 1000000
	trial.gold = 100000
	var cells: Array[Vector2i] = trial.field.get_buildable_cells()
	for index: int in 6:
		trial.execute(RitualCommand.new(RitualCommand.Action.BUY, index, cells[index * 3 % cells.size()]))
	var nights: RitualNightRules = _panel.settings.nights
	var boss: int = 1
	while not nights.is_boss_night(boss):
		boss += 1
	var moments: Dictionary[String, int] = {
		"first_evening": 300,
		"day": nights.night_end(1) + 220,
		"dusk": nights.night_start(2) - 40,
		"night": nights.night_start(2) + 500,
		"boss_night": nights.night_start(boss) + 500,
	}
	print("LIGHT: фаза | поле | дорога | двор | дорога-двор | рамка")
	for phase: String in PHASES:
		while trial.tick_count < moments[phase]:
			if not trial.gift_choice.is_empty():
				trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
			trial.tick()
		await _measure(phase)
	quit()


func _measure(phase: String) -> void:
	_panel._paused = true
	for frame: int in 40:
		_panel._process(1.0 / 60.0)
		await process_frame
	# Надписи поверх поля (затемнение паузы, баннеры, выбор усиления) не должны попадать в замер;
	# панель на время кадра не обновляется, иначе сама вернёт их на экран.
	_panel.set_process(false)
	for node_name: String in ["RitualHudOverlay", "BoonPanel", "BoonShade"]:
		var node: CanvasItem = _panel.find_child(node_name, true, false) as CanvasItem
		if node != null:
			node.visible = false
	_panel._toast.visible = false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(_out + "light_%s.jpg" % phase), 0.85)
	var board: RitualBoard = _panel.board
	var scale: Vector2 = Vector2(image.get_size()) / _panel.size
	var trial: RitualTrial = _panel.trial
	var road: float = _mean_at(image, scale, trial.field.open_road_cells())
	var plots: float = _mean_at(image, scale, _yard_cells(trial))
	var inset: Rect2 = Rect2(board.map_inset.position, _panel.size - board.map_inset.position - board.map_inset.size)
	var field: Rect2 = Rect2(inset.position + inset.size * 0.2, inset.size * 0.6)
	var frame: Rect2 = Rect2(inset.position, Vector2(inset.size.x, inset.size.y * 0.12))
	_panel.set_process(true)
	print("LIGHT: %-13s | %5.1f | %5.1f | %5.1f | %+5.1f | %5.1f" % [phase, _mean_rect(image, scale, field),
		road, plots, road - plots, _mean_rect(image, scale, frame)])


func _luma(color: Color) -> float:
	return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0


func _mean_rect(image: Image, scale: Vector2, rect: Rect2) -> float:
	var total: float = 0.0
	var count: int = 0
	var step: int = 6
	for y: int in range(int(rect.position.y * scale.y), int(rect.end.y * scale.y), step):
		for x: int in range(int(rect.position.x * scale.x), int(rect.end.x * scale.x), step):
			total += _luma(image.get_pixel(x, y))
			count += 1
	return total / maxi(1, count)


## Двор: клетки кварталов без дорог и участков (мостовая между домами).
func _yard_cells(trial: RitualTrial) -> Array[Vector2i]:
	var taken: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in trial.field.open_road_cells() + trial.field.get_buildable_cells():
		taken[cell] = true
	var result: Array[Vector2i] = []
	for region: Rect2i in trial.field.open_regions():
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if not taken.has(Vector2i(x, y)):
					result.append(Vector2i(x, y))
	return result


## Средняя яркость в центрах клеток (без домов на них — у участка берётся край).
func _mean_at(image: Image, scale: Vector2, cells: Array[Vector2i]) -> float:
	var stage: RitualStage3D = _panel.board.stage
	var total: float = 0.0
	var count: int = 0
	for cell: Vector2i in cells:
		if _panel.trial.field.get_tower_at(cell) != null:
			continue
		var at: Vector2 = stage.project_milli(Vector2(cell) * 1000.0 + Vector2(500, 500)) * scale
		if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
			continue
		total += _luma(image.get_pixelv(Vector2i(at)))
		count += 1
	return total / maxi(1, count)
