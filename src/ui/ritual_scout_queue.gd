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
const ELITE_CROWN: Texture2D = preload("res://assets/ui/elite_crown.svg")
## Метка входа на карточке, когда входов больше одного: главная дорога, верхняя и нижняя улицы.
const LANE_MARKS: Array[String] = ["→", "↑", "↓"]
const LANE_COLORS: Array[Color] = [Color("f0c27a"), Color("7fd6d0"), Color("c59cf0")]

var _key: String = ""
var _cards: Array[Control] = []
var _packs: Array[RitualPack] = []
var _tips: PackedStringArray = []
## Шапка полосы значками (плейтест 19 ноября: «неприлично много букв»): пачки и враги — значок и
## число, примета и ближайший босс — значок, подробности в подсказке.
const PACKS_ICON: Texture2D = preload("res://assets/ui/ritual/packs.svg")
const ENEMIES_ICON: Texture2D = preload("res://assets/ui/ritual/enemies.svg")
const OMEN_ICON: Texture2D = preload("res://assets/ui/ritual/omen.svg")
const BOSS_ICON: Texture2D = preload("res://assets/ui/ritual/boss.svg")
var _title: Label
var _packs_box: HBoxContainer
var _enemies: Label
var _enemies_box: HBoxContainer
## Примета ночи (docs/36 §2): значок, название и описание — в подсказке.
var _omen: TextureRect
## Босс в следующие ночи: значок, номер ночи и стихия неуязвимости; подробно — в подсказке.
var _boss: HBoxContainer
var _boss_night: Label
var _boss_resist: TextureRect
var _flow: HFlowContainer
const MAX_FLOW_WIDTH: float = 760.0


func _init() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	header.add_theme_constant_override("separation", 10)
	_packs_box = _counter(header, PACKS_ICON)
	_title = _packs_box.get_child(1) as Label
	_enemies_box = _counter(header, ENEMIES_ICON)
	_enemies = _enemies_box.get_child(1) as Label
	_omen = _glyph(OMEN_ICON, Vector2(26, 26))
	_omen.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_child(_omen)
	_boss = HBoxContainer.new()
	_boss.add_theme_constant_override("separation", 3)
	_boss.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_child(_boss)
	var skull: TextureRect = _glyph(BOSS_ICON, Vector2(26, 26))
	skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.add_child(skull)
	_boss_night = _small_label(_boss, 18)
	_boss_night.add_theme_color_override("font_color", Color("ffab65"))
	_boss_resist = _glyph(null, Vector2(20, 20))
	_boss_resist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.add_child(_boss_resist)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 4)
	_flow.add_theme_constant_override("v_separation", 4)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)


func refresh(trial: RitualTrial) -> void:
	_fit_flow()
	var queue: Array[RitualPack] = trial.night_queue()
	var night: int = trial.current_night()
	var at_night: bool = trial.settings.is_night(trial.tick_count)
	# Номер ночи уже в шапке слева (critique_3 п. 44): здесь только пачки и враги — значками.
	_title.text = str(queue.size())
	_packs_box.tooltip_text = "%s: %d" % ["Осталось пачек этой ночи" if at_night else "Пачек в ночь %d" % night,
		queue.size()]
	var alive: int = trial.field.count_alive_mobs()
	_enemies_box.visible = at_night and alive > 0
	_enemies.text = str(alive)
	_enemies_box.tooltip_text = "Врагов в городе: %d" % alive
	var night_omen: RitualOmenData = trial.plan().omen(night)
	_omen.visible = night_omen != null
	_omen.tooltip_text = "" if night_omen == null else "Примета ночи %d — %s.\n%s" % [
		night, night_omen.title, night_omen.description]
	var boss: RitualPack = trial.boss_warning()
	_boss.visible = boss != null
	if boss != null:
		_boss_night.text = str(boss.night)
		_boss_resist.visible = boss.resist != &""
		_boss_resist.texture = RitualIcons.god(boss.resist)
		_boss_resist.modulate = GodSymbols.get_color(boss.resist) if boss.resist != &"" else Color.WHITE
		_boss.tooltip_text = "Босс %s — в ночь %d%s" % [trial.settings.enemies[boss.leader].display_name, boss.night,
			"" if boss.resist == &"" else ".\nНеуязвим к стихии: " + element_name(boss.resist)]
	var key: String = str(night)
	for pack: RitualPack in queue:
		key += ";%d@%d" % [pack.at_tick, trial.pack_lane(pack)]
	if key != _key:
		_key = key
		_rebuild(trial, queue)
	# Подсказку меняем, только когда меняется текст (время прихода), а не каждый кадр.
	for index: int in _cards.size():
		var tip: String = describe(trial, _packs[index])
		if tip != _tips[index]:
			_tips[index] = tip
			_cards[index].tooltip_text = tip


