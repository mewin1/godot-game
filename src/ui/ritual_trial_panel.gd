class_name RitualTrialPanel
extends Control
## Основной режим «Обряд»: бесконечный забег (endless.tres). Прежний 4-суточный опыт (trial.tres)
## остаётся для тестов и инструментов: задать `settings = TRIAL` до добавления в дерево.

const TRIAL: RitualTrialConfig = preload("res://data/ritual/trial.tres")
const ENDLESS: RitualTrialConfig = preload("res://data/ritual/endless.tres")
const MAX_FRAME_TICKS: int = 8
## Сообщение внизу поля гаснет через столько секунд (подсказка выбора - пока выбор идет).
const TOAST_SECONDS: float = 4.0
const PLACE_HINT: String = "ЛКМ - поставить · R - поворот · ПКМ/Esc - отмена"
var settings: RitualTrialConfig = ENDLESS
var trial: RitualTrial
var board: RitualBoard
var _hud: RitualMatchHud
var _shop: RitualShopPanel
var _idol_slots: Array[IdolSlot] = []
var _preset: OptionButton
var _branch: OptionButton
var _clock: Label
var _status: Label
var _selection: Label
var _threat: Label
var _message: Label
var _history: Label
var _idols: Label
var _pause_button: Button
var _start_button: Button
var _skill_button: Button
var _palisade_button: Button
var _checkpoint: Dictionary = {}
var _accumulator: float = 0.0
var _paused: bool = true
var _pause_count: int = 0
var _paused_seconds: float = 0.0
var _saved_result: bool = false
var _attempts: PackedStringArray = []
var _schedule: PanelContainer
var _schedule_was_paused: bool = true
var _enchant_index: int = -1
var _repair_button: Button
var _defeat: PanelContainer
var _scout: RitualScoutQueue
var _repair_all_button: Button
## Пристроить улицу (docs/34 §3); нет улиц в данных — кнопки нет.
var _street_button: Button
var _gift_panel: PanelContainer
var _gift_buttons: VBoxContainer
var _gift_key: String = ""
var _repair_house_button: Button
var _defeat_text: Label
## Выбор героя перед бесконечным забегом (docs/36 §1).
var _hero_panel: PanelContainer
var _hero_choice: int = 0
var _omen_night: int = 0
## Ряд припасов (docs/36 §4): смола, чаша, оберег.
var _supply_buttons: Array[Button] = []
var _fast_button: Button
var _speed: int = 1
var _toast: PanelContainer
var _toast_text: String = ""
var _toast_age: float = 0.0
## Счетчик кадров и кнопка "Проверки" в бесконечном забеге скрыты: F10 показывает их.
var _fps: FpsLabel
var _sound_bank: SoundBank
## Ночь ли была на прошлом обновлении: смена дня и ночи звучит рогом и колоколом.
var _was_night: bool = false
var _upgrade_button: Button
var _upgrade_surcharge: Label
var _specialise_buttons: Array[Button] = []
var _sell_button: Button
var _wear_dawn: int = -1
## Нижний док и окно идола забега с участками (docs/37 §8, §10); null — прежняя раскладка.
var _dock: RitualDock
var _idol_popup: RitualIdolPopup
var _selection_title: Label
var _overlay: RitualHudOverlay
var _barricade_buttons: Array[Button] = []
## Реакции, вызванные каждым домом за текущую ночь (docs/37 RX-6): id дома → id реакции → число.
var _tower_reactions: Dictionary[int, Dictionary] = {}
var _numbers_button: Button
## Усиления рассвета (docs/37 D4): ряд карточек над доком, днём, игра не стоит.
var _boon_panel: PanelContainer
var _boon_buttons: HBoxContainer
var _boon_key: String = ""
var _supply_menu: MenuButton
var _boon_shade: ColorRect
const PALISADE_ICON: Texture2D = preload("res://assets/ui/ritual/palisade.svg")
## Усиление без бога (плотники, купцы, ремесло) — общий знак дара.
const BOON_ICON: Texture2D = preload("res://assets/ui/ritual/supply_charm.svg")
const SUPPLY_ICONS: Array[Texture2D] = [preload("res://assets/ui/ritual/supply_tar.svg"),
	preload("res://assets/ui/ritual/supply_bowl.svg"), preload("res://assets/ui/ritual/supply_charm.svg")]
## Итоги забега для экрана поражения (docs/37 UI-14).
var _stats: RitualRunStats = RitualRunStats.new()
var _defeat_columns: HBoxContainer


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = DuskTheme.create()
	_build_ui()
	_reset(0)
	_show_heroes()


func _build_ui() -> void:
	board = RitualBoard.new()
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.cell_clicked.connect(_on_cell)
	board.command_requested.connect(_issue)
	# Звуки выстрелов, смертей и прорывов шлет слой эффектов, как в PvP (docs/37 BUG-13).
	_sound_bank = SoundBank.new()
	add_child(_sound_bank)
	if board.effects != null:
		board.effects.sound_requested.connect(_sound_bank.play)
	var root_box: VBoxContainer = VBoxContainer.new()
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud = RitualMatchHud.new()
	root_box.add_child(_hud)
	_hud.pause_pressed.connect(_pause)
	_hud.skill_pressed.connect(_choose_skill)
	_hud.reserve_pressed.connect(_choose_palisade)
	_hud.speed_pressed.connect(_toggle_tools)
	_hud.set_preparation(true)
	_hud._speed_button.show()
	_hud._speed_button.text = "Проверки"
	_hud._speed_button.custom_minimum_size.x = 90
	_hud._speed_button.tooltip_text = "Настройки опыта, расписание и снимки"
	# Скорость ×1 → ×2 → ×3 (docs/36 §5): спокойные отрезки не тянутся. Клавиша X.
	_fast_button = Button.new()
	_fast_button.text = "×1"
	_fast_button.tooltip_text = "Скорость игры: ×1, ×2, ×3 (клавиша X)"
	_fast_button.custom_minimum_size = Vector2(44, 36)
	_fast_button.focus_mode = Control.FOCUS_NONE
	_fast_button.pressed.connect(_toggle_speed)
	var hud_tools: Node = _hud._pause_button.get_parent()
	hud_tools.add_child(_fast_button)
	hud_tools.move_child(_fast_button, _hud._pause_button.get_index() + 1)
	# Ряд привязан к правому краю: лишняя кнопка сдвигает его влево, а не за край экрана.
	_hud._prep_tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if settings.uses_plots():
		_build_dock(root_box)
	else:
		_build_legacy(root_box)
	_skill_button = _hud._skill_button
	if _palisade_button == null:
		_palisade_button = _hud._reserve_button
	_pause_button = _hud._pause_button
	_start_button = _shop._ready if _shop != null else null
	_clock = _hud._phase_label
	_status = _hud._hp_label
	_idols = _label(self, "", 10)
	_idols.hide()
	# Временный счётчик кадров: справа под кнопками «Пауза» и «Проверки».
	_fps = FpsLabel.new()
	_fps.viewport = board.stage._viewport if board.stage != null else null
	add_child(_fps)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.offset_left = -190.0
	_fps.offset_right = -16.0
	_fps.offset_top = 52.0
	if settings.is_endless():
		_fps.hide()
		_hud._speed_button.hide()
	# Техническая строка опыта сохранена отдельно от интерфейса PvP.
	var tools: VBoxContainer = VBoxContainer.new()
	root_box.add_child(tools)
	var controls: HFlowContainer = HFlowContainer.new()
	controls.name = "TrialTools"
	controls.visible = false
	tools.add_child(controls)
	_preset = OptionButton.new()
	_preset.focus_mode = Control.FOCUS_NONE
	for loadout: RitualLoadout in settings.loadouts:
		_preset.add_item(loadout.title)
	controls.add_child(_preset)
	_button(controls, "Заново", _reset_selected)
	_button(controls, "Один тик", _step)
	_button(controls, "Снимок", _capture)
	_button(controls, "Открыть снимок", _load_checkpoint)
	_branch = OptionButton.new()
	_branch.focus_mode = Control.FOCUS_NONE
	for text: String in ["Свободное продолжение", "Без команд", "Только приёмы", "Приёмы + переносы"]:
		_branch.add_item(text)
	controls.add_child(_branch)
	_button(controls, "Ветка из снимка", _restore_branch)
	_button(controls, "Сохранить итог", _save_result)
	_button(controls, "Расписание · все сутки", _show_schedule).visible = not settings.is_endless()
	_button(controls, "В меню", _back)
	_threat = _hud._siege_label
	_hud._siege_panel.show()
	if settings.is_endless():
		# Очередь ближайшей ночи — своя полоса сверху над полем: пачек много, карточки шире.
		_scout = RitualScoutQueue.new()
		_hud._siege_panel.hide()
		var strip: PanelContainer = PanelContainer.new()
		strip.add_theme_stylebox_override("panel", DuskTheme.glass(0.62, 6))
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(_scout)
		if _dock != null:
			_build_top_bar(strip)
		else:
			add_child(strip)
			strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			strip.offset_left = 430
			strip.offset_right = -230
			strip.offset_top = 8
	_threat.visible = not settings.is_endless()
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", DuskTheme.glass(0.82, 8))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_left = 356
	_toast.offset_right = -20
	# Над панелью выбора постройки, чтобы не закрывать её строку.
	_toast.offset_top = -258
	_toast.offset_bottom = -228
	if _dock != null:
		# Забег: сообщения сверху по центру под шапкой (docs/37 UI-12), карту снизу не закрывают.
		_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_toast.offset_left = -380
		_toast.offset_right = 380
		# Под шапкой (она до ~80 px), а не на нижнем крае полосы разведки.
		_toast.offset_top = 90
		_toast.offset_bottom = 120
	_message = _label(_toast, "", 18)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_history = _label(controls, "", 10)
	_history.hide()
	_build_schedule()
	_build_defeat()
	_build_gifts()
	_build_heroes()


