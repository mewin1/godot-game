class_name ScenePaths
extends RefCounted
## Пути к сценам верхнего уровня — в одном месте, чтобы не опечататься.

const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const HOW_TO_PLAY: String = "res://scenes/how_to_play.tscn"
const MATCH: String = "res://scenes/match.tscn"


## Переход на другую сцену с проверкой ошибки.
static func go_to(tree: SceneTree, path: String) -> void:
	var error: Error = tree.change_scene_to_file(path)
	if error != OK:
		push_error("Не удалось открыть сцену %s: %s" % [path, error_string(error)])
