extends SceneTree
## Делает скриншот сцены и выходит. Нужен, чтобы проверять визуал без редактора.
## Запуск: godot --path . -s res://tools/screenshot.gd -- --scene=res://scenes/main.tscn --out=/путь/к/файлу.png
## Необязательно: --frames=N (сколько кадров подождать перед снимком, по умолчанию 10).

const DEFAULT_FRAMES: int = 10


func _initialize() -> void:
	var args: Dictionary[String, String] = _parse_args()
	var scene_path: String = args.get("scene", "res://scenes/main.tscn")
	var out_path: String = args.get("out", "user://screenshot.png")
	var frames_text: String = args.get("frames", str(DEFAULT_FRAMES))
	var frames: int = frames_text.to_int()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Не удалось загрузить сцену: %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	_capture_later(out_path, frames)


func _capture_later(out_path: String, frames: int) -> void:
	for i: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(out_path)
	if error != OK:
		push_error("Не удалось сохранить скриншот: %s" % out_path)
	quit(0 if error == OK else 1)


func _parse_args() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