## Шапка забега одной строкой (critique_2 п. 18-19): [время] [разведка — тянется, лишнее обрезает]
## [инструменты]. Раньше полоса стояла на жёстких отступах 430/−230 и накрывала таймер и «?»,
## а инструменты лежали в корневом столбце и уезжали за край вместе с широким доком.
func _build_top_bar(strip: PanelContainer) -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 8
	var chip: Control = _hud._prep_info.get_parent() as Control
	chip.reparent(bar, false)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip.clip_contents = true
	bar.add_child(strip)
	var tools: HBoxContainer = _hud._prep_tools
	tools.reparent(bar, false)
	tools.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Кегль 18 у инструментов шапки (critique_3 п. 4): общий MatchHud ставит 17.
	for child: Node in tools.get_children():
		if child is Button:
			(child as Button).add_theme_font_size_override("font_size", 18)


## Прежняя раскладка (4-суточный опыт): лавка и правка слева, идолы и герой под картой.
func _build_legacy(root_box: VBoxContainer) -> void:
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size.x = 324
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	_shop = RitualShopPanel.new()
	_shop.custom_minimum_size.x = 324
	left.add_child(_shop)
	_shop.setup_ritual(settings)
	_shop.purchase_chosen.connect(_choose_purchase)
	_shop.rite_chosen.connect(_buy_rite)
	_shop.start_requested.connect(_start)
	_shop.sell_requested.connect(_sell_tower)
	_shop.enchant_chosen.connect(_choose_enchant)
	_shop.reroll_requested.connect(_reroll)
	_shop.placement_cancelled.connect(_cancel_from_catalogue)
	var edit: HBoxContainer = HBoxContainer.new()
	left.add_child(edit)
	_button(edit, "Перенести", _choose_move)
	_sell_button = _button(edit, "Продать", _sell)
	_button(edit, "Отмена", _cancel_move)
	var upkeep: HBoxContainer = HBoxContainer.new()
	left.add_child(upkeep)
	_repair_button = _button(upkeep, "Починить терем +%d · %d" % [settings.repair_hp, settings.repair_cost], _repair)
	_repair_button.tooltip_text = "Терем +%d HP за %d золота (не выше %d)" % [
		settings.repair_hp, settings.repair_cost, settings.hero_hp]
	if not settings.streets.is_empty():
		_street_button = _button(upkeep, "", _grow)
	if settings.wear_ticks > 0:
		var houses: HBoxContainer = HBoxContainer.new()
		left.add_child(houses)
		_repair_all_button = _button(houses, "Починить всё", _repair_houses.bind(0))
		_repair_all_button.tooltip_text = "Вернуть полную прочность всем домам. Ремонт дешевле новой постройки."
		_repair_house_button = _button(houses, "Починить дом", _repair_selected)
	if settings.supply_cap > 0:
		var supplies: HBoxContainer = HBoxContainer.new()
		left.add_child(supplies)
		for kind: int in RitualTrial.SUPPLY_NAMES.size():
			_supply_buttons.append(_button(supplies, "", _choose_supply.bind(kind)))
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(gap)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(right)
	var field_space: Control = Control.new()
	field_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(field_space)
	_shop.mount_selection(field_space)
	_selection = _shop._selection
	if settings.uses_plots():
		var upgrades: HBoxContainer = HBoxContainer.new()
		_selection.get_parent().add_child(upgrades)
		_upgrade_button = _button(upgrades, "Улучшить", _upgrade_selected.bind(-1))
		_upgrade_button.name = "UpgradeHouse"
		for branch_index: int in 2:
			_specialise_buttons.append(_button(upgrades, "", _upgrade_selected.bind(branch_index)))
			_specialise_buttons[-1].name = "SpecialiseHouse%d" % branch_index
		_upgrade_surcharge = Label.new()
		_upgrade_surcharge.name = "UpgradeNightSurcharge"
		_upgrade_surcharge.text = "↑"
		_upgrade_surcharge.mouse_filter = Control.MOUSE_FILTER_PASS
		_upgrade_surcharge.add_theme_color_override("font_color", Color("ff6258"))
		upgrades.add_child(_upgrade_surcharge)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 12)
	right.add_child(bottom)
	var idols: PanelContainer = PanelContainer.new()
	idols.add_theme_stylebox_override("panel", DuskTheme.glass(0.62, 6))
	bottom.add_child(idols)
	var idol_row: HBoxContainer = HBoxContainer.new()
	idols.add_child(idol_row)
	_label(idol_row, "ИДОЛЫ", 13)
	for index: int in 3:
		var slot: RitualIdolSlot = RitualIdolSlot.new()
		slot.rite_chosen.connect(_buy_rite)
		slot.slot_index = index
		slot.custom_minimum_size = Vector2(78, 72)
		idol_row.add_child(slot)
		_idol_slots.append(slot)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(spacer)
	var hero_dock: PanelContainer = PanelContainer.new()
	hero_dock.add_theme_stylebox_override("panel", DuskTheme.glass(0.66, 6))
	bottom.add_child(hero_dock)
	var hero_row: HBoxContainer = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 10)
	hero_dock.add_child(hero_row)
	_hud.move_hero_controls(hero_row)


