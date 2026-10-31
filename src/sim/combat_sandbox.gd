class_name CombatSandbox
extends RefCounted
## Свободный эксперимент с настоящим FieldState, отдельными RNG и ресурсами матча.

const SEED: int = 713
const JOURNAL_SIZE: int = 10

var config: GameConfig
var field: FieldState
var journal: PackedStringArray = []
var _towers: Array[TowerState] = []
var _mobs: Array[MobState] = []


func _init(game_config: GameConfig) -> void:
	config = game_config
	_rebuild()


## Единственная точка ввода: установка, цели, ручной удар и управление временем.
func execute(command: SandboxCommand) -> String:
	match command.action:
		SandboxCommand.Action.TOWER:
			if command.tower == null or not field.can_place_tower_data(
					command.tower, command.cell, command.rotation):
				return "Фигура не помещается: выберите свободные клетки вне дороги"
			var tower: TowerState = field.add_tower(command.tower, command.cell, command.rotation)
			tower.level = clampi(command.level, 1, config.max_tower_level)
			tower.enchantment = command.enchantment
			tower.awakening = command.awakening
			_towers.append(_copy_tower(tower))
			field.battle_report.register_tower(tower)
		SandboxCommand.Action.MOB:
			if command.mob == null:
				return "Выберите юнита"
			var mob: MobState = MobState.create(command.mob)
			if command.hp > 0:
				mob.max_hp = command.hp
				mob.hp = command.hp
			if command.stationary:
				mob.speed = 0
			mob.progress = clampi(command.progress, 0, field.get_path_end_progress() - 1)
			_mobs.append(_copy_mob(mob))
			_spawn(mob)
		SandboxCommand.Action.REMOVE:
			var tower: TowerState = field.get_tower(command.tower_id)
			if tower == null:
				return "Выберите башню для удаления"
			for index: int in range(_towers.size() - 1, -1, -1):
				if _towers[index].anchor == tower.anchor:
					_towers.remove_at(index)
			field.remove_tower(tower)
		SandboxCommand.Action.STRIKE:
			var tower: TowerState = field.get_tower(command.tower_id)
			var mob: MobState = find_mob(command.mob_id)
			if tower == null or mob == null or not mob.is_alive():
				return "Выберите башню и живую цель"
			if not tower.data.attacks:
				return "Ветер работает при ходе времени; ручного выстрела у него нет"
			field.refresh_bonuses()
			field._shoot(tower, mob)
		SandboxCommand.Action.STEP:
			for index: int in maxi(0, command.ticks):
				field.tick(command.automatic_fire)
		SandboxCommand.Action.RESET:
			_rebuild()
		SandboxCommand.Action.CLEAR:
			_towers.clear()
			_mobs.clear()
			_rebuild()
	return ""


## Цель можно осмотреть по id и после одиночного смертельного удара, до следующего тика.
func find_mob(id: int) -> MobState:
	for mob: MobState in field.mobs:
		if mob.id == id:
			return mob
	return null


func _rebuild() -> void:
	field = FieldState.new(config, config.max_shop_level, SEED)
	journal.clear()
	field.damage_recorded.connect(_on_damage)
	field.effect_played.connect(_on_effect)
	field.curse_transferred.connect(_on_curse_transferred)
	for saved: TowerState in _towers:
		var tower: TowerState = field.add_tower(saved.data, saved.anchor, saved.rotation)
		tower.level = saved.level
		tower.enchantment = saved.enchantment
		tower.awakening = saved.awakening
	field.start_wave()
	for saved: MobState in _mobs:
		_spawn(_copy_mob(saved))


func _spawn(mob: MobState) -> void:
	var progress: int = mob.progress
	field.schedule_spawn(mob, field.wave_tick)
	field._spawn_due_mobs()
	mob.progress = progress
	mob.previous_progress = progress
	mob.visual_start_progress = progress


func _copy_tower(source: TowerState) -> TowerState:
	var tower: TowerState = TowerState.new()
	tower.data = source.data
	tower.anchor = source.anchor
	tower.rotation = source.rotation
	tower.level = source.level
	tower.enchantment = source.enchantment
	tower.awakening = source.awakening
	return tower


func _copy_mob(source: MobState) -> MobState:
	var mob: MobState = MobState.create(source.data)
	mob.hp = source.max_hp
	mob.max_hp = source.max_hp
	mob.speed = source.speed
	mob.progress = source.progress
	return mob


func _on_damage(mob: MobState, actual: int, tower_id: int, kind: StringName) -> void:
	var names: Dictionary[StringName, String] = {&"hit": "удар", &"chain": "цепь",
			&"burn": "горение", &"curse": "проклятие", &"other": "прочее"}
	var source: String = " · башня #%d" % tower_id if tower_id > 0 else ""
	_note("#%d −%d HP → %d · %s%s" % [mob.id, actual,
			maxi(0, mob.hp), names.get(kind, String(kind)), source])


func _on_effect(effect: StringName, mob: MobState) -> void:
	var title: String = String(effect)
	for rule: ReactionData in config.reactions:
		if rule.id == effect:
			title = rule.display_name
	if effect == &"curse_burst":
		title = "Взрыв проклятия"
	if effect == &"infection":
		return
	_note("#%d · %s" % [mob.id, title])


func _on_curse_transferred(source: MobState, target: MobState) -> void:
	_note("Перенос проклятия #%d → #%d · сила %d" % [
			source.id, target.id, target.curse_damage])


func _note(message: String) -> void:
	journal.append("тик %d · %s" % [field.wave_tick, message])
	if journal.size() > JOURNAL_SIZE:
		journal.remove_at(0)
