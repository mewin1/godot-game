extends SceneTree
## Запуск новой сцены, ввод, полная запись/загрузка и возврат в прежнее меню.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


## Основной режим: бесконечный забег идёт сам, ночь приходит после вечера, конец — экран поражения.
func _check_endless(scene: PackedScene) -> void:
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	root.add_child(panel)
	await process_frame
	await process_frame
	_check(panel.settings.is_endless(), "«Играть» ведёт не в бесконечный забег")
	_check(panel._hero_panel != null and panel._hero_panel.visible and panel._paused,
		"Перед забегом нет выбора героя или игра идёт")
	_check(panel._hero_panel.get_global_rect().end.y <= panel.size.y, "Выбор героя не помещается по высоте")
	panel._pick_hero(0)
	_check(not panel._hero_panel.visible, "Выбор героя не закрылся")
	_check(panel.trial.phase == RitualTrial.Phase.RUNNING and not panel._paused, "Забег не идёт сам с вечера")
	_check(panel.get_combined_minimum_size().y <= panel.size.y, "Бесконечный забег не помещается по высоте")
	_check(panel._scout.is_visible_in_tree() and panel._scout._cards.size() == panel.trial.night_queue().size(),
		"Очередь не показывает всю первую ночь")
	_check(panel._scout._cards[0].tooltip_text.contains("Состав"), "В подсказке пачки нет состава")
	_check(panel._scout.get_global_rect().end.x <= panel.size.x, "Очередь разведки за краем экрана")
	_check(panel._supply_buttons.size() == 3, "Нет ряда припасов")
	# "Проверки" и счетчик кадров игроку не показываются (docs/37 BUG-16), открываются по F10.
	_check(not panel._hud._speed_button.visible and not panel._fps.visible, "Отладка видна игроку")
	_check(panel._fast_button.get_global_rect().end.x <= panel.size.x + 1, "Скорость за правым краем экрана")
	panel._toggle_speed()
	_check(panel._speed == 2 and panel._fast_button.text == "×2", "Скорость не переключается")
	var before_fast: int = panel.trial.tick_count
	panel._paused = false
	for frame: int in 5:
		panel._process(0.1)
	_check(panel.trial.tick_count - before_fast >= 18, "На ×2 за 0,5 с прошло меньше 18 тиков")
	panel._toggle_speed()
	panel._toggle_speed()
	_check(panel._speed == 1, "После ×3 скорость не вернулась к ×1")
	for button: Button in panel._supply_buttons:
		_check(button.get_global_rect().end.y <= panel.size.y, "Припас за нижним краем экрана")
	panel._paused = true
	# Лавку проверяем через panel.shop_report(): прямой доступ к panel._shop из этого скрипта
	# оставлял утечку ресурсов при выходе (статические кэши иконок).
	var shop: Dictionary[String, Variant] = panel.shop_report()
	var cards: int = shop["cards"]
	var reroll: bool = shop["reroll"]
	var enchants: bool = shop["enchants"]
	_check(cards == 21, "Нижний док не показывает весь каталог: %d" % cards)
	var dock_bottom: float = shop["dock_bottom"]
	var dock_right: float = shop["dock_right"]
	_check(dock_bottom <= panel.size.y + 1 and dock_right <= panel.size.x + 1, "Док за краем экрана")
	# Идолы на площади (docs/37 IDL-2): окно по щелчку, заговор уходит выбранному идолу.
	panel._open_idol(1)
	var popup_open: bool = panel.shop_report()["idol_popup"]
	_check(popup_open, "Окно идола не открылось")
	panel._buy_rite_at(0, 1)
	_check(panel.trial.field.idols[1].god == panel.settings.rites[0].god and panel.trial.field.idols[0].god == &"",
		"Заговор ушёл не тому идолу")
	panel._on_cell(Vector2i(-1, -1), true)
	popup_open = panel.shop_report()["idol_popup"]
	_check(not popup_open, "ПКМ по карте не закрыл окно идола")
	_check(not reroll, "В каталоге осталась кнопка обновления")
	_check(not enchants, "Ряд чар остался в бесконечном забеге")
	var gold: int = panel.trial.gold
	panel._reroll()
	_check(panel.trial.gold == gold, "Обновление каталога списало золото")
	var offered: int = 0
	var plot: Vector2i = panel.trial.field.get_buildable_cells()[0]
	panel._choose_purchase(offered)
	panel._on_cell(plot, false)
	_check(panel.trial.field.towers.size() == 1, "Вечером нельзя строить с прилавка")
	panel._refresh()
	panel._on_cell(plot, false)
	_check(panel._selection_title.text.contains(panel.settings.level_name(1)), "Не виден материал дома: " + panel._selection_title.text)
	_check(panel._selection.text.contains("прочность 100%"), "Не видна прочность дома: " + panel._selection.text)
	panel.trial.field.towers[0].durability = 0
	panel._repair_houses(0)
	_check(panel.trial.field.towers[0].durability == panel.settings.max_durability(1), "«Починить всё» не чинит")
	cards = panel.shop_report()["cards"]
	_check(cards == 21, "Покупка убрала постройку из постоянного каталога")
	# Уровень города и завал проулка из панели города (docs/37 P3).
	panel.trial.gold += 1000
	panel._grow()
	_check(panel.trial.city_level() == 2 and panel.trial.entrances(1000) == 2, "«Укрепить город» не открыл север")
	panel._toggle_barricade(0)
	_check(panel.trial.barricades[0] and not panel.trial.alley_open(0), "Проулок не завален")
	panel._toggle_barricade(0)
	_check(panel.trial.alley_open(0), "Завал не разобран")
	# Припасы за золото днём (docs/37 SUP-2).
	var tar: int = panel.trial.supplies[RitualTrial.Supply.TAR]
	panel._buy_supply(RitualTrial.Supply.TAR)
	_check(panel.trial.supplies[RitualTrial.Supply.TAR] == tar + 1, "Припас не покупается днём")
	var nights: RitualNightRules = panel.settings.nights
	while panel.trial.tick_count < nights.night_start(1) + 1:
		panel.trial.tick()
	panel._refresh()
	_check(panel._hud._round_label.text == "Ночь 1" and panel._clock.text.begins_with("рассвет через"),
		"Ночь не наступила после вечера: %s %s" % [panel._hud._round_label.text, panel._clock.text])
	var boss: RitualMob = panel.trial.field.spawn_mob(nights.boss_enemy)
	panel.trial.field.deal_mob_damage(boss, boss.hp * 10)
	panel._refresh()
	_check(panel._gift_panel.visible and panel._gift_buttons.get_child_count() == 3, "Нет выбора из 3 даров")
	var stopped_at: int = panel.trial.tick_count
	panel._process(0.5)
	_check(panel.trial.tick_count == stopped_at, "Во время выбора дара игра идёт")
	panel._choose_gift(panel.trial.gift_choice[0])
	_check(not panel._gift_panel.visible and panel.trial.gifts_taken.size() == 1, "Дар не выбирается")
	panel.trial.hp = 1
	while panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
	panel._process(0.0)
	# С 17 ноября (critique_3 п. 73): заголовок «Илья пал» отдельно (Kurale), итог — строкой ниже.
	_check(panel._defeat.visible and panel._defeat_text.text.contains("Ночей"), "Нет экрана поражения")
	_check(panel._defeat_title.text.begins_with("Илья пал"), "Поражение не от гибели Ильи: " + panel._defeat_title.text)
	_check(panel._defeat_columns.get_child_count() == 3, "На экране поражения нет разбивки")
	_check(panel._status.text == "0/%d" % panel.trial.max_hp() and panel._hud._hero_name.text.begins_with("Илья"),
		"В доке нет «Илья» и «HP/макс»: " + panel._status.text)
	# Ещё забег — снова выбор героя; Яга: своё HP и варево без прицела.
	# Ещё забег — тот же герой сразу; «Сменить героя» — выбор (docs/37 HER-4).
	panel._again()
	_check(not panel._hero_panel.visible and panel.trial.hero_index == 0 and panel.trial.phase == RitualTrial.Phase.RUNNING,
		"«Ещё забег» не продолжил тем же героем")
	panel._change_hero()
	_check(panel._hero_panel.visible and panel._paused, "«Сменить героя» не предлагает героя")
	panel._pick_hero(2)
	panel._refresh()
	_check(panel._status.text == "40/40" and panel._hud._hero_name.text.contains("Яга"),
		"В доке не Яга: " + panel._status.text + " " + panel._hud._hero_name.text)
	_check(panel._skill_button.text.begins_with("Варево"), "Навык Яги не варево: " + panel._skill_button.text)
	panel._choose_skill()
	_check(panel.trial.brew_charges == 1 and panel.board.action == &"", "Варево требует прицела или не готово")
	panel.queue_free()
	await process_frame