## Забег с участками (docs/37 §10): карта на весь экран между шапкой и нижним доком,
## идолы — на площади у терема (окно по щелчку), правка дома — в правой части дока.
func _build_dock(root_box: VBoxContainer) -> void:
	var field_space: Control = Control.new()
	field_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(field_space)
	_dock = RitualDock.new()
	root_box.add_child(_dock)
	_dock.setup_catalogue(settings)
	_dock.building_chosen.connect(_choose_purchase)
	_dock.building_hovered.connect(_hover_building)
	_dock.placement_cancelled.connect(_cancel_from_catalogue)
	_hud.hero_name_width = 150.0
	_hud.move_hero_controls(_dock.hero_row)
	# Портрет мельче прежнего блока героя: док делит ширину экрана с каталогом.
	_hud._hero_portrait.custom_minimum_size = Vector2.ONE * 48
	for value: Label in [_hud._hp_label, _hud._gold_label]:
		value.add_theme_font_override("font", DuskTheme.NUMBER_FONT)
		value.add_theme_font_size_override("font_size", 20)
	# Действия героя одним рядом плиток (critique_2 п. 23-24): умение, частокол, три припаса.
	var orders: Node = _hud._skill_button.get_parent()
	_hud._skill_button.reparent(_dock.utility_row)
	_hud._skill_button.custom_minimum_size = Vector2(112, 48)
	_hud._skill_button.add_theme_font_size_override("font_size", 18)
	_hud._reserve_button.reparent(_dock.utility_row)
	_hud._reserve_button.hide()
	orders.queue_free()
	var palisade: RitualActionTile = _tile(PALISADE_ICON, "F", _choose_palisade)
	palisade.name = "PalisadeTile"
	_hud.palisade_tile = palisade
	_palisade_button = palisade
	for kind: int in RitualTrial.SUPPLY_NAMES.size():
		var tile: RitualActionTile = _tile(SUPPLY_ICONS[kind], str(kind + 1), _supply_pressed.bind(kind))
		tile.name = "Supply%d" % kind
		_supply_buttons.append(tile)
	# Лечение — рядом с HP героя (сердце-кнопка путалось с меткой здоровья).
	_repair_button = Button.new()
	_repair_button.name = "HealHero"
	_repair_button.focus_mode = Control.FOCUS_NONE
	_repair_button.custom_minimum_size = Vector2(0, 28)
	_repair_button.add_theme_font_size_override("font_size", 18)
	# Монета иконкой справа (critique_3 п. 49): одна валюта — один знак.
	_repair_button.icon = DuskTheme.COIN
	_repair_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_repair_button.add_theme_constant_override("icon_max_width", 16)
	_repair_button.pressed.connect(_repair)
	(_hud._hp_label.get_parent() as Control).add_child(_repair_button)
	_selection = _dock.context_text
	_selection_title = _dock.context_title
	_upgrade_button = _button(_dock.house_actions, "Улучшить", _upgrade_selected.bind(-1))
	_upgrade_button.name = "UpgradeHouse"
	for branch_index: int in 2:
		_specialise_buttons.append(_button(_dock.house_actions, "", _upgrade_selected.bind(branch_index)))
		_specialise_buttons[-1].name = "SpecialiseHouse%d" % branch_index
	_upgrade_surcharge = Label.new()
	_upgrade_surcharge.name = "UpgradeNightSurcharge"
	_upgrade_surcharge.text = "↑"
	_upgrade_surcharge.mouse_filter = Control.MOUSE_FILTER_PASS
	_upgrade_surcharge.add_theme_color_override("font_color", Color("ff6258"))
	_dock.house_actions.add_child(_upgrade_surcharge)
	_repair_house_button = _button(_dock.house_actions, "Починить дом", _repair_selected)
	_sell_button = _button(_dock.house_actions, "Продать", _sell)
	if not settings.streets.is_empty():
		_street_button = _button(_dock.city_actions, "", _grow)
	for index: int in settings.alleys.size():
		var barricade: Button = _button(_dock.city_actions, "", _toggle_barricade.bind(index))
		barricade.name = "Barricade%d" % index
		_barricade_buttons.append(barricade)
	_repair_all_button = _button(_dock.city_actions, "Починить всё", _repair_houses.bind(0))
	_repair_all_button.tooltip_text = "Вернуть полную прочность всем домам. Ремонт дешевле новой постройки."
	# Кнопки города и дома — 18 (14 px на 1280x720, critique_3 п. 4); не больше двух рядов,
	# высота островка постоянная (п. 54).
	for group: Container in [_dock.city_actions, _dock.house_actions]:
		for child: Node in group.get_children():
			if child is Button:
				(child as Button).add_theme_font_size_override("font_size", 18)
	# Выбор усиления на рассвете — три карточки по центру поверх затемнения (critique.md п. 22):
	# раньше — плоские кнопки в окне-диалоге поверх домов.
	_boon_shade = ColorRect.new()
	_boon_shade.name = "BoonShade"
	_boon_shade.color = Color(0.0, 0.01, 0.02, 0.45)
	_boon_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boon_shade.z_index = 4  # выше затемнения паузы и подсказок оверлея
	add_child(_boon_shade)
	_boon_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boon_shade.hide()
	_boon_panel = PanelContainer.new()
	_boon_panel.name = "BoonPanel"
	_boon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_boon_panel.z_index = 5
	add_child(_boon_panel)
	var boon_box: VBoxContainer = VBoxContainer.new()
	boon_box.add_theme_constant_override("separation", 10)
	_boon_panel.add_child(boon_box)
	var boon_title: Label = _label(boon_box, "Рассвет: выберите усиление до ночи", 26)
	boon_title.theme_type_variation = &"HeaderLabel"
	boon_title.add_theme_font_size_override("font_size", 26)
	boon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boon_title.add_theme_color_override("font_color", DuskTheme.GOLD)
	_boon_buttons = HBoxContainer.new()
	_boon_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_boon_buttons.add_theme_constant_override("separation", 14)
	boon_box.add_child(_boon_buttons)
	_boon_panel.hide()
	_idol_popup = RitualIdolPopup.new()
	add_child(_idol_popup)
	_idol_popup.rite_requested.connect(_buy_rite_at)
	_idol_popup.closed.connect(_on_idol_closed)
	board.idol_clicked.connect(_open_idol)
	board.map_inset = Rect2(12, 58, 12, RitualDock.HEIGHT + 6)
	_overlay = RitualHudOverlay.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.skill_button = _hud._skill_button
	_overlay.sound_bank = _sound_bank
	_overlay.bottom_inset = RitualDock.HEIGHT + 6
	# «?» в шапке - легенда меток и реакций (docs/37 UI-15).
	var legend: Button = Button.new()
	legend.text = "?"
	legend.name = "LegendButton"
	legend.tooltip_text = "Метки на врагах и реакции стихий"
	legend.custom_minimum_size = Vector2(36, 36)
	legend.focus_mode = Control.FOCUS_NONE
	legend.pressed.connect(func() -> void: _overlay.toggle_legend(settings))
	var hud_tools: Node = _hud._pause_button.get_parent()
	hud_tools.add_child(legend)
	hud_tools.move_child(legend, 0)
	# Числа урона: нет / важные / все (docs/37 RX-8, D11) — настройка, а не действие боя:
	# в шапке короткий значок «123», режим — в подсказке (critique_2: «Числа: важные» занимали шапку).
	_numbers_button = Button.new()
	_numbers_button.name = "DamageNumbers"
	_numbers_button.text = "123"
	_numbers_button.custom_minimum_size = Vector2(44, 36)
	_numbers_button.focus_mode = Control.FOCUS_NONE
	_numbers_button.pressed.connect(func() -> void:
		board.cycle_damage_numbers()
		_show_numbers_mode())
	hud_tools.add_child(_numbers_button)
	hud_tools.move_child(_numbers_button, 1)
	_show_numbers_mode()


func _show_numbers_mode() -> void:
	var mode: String = RitualBoard.NUMBER_NAMES[board.damage_numbers]
	_numbers_button.tooltip_text = "Числа урона над врагами: %s.\nЩелчок — нет / важные (реакции, боссы, крупные удары) / все." % mode
	_numbers_button.modulate = Color(1, 1, 1, 0.5) if board.damage_numbers == 0 else Color.WHITE


## Плитка действия в ряду героя (иконка, клавиша, число).
func _tile(picture: Texture2D, key_hint: String, callback: Callable) -> RitualActionTile:
	var tile: RitualActionTile = RitualActionTile.new()
	tile.picture = picture
	tile.key_hint = key_hint
	tile.pressed.connect(callback)
	_dock.utility_row.add_child(tile)
	return tile


## Экран поражения бесконечного забега: ночи, рекорд на устройстве, убитые боссы.
func _build_defeat() -> void:
	_defeat = PanelContainer.new()
	_defeat.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	_defeat.z_index = 10
	add_child(_defeat)
	_defeat.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_defeat.add_child(content)
	_defeat_text = _label(content, "", 20)
	_defeat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_columns = HBoxContainer.new()
	_defeat_columns.add_theme_constant_override("separation", 28)
	content.add_child(_defeat_columns)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	_button(buttons, "Ещё забег", _again).tooltip_text = "Новый забег тем же героем"
	if settings.heroes.size() > 1:
		_button(buttons, "Сменить героя", _change_hero)
	_button(buttons, "В меню", _back)
	_defeat.hide()


## Карточки героев: портрет, пассивка, навык. Забег стоит, пока герой не выбран.
func _build_heroes() -> void:
	if settings.heroes.size() < 2:
		return
	_hero_panel = PanelContainer.new()
	_hero_panel.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	_hero_panel.z_index = 10
	add_child(_hero_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_hero_panel.add_child(content)
	_label(content, "Кто встанет в сторожку?", 24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	for index: int in settings.heroes.size():
		var hero: RitualHeroData = settings.heroes[index]
		var card: VBoxContainer = VBoxContainer.new()
		card.custom_minimum_size = Vector2(250, 0)
		card.add_theme_constant_override("separation", 8)
		row.add_child(card)
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = load(hero.portrait) as Texture2D
		portrait.custom_minimum_size = Vector2(250, 170)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(portrait)
		var title: Label = _label(card, hero.display_name, 20)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", DuskTheme.GOLD)
		# HP и перезарядка - главное отличие героев в забеге (docs/37 HER-4).
		var vitals: Label = _label(card, "♥ %d · умение раз в %d с" % [hero.hp,
			hero.cooldown_ticks / settings.combat.ticks_per_second], 15)
		vitals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vitals.add_theme_color_override("font_color", Color("e7b2a4"))
		for text: String in [hero.passive_text, hero.skill_text]:
			var line: Label = _label(card, text, 18)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(250, 0)
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(spacer)
		var button: Button = _button(card, "Выбрать", _pick_hero.bind(index))
		button.add_theme_font_size_override("font_size", 18)
	_hero_panel.hide()


func _show_heroes() -> void:
	if _hero_panel == null or not settings.is_endless():
		return
	_paused = true
	_hero_panel.show()
	_hero_panel.reset_size()
	_hero_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_message.text = "Выберите героя: он стоит в сторожке, его здоровье — здоровье забега."


func _pick_hero(index: int) -> void:
	_hero_choice = index
	_hero_panel.hide()
	_reset(0)


## Ещё забег тем же героем (docs/37 HER-4); сменить героя - отдельная кнопка.
func _again() -> void:
	_reset(0)


func _change_hero() -> void:
	_reset(0)
	_show_heroes()


## Выбор дара за босса: игра стоит (симуляция не идёт), пока не выбран один из трёх.
func _build_gifts() -> void:
	_gift_panel = PanelContainer.new()
	_gift_panel.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	_gift_panel.z_index = 10
	add_child(_gift_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_gift_panel.add_child(content)
	_label(content, "Босс повержен! Выберите дар:", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gift_buttons = VBoxContainer.new()
	_gift_buttons.add_theme_constant_override("separation", 8)
	content.add_child(_gift_buttons)
	_gift_panel.hide()


## Карточки усилений рассвета: пересобираются при новом выборе, стоят над доком по центру.
func _refresh_boons() -> void:
	if _boon_panel == null:
		return
	var key: String = str(trial.boon_choice)
	if key != _boon_key:
		_boon_key = key
		for child: Node in _boon_buttons.get_children():
			_boon_buttons.remove_child(child)
			child.queue_free()
		for index: int in trial.boon_choice:
			var boon: RitualGiftData = settings.boons[index]
			var button: Button = _button(_boon_buttons, "%s\n\n%s" % [boon.display_name, boon.description],
				_take_boon.bind(index))
			button.name = "Boon_%s" % boon.id
			button.custom_minimum_size = Vector2(190, 200)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 18)
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 56)
			button.add_theme_stylebox_override("normal", DuskTheme.panel(Color(0.05, 0.08, 0.12, 0.95),
					GodSymbols.get_color(boon.god) if boon.god != &"" else DuskTheme.GLASS_EDGE, 14))
			button.icon = GodSymbols.get_icon(boon.god) if boon.god != &"" else BOON_ICON
		_boon_panel.reset_size()
	_boon_panel.visible = not trial.boon_choice.is_empty() and trial.phase == RitualTrial.Phase.RUNNING
	_boon_shade.visible = _boon_panel.visible
	if _boon_panel.visible:
		_boon_panel.position = Vector2((size.x - _boon_panel.size.x) * 0.5,
			(size.y - RitualDock.HEIGHT - _boon_panel.size.y) * 0.5)


func _take_boon(index: int) -> void:
	var boon: RitualGiftData = settings.boons[index]
	if _issue(RitualCommand.new(RitualCommand.Action.BOON, index)):
		_message.text = "Усиление: %s" % boon.display_name


func _buy_supply(kind: int) -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.BUY_SUPPLY, kind)):
		_message.text = "Куплено: %s" % RitualTrial.SUPPLY_NAMES[kind].to_lower()


