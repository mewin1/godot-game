class_name RitualDock
extends PanelContainer
## Нижний док забега «Обряда» (docs/37 §10): слева герой, золото, умение, частокол и припасы;
## в центре весь каталог построек (7 богов × 3 тира); справа — выбранный дом или город.
## Только раскладка и отображение: команды собирает RitualTrialPanel, правила — RitualTrial.

signal building_chosen(index: int)
signal building_hovered(index: int)
signal placement_cancelled()

## Док легче (critique.md п. 16, spec §10.1): вместо сплошной плиты 172 px — три стеклянных
## островка 132 px, между ними видна сцена. Ширина влезает в логические 1600 (critique_2 п. 18).
## 146 вместо 132 (critique_3 п. 4, 58): кегли не мельче 18 и цена над домом, а не на машине.
## Высота одна и та же с выбранным домом и без (п. 54): островки не растут от содержимого.
const HEIGHT: float = 146.0
const CONTEXT_WIDTH: float = 340.0
## Портрет: островок дома уже, его кнопки бывают в три ряда — запас, чтобы док не прыгал.
const COMPACT_EXTRA: float = 40.0
const TIER_NAMES: Array[String] = ["I", "II", "III"]

## Сюда панель переносит портрет, HP, золото героя (MatchHud).
var hero_row: HBoxContainer
## Ряд действий героя: умение, частокол, припасы — плитками с клавишами.
var utility_row: HBoxContainer
var chips: Array[RitualBuildChip] = []
var context_title: Label
var context_text: Label
## Кнопки выбранного дома (улучшить, ветки, починить, продать).
var house_actions: HFlowContainer
## Кнопки города, когда ничего не выбрано (новая улица, завал, починить всё) — переносятся.
var city_actions: HFlowContainer
var _grid: GridContainer
## Переключатель тиров каталога I-II-III (просьба автора 13 ноября: на вкладке — 7 крупных карточек).
var _tier_tabs: Array[Button] = []
var shown_tier: int = 1
var _row: HBoxContainer
## Портрет (critique_3 п. 3): второй ряд дока — герой и выбранный дом под каталогом.
var _row2: HBoxContainer
var _stack: VBoxContainer
var _scroll: ScrollContainer
var compact: bool = false
var _context_island: Control
var _left_island: Control


func _init() -> void:
	name = "RitualDock"
	var frame: StyleBoxEmpty = StyleBoxEmpty.new()
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_bottom = 6
	add_theme_stylebox_override("panel", frame)
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 6)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(row)
	_row = row
	_row2 = HBoxContainer.new()
	_row2.add_theme_constant_override("separation", 8)
	_row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row2.hide()
	_stack.add_child(_row2)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_island(row).add_child(left)
	hero_row = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 8)
	left.add_child(hero_row)
	utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 4)
	left.add_child(utility_row)
	row.add_child(_spacer())
	var middle: HBoxContainer = HBoxContainer.new()
	middle.add_theme_constant_override("separation", 6)
	_island(row).add_child(middle)
	var tabs: VBoxContainer = VBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 4)
	middle.add_child(tabs)
	for index: int in 3:
		var tab: Button = Button.new()
		tab.name = "TierTab%d" % (index + 1)
		tab.text = TIER_NAMES[index]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(40, 36)
		tab.add_theme_font_size_override("font_size", 18)
		tab.pressed.connect(show_tier.bind(index + 1))
		tabs.add_child(tab)
		_tier_tabs.append(tab)
	_grid = GridContainer.new()
	_grid.name = "Catalogue"
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	# Каталог в прокрутке: на широком экране она во всю ширину карточек и не видна, в портрете —
	# по ширине экрана, карточки листаются (critique_3 п. 3).
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	middle.add_child(_scroll)
	_scroll.add_child(_grid)
	row.add_child(_spacer())
	var context: PanelContainer = _island(row)
	_context_island = context
	_left_island = left.get_parent() as Control
	context.custom_minimum_size.x = CONTEXT_WIDTH
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	context.add_child(right)
	context_title = Label.new()
	context_title.theme_type_variation = &"HeaderLabel"
	context_title.add_theme_font_size_override("font_size", 19)
	context_title.add_theme_color_override("font_color", Color("e9cea2"))
	context_title.add_theme_constant_override("outline_size", 0)
	context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Постоянные высоты строк: док не дёргается от разных букв заголовка (critique_3 п. 54).
	context_title.custom_minimum_size.y = 30
	context_title.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(context_title)
	context_text = Label.new()
	context_text.name = "Selection"
	context_text.add_theme_font_size_override("font_size", 18)
	context_text.add_theme_color_override("font_color", DuskTheme.MUTED)
	context_text.custom_minimum_size.x = CONTEXT_WIDTH
	# Одна строка: вторая раздвигала док (critique_3 п. 54); всё описание — в подсказке.
	context_text.max_lines_visible = 1
	context_text.custom_minimum_size.y = 24
	context_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_text.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(context_text)
	# Ветки на 3-м уровне длинные: кнопки переносятся во второй ряд, а не раздвигают док.
	house_actions = HFlowContainer.new()
	house_actions.add_theme_constant_override("h_separation", 4)
	house_actions.add_theme_constant_override("v_separation", 4)
	right.add_child(house_actions)
	city_actions = HFlowContainer.new()
	city_actions.add_theme_constant_override("h_separation", 4)
	city_actions.add_theme_constant_override("v_separation", 4)
	right.add_child(city_actions)


