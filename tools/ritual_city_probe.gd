extends SceneTree
## Кадры карты «Городища» по уровням города 1-4: дома на всех участках, ночь со врагами на открытых
## дорогах (пропорции дом/враг, плотность, весь город в кадре над доком), плюс день 4-го уровня.
## godot --path . --screen 1 -s res://tools/ritual_city_probe.gd [-- --out=docs/reports/<папка>/ --size=1920x1080]

var _panel: RitualTrialPanel
var _out: String = "res://docs/reports/2026-11-15_city/"
var _size: Vector2i = Vector2i(1920, 1080)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = "res://" + argument.trim_prefix("--out=").trim_prefix("res://")
		elif argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").split("x")
			_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.mode = Window.MODE_WINDOWED
	# Без рамки и без изменения размера: тайловый менеджер не ужмёт окно (critique_2).
	root.borderless = true
	root.unresizable = true
	root.size = _size
	_panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(_panel)
	await process_frame
	_panel._pick_hero(0)
	var trial: RitualTrial = _panel.trial
	trial.hp = 1000000
	trial.gold = 1000000
	var suffix: String = "" if _size == Vector2i(1920, 1080) else "_%dx%d" % [_size.x, _size.y]
	var nights: RitualNightRules = _panel.settings.nights
	for level: int in range(1, 5):
		if level > 1:
			trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
		_fill_plots(trial)
		# Ночь после покупки уровня: враги идут со всех открытых входов.
		var night: int = 1
		while nights.night_start(night) <= trial.tick_count:
			night += 1
		_advance(trial, nights.night_start(night) + 450)
		await _shot("city_%d_night%s" % [level, suffix])
	var last: int = 1
	while nights.night_start(last + 1) <= trial.tick_count:
		last += 1
	_advance(trial, nights.night_end(last) + 220)
	await _shot("city_4_day%s" % suffix)
	quit()


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


func _shot(title: String) -> void:
	_panel._paused = true
	for frame: int in 40:
		_panel._process(1.0 / 60.0)
		await process_frame
	_panel._toast.visible = false
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(_out + title + ".jpg"), 0.85)
	print("CITY: ", title)
