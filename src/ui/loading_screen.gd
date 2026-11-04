class_name LoadingScreen
extends Control
## Короткий экран перед 3D-матчем: в фоновых потоках читает сцену матча и все модели «нуара»,
## чтобы постройки и юниты появлялись без подвисания. Куда идти — ScenePaths.loading_target.

@onready var _bar: ProgressBar = %Bar

var _target: String = ""
var _pending: PackedStringArray = []
var _total: int = 0
var _target_ready: bool = false


func _ready() -> void:
	_target = ScenePaths.loading_target
	if _target.is_empty():
		push_error("Экран загрузки открыт без цели")
		_target = ScenePaths.MAIN_MENU
	_request(_target)
	for path: String in NoirModels.all_paths():
		if not NoirModels.is_cached(path):
			_request(path)
	_total = _pending.size()


func _process(_delta: float) -> void:
	var progress: Array = []
	var loaded: float = _total - _pending.size()
	var remaining: PackedStringArray = []
	for path: String in _pending:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var part: float = progress[0]
			loaded += part
			remaining.append(path)
		elif status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("Не удалось прочитать %s" % path)
		elif path == _target:
			_target_ready = true
		else:
			loaded += 1.0
			NoirModels.remember(path, ResourceLoader.load_threaded_get(path) as PackedScene)
	_pending = remaining
	_bar.value = loaded / maxf(_total, 1.0)
	if _pending.is_empty():
		_finish()


func _request(path: String) -> void:
	var error: Error = ResourceLoader.load_threaded_request(path, "", true)
	if error != OK:
		push_error("Не удалось начать чтение %s: %s" % [path, error_string(error)])
		return
	_pending.append(path)


## Всё дочитано: в цель (или назад в меню, если сцена цели не прочиталась).
func _finish() -> void:
	set_process(false)
	ScenePaths.loading_target = ""
	if not _target_ready:
		get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(_target) as PackedScene
	var error: Error = get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("Не удалось открыть сцену %s: %s" % [_target, error_string(error)])