## Стеклянный островок дока: ловит мышь, промежутки между островками — нет.
func _island(row: HBoxContainer) -> PanelContainer:
	var island: PanelContainer = PanelContainer.new()
	island.add_theme_stylebox_override("panel", DuskTheme.glass(0.8, 6))
	island.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(island)
	return island


func _spacer() -> Control:
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## Карточки по столбцам богов (в порядке каталога), строки — тиры I/II/III.
func setup_catalogue(settings: RitualTrialConfig) -> void:
	var gods: Array[StringName] = []
	for tower: TowerData in settings.combat.towers:
		if not gods.has(tower.god):
			gods.append(tower.god)
	_grid.columns = gods.size()
	for level: int in range(1, 4):
		for god: StringName in gods:
			var index: int = _find(settings, god, level)
			if index < 0:
				var gap: Control = Control.new()
				gap.custom_minimum_size = RitualBuildChip.CHIP_SIZE
				_grid.add_child(gap)
				continue
			var chip: RitualBuildChip = RitualBuildChip.new()
			chip.setup(index, settings.combat.towers[index])
			chip.chosen.connect(building_chosen.emit)
			chip.hovered.connect(building_hovered.emit)
			chip.cancelled.connect(placement_cancelled.emit)
			_grid.add_child(chip)
			chips.append(chip)
	show_tier(1)


## Показать карточки тира level (1–3); остальные скрыты, но обновляются.
func show_tier(level: int) -> void:
	shown_tier = level
	for chip: RitualBuildChip in chips:
		chip.visible = clampi(chip.data.tier, 1, 3) == level
	for gap: Node in _grid.get_children():
		if not gap is RitualBuildChip:
			(gap as Control).visible = false
	for index: int in _tier_tabs.size():
		_tier_tabs[index].set_pressed_no_signal(index + 1 == level)


static func _find(settings: RitualTrialConfig, god: StringName, tier: int) -> int:
	for index: int in settings.combat.towers.size():
		var tower: TowerData = settings.combat.towers[index]
		if tower.god == god and clampi(tower.tier, 1, 3) == tier:
			return index
	return -1