## Только стихия: "Война · Бог войны" после "неуязвим к стихии" повторяет бога дважды.
static func element_name(god: StringName) -> String:
	return GodSymbols.get_power_name(god).get_slice(" · ", 0)


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
		lines.append("Обереги: %d (огонь %d%%, физика %d%%, молния %d%%, прочее %d%%)" % [
			wards, settings.ward_fire_percent, settings.ward_physical_percent,
			settings.ward_lightning_percent, settings.ward_other_percent])
	var elites: int = pack.elite.size() - pack.elite.count(0)
	if elites > 0:
		lines.append("Элита: %d (здоровье и награда x%d)" % [elites, pack.elite_multiplier])
	if pack.resist != &"":
		lines.append("Неуязвим к стихии: %s" % element_name(pack.resist))
	var fresh: Array[int] = trial.plan().new_types(pack)
	if not fresh.is_empty():
		var names: PackedStringArray = []
		for member: int in fresh:
			names.append(settings.enemies[member].display_name)
		lines.append("Впервые: " + ", ".join(names))
	if trial.entrances(pack.night) > 1:
		lines.append("Вход: " + lane_name(trial, trial.pack_lane(pack)))
	var routes: Array[int] = trial.pack_routes(pack)
	if routes.size() > 1:
		var straight: int = (pack.members.size() + routes.size() - 1) / routes.size()
		lines.append("Делится у проулка: %d прямо, %d в проулок" % [straight, pack.members.size() - straight])
	var alley_note: String = alley_users(trial, pack)
	if not alley_note.is_empty():
		lines.append(alley_note)
	lines.append(_eta(trial, pack))
	return "\n".join(lines)


## Кто из пачки срежет проулком (docs/37 ALY-3): быстрые — всегда, если проулок открыт.
static func alley_users(trial: RitualTrial, pack: RitualPack) -> String:
	var settings: RitualTrialConfig = trial.settings
	var lane: int = trial.pack_lane(pack)
	for index: int in settings.alleys.size():
		var alley: RitualAlley = settings.alleys[index]
		if alley.lane != lane or trial.city_level() < alley.city_level:
			continue
		if not trial.alley_open(index):
			return "Проулок завален: все идут по дороге"
		var counts: Dictionary[int, int] = {}
		for member: int in pack.members:
			if trial.takes_alley(index, settings.enemies[member]):
				counts[member] = counts.get(member, 0) + 1
		if counts.is_empty():
			return "Проулком никто не срежет (свернут, только если впереди частокол или смола)"
		var parts: PackedStringArray = []
		for member: int in counts:
			parts.append("%s ×%d" % [settings.enemies[member].display_name, counts[member]])
		return "Проулком срежут: " + ", ".join(parts)
	return ""


## Вход по имени: главная дорога или название улицы.
static func lane_name(trial: RitualTrial, lane: int) -> String:
	if lane <= 0:
		return "западные ворота" if not trial.settings.alleys.is_empty() else "главная дорога"
	return trial.settings.streets[lane - 1].title if lane <= trial.settings.streets.size() else "проулок"


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
	if trial.entrances(pack.night) > 1:
		var lane: int = trial.pack_lane(pack)
		var mark: Label = _small_label(row, 18)
		mark.text = LANE_MARKS[lane % LANE_MARKS.size()]
		mark.add_theme_color_override("font_color", LANE_COLORS[lane % LANE_COLORS.size()])
	for kind: Vector2i in kinds(pack):
		var icon: TextureRect = TextureRect.new()
		icon.texture = _icon(trial.settings.enemies[kind.x])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		# Число — только если врагов этого вида больше одного (плейтест 19 ноября: «×1» — лишние буквы).
		if kind.y > 1:
			var count: Label = _small_label(row, 18)
			count.text = str(kind.y)
	if pack.elite.size() > pack.elite.count(0):
		var crown: TextureRect = TextureRect.new()
		crown.texture = ELITE_CROWN
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.custom_minimum_size = Vector2(20, 16)
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(crown)
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


## Значок и число рядом; подсказка — на всей паре.
func _counter(parent: Node, texture: Texture2D) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var icon: TextureRect = _glyph(texture, Vector2(24, 24))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	_small_label(box, 18)
	return box


static func _glyph(texture: Texture2D, size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


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
	symbol.texture = RitualIcons.god(god)
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


## Полоса разведки по содержимому (critique_3 п. 43): карточки пачек в один ряд, пока помещаются
## (до MAX_FLOW_WIDTH), а не столбиком в узкой полосе.
func _fit_flow() -> void:
	var total: float = 0.0
	for child: Node in _flow.get_children():
		var card: Control = child as Control
		if card != null and card.visible:
			total += card.get_combined_minimum_size().x + 4.0
	var width: float = minf(total, minf(MAX_FLOW_WIDTH, get_viewport_rect().size.x - 60.0))
	if not is_equal_approx(_flow.custom_minimum_size.x, width):
		_flow.custom_minimum_size.x = width
