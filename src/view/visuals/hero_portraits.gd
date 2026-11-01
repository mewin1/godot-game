class_name HeroPortraits
extends RefCounted
## Портреты героев из атласа; прежние SVG остаются для исторического контента.

const PATH_FORMAT: String = "res://data/visuals/portraits/%s.tres"

static var _cache: Dictionary[StringName, Texture2D] = {}


## Портрет героя (null — героя нет или картинки нет).
static func get_portrait(hero: HeroData) -> Texture2D:
	if hero == null:
		return null
	if not _cache.has(hero.id):
		var path: String = PATH_FORMAT % hero.id
		if not ResourceLoader.exists(path):
			path = "res://assets/heroes/%s.svg" % hero.id
		_cache[hero.id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[hero.id]