func _refresh_supply_menu() -> void:
	if _supply_menu == null:
		return
	var popup: PopupMenu = _supply_menu.get_popup()
	var at_night: bool = settings.is_night(trial.tick_count)
	_supply_menu.disabled = at_night or trial.phase != RitualTrial.Phase.RUNNING
	_supply_menu.tooltip_text = "Ночью мастера спят: припасы — днём" if at_night else "Купить припас (днём)"
	if popup.item_count != settings.supply_costs.size():
		popup.clear()
		for kind: int in settings.supply_costs.size():
			popup.add_item("", kind)
	for kind: int in settings.supply_costs.size():
		popup.set_item_text(kind, "%s · %d" % [RitualTrial.SUPPLY_NAMES[kind], settings.supply_costs[kind]])
		popup.set_item_disabled(kind, trial.gold < settings.supply_costs[kind])


func _refresh_gifts() -> void:
	var key: String = str(trial.gift_choice)
	if key == _gift_key:
		return
	_gift_key = key
	for child: Node in _gift_buttons.get_children():
		child.queue_free()
	_gift_panel.visible = not trial.gift_choice.is_empty()
	for index: int in trial.gift_choice:
		var gift: RitualGiftData = settings.gifts[index]
		var text: String = "%s — %s" % [gift.display_name, gift.description]
		var hint: String = _gift_hint(gift)
		if not hint.is_empty():
			text += "\n" + hint
		var button: Button = _button(_gift_buttons, text, _choose_gift.bind(index))
		button.custom_minimum_size = Vector2(600, 56)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		if gift.god != &"":
			button.icon = GodSymbols.get_icon(gift.god)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 40)
	_gift_panel.reset_size()
	_gift_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Подсказка к дару (docs/37 BOS-4): сколько своих домов этой стихии или чем он поможет городу.
func _gift_hint(gift: RitualGiftData) -> String:
	if gift.god != &"":
		var houses: int = 0
		for tower: TowerState in trial.field.towers:
			houses += int(tower.data.god == gift.god)
		var idol: bool = trial.field.get_idol(gift.god) != null
		var element: String = RitualScoutQueue.element_name(gift.god)
		if houses == 0 and not idol:
			return "У вас нет домов стихии «%s»" % element
		return "Ваших домов стихии «%s»: %d%s" % [element, houses, " · есть её идол" if idol else ""]
	match gift.effect:
		RitualGiftData.Effect.FREE_REPAIR:
			return "Сейчас ремонт всех домов стоит %d" % trial.repair_all_cost()
		RitualGiftData.Effect.HEAL_ILYA:
			return "Здоровье героя: %d из %d" % [trial.hp, trial.max_hp()]
	return "Действует на все %d домов" % trial.field.towers.size()


func _choose_gift(index: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.GIFT, index))


func _show_defeat() -> void:
	var nights: int = trial.nights_survived()
	var record: bool = RitualRunRecord.submit(nights, trial.bosses_killed)
	var best: Dictionary[String, int] = RitualRunRecord.best()
	var seconds: int = trial.tick_count / settings.combat.ticks_per_second
	_defeat_text.text = "%s\nПродержались ночей: %d · рекорд: %d%s\nВремя забега %d:%02d · боссов убито: %d" % [
		trial.result, nights, best["nights"], " — новый!" if record else "", seconds / 60, seconds % 60,
		trial.bosses_killed]
	for child: Node in _defeat_columns.get_children():
		_defeat_columns.remove_child(child)
		child.queue_free()
	var reaction: String = RitualRunStats.best_reaction(trial)
	_defeat_column("Золото: заработано %d, потрачено %d" % [trial.earned, trial.spent], _stats.spend_lines())
	_defeat_column("Урон по домам", _stats.top_damage(5))
	var leaks: PackedStringArray = RitualRunStats.leak_lines(trial)
	if not reaction.is_empty():
		leaks.append("")
		leaks.append("Чаще всего: %s" % reaction)
	_defeat_column("Прорвались", leaks)
	_defeat.reset_size()
	_defeat.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_defeat.show()


func _defeat_column(title: String, lines: PackedStringArray) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 230
	_defeat_columns.add_child(column)
	var head: Label = _label(column, title, 18)
	head.add_theme_color_override("font_color", DuskTheme.GOLD)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 230
	_label(column, "\n".join(lines) if not lines.is_empty() else "—", 14)


func _build_schedule() -> void:
	_schedule = PanelContainer.new()
	add_child(_schedule)
	_schedule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_schedule.offset_left = 24
	_schedule.offset_top = 24
	_schedule.offset_right = -24
	_schedule.offset_bottom = -24
	_schedule.z_index = 10
	_schedule.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	var content: VBoxContainer = VBoxContainer.new()
	_schedule.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	var title: Label = _label(header, "Полное расписание · время от начала опыта", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Закрыть", _hide_schedule)
	_label(content, "Бой на паузе. Все появления известны заранее; оставшиеся враги переходят в следующий день.", 18)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	for cycle: int in 0 if settings.is_endless() else settings.cycles:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		columns.add_child(column)
		_label(column, "Сутки %d" % (cycle + 1), 21)
		for spawn: RitualSpawn in settings.spawns:
			if spawn.at_tick / settings.cycle_ticks != cycle:
				continue
			var seconds: int = spawn.at_tick / settings.combat.ticks_per_second
			var row: Label = _label(column, "%d:%02d  %s" % [seconds / 60, seconds % 60,
				settings.enemies[spawn.mob_index].display_name], 15)
			row.tooltip_text = settings.enemies[spawn.mob_index].description
	_schedule.visible = false


func _show_schedule() -> void:
	if _schedule.visible:
		return
	_schedule_was_paused = _paused
	if not _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_pause_count += 1
	_paused = true
	_accumulator = 0.0
	_schedule.show()
	_refresh()


func _hide_schedule() -> void:
	_schedule.hide()
	_paused = _schedule_was_paused
	_accumulator = 0.0
	_refresh()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	# Без фокуса: иначе пробел (пауза) повторно нажимает последнюю кнопку, например «Продать».
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var style: StyleBox = theme.get_stylebox(state, &"Button").duplicate() as StyleBox
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _reset_selected() -> void:
	_reset(_preset.selected)


func _reset(index: int) -> void:
	# Сид выбирает интерфейс (не симуляция): каждый забег — новые ночи, сид виден в записи.
	trial = RitualTrial.new(settings, index, randi() % 1000000 if settings.is_endless() else -1, _hero_choice)
	if index < _preset.item_count:
		_preset.select(index)
	_board_reset()
	if settings.is_endless():
		_message.text = "Вечер: поставьте первые постройки, ночью придёт нежить. Пробел — пауза."
		return
	_message.text = "Подготовка: перетащите постройки из лавки. Башня на такую же — слияние, ПКМ — поворот, сброс на лавку — продажа." \
		if trial.phase == RitualTrial.Phase.PREP else "Контрольный старт на паузе: перенос требует времени, продажа возвращает половину цены."


func _board_reset() -> void:
	_wear_dawn = -1
	_stats = RitualRunStats.new()
	_stats.watch(trial.field)
	_tower_reactions.clear()
	trial.field.tower_reaction.connect(_count_tower_reaction)
	if _overlay != null:
		_overlay.reset()
	board.trial = trial
	board.selected_id = 0
	board.preview_index = -1
	board.preview_rotation = 0
	board.action = &""
	_paused = true
	_pause_count = 0
	_paused_seconds = 0.0
	_saved_result = false
	_accumulator = 0.0
	if _defeat != null:
		_defeat.hide()
	# Бесконечный забег идёт сразу: вечер и есть время на подготовку (docs/34 §8).
	_paused = not settings.is_endless()
	_refresh()


func _issue(command: RitualCommand) -> bool:
	var before: int = trial.gold
	var error: String = trial.execute(command)
	if error.is_empty():
		_stats.add_spend(command.action, before - trial.gold)
	_message.text = error if not error.is_empty() else "Приказ принят"
	_sound_bank.play(_command_sound(command) if error.is_empty() else &"click")
	_refresh()
	return error.is_empty()


func _command_sound(command: RitualCommand) -> StringName:
	match command.action:
		RitualCommand.Action.BUY:
			return &"merge" if command.tower_id != 0 else &"buy"
		RitualCommand.Action.SELL:
			return &"sell"
		RitualCommand.Action.MERGE, RitualCommand.Action.RITE:
			return &"merge"
		RitualCommand.Action.SKILL:
			return &"skill"
	return &"click"


func _start() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.START)):
		_paused = false
		_accumulator = 0.0
	_refresh()


