class_name RitualRunStats
extends RefCounted
## Итоги забега для экрана поражения (docs/37 UI-14): на что ушло золото, кто сколько урона нанёс,
## кто прорвался и какая реакция была самой частой. Только наблюдение: в симуляцию не пишет.

const SPEND_ORDER: Array[String] = ["Постройки", "Улучшения", "Город", "Заговоры", "Ремонт и лечение"]

var spend: Dictionary[String, int] = {}
## Урон по типам домов: id постройки → урон по здоровью и оберегу.
var damage: Dictionary[StringName, int] = {}
var _names: Dictionary[StringName, String] = {}
## Поле забега слабой ссылкой: поле держит подписку на add_hit, сильная ссылка дала бы кольцо.
var _field: WeakRef


func watch(field: RitualField) -> void:
	_field = weakref(field)
	field.hit_observed.connect(add_hit)


## Сколько золота ушло на команду (разница до и после успешного приказа).
func add_spend(action: RitualCommand.Action, amount: int) -> void:
	if amount <= 0:
		return
	var category: String = ""
	match action:
		RitualCommand.Action.BUY:
			category = "Постройки"
		RitualCommand.Action.UPGRADE, RitualCommand.Action.SPECIALISE:
			category = "Улучшения"
		RitualCommand.Action.STREET:
			category = "Город"
		RitualCommand.Action.RITE:
			category = "Заговоры"
		RitualCommand.Action.REPAIR, RitualCommand.Action.REPAIR_HOUSE:
			category = "Ремонт и лечение"
		_:
			category = "Прочее"
	spend[category] = spend.get(category, 0) + amount


## Попадание из RitualField.hit_observed: урон записывается типу дома, который ударил.
func add_hit(details: Dictionary) -> void:
	if _field == null:
		return
	var held: Variant = _field.get_ref()
	if not held is RitualField:
		return
	var field: RitualField = held
	var tower: TowerState = field.get_tower(RitualStateCodec.integer(details.get("tower", 0)))
	if tower == null:
		return
	var amount: int = RitualStateCodec.integer(details.get("hp_damage", 0)) \
			+ RitualStateCodec.integer(details.get("ward_damage", 0))
	damage[tower.data.id] = damage.get(tower.data.id, 0) + amount
	_names[tower.data.id] = tower.data.display_name


## Строки «имя — доля урона» по убыванию, не больше count.
func top_damage(count: int) -> PackedStringArray:
	var total: int = 0
	for id: StringName in damage:
		total += damage[id]
	var ids: Array[StringName] = damage.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return damage[a] > damage[b])
	var lines: PackedStringArray = []
	for id: StringName in ids.slice(0, count):
		lines.append("%s — %d%%" % [_names.get(id, String(id)), damage[id] * 100 / maxi(1, total)])
	return lines


func spend_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var total: int = 0
	for category: String in spend:
		total += spend[category]
	for category: String in SPEND_ORDER + ["Прочее"]:
		if spend.get(category, 0) > 0:
			lines.append("%s — %d (%d%%)" % [category, spend[category], spend[category] * 100 / maxi(1, total)])
	return lines


## Прорывы по видам врагов из журнала забега.
static func leak_lines(trial: RitualTrial) -> PackedStringArray:
	var counts: Dictionary[String, int] = {}
	for record: Dictionary in trial.journal:
		if str(record.get("event", "")) == "breach":
			var kind: String = str(record.get("kind", ""))
			counts[kind] = counts.get(kind, 0) + 1
	var names: Dictionary[String, String] = {}
	for enemy: MobData in trial.settings.enemies:
		names[String(enemy.id)] = enemy.display_name
	var kinds: Array[String] = counts.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var lines: PackedStringArray = []
	for kind: String in kinds.slice(0, 4):
		lines.append("%s ×%d" % [names.get(kind, kind), counts[kind]])
	return lines


## Самая частая реакция за забег («Цепь ×340») или пусто.
static func best_reaction(trial: RitualTrial) -> String:
	var best: StringName = &""
	for id: StringName in trial.field.reaction_counts:
		if best == &"" or trial.field.reaction_counts[id] > trial.field.reaction_counts[best]:
			best = id
	if best == &"":
		return ""
	var title: String = String(best)
	for reaction: ReactionData in trial.settings.combat.reactions:
		if reaction.id == best:
			title = reaction.display_name
	return "%s ×%d" % [title, trial.field.reaction_counts[best]]