## Цены, доступность и ночная наценка; chosen — карточка, ждущая участка (-1 — нет).
func refresh_catalogue(trial: RitualTrial, chosen: int) -> void:
	var free: bool = false
	for cell: Vector2i in trial.field.get_buildable_cells():
		if trial.field.get_tower_at(cell) == null:
			free = true
			break
	var at_night: bool = trial.settings.is_night(trial.tick_count)
	var city: int = trial.city_level()
	for index: int in _tier_tabs.size():
		var open: bool = city >= index + 1
		# Условие открытия — в подсказке, а не в надписи вкладки (critique_2: «Тир» — жаргон).
		_tier_tabs[index].tooltip_text = "Дома %s уровня" % TIER_NAMES[index] if open \
				else "Дома %s уровня — с города %d («Новая улица»)" % [TIER_NAMES[index], index + 1]
		_tier_tabs[index].modulate = Color.WHITE if open else Color(1, 1, 1, 0.55)
	for chip: RitualBuildChip in chips:
		var price: int = trial.building_cost(chip.index)
		var unlock: String = trial.building_unlock_error(chip.index)
		var locked: String = "город %d" % clampi(chip.data.tier, 1, 3) if not unlock.is_empty() else ""
		var affordable: bool = free and trial.gold >= price
		if chip.price != price or chip.locked_text != locked or chip.affordable != affordable \
				or chip.at_night != at_night or chip.is_chosen != (chip.index == chosen):
			chip.price = price
			chip.locked_text = locked
			chip.affordable = affordable
			chip.at_night = at_night
			chip.is_chosen = chip.index == chosen
			chip.tooltip_text = _chip_tooltip(trial, chip, unlock, free)
			chip.queue_redraw()


static func _chip_tooltip(trial: RitualTrial, chip: RitualBuildChip, unlock: String, free: bool) -> String:
	var settings: RitualTrialConfig = trial.settings
	var levels: RitualBuildingLevels = settings.levels_for(chip.data)
	var first: RitualLevelBehavior = levels.at_level(1) if levels != null else null
	var lines: PackedStringArray = ["%s · %s · дома %s уровня" % [chip.data.display_name,
		GodSymbols.get_power_name(chip.data.god), RitualBuildChip.TIER_NAMES[clampi(chip.data.tier, 1, 3) - 1]]]
	if levels != null and not levels.role.is_empty():
		lines.append(levels.role)
	var note: String = first.note if first != null and not first.note.is_empty() else chip.data.description
	if levels == null or note != levels.role:
		lines.append(note)
	lines.append("Цена %d · один дом на участок · %s" % [chip.price,
		RitualTrialPanel.ward_note(settings, chip.data)])
	var discount: int = trial.discount_bp(chip.data.god)
	if discount > 0:
		lines.append("Скидка %s: −%d%%" % [GodSymbols.get_power_name(chip.data.god), discount / 100])
	if settings.is_night(trial.tick_count):
		lines.append("Мастера спят. Ночной вызов: +%d%% к цене, стройка %d с." % [
			settings.night_cost_percent - 100, settings.night_install_ticks / settings.combat.ticks_per_second])
	if not unlock.is_empty():
		lines.append(unlock)
	elif not free:
		lines.append("Свободных участков нет — улучшайте дома или стройте новую улицу")
	return "\n".join(lines)


## Сколько карточек каталога (для проверок без доступа к самим карточкам).
func chip_count() -> int:
	return chips.size()


## Содержимое дока (до выбора героя — пусто); высота дока при этом не меняется.
func set_content_visible(shown: bool) -> void:
	if _row != null and _row.visible != shown:
		_row.visible = shown


## Узкий экран (портрет): каталог — первым рядом с прокруткой, герой и выбранный дом — вторым.
## Высота дока в этом режиме двойная; на широком — прежний один ряд.
func set_compact(on: bool, width: float) -> void:
	var catalogue: Vector2 = _grid.get_combined_minimum_size()
	var room: float = width - 20.0 - 60.0
	_scroll.custom_minimum_size = Vector2(minf(catalogue.x, room) if on else catalogue.x, catalogue.y)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if on and catalogue.x > room \
			else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if on == compact:
		return
	compact = on
	if on:
		_left_island.reparent(_row2, false)
		_context_island.reparent(_row2, false)
		_context_island.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_context_island.custom_minimum_size.x = 0.0
		context_text.custom_minimum_size.x = 0.0
		_row2.show()
		custom_minimum_size.y = HEIGHT * 2.0 + COMPACT_EXTRA
	else:
		_left_island.reparent(_row, false)
		_row.move_child(_left_island, 0)
		_context_island.reparent(_row, false)
		_context_island.size_flags_horizontal = Control.SIZE_FILL
		_context_island.custom_minimum_size.x = CONTEXT_WIDTH
		context_text.custom_minimum_size.x = CONTEXT_WIDTH
		_row2.hide()
		custom_minimum_size.y = HEIGHT