func _toggle_speed() -> void:
	_speed = _speed % 3 + 1
	_fast_button.text = "×%d" % _speed


func _pause() -> void:
	if _hero_panel != null and _hero_panel.visible:
		return
	if trial.phase == RitualTrial.Phase.PREP:
		_start()
		return
	_paused = not _paused
	if _paused:
		_pause_count += 1
	_accumulator = 0.0
	_refresh()


func _step() -> void:
	if trial.phase == RitualTrial.Phase.PREP:
		if not _issue(RitualCommand.new(RitualCommand.Action.START)):
			return
	_paused = true
	trial.tick()
	_refresh()


func _process(delta: float) -> void:
	if trial == null:
		return
	if _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_paused_seconds += delta
	if not _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_accumulator += delta * settings.combat.ticks_per_second * _speed
		var steps: int = mini(MAX_FRAME_TICKS, int(_accumulator))
		for index: int in steps:
			trial.tick()
		_accumulator -= steps
	if trial.phase == RitualTrial.Phase.OVER and not _saved_result:
		_save_result()
		if settings.is_endless():
			_show_defeat()
	_refresh()
	_age_toast(delta)
	if _overlay != null:
		var modal: bool = (_hero_panel != null and _hero_panel.visible) or _gift_panel.visible or _defeat.visible
		_overlay.refresh(trial, _paused, modal, delta)


## Сообщение гаснет через TOAST_SECONDS после последней смены текста; подсказка выбора цели
## держится, пока выбор не закончен.
func _age_toast(delta: float) -> void:
	if _message.text != _toast_text:
		_toast_text = _message.text
		_toast_age = 0.0
	_toast_age += delta
	_toast.visible = not _toast_text.is_empty() and (_toast_age < TOAST_SECONDS or board.action != &"")


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.keycode == KEY_ALT and settings.uses_plots():
		board.show_all_marks = key.pressed
		board.queue_redraw()
	if key != null and key.pressed and not key.echo and _dock != null:
		if key.keycode == KEY_TAB:
			_cycle_same_type()
			get_viewport().set_input_as_handled()
			return
		if key.keycode in [KEY_4, KEY_5, KEY_6, KEY_7] and key.keycode - KEY_4 < trial.field.idols.size():
			_open_idol(key.keycode - KEY_4)
			return
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_Q and not _skill_button.disabled:
			_choose_skill()
		elif key.keycode == KEY_F and not _palisade_button.disabled:
			_choose_palisade()
		elif key.keycode == KEY_SPACE:
			_pause()
		elif key.keycode == KEY_X:
			_toggle_speed()
		elif key.keycode in [KEY_1, KEY_2, KEY_3] and _supply_buttons.size() == 3:
			var kind: int = key.keycode - KEY_1
			if not _supply_buttons[kind].disabled:
				_supply_pressed(kind)
		elif key.keycode == KEY_R and not settings.uses_plots() and board.action in [&"buy", &"move"]:
			board.preview_rotation = (board.preview_rotation + 1) % TowerState.ROTATIONS
			board.queue_redraw()
		elif key.keycode == KEY_F10 and settings.is_endless():
			_fps.visible = not _fps.visible
			_hud._speed_button.visible = _fps.visible
	if event.is_action_pressed(&"ui_cancel"):
		if _schedule.visible:
			_hide_schedule()
			get_viewport().set_input_as_handled()
			return
		if _idol_popup != null and _idol_popup.visible:
			_idol_popup.close_popup()
			get_viewport().set_input_as_handled()
			return
		_cancel_aim()
		board.selected_id = 0
		_refresh()


## Отмена выбора места/цели: покупки, переноса, навыка, припаса, чары.
func _cancel_aim() -> void:
	if board.action != &"":
		_message.text = "Отменено"
	board.preview_index = -1
	board.preview_rotation = 0
	board.action = &""
	board.queue_redraw()


func _choose_purchase(index: int) -> void:
	if settings.is_endless() and board.action == &"buy" and board.preview_index == index:
		# Повторный щелчок по выбранной карточке - отмена (docs/37 UI-6).
		_cancel_aim()
		_refresh()
		return
	board.preview_index = index
	board.selected_id = 0
	board.preview_rotation = 0
	board.action = &"buy"
	_message.text = "Выберите свободный участок. ПКМ/Esc - отмена" if settings.uses_plots() \
		else PLACE_HINT if settings.is_endless() else "Выберите свободные клетки. ПКМ поворачивает фигуру."
	_refresh()


func _buy_rite(index: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.RITE, index))


## Заговор у выбранного идола (docs/37 IDL-2): номер идола едет в команде (tower_id = номер + 1).
func _buy_rite_at(index: int, idol_index: int) -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.RITE, index, Vector2i.ZERO, 0, idol_index + 1)):
		var god: StringName = settings.rites[index].god
		_message.text = "%s: заговор «%s»" % [GodSymbols.get_power_name(god), settings.rites[index].display_name]
		var count: int = trial.idol_rites(trial.field.get_idol(god))
		for milestone: RitualIdolMilestone in settings.milestones_for(god):
			if milestone.rites == count:
				_banner("Веха идола · %s" % milestone.title, milestone.description, GodSymbols.get_color(god))
				_sound_bank.play(&"merge", 0.0)


func _open_idol(index: int) -> void:
	if _idol_popup == null or board.action != &"":
		return
	board.selected_id = 0
	_idol_popup.open(index)
	if board.stage != null:
		board.stage.idol_selected = index
	_refresh()


func _on_idol_closed() -> void:
	if board.stage != null:
		board.stage.idol_selected = -1


## Окно идола сбоку от его фигуры (сама фигура и её огонь остаются видны); в пределах карты.
func _place_idol_popup() -> void:
	if _idol_popup == null or not _idol_popup.visible or board.stage == null:
		return
	_idol_popup.refresh(trial)
	_idol_popup.reset_size()
	var middle: Vector2 = board.stage.idol_screen(_idol_popup.idol_index, 1.4)
	var box: Vector2 = _idol_popup.size
	var at: Vector2 = Vector2(middle.x - box.x - 40.0, middle.y - box.y * 0.5)
	var limit: Rect2 = Rect2(board.map_inset.position, size - board.map_inset.position - board.map_inset.size)
	if at.x < limit.position.x:
		at.x = middle.x + 40.0
	at.x = clampf(at.x, limit.position.x, limit.end.x - box.x)
	at.y = clampf(at.y, limit.position.y, limit.end.y - box.y)
	_idol_popup.position = at


## Баннер важного события: в доке - плашка сверху, в прежней раскладке - строка сообщений.
func _banner(title: String, text: String, color: Color) -> void:
	if _overlay != null:
		_overlay.show_banner(title, text, color)
	else:
		_message.text = "%s. %s" % [title, text]


func _hover_building(index: int) -> void:
	board.highlight_data = settings.combat.towers[index] if index >= 0 else null
	board.queue_redraw()


## Tab: следующий дом того же типа, что выбранный (docs/37 UI-11).
func _cycle_same_type() -> void:
	var current: TowerState = trial.field.get_tower(board.selected_id)
	if current == null:
		return
	var kin: Array[TowerState] = []
	for tower: TowerState in trial.field.towers:
		if tower.data == current.data:
			kin.append(tower)
	board.selected_id = kin[(kin.find(current) + 1) % kin.size()].id
	_refresh()


func _choose_enchant(index: int) -> void:
	_enchant_index = index
	board.action = &"enchant"
	board.preview_index = -1
	_message.text = "Выберите башню для чары «%s». ПКМ — отмена." % settings.enchants[index].display_name


## Состояние лавки для проверок (smoke не обращается к лавке напрямую: так при выходе
## оставались в памяти статические кэши иконок).
func shop_report() -> Dictionary[String, Variant]:
	if _dock != null:
		return {"cards": _dock.chip_count(), "reroll": false, "enchants": false, "gods": 0,
			"catalogue_god": "", "idol_popup": _idol_popup.visible,
			"dock_bottom": _dock.get_global_rect().end.y, "dock_right": _dock.get_global_rect().end.x}
	return {"cards": _shop.visible_offer_count(), "reroll": _shop._reroll.is_visible_in_tree(),
		"enchants": _shop.has_enchants(), "gods": _shop._god_buttons.size(),
		"catalogue_god": String(_shop._catalogue_god)}


func _reroll() -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REROLL))


func _repair_houses(tower_id: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE, 0, Vector2i.ZERO, 0, tower_id))


