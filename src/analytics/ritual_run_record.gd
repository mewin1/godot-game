class_name RitualRunRecord
extends RefCounted
## Рекорд бесконечного «Обряда» на этом устройстве (user://). Не часть симуляции.

const PATH: String = "user://ritual_record.cfg"
const SECTION: String = "endless"


static func best(path: String = PATH) -> Dictionary[String, int]:
	var file: ConfigFile = ConfigFile.new()
	var nights: int = 0
	var bosses: int = 0
	if file.load(path) == OK:
		var saved_nights: Variant = file.get_value(SECTION, "nights", 0)
		var saved_bosses: Variant = file.get_value(SECTION, "bosses", 0)
		nights = saved_nights if saved_nights is int else 0
		bosses = saved_bosses if saved_bosses is int else 0
	return {"nights": nights, "bosses": bosses}


## Записывает забег, если он лучше: больше ночей, при равенстве — больше боссов.
## Возвращает true для нового рекорда.
static func submit(nights: int, bosses: int, path: String = PATH) -> bool:
	var previous: Dictionary[String, int] = best(path)
	if nights < previous["nights"] or (nights == previous["nights"] and bosses <= previous["bosses"]):
		return false
	var file: ConfigFile = ConfigFile.new()
	file.set_value(SECTION, "nights", nights)
	file.set_value(SECTION, "bosses", bosses)
	return file.save(path) == OK
