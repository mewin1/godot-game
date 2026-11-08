class_name RitualStateCodec
extends RefCounted
## Снимок только значений скрипта; ресурсы/ноды/скрипты не сериализуются.

static func capture(source: Object) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	for info: Dictionary in source.get_property_list():
		if (integer(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: String = str(info["name"])
		var value: Variant = source.get(key)
		if typeof(value) in [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME,
				TYPE_VECTOR2I, TYPE_ARRAY, TYPE_DICTIONARY]:
			result[key] = clone_value(value)
	return result


static func apply(target: Object, values: Dictionary) -> void:
	# Не разрешаем записи script/data и других свойств-объектов из файла.
	for info: Dictionary in target.get_property_list():
		var key: String = str(info["name"])
		if not values.has(key) or (integer(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if integer(info["type"]) in [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME,
				TYPE_VECTOR2I, TYPE_ARRAY, TYPE_DICTIONARY]:
			var value: Variant = values[key]
			target.set(key, clone_value(value))


static func hash_value(hasher: StateHasher, value: Variant) -> void:
	hasher.add(typeof(value))
	if value is Dictionary:
		var data: Dictionary = dictionary(value)
		var keys: Array = data.keys()
		keys.sort()
		hasher.add(keys.size())
		for key: Variant in keys:
			hash_value(hasher, key)
			hash_value(hasher, data[key])
	elif value is Array:
		var elements: Array = array(value)
		hasher.add(elements.size())
		for element: Variant in elements:
			hash_value(hasher, element)
	elif value is Vector2i:
		hasher.add_many([value.x, value.y])
	elif value is int or value is bool:
		hasher.add(integer(value) if value is int else int(boolean(value)))
	else:
		hasher.add_string(str(value))


static func integer(value: Variant, fallback: int = 0) -> int:
	return value if value is int else fallback


static func boolean(value: Variant) -> bool:
	return value if value is bool else false


static func text(value: Variant) -> String:
	return value if value is String else ""


static func dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func array(value: Variant) -> Array:
	return value if value is Array else []


static func clone_value(value: Variant) -> Variant:
	if value is Array:
		return array(value).duplicate(true)
	if value is Dictionary:
		return dictionary(value).duplicate(true)
	return value


static func rules_state(source: Resource) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	for info: Dictionary in source.get_property_list():
		if (integer(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: String = str(info["name"])
		result[key] = _rule_value(source.get(key))
	return result


static func _rule_value(value: Variant) -> Variant:
	if value is Resource:
		return rules_state(resource(value))
	if value is Array:
		var result: Array[Variant] = []
		for element: Variant in array(value):
			result.append(_rule_value(element))
		return result
	if typeof(value) in [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME,
			TYPE_VECTOR2I, TYPE_RECT2I]:
		return value
	# Цвет/размер картинки не являются числами симуляции.
	return null


static func resource(value: Variant) -> Resource:
	return value if value is Resource else null