func _repair_selected() -> void:
	_repair_houses(board.selected_id)


func _upgrade_selected(branch_index: int) -> void:
	var kind: RitualCommand.Action = RitualCommand.Action.UPGRADE if branch_index < 0 \
		else RitualCommand.Action.SPECIALISE
	_issue(RitualCommand.new(kind, branch_index, Vector2i.ZERO, 0, board.selected_id))


func _cancel_from_catalogue() -> void:
	_cancel_aim()
	_refresh()


func _announce_repairs() -> void:
	if not settings.uses_plots() or settings.is_night(trial.tick_count):
		return
	var dawn: int = trial.nights_survived()
	if dawn == _wear_dawn:
		return
	_wear_dawn = dawn
	var worn: int = 0
	for tower: TowerState in trial.field.towers:
		if tower.durability >= 0 and tower.durability * 2 <= settings.max_durability(tower.level):
			worn += 1
	if worn > 0:
		_message.text = "Нужен ремонт: ослабших домов %d. Починить все: %d" % [worn, trial.repair_all_cost()]


func _refresh_building_actions(tower: TowerState) -> void:
	if not settings.uses_plots():
		return
	_sell_button.disabled = tower == null
	_sell_button.text = "Продать" if tower == null else "Продать · %d" % trial.sell_value(tower)
	var can_upgrade: bool = tower != null and tower.level < settings.combat.max_tower_level
	var at_night: bool = settings.is_night(trial.tick_count)
	_upgrade_surcharge.visible = can_upgrade and at_night
	_upgrade_surcharge.tooltip_text = "Мастера спят. Ночной вызов: +%d%% к цене, стройка %d с." % [
		settings.night_cost_percent - 100, settings.night_install_ticks / settings.combat.ticks_per_second]
	_color_build_price(_upgrade_button, at_night)
	_upgrade_button.visible = can_upgrade and tower.level != 2
	if _upgrade_button.visible:
		_upgrade_button.text = "Улучшить · %d" % trial.upgrade_cost(tower)
		var error: String = trial.upgrade_error(tower)
		_upgrade_button.disabled = not error.is_empty()
		_upgrade_button.tooltip_text = error if not error.is_empty() else _upgrade_note(tower, -1)
	for index: int in _specialise_buttons.size():
		var button: Button = _specialise_buttons[index]
		_color_build_price(button, at_night)
		button.visible = can_upgrade and tower.level == 2
		if not button.visible:
			continue
		var levels: RitualBuildingLevels = settings.levels_for(tower.data)
		button.text = "%s · %d" % [levels.branches[index].title, trial.upgrade_cost(tower)]
		var error: String = trial.upgrade_error(tower, index)
		button.disabled = not error.is_empty()
		button.tooltip_text = error if not error.is_empty() else _upgrade_note(tower, index)


func _color_build_price(button: Button, at_night: bool) -> void:
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		if at_night:
			button.add_theme_color_override(key, Color("ffe066"))
		else:
			button.remove_theme_color_override(key)


func _display_dps(tower: TowerState) -> int:
	return trial.field.get_tower_damage(tower) * settings.combat.ticks_per_second \
		* trial.field.get_tower_targets(tower) / maxi(1, trial.field.get_tower_cooldown(tower))


func _upgrade_note(tower: TowerState, branch_index: int) -> String:
	var preview: RitualTower = trial.upgrade_preview(tower, branch_index)
	if preview == null:
		return "Выберите специализацию"
	return "%s: %s\nУрон/с по целям: %d, после улучшения %d\nСтройка %d с" % [
		settings.level_name(preview.level), settings.level_behavior(preview).note,
		_display_dps(tower), _display_dps(preview),
		(settings.night_install_ticks if settings.is_night(trial.tick_count)
			else settings.install_ticks) / settings.combat.ticks_per_second]


func _refresh_wear(selected: TowerState) -> void:
	if _repair_all_button == null:
		return
	var total: int = trial.repair_all_cost()
	_repair_all_button.text = "Починить всё · %d" % total
	_repair_all_button.disabled = total == 0 or trial.gold < total
	# Чинить нечего — кнопки нет (critique_2 п. 27: «Починить всё · 0» висела всегда).
	if _dock != null:
		_repair_all_button.visible = total > 0
	var one: int = trial.repair_cost(selected) if selected != null else 0
	_repair_house_button.visible = one > 0
	_repair_house_button.text = "Починить дом · %d" % one
	_repair_house_button.disabled = trial.gold < one


func _repair() -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REPAIR))


func _grow() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.STREET)):
		var street: RitualStreetData = settings.streets[trial.street_nights.size() - 1]
		if _dock != null:
			# Новый тир открылся — сразу показать его вкладку каталога.
			if trial.city_level() <= 3:
				_dock.show_tier(trial.city_level())
			var text: String = street.summary
			if not street.path_cells.is_empty():
				text += "\nНовый вход — с ночи %d" % trial.street_nights[-1]
			_banner("Город %d · %s" % [trial.city_level(), street.title], text, DuskTheme.GOLD)
			return
		_message.text = "%s пристроена: места под дома уже открыты, вход для нежити — с ночи %d" % [
			street.title, trial.street_nights[-1]]


## Завал проулка (docs/37 ALY-1): быстрые враги больше не срезают; разбор бесплатный.
func _toggle_barricade(index: int) -> void:
	var closed: bool = index < trial.barricades.size() and trial.barricades[index]
	if _issue(RitualCommand.new(RitualCommand.Action.BARRICADE, index)):
		_message.text = "Завал разобран: проулок снова открыт" if closed \
			else "Проулок завален: все идут по дороге"


func _refresh_barricades() -> void:
	for index: int in _barricade_buttons.size():
		var button: Button = _barricade_buttons[index]
		var alley: RitualAlley = settings.alleys[index]
		button.visible = trial.city_level() >= alley.city_level
		var closed: bool = index < trial.barricades.size() and trial.barricades[index]
		# Коротко (critique_3 п. 54): две кнопки города в ряд; что делает завал — в подсказке.
		button.text = "Разобрать завал" if closed else "Завал · %d" % alley.barricade_cost
		button.tooltip_text = "Проулок срезает подкову западной дороги: быстрые враги (упыри, волкодлаки) идут им всегда, остальные — если впереди частокол или смола.\nЗавал закрывает проулок для всех; разбор бесплатный, без возврата."
		button.disabled = trial.phase != RitualTrial.Phase.RUNNING or (not closed and trial.gold < alley.barricade_cost)


## Кнопка улицы: цена следующей; город упёрся в предел — серая.
func _refresh_streets() -> void:
	if _street_button == null:
		return
	if not trial.can_grow():
		_street_button.text = "Город достроен" if _dock != null else "Проклятая земля"
		_street_button.tooltip_text = "Дальше — проклятая земля: больше улиц не пристроить."
		_street_button.disabled = true
		return
	var street: RitualStreetData = settings.streets[trial.street_nights.size()]
	if _dock != null:
		# «Укрепить» обещало защиту, а улица открывает новый вход врагам (critique_2 п. 26).
		_street_button.text = "Новая улица · %d" % street.cost
		_street_button.tooltip_text = "Город %d — %s: %s.\nУчастки под дома — сразу; новый вход для нежити — со следующей ночи.\nОткрывает дома следующего уровня в каталоге." % [
			trial.city_level() + 1, street.title, street.summary]
		_street_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.gold < street.cost
		return
	_street_button.text = "Новая улица · %d" % street.cost
	_street_button.tooltip_text = "%s: места под дома — сразу, новый вход для нежити — со следующей ночи.\nКвартал пустой: застройте его, иначе враги прорвутся.\nПодать: +%d золота каждый рассвет, когда ночь с новым входом пережита." % [
		street.title, street.tribute]
	_street_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.gold < street.cost


const SUPPLY_SHORT: Array[String] = ["Смола", "Чаша", "Оберег"]
const SUPPLY_TIPS: Array[String] = [
	"Смоляная полоса (клавиша 1): на участке дороги враги вдвое медленнее 10 с.",
	"Дождевая чаша (клавиша 2): вся группа в круге мокрая — молния бьёт цепью, проклятие заражает, мороз сковывает.",
	"Оберег сторожки (клавиша 3): следующие 5 прорывов не ранят героя.",
]


func _choose_supply(kind: int) -> void:
	if kind == RitualTrial.Supply.CHARM:
		if _issue(RitualCommand.new(RitualCommand.Action.SUPPLY, 0, Vector2i.ZERO, kind)):
			_message.text = "Оберег на сторожке: следующие %d прорывов не ранят героя." % settings.charm_blocks
		return
	board.action = &"supply"
	board.supply_kind = kind
	board.preview_index = -1
	_message.text = "Укажите точку дороги: %s." % RitualTrial.SUPPLY_NAMES[kind].to_lower()


