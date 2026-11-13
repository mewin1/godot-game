extends SceneTree
## Кривая ночей бесконечного "Обряда" (docs/37 §2.3, приложение C): враги, здоровье (с оберегами),
## награда, рост к прошлой ночи, примета. Без боя - только генератор ночей.
## godot --headless --path . -s res://tools/ritual_curve.gd [-- --seeds=915701,1,2 --nights=30 --rules=res://...tres]


func _initialize() -> void:
	var seeds: Array[int] = [915701]
	var nights: int = 30
	var rules_path: String = "res://data/ritual/endless.tres"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seeds.clear()
			for part: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(part.to_int())
		elif argument.begins_with("--nights="):
			nights = argument.trim_prefix("--nights=").to_int()
		elif argument.begins_with("--rules="):
			rules_path = argument.trim_prefix("--rules=")
	var settings: RitualTrialConfig = load(rules_path) as RitualTrialConfig
	for seed_value: int in seeds:
		var plan: RitualNightPlan = RitualNightPlan.new(settings, seed_value)
		print("Сид %d: ночь | врагов | пачек | элиты | здоровье | рост | награда | рост | здоровья на монету | примета" % seed_value)
		var previous_hp: int = 0
		var previous_gold: int = 0
		for night: int in range(1, nights + 1):
			var hp: int = plan.total_ehp(night)
			var gold: int = plan.total_gold(night)
			var mobs: int = 0
			var elites: int = 0
			for pack: RitualPack in plan.packs(night):
				mobs += pack.members.size()
				for rank: int in pack.elite:
					elites += int(rank > 0)
			var omen: RitualOmenData = plan.omen(night)
			print("  %2d | %4d | %2d | %3d | %10d | %s | %5d | %s | %6d | %s" % [night, mobs,
				plan.packs(night).size(), elites, hp, _growth(hp, previous_hp), gold, _growth(gold, previous_gold),
				hp / maxi(1, gold), "босс" if settings.nights.is_boss_night(night) else omen.title if omen != null else ""])
			previous_hp = hp
			previous_gold = gold
	quit()


func _growth(value: int, previous: int) -> String:
	return "  -  " if previous <= 0 else "x%.2f" % (float(value) / previous)
