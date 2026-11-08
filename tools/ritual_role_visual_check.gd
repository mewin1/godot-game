extends SceneTree
## Регрессия различимости: свежие ратник/бегун/тяжёлый в одной точке должны отличаться.

const SETTINGS: RitualTrialConfig = preload("res://data/ritual/trial.tres")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	var stage: String = "after"
	if OS.get_cmdline_user_args().has("before"):
		stage = "before"
	var directory: String = "res://.godot/ritual/roles_" + stage
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	assert(error == OK)
	var board: RitualBoard = RitualBoard.new()
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hashes: PackedStringArray = []
	for index: int in [0, 1, 2]:
		var trial: RitualTrial = RitualTrial.new(SETTINGS, 3)
		var mob: RitualMob = trial.field.spawn_mob(index)
		mob.progress = 8000
		board.trial = trial
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		var center: Vector2i = Vector2i(board._point(trial.field.get_mob_position(mob)))
		var patch: Image = picture.get_region(Rect2i(center - Vector2i(40, 40), Vector2i(80, 80)))
		var digest: HashingContext = HashingContext.new()
		error = digest.start(HashingContext.HASH_SHA256)
		assert(error == OK)
		error = digest.update(patch.get_data())
		assert(error == OK)
		hashes.append(digest.finish().hex_encode())
		error = patch.save_png(directory + "/%s.png" % mob.data.id)
		assert(error == OK)
	var different: bool = hashes[0] != hashes[1] and hashes[0] != hashes[2] and hashes[1] != hashes[2]
	var file: FileAccess = FileAccess.open(directory + "/hashes.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"roles": ["ratnik", "runner", "heavy"], "hashes": hashes,
		"different": different}, "\t"))
	file.close()
	board.queue_free()
	await process_frame
	if not different:
		push_error("RITUAL ROLES: свежие ратник, бегун и тяжёлый выглядят одинаково")
	else:
		print("RITUAL ROLES: OK — три роли имеют различные маркеры")
	quit(0 if different else 1)