func _refresh_supplies() -> void:
	var running: bool = trial.phase == RitualTrial.Phase.RUNNING
	var day: bool = not settings.is_night(trial.tick_count)
	for kind: int in _supply_buttons.size():
		var button: Button = _supply_buttons[kind]
		var count: int = trial.supplies[kind]
		var cost: int = settings.supply_costs[kind] if kind < settings.supply_costs.size() else -1
		var buy_tip: String = ""
		if cost >= 0:
			buy_tip = "\nПусто — щелчок днём покупает за %d золота." % cost if day \
					else "\nНочью мастера спят: купить — днём (%d золота)." % cost
		button.tooltip_text = "%s\nКаждый рассвет — один случайный припас, в запасе до %d.%s" % [
			SUPPLY_TIPS[kind], settings.supply_cap, buy_tip]
		if kind == RitualTrial.Supply.CHARM and trial.charm_left > 0:
			button.tooltip_text += "\nЩит на сторожке: ещё %d прорывов." % trial.charm_left
		var buyable: bool = count <= 0 and cost >= 0 and day
		if button is RitualActionTile:
			(button as RitualActionTile).set_state(count, count <= 0, cost if buyable else -1)
		else:
			button.text = "%s ×%d" % [SUPPLY_SHORT[kind], count]
		button.disabled = not running or (count <= 0 and not (buyable and trial.gold >= cost))


## Плитка припаса: есть — выбрать место (оберег — сразу); пусто днём — купить (docs/37 SUP-2).
func _supply_pressed(kind: int) -> void:
	if trial.supplies[kind] > 0:
		_choose_supply(kind)
	elif kind < settings.supply_costs.size():
		_buy_supply(kind)


func _choose_skill() -> void:
	if trial.hero() != null and not trial.hero().needs_spot():
		# Варево без прицела: действует на следующую купленную постройку.
		if _issue(RitualCommand.new(RitualCommand.Action.SKILL)):
			_message.text = "Варево готово: следующая постройка встанет сразу каменной."
		return
	board.action = &"skill"
	board.preview_index = -1
	_message.text = "Укажите точку дороги: враги в круге отлетят назад и замрут на 2 с." \
			if trial.hero() != null and trial.hero().skill == RitualHeroData.Skill.WHISTLE \
			else "Укажите точку дороги. Число у врага — текущий прогноз урона; замах 1 с."


func _choose_palisade() -> void:
	board.action = &"palisade"
	board.preview_index = -1
	_message.text = "Укажите дорогу: установка 2 с, первый тяжёлый расходует частокол."


func _choose_move() -> void:
	var tower: TowerState = trial.field.get_tower(board.selected_id)
	if tower == null:
		_message.text = "Сначала выберите башню"
		return
	board.preview_rotation = tower.rotation
	board.preview_index = -1
	board.action = &"move"
	_message.text = "Выберите место переноса. Во время установки башня не работает."


func _sell() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.SELL, 0, Vector2i.ZERO, 0, board.selected_id)):
		board.selected_id = 0
		board.action = &""


func _cancel_move() -> void:
	if board.action != &"":
		# Кнопка "Отмена" сначала отменяет начатый выбор места, а не только перенос.
		_cancel_aim()
		_refresh()
		return
	_issue(RitualCommand.new(RitualCommand.Action.CANCEL_MOVE, 0, Vector2i.ZERO, 0, board.selected_id))


func _on_cell(cell: Vector2i, right: bool) -> void:
	if _idol_popup != null and _idol_popup.visible:
		_idol_popup.close_popup()
		if right or board.action == &"":
			return
	if right and settings.is_endless() and board.action in [&"buy", &"move"]:
		# В забеге ПКМ отменяет выбор места; поворот фигуры - клавиша R (docs/37 UI-6).
		_cancel_aim()
		_refresh()
		return
	if right and settings.uses_plots():
		_cancel_aim()
		_refresh()
		return
	if right:
		if board.action in [&"buy", &"move"]:
			board.preview_rotation = (board.preview_rotation + 1) % TowerState.ROTATIONS
		elif board.action in [&"skill", &"palisade", &"enchant", &"supply"]:
			# ПКМ при прицеливании — отмена, а не поворот башни под курсором.
			board.action = &""
			_message.text = "Отменено"
		else:
			var tower: TowerState = trial.field.get_tower_at(cell)
			if tower != null:
				_issue(RitualCommand.new(RitualCommand.Action.MOVE, 0, tower.anchor,
					tower.rotation + 1, tower.id))
		board.queue_redraw()
		return
	match board.action:
		&"buy":
			var twin: TowerState = trial.field.get_tower_at(cell)
			var into: int = twin.id if not settings.uses_plots() and twin != null and twin.level == 1 \
					and twin.data == settings.combat.towers[board.preview_index] else 0
			if _issue(RitualCommand.new(RitualCommand.Action.BUY, board.preview_index, cell,
					board.preview_rotation, into)):
				board.action = &""
				board.preview_index = -1
				board.preview_rotation = 0
			elif settings.is_endless() and not trial.field.is_buildable(cell):
				# Щелчок мимо мест под дома (дорога, лес) - отмена выбора.
				_cancel_aim()
		&"move":
			var twin: TowerState = trial.field.get_tower_at(cell)
			var moving: TowerState = trial.field.get_tower(board.selected_id)
			var command: RitualCommand = RitualCommand.new(RitualCommand.Action.MOVE, 0, cell,
				board.preview_rotation, board.selected_id)
			if not settings.uses_plots() and twin != null and moving != null and twin != moving and twin.data == moving.data:
				command = RitualCommand.new(RitualCommand.Action.MERGE, twin.id, Vector2i.ZERO, 0, moving.id)
			if _issue(command):
				board.action = &""
				board.selected_id = twin.id if command.action == RitualCommand.Action.MERGE else board.selected_id
		&"enchant":
			var target: TowerState = trial.field.get_tower_at(cell)
			if target == null:
				_message.text = "Выберите башню для чары"
			elif _issue(RitualCommand.new(RitualCommand.Action.ENCHANT, _enchant_index, Vector2i.ZERO, 0, target.id)):
				board.action = &""
				board.selected_id = target.id
		&"supply":
			var supply_spot: Vector2i = board.road_spot(cell)
			if _issue(RitualCommand.new(RitualCommand.Action.SUPPLY, supply_spot.x, Vector2i.ZERO,
					board.supply_kind, 0, supply_spot.y)):
				board.action = &""
		&"skill", &"palisade":
			var spot: Vector2i = board.road_spot(cell)
			var kind: RitualCommand.Action = RitualCommand.Action.SKILL if board.action == &"skill" \
					else RitualCommand.Action.PALISADE
			if _issue(RitualCommand.new(kind, spot.x, Vector2i.ZERO, 0, 0, spot.y)):
				board.action = &""
		_:
			var tower: TowerState = trial.field.get_tower_at(cell)
			board.selected_id = tower.id if tower != null else 0
	_refresh()


func _capture(path: String = RitualTrialRecord.SNAPSHOT_PATH) -> void:
	_checkpoint = trial.snapshot()
	var error: String = RitualTrialRecord.save_checkpoint(trial, path)
	_message.text = "Снимок сохранён: " + path.trim_prefix("res://") if error.is_empty() else error


func _load_checkpoint() -> void:
	var loaded: RitualTrial = RitualTrialRecord.load_checkpoint(settings)
	if loaded == null:
		_message.text = "Нет подходящего сохранённого снимка"
		return
	_checkpoint = loaded.snapshot()
	_message.text = "Снимок открыт; выберите ветку и нажмите «Ветка из снимка»"


func _restore_branch() -> void:
	if _checkpoint.is_empty():
		_message.text = "Сначала сделайте или откройте снимок"
		return
	var restored: RitualTrial = RitualTrial.from_snapshot(settings, _checkpoint)
	if restored == null:
		_message.text = "Снимок несовместим"
		return
	trial = restored if _branch.selected == 0 else restored.fork_control(_branch.selected as RitualTrial.ControlMode)
	_board_reset()
	_message.text = "Восстановлено исходное состояние. Продолжите бой; новые ветки не наследуют изменения друг друга."


func _save_result() -> void:
	var path: String = RitualTrialRecord.save_result(trial,
		{"pause_count": _pause_count, "paused_seconds": snappedf(_paused_seconds, 0.1)})
	if path.is_empty():
		_message.text = "Не удалось сохранить запись опыта"
		return
	_saved_result = trial.phase == RitualTrial.Phase.OVER
	_attempts.append("%s: HP %d, живых %d" % [trial.title, trial.hp, trial.field.count_alive_mobs()])
	if _attempts.size() > 3:
		_attempts.remove_at(0)
	_history.text = " | ".join(_attempts)
	# Путь к записи нужен только для проверок, игроку в забеге он ни к чему.
	if not settings.is_endless():
		_message.text = "Запись: " + path.trim_prefix("res://")


## Новая ночь с приметой — объявить её в строке сообщений, пока день и есть время готовиться.
func _announce_omen() -> void:
	if not settings.is_endless() or trial.current_night() == _omen_night or _overlay != null:
		return
	_omen_night = trial.current_night()
	var parts: PackedStringArray = []
	var tribute: int = trial.tribute_due(trial.nights_survived()) if trial.nights_survived() > 0 else 0
	if tribute > 0:
		parts.append("Рассвет: подать с улиц +%d золота." % tribute)
	var night_omen: RitualOmenData = trial.plan().omen(_omen_night)
	if night_omen != null:
		parts.append("Примета ночи %d — %s. %s" % [_omen_night, night_omen.title, night_omen.description])
	if not parts.is_empty():
		_message.text = " ".join(parts)


