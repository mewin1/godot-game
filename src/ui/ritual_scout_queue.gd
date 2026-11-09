class_name RitualScoutQueue
extends VBoxContainer
## Очередь разведки (docs/34 §9, плейтест 9 ноября): вся ближайшая ночь. Карточка пачки — все виды
## врагов со счётом, ведущий первым; состав подробно — подсказкой. Босс дальше ближайшей ночи —
## отдельной строкой. Без новой графики: спрайты мобов и иконки богов GodSymbols.

const ICON_SIZE: Vector2 = Vector2(26, 26)
const BOSS_FRAME: Color = Color("d46c50")
const NEW_FRAME: Color = Color("e0b45a")
const PLAIN_FRAME: Color = Color("4b5a63")
const RESIST_FRAME: Color = Color("e04848")
const MOB_VISUALS: String = "res://data/visuals/mobs/%s.tres"

var _key: String = ""
var _cards: Array[Control] = []
var _packs: Array[RitualPack] = []
var _tips: PackedStringArray = []
var _title: Label
var _warning: Label
var _flow: HFlowContainer


func _init() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	_title = _small_label(header, 16)
	_warning = _small_label(header, 15)
	_warning.add_theme_color_override("font_color", Color("ffab65"))
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 4)
	_flow.add_theme_constant_override("v_separation", 4)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)


func refresh(trial: RitualTrial) -> void:
	var queue: Array[RitualPack] = trial.night_queue()
	var night: int = trial.current_night()
	var at_night: bool = trial.settings.is_night(trial.tick_count)
	_title.text = "Ночь %d · %s: %d" % [night, "осталось пачек" if at_night else "пачек", queue.size()]
	var boss: RitualPack = trial.boss_warning()
	_warning.text = "" if boss == null else "  · Босс в ночь %d%s" % [boss.night,
		"" if boss.resist == &"" else ", неуязвим: " + GodSymbols.get_power_name(boss.resist)]
	var key: String = str(night)
	for pack: RitualPack in queue:
		key += ";%d" % pack.at_tick
	if key != _key:
		_key = key
		_rebuild(trial, queue)
	# Подсказку меняем, только когда меняется текст (время прихода), а не каждый кадр.
	for index: int in _cards.size():
		var tip: String = describe(trial, _packs[index])
		if tip != _tips[index]:
			_tips[index] = tip
			_cards[index].tooltip_text = tip


## Текст подсказки: кто ведёт, кто с ним, обереги, неуязвимость, когда придёт.
static func describe(trial: RitualTrial, pack: RitualPack) -> String:
	var settings: RitualTrialConfig = trial.settings
	var lines: PackedStringArray = []
	var leader: MobData = settings.enemies[pack.leader]
	lines.append(("БОСС: " if pack.boss else "Ведёт: ") + leader.display_name)
	var counts: Dictionary[int, int] = {}
	var order: Array[int] = []
	var wards: int = 0
	for member: int in pack.members:
		if not counts.has(member):
			order.append(member)
		counts[member] = counts.get(member, 0) + 1
		if settings.enemies[member].tags.has(settings.ward_tag):
			wards += 1
	var parts: PackedStringArray = []
	for member: int in order:
		parts.append("%s ×%d" % [settings.enemies[member].display_name, counts[member]])
	lines.append("Состав (%d): %s" % [pack.members.size(), ", ".join(parts)])
	if pack.hp_percent != 100:
		lines.append("Здоровье: %d%% от обычного" % pack.hp_percent)
	if wards > 0:
		lines.append("Обереги: %d (сбивает огонь)" % wards)
	if pack.resist != &"":
		lines.append("Неуязвим к стихии: %s" % GodSymbols.get_power_name(pack.resist))
	var fresh: Array[int] = trial.plan().new_types(pack)
	if not fresh.is_empty():
		var names: PackedStringArray = []
		for member: int in fresh:
			names.append(settings.enemies[member].display_name)
		lines.append("Впервые: " + ", ".join(names))
	lines.append(_eta(trial, pack))
	return "\n".join(lines)


static func _eta(trial: RitualTrial, pack: RitualPack) -> String:
	var seconds: int = maxi(0, pack.at_tick - trial.tick_count) / trial.settings.combat.ticks_per_second
	var when: String = "через %d:%02d" % [seconds / 60, seconds % 60]
	if pack.night != trial.current_night() or not trial.settings.is_night(trial.tick_count):
		return "Придёт в ночь %d, %s" % [pack.night, when]
	return "Придёт %s" % when


func _rebuild(trial: RitualTrial, queue: Array[RitualPack]) -> void:
	for card: Control in _cards:
		card.queue_free()
	_cards.clear()
	_tips.clear()
	_packs = queue
	for pack: RitualPack in queue:
		var card: Control = _card(trial, pack)
		_flow.add_child(card)
		_cards.append(card)
		_tips.append("")


## Карточка пачки: все виды врагов со счётом (ведущий первым), рамка босса/новой угрозы.
func _card(trial: RitualTrial, pack: RitualPack) -> Control:
	var frame: Color = BOSS_FRAME if pack.boss else NEW_FRAME if trial.plan().is_important(pack) else PLAIN_FRAME
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.11, 0.85)
	style.border_color = frame
	style.set_border_width_all(3 if pack.boss else 2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(3)
	card.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	for kind: Vector2i in kinds(pack):
		var icon: TextureRect = TextureRect.new()
		icon.texture = _icon(trial.settings.enemies[kind.x])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var count: Label = _small_label(row, 13)
		count.text = "×%d" % kind.y
	if pack.resist != &"":
		row.add_child(_resist_badge(pack.resist))
	return card


## Виды врагов пачки: x — индекс врага, y — сколько; ведущий первым, дальше по убыванию числа.
static func kinds(pack: RitualPack) -> Array[Vector2i]:
	var counts: Dictionary[int, int] = {}
	for member: int in pack.members:
		counts[member] = counts.get(member, 0) + 1
	var result: Array[Vector2i] = []
	for member: int in counts:
		result.append(Vector2i(member, counts[member]))
	var leader: int = pack.leader
	result.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		if (first.x == leader) != (second.x == leader):
			return first.x == leader
		return first.y > second.y or (first.y == second.y and first.x < second.x))
	return result


func _small_label(parent: Node, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Значок неуязвимости: иконка стихии в красной рамке, в углу карточки.
func _resist_badge(god: StringName) -> Control:
	var badge: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.03, 0.03, 0.9)
	style.border_color = RESIST_FRAME
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	badge.add_theme_stylebox_override("panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var symbol: TextureRect = TextureRect.new()
	symbol.texture = GodSymbols.get_icon(god)
	symbol.modulate = GodSymbols.get_color(god)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.custom_minimum_size = Vector2(16, 16)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(symbol)
	return badge


## Иконка врага: спрайт роли его модели-заглушки (нежить пока на моделях прежних врагов).
## Спрайт читается прямо из data/visuals/mobs: обращение к VisualCatalog отсюда оставляло
## утечку ресурсов при выходе (проверено smoke-прогоном «Обряда»).
func _icon(mob: MobData) -> Texture2D:
	var kind: StringName = RitualStage3D.UNIT_IDS.get(mob.id, &"basic")
	var visual: Resource = load(MOB_VISUALS % kind)
	var texture: Variant = visual.get(&"texture") if visual != null else null
	return texture if texture is Texture2D else null
