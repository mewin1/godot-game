class_name VisualCatalog
extends Resource
## Все визуальные описания игры: башни и мобы по id, стиль поля.
## Загружается один раз (get_default) и дальше берётся из памяти.

const DEFAULT_PATH: String = "res://data/visuals/visual_catalog.tres"

static var _default: VisualCatalog

@export var towers: Array[TowerVisual] = []
@export var mobs: Array[MobVisual] = []
@export var field: FieldStyle

var _towers_by_id: Dictionary[StringName, TowerVisual] = {}
var _mobs_by_id: Dictionary[StringName, MobVisual] = {}


static func get_default() -> VisualCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as VisualCatalog
		assert(_default != null, "Нет каталога графики: " + DEFAULT_PATH)
	return _default


## Внешний вид башни по id. Если описания нет — первое попавшееся (и ошибка в лог).
func get_tower(tower_id: StringName) -> TowerVisual:
	if _towers_by_id.is_empty():
		for visual: TowerVisual in towers:
			_towers_by_id[visual.tower_id] = visual
	if not _towers_by_id.has(tower_id):
		push_error("Нет графики для башни %s" % tower_id)
		return towers[0]
	return _towers_by_id[tower_id]


func get_mob(mob_id: StringName) -> MobVisual:
	if _mobs_by_id.is_empty():
		for visual: MobVisual in mobs:
			_mobs_by_id[visual.mob_id] = visual
	if not _mobs_by_id.has(mob_id):
		push_error("Нет графики для моба %s" % mob_id)
		return mobs[0]
	return _mobs_by_id[mob_id]
