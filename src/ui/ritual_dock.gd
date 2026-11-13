class_name RitualDock
extends PanelContainer
## Нижний док забега «Обряда» (docs/37 §10): слева герой, золото, умение, частокол и припасы;
## в центре весь каталог построек (7 богов × 3 тира); справа — выбранный дом или город.
## Только раскладка и отображение: команды собирает RitualTrialPanel, правила — RitualTrial.

signal building_chosen(index: int)
signal building_hovered(index: int)
signal placement_cancelled()

const HEIGHT: float = 172.0
const CONTEXT_WIDTH: float = 320.0

## Сюда панель переносит портрет, HP, золото, умение и частокол героя (MatchHud).
var hero_row: HBoxContainer
## Ряд припасов и лечения героя под портретом.
var utility_row: HBoxContainer
var chips: Array[RitualBuildChip] = []
var context_title: Label
var context_text: Label
## Кнопки выбранного дома (улучшить, ветки, починить, продать).
var house_actions: HFlowContainer
## Кнопки города, когда ничего не выбрано (новая улица, починить всё).
var city_actions: HBoxContainer
var _grid: GridContainer
## Вкладки тиров каталога (просьба автора 13 ноября): на вкладке — 7 крупных карточек богов.
var _tier_tabs: Array[Button] = []
var shown_tier: int = 1


func _init() -> void:
	name = "RitualDock"
	add_theme_stylebox_override("panel", DuskTheme.glass(0.82, 8))
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	hero_row = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 8)
	left.add_child(hero_row)
	utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 4)
	left.add_child(utility_row)
	row.add_child(_separator())
	var middle: VBoxContainer = VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	middle.add_child(tabs)
	for index: int in 3:
		var tab: Button = Button.new()
		tab.name = "TierTab%d" % (index + 1)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(150, 26)
		tab.add_theme_font_size_override("font_size", 13)
		tab.pressed.connect(show_tier.bind(index + 1))
		tabs.add_child(tab)
		_tier_tabs.append(tab)
	var center: CenterContainer = CenterContainer.new()
	middle.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "Catalogue"
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	center.add_child(_grid)
	row.add_child(_separator())
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size.x = CONTEXT_WIDTH
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	context_title = Label.new()
	context_title.add_theme_font_size_override("font_size", 15)
	context_title.add_theme_color_override("font_color", Color("e9cea2"))
	context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(context_title)
	context_text = Label.new()
	context_text.name = "Selection"
	context_text.add_theme_font_size_override("font_size", 12)
	context_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_text.custom_minimum_size.x = CONTEXT_WIDTH
	context_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	context_text.max_lines_visible = 3
	context_text.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(context_text)
	# Ветки на 3-м уровне длинные: кнопки переносятся во второй ряд, а не раздвигают док.
	house_actions = HFlowContainer.new()
	house_actions.add_theme_constant_override("h_separation", 4)
	house_actions.add_theme_constant_override("v_separation", 4)
	right.add_child(house_actions)
	city_actions = HBoxContainer.new()
	city_actions.add_theme_constant_override("separation", 4)
	right.add_child(city_actions)


func _separator() -> VSeparator:
	var line: VSeparator = VSeparator.new()
	line.modulate = Color(1, 1, 1, 0.35)
	return line


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
	var names: Array[String] = ["I", "II", "III"]
	for index: int in _tier_tabs.size():
		var open: bool = city >= index + 1
		_tier_tabs[index].text = "Тир %s" % names[index] if open else "Тир %s · город %d" % [names[index], index + 1]
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
	var lines: PackedStringArray = ["%s · %s · тир %s" % [chip.data.display_name,
		GodSymbols.get_power_name(chip.data.god), RitualBuildChip.TIER_NAMES[clampi(chip.data.tier, 1, 3) - 1]]]
	if levels != null and not levels.role.is_empty():
		lines.append(levels.role)
	var note: String = first.note if first != null and not first.note.is_empty() else chip.data.description
	if levels == null or note != levels.role:
		lines.append(note)
	lines.append("Цена %d · один дом на свободный участок · %s" % [chip.price,
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
