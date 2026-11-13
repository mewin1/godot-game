extends SceneTree
## Развилки записи "Обряда" (docs/37 P0, приложение E): забег автора до начала ночи N, снимок,
## от снимка - варианты (без группы построек, с даром, без реакций), ночь без команд игрока.
## godot --headless --path . -s res://tools/ritual_whatif.gd -- res://.godot/ritual/FILE.json --night=14
##     [--hero=1] [--rules=res://...tres]
## Одна развилка - ориентир: исход ночи скачет от мелочей (docs/37 F9), сравнивать по многим.

var _damage: int = 0


func _initialize() -> void:
	var path: String = ""
	var night: int = 0
	var hero: int = -1
	var rules_path: String = "res://data/ritual/endless.tres"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--night="):
			night = argument.trim_prefix("--night=").to_int()
		elif argument.begins_with("--hero="):
			hero = argument.trim_prefix("--hero=").to_int()
		elif argument.begins_with("--rules="):
			rules_path = argument.trim_prefix("--rules=")
		else:
			path = argument
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or night < 1:
		printerr("Укажите запись attempt_*.json и --night=N после --")
		quit(1)
		return
	var report: Dictionary = parsed
	var settings: RitualTrialConfig = load(rules_path) as RitualTrialConfig
	var start: int = settings.nights.night_start(night) - 1
	var trial: RitualTrial = RitualTrialRecord.replay(report, settings, start, hero)
	if trial == null or trial.tick_count != start:
		printerr("Повтор не дошел до ночи %d (другие правила - см. --rules)" % night)
		quit(1)
		return
	var snapshot: Dictionary = trial.snapshot()
	print("Ночь %d: HP %d, золото %d, построек %d. Ночь без команд игрока и новых даров:" % [night, trial.hp, trial.gold,
		trial.field.towers.size()])
	_play(settings, snapshot, night, "как в записи", Callable())
	var kinds: Dictionary[StringName, int] = {}
	for tower: TowerState in trial.field.towers:
		kinds[tower.data.id] = kinds.get(tower.data.id, 0) + 1
	for kind: StringName in kinds:
		_play(settings, snapshot, night, "без %s ×%d" % [kind, kinds[kind]], _remove_kind.bind(kind))
	for index: int in settings.gifts.size():
		if not trial.gifts_taken.has(index):
			_play(settings, snapshot, night, "+ дар %s" % settings.gifts[index].display_name,
				_give_gift.bind(index))
	var reactions: Array[ReactionData] = settings.combat.reactions.duplicate()
	settings.combat.reactions.clear()
	# Правила меняются только после from_snapshot (он сверяет rules_hash) и сразу возвращаются.
	_play(settings, snapshot, night, "без реакций", Callable(), false)
	settings.combat.reactions.assign(reactions)
	quit()


## Ночь от снимка с изменением change(trial); HP, урон, реакции и кто остался.
func _play(settings: RitualTrialConfig, snapshot: Dictionary, night: int, title: String, change: Callable,
		check_rules: bool = true) -> void:
	var trial: RitualTrial = RitualTrial.from_snapshot(settings, snapshot) if check_rules \
			else _restore_without_check(settings, snapshot)
	if trial == null:
		print("  %-28s снимок не восстановился" % title)
		return
	if change.is_valid():
		change.call(trial)
	_damage = 0
	trial.field.hit_observed.connect(_on_hit)
	var hp: int = trial.hp
	var reactions: int = _reaction_total(trial)
	var dawn: int = settings.nights.night_end(night)
	advance_without_gifts(trial, dawn)
	print("  %-28s HP %3d -> %3d, урон %7d, реакций %5d%s" % [title, hp, trial.hp, _damage,
		_reaction_total(trial) - reactions,
		", пал: живых %d" % trial.field.count_alive_mobs() if trial.phase == RitualTrial.Phase.OVER else ""])


## Новый дар после убийства босса не меняет сравниваемый вариант и не останавливает стенд.
static func advance_without_gifts(trial: RitualTrial, until_tick: int) -> void:
	while trial.phase == RitualTrial.Phase.RUNNING and trial.tick_count < until_tick:
		trial.gift_choice.clear()
		trial.tick()


## Снимок под измененные правила: хеш правил уже другой, поэтому сверка подменяется.
func _restore_without_check(settings: RitualTrialConfig, snapshot: Dictionary) -> RitualTrial:
	var patched: Dictionary = snapshot.duplicate()
	patched["rules_hash"] = RitualTrial.new(settings, -1).rules_hash
	return RitualTrial.from_snapshot(settings, patched)


func _remove_kind(trial: RitualTrial, kind: StringName) -> void:
	for tower: TowerState in trial.field.towers.duplicate():
		if tower.data.id == kind:
			trial.field.remove_tower(tower)
	trial.field.mark_towers_changed()


func _give_gift(trial: RitualTrial, index: int) -> void:
	trial.gift_choice.assign([index])
	trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, index))


func _reaction_total(trial: RitualTrial) -> int:
	var total: int = 0
	for kind: StringName in trial.field.reaction_counts:
		total += trial.field.reaction_counts[kind]
	return total


func _on_hit(details: Dictionary) -> void:
	_damage += RitualStateCodec.integer(details.get("hp_damage")) + RitualStateCodec.integer(details.get("ward_damage"))