func _refresh() -> void:
	if _dock != null:
		# До выбора героя док пуст: в нём нет чужого героя по умолчанию (critique_3 п. 53).
		_dock.set_content_visible(_hero_panel == null or not _hero_panel.visible)
	if trial == null:
		return
	var at_night: bool = settings.is_endless() and settings.is_night(trial.tick_count)
	if at_night and not _was_night:
		_tower_reactions.clear()
	if at_night != _was_night and trial.phase == RitualTrial.Phase.RUNNING:
		_sound_bank.play(&"wave" if at_night else &"round", 0.0)
	_was_night = at_night
	_hud.refresh_ritual(trial, _paused)
	_refresh_gifts()
	_announce_omen()
	if _dock != null:
		_dock.refresh_catalogue(trial, board.preview_index if board.action == &"buy" else -1)
		_place_idol_popup()
	else:
		_shop.refresh_ritual(trial)
		_shop.mark_chosen(board.preview_index if board.action == &"buy" else -1)
	for index: int in _idol_slots.size():
		var slot: RitualIdolSlot = _idol_slots[index] as RitualIdolSlot
		slot.trial = trial
		slot.refresh(trial.field.idols[index], true, settings.combat.ticks_per_second)
	var selected: TowerState = trial.field.get_tower(board.selected_id)
	_selection.text = "Башня: не выбрана" if selected == null else _selection_text(selected)
	if _dock != null:
		_refresh_context(selected)
	_refresh_building_actions(selected)
	_refresh_wear(selected)
	_announce_repairs()
	_refresh_streets()
	_refresh_barricades()
	_refresh_supplies()
	_refresh_boons()
	_refresh_supply_menu()
	if settings.is_endless():
		var accusative: String = trial.hero().accusative if trial.hero() != null else "Илью"
		_repair_button.text = "Лечить %s +%d · %d" % [accusative, settings.repair_hp, settings.repair_cost] \
			if _dock == null else "+%d за %d" % [settings.repair_hp, settings.repair_cost]
		_repair_button.tooltip_text = "%s в сторожке +%d HP за %d золота (не выше %d). Враг, дошедший до сторожки, бьёт героя." % [
			trial.hero_name(), settings.repair_hp, settings.repair_cost, trial.max_hp()]
	_repair_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.hp >= trial.max_hp() \
			or trial.gold < settings.repair_cost
	if _dock == null:
		_shop._selection_panel.visible = selected != null
	if settings.is_endless():
		_scout.refresh(trial)
	var threats: PackedStringArray = _threat_names()
	_threat.text = trial.result if trial.phase == RitualTrial.Phase.OVER else "Далее: " + " · ".join(threats)
	board.queue_redraw()


## Правая часть дока: выбранный дом (название и уровень отдельно, детали ниже) или город.
func _refresh_context(selected: TowerState) -> void:
	_dock.house_actions.visible = selected != null
	_dock.city_actions.visible = selected == null
	if selected != null:
		var lines: PackedStringArray = _selection_text(selected).split("\n", true, 1)
		_selection_title.text = lines[0]
		_selection.text = lines[1] if lines.size() > 1 else ""
		# В доке видно две строки; всё описание дома — в подсказке.
		_selection_title.tooltip_text = _selection.text
		_selection.tooltip_text = _selection.text
		return
	var free: int = 0
	for cell: Vector2i in trial.field.get_buildable_cells():
		free += int(trial.field.get_tower_at(cell) == null)
	_selection_title.text = "Город %d" % trial.city_level()
	# Статус одной строкой; инструкции — в подсказке (critique_2 п. 25).
	_selection.text = "Свободно участков: %d · домов: %d" % [free, trial.field.towers.size()]
	_selection_title.tooltip_text = "Идолы — на площади у терема: щёлкните идол (или 4/5/6).\nДом на карте — выбор и улучшение; Alt — уровни всех домов."
	_selection.tooltip_text = _selection_title.tooltip_text


## Выбранная постройка: материал (уровень) и что он даёт, вложения и готовность.
func _selection_text(tower: TowerState) -> String:
	if settings.uses_plots():
		var profile: RitualBuildingLevels = settings.levels_for(tower.data)
		var house: RitualTower = tower as RitualTower
		var branch_name: String = " · " + profile.branches[house.branch].title if house.branch >= 0 else ""
		var full: int = settings.max_durability(tower.level)
		var condition: String = "Молчит" if tower.durability == 0 else "Ослаб" \
			if tower.durability * 2 <= full else "Готов"
		if tower.durability > 0 and tower.durability * 2 <= full:
			condition = "Ослаб, урон %d%%" % settings.worn_damage_percent if tower.data.damage > 0 else "Изношен"
		if tower.is_action_blocked():
			condition = "Строится"
		var next: RitualTower = trial.upgrade_preview(tower)
		var damage: String = "Урон/с по целям %d" % _display_dps(tower)
		if next != null:
			damage += ", после улучшения %d" % _display_dps(next)
		var text: String = "%s · %s%s\n%s · %s · %s\n%s · прочность %d%% · ремонт %d" % [tower.data.display_name,
			settings.level_name(tower.level), branch_name, profile.role, damage, ward_note(settings, tower.data),
			condition, tower.durability * 100 / maxi(1, full), trial.repair_cost(tower)]
		var reactions: String = _reaction_note(tower.id)
		return text + ("\n" + reactions if not reactions.is_empty() else "")
	var behavior: RitualLevelBehavior = settings.level_behavior(tower)
	var level: String = "ур. %d" % tower.level if behavior == null \
			else "%s (%d)" % [settings.level_name(tower.level), tower.level]
	var lines: PackedStringArray = ["#%d %s · %s%s" % [tower.id, tower.data.display_name, level,
		_enchant_names(tower)]]
	var state: String = "устанавливается" if tower.is_action_blocked() else "готова"
	if behavior == null:
		lines.append("Вложено %d · %s" % [tower.invested_total, state])
		return "\n".join(lines)
	# Одной строкой: вторая строка панели выбора уходит под всплывающее сообщение внизу поля.
	var wear: String = ""
	if tower.durability >= 0:
		var full: int = settings.max_durability(tower.level)
		wear = " · прочность %d%%%s" % [tower.durability * 100 / full,
			" — молчит" if tower.durability == 0 else " — ослаб" if tower.durability * 2 <= full else ""]
	return "%s — %s%s · вложено %d%s" % [lines[0], behavior.note, wear, tower.invested_total,
		" · устанавливается" if tower.is_action_blocked() else ""]


func _count_tower_reaction(tower_id: int, reaction_id: StringName) -> void:
	var counts: Dictionary = _tower_reactions.get(tower_id, {})
	counts[reaction_id] = RitualStateCodec.integer(counts.get(reaction_id, 0)) + 1
	_tower_reactions[tower_id] = counts


## «Реакции за ночь: Цепь ×34, Пар ×12» для выбранного дома (docs/37 RX-6).
func _reaction_note(tower_id: int) -> String:
	var counts: Dictionary = _tower_reactions.get(tower_id, {})
	if counts.is_empty():
		return ""
	var parts: PackedStringArray = []
	for id: Variant in counts:
		var title: String = str(id)
		for reaction: ReactionData in settings.combat.reactions:
			if reaction.id == StringName(str(id)):
				title = reaction.display_name
		parts.append("%s ×%d" % [title, RitualStateCodec.integer(counts[id])])
	return "Реакции за ночь: " + ", ".join(parts)


## Как дом бьёт по оберегу навьих щитов (docs/37 RX-11): та же таблица, что в RitualField._hit.
static func ward_note(rules: RitualTrialConfig, data: TowerData) -> String:
	if not data.attacks or data.damage <= 0:
		return "оберег не пробивает"
	var percent: int = rules.ward_other_percent
	if data.tags.has(&"fire"):
		percent = rules.ward_fire_percent
	elif data.tags.has(&"physical"):
		percent = rules.ward_physical_percent
	elif data.tags.has(&"lightning"):
		percent = rules.ward_lightning_percent
	return "по оберегу %d%%" % percent if percent > 0 else "оберег не пробивает"


func _threat_names() -> PackedStringArray:
	var threats: PackedStringArray = []
	if settings.is_endless():
		for pack: RitualPack in trial.night_queue():
			threats.append("%s ×%d" % [settings.enemies[pack.leader].display_name, pack.members.size()])
		return threats
	for index: int in range(trial.next_spawn, mini(trial.next_spawn + 3, settings.spawns.size())):
		var spawn: RitualSpawn = settings.spawns[index]
		threats.append("%d:%02d %s" % [spawn.at_tick / 1200, (spawn.at_tick / 20) % 60,
			settings.enemies[spawn.mob_index].display_name])
	return threats


func _enchant_names(tower: TowerState) -> String:
	var names: PackedStringArray = []
	for rite: RiteData in settings.enchants:
		if tower.has_enchantment(rite.effect):
			names.append(rite.display_name)
	return "" if names.is_empty() else "\n" + ", ".join(names)


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


func _toggle_tools() -> void:
	var controls: Control = find_child("TrialTools", true, false) as Control
	controls.visible = not controls.visible


func _sell_tower(tower_id: int) -> void:
	board.selected_id = tower_id
	_sell()