func _run() -> void:
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	await _check_endless(scene)
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	panel.settings = RitualTrialPanel.TRIAL
	root.add_child(panel)
	await process_frame
	await process_frame
	_check(panel.trial != null, "Нет симуляции опыта")
	_check(panel.size.x >= 1200, "Не задан размер экрана")
	_check(panel.get_combined_minimum_size().x <= panel.size.x, "Интерфейс не помещается по ширине")
	_check(panel.get_combined_minimum_size().y <= panel.size.y, "Интерфейс не помещается по высоте")
	_check(panel._palisade_button.get_global_rect().end.y <= panel.size.y, "Припас за границей окна")
	for slot: IdolSlot in panel._idol_slots:
		_check(slot.get_global_rect().end.y <= panel.size.y, "Идол за границей окна")
	_check(panel._threat.get_global_rect().end.y <= panel.size.y, "Очередь угроз за границей окна")
	panel._choose_purchase(0)
	panel._on_cell(Vector2i(1, 2), false)
	_check(panel.trial.gold == 0, "Отказ покупки списал деньги")
	panel._on_cell(Vector2i(10, 3), false)
	panel.board.action = &""
	panel._on_cell(Vector2i(10, 3), false)
	_check(panel.board.selected_id == 1, "Башня не выбирается")
	panel._choose_move()
	panel._on_cell(Vector2i(9, 8), false)
	_check(panel.trial.field.get_tower(1).anchor == Vector2i(9, 8), "Перенос подготовки не выполнен")
	panel._start()
	panel._paused = true
	for index: int in 35:
		panel.trial.tick()
	panel._choose_skill()
	panel._on_cell(Vector2i(7, 2), false)
	_check(panel.trial.hero_due >= 0, "Нет замаха Ильи")
	panel._capture(RitualTrialRecord.DIRECTORY + "/smoke_checkpoint.bin")
	var expected: int = panel.trial.state_hash()
	var restored: RitualTrial = RitualTrialRecord.load_checkpoint(panel.settings, RitualTrialRecord.DIRECTORY + "/smoke_checkpoint.bin")
	_check(restored != null and restored.state_hash() == expected, "Файл снимка не восстанавливает состояние")
	panel._branch.select(1)
	panel._restore_branch()
	_check(panel.trial.control_mode == RitualTrial.ControlMode.PASSIVE, "Не включён пассивный контроль")
	panel._step()
	_check(panel.trial.hero_due >= 0, "Смена ветки потеряла начатый замах")
	panel._save_result()
	_check(not panel._saved_result, "Промежуточное сохранение ошибочно помечено финальным")
	panel._reset(4)
	_check(panel.trial.phase == RitualTrial.Phase.RUNNING, "Заполненный старт получил подготовку")
	_check(panel._paused, "Заполненный старт должен быть на паузе")
	panel._on_cell(Vector2i(10, 3), false)
	panel._choose_move()
	panel._on_cell(Vector2i(9, 8), false)
	_check(panel.trial.field.get_tower(1).is_action_blocked(), "Перенос заполненного старта бесплатный")
	panel.queue_free()
	await process_frame
	var menu: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
	var menu_node: Control = menu.instantiate() as Control
	root.add_child(menu_node)
	await process_frame
	await process_frame
	var library: Control = menu_node.get_node("%Library") as Control
	_check(library.get_global_rect().end.y <= menu_node.size.y, "Кнопки меню вышли за экран")
	_check(ResourceLoader.exists(ScenePaths.MATCH), "Потерян основной матч")
	_check(ResourceLoader.exists(ScenePaths.SIEGE_TRIAL), "Потеряна прежняя дуэль")
	menu_node.queue_free()
	await process_frame
	if not _failed:
		print("RITUAL SMOKE: OK — бесконечный забег, сцена, ввод, снимок, ветка, запись, старое меню")
	quit(1 if _failed else 0)
