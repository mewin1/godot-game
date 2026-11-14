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
		# StringName в sort() сравниваются по адресу в памяти: порядок зависел бы от процесса.
		keys.sort_custom(_key_before)
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


static func _key_before(first: Variant, second: Variant) -> bool:
	if typeof(first) != typeof(second):
		return typeof(first) < typeof(second)
	if first is int:
		return integer(first) < integer(second)
	return str(first) < str(second)


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
		# Отключенная модель участков не меняет отпечаток старого опыта и его записей.
		if source is RitualTrialConfig and key in ["ward_lightning_percent", "ward_other_percent"] \
				and integer(source.get(key)) == 0:
			continue
		if source is RitualNightRules:
			var nights: RitualNightRules = source as RitualNightRules
			if nights.pressure_base <= 0 and key in ["pressure_base", "pressure_growth_percent",
					"boss_night_percent", "bounty_percent", "elite_multiplier"]:
				continue
			if nights.pressure_base > 0 and key == "hp_growth_percent":
				continue
		# Вехи идолов и проулки-срезки (docs/37 IDL-4, ALY-1): пустые списки не меняют отпечаток
		# прежних правил; новые поля уровня города тоже, пока не заданы.
		if source is RitualTrialConfig and key in ["idol_milestones", "alleys"] \
				and array(source.get(key)).is_empty():
			continue
		# Перезарядки реакций (docs/37 RX-1..3, RX-9): нули не меняют отпечаток прежних правил.
		if ((source is ReactionData and key in ["cooldown_ticks", "pay_out_consumed"])
				or (source is GameConfig and key == "reaction_gate_ticks")
				or (source is TowerData and key == "status_apply_cooldown_ticks")) \
				and str(source.get(key)) in ["0", "false"]:
			continue
		# Рассвет и припасы (docs/37 D4, ECO-3, SUP-2, BOS-2, HER-3): нули не меняют прежний отпечаток.
		if ((source is RitualTrialConfig and key in ["gift_relevance", "boons", "boon_choices",
					"clean_night_gold", "clean_night_gold_per_night", "supply_costs"])
				or (source is RitualHeroData and key == "cap_growth_percent")) \
				and str(source.get(key)) in ["0", "false", "[]"]:
			continue
		if source is RitualStreetData and key in ["summary", "hero_hp", "extra_idol"] \
				and (source.get(key) == null or str(source.get(key)) in ["", "0", "false"]):
			continue
		if source is RitualTrialConfig and not (source as RitualTrialConfig).uses_plots() \
				and key in ["plots", "upgrade_cost_percent", "upgrade_city_levels",
					"plot_sell_percent", "sell_undo_ticks", "plot_support_radius_milli"]:
			continue
		if source is RitualBuildingLevels and (source as RitualBuildingLevels).branches.is_empty() \
				and (source as RitualBuildingLevels).role.is_empty() and key in ["branches", "role"]:
			continue
		if source is RitualLevelBehavior and key in ["wind_power_bonus", "wind_length_bonus_milli",
				"wind_width_bonus_milli"] and integer(source.get(key)) == 0:
			continue
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
