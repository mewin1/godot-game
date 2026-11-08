class_name ScenePaths
extends RefCounted
## Пути к сценам верхнего уровня — в одном месте, чтобы не опечататься.

const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const HOW_TO_PLAY: String = "res://scenes/how_to_play.tscn"
const MATCH: String = "res://scenes/match.tscn"
const REACTION_LAB: String = "res://scenes/reaction_lab.tscn"
const COMBAT_SANDBOX: String = "res://scenes/combat_sandbox.tscn"
const SIEGE_TRIAL: String = "res://scenes/siege_trial.tscn"
const RITUAL_TRIAL: String = "res://scenes/ritual_trial.tscn"
const HEROES: String = "res://scenes/heroes_gallery.tscn"
const VISUAL_SLICE: String = "res://scenes/visual_slice.tscn"
const SETTINGS: String = "res://scenes/settings.tscn"
const LOADING: String = "res://scenes/loading_screen.tscn"
## Сцены с 3D-ареной открываются через экран загрузки (модели читаются заранее).
const VIA_LOADING: PackedStringArray = [MATCH, SIEGE_TRIAL, RITUAL_TRIAL]


## Параметр следующего перехода из меню в матч.
static var requested_teams: int = 0
## Куда идти экрану загрузки.
static var loading_target: String = ""


## Переход на другую сцену с проверкой ошибки.
static func go_to(tree: SceneTree, path: String) -> void:
	if VIA_LOADING.has(path):
		loading_target = path
		path = LOADING
	var error: Error = tree.change_scene_to_file(path)
	if error != OK:
		push_error("Не удалось открыть сцену %s: %s" % [path, error_string(error)])
