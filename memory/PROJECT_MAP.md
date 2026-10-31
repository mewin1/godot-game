# Карта проекта для быстрых изменений

Начать с `AGENTS.md`, `memory/CURRENT.md`; перед любым кодом — целиком `DEVELOPMENT.md`.
Правила и контент: `docs/CURRENT_RULES.md`. Индекс документов: `docs/README.md`.
Это навигация, не замена чтения конкретной реализации перед её изменением.

## Где менять конкретное поведение

| Запрос | Основные файлы | Проверка |
|---|---|---|
| Улучшения/цели заговоров | `src/ui/tower_upgrade_guide.gd`, `field_view.gd`, `offer_card.gd` | `tools/rework_smoke.gd` |
| Разбор боя | `src/sim/field_battle_report.gd`, `field_state.gd`, `src/ui/battle_report_text.gd` | `test_battle_report`, `test_analytics`, smoke |
| Учебный стенд | `src/sim/reaction_lesson.gd`, `data/lessons/`, `src/ui/reaction_lab.gd` | `test_reaction_lesson`, `tools/reaction_lab_smoke.gd` |
| Проба защиты | `src/sim/defense_trial.gd`, `src/ui/shop_panel.gd` | `test_defense_trial`, smoke |
| Общая зона реакций | `src/sim/combat_coverage.gd`, `src/view/field_view.gd` | `test_combat_coverage` |
| HTML-демонстрация | `tools/export_gameplay_demo.gd`, `tools/build_gameplay_demo.py` | 48переходов JS, локальный HTML |
| Фазы, пары, призрак, осада, смерть и награды | `src/sim/match_sim.gd` | `test_match`, `test_lobby`, `test_divine_rework` |
| Движение, цели, выстрелы, лечение, убийства | `src/sim/field_state.gd`, `mob_state.gd` | `test_field_state`, `test_buildings_mobs` |
| Ветер, горение, мокрота и вероятностная цепь | `src/sim/divine_combat.gd`, `field_state.gd` | `test_divine_rework`, `test_water_lightning` |
| Статусы, реакции, холод и физический финишер | `src/sim/reaction_resolver.gd`, `data/reactions/`, `divine_combat.gd`, `mob_state.gd` | `test_reactions`, `test_new_idols` |
| Проклятие и разнос ветром | `src/sim/curse_combat.gd`, `wind_reactions.gd` | `test_reactions` |
| Драфт и фильтр контента | `src/sim/pantheon_draft.gd`, `match_sim.gd`, `shop_state.gd`, `player_state.gd` | `test_pantheon_draft` (все 35 четвёрок) |
| Справка реакций и метки в бою | `src/ui/reaction_guide.gd`, `shop_panel.gd`, `src/view/battle_layer.gd` | smoke, живой запуск |
| Покупка, перенос, резерв, подарок, слияние, продажа | `src/sim/player_state.gd`, `tower_state.gd`, `commands/` | `test_economy`, `test_divine_rework`, smoke |
| Витрина, заговоры, вероятность выпадения | `src/sim/shop_state.gd`, `data/game_config.tres`, `data/rites/` | `test_divine_rework`, `test_economy` |
| Идолы и постоянные усиления | `src/sim/idol_state.gd`, `src/sim/data/rite_data.gd`, `player_state.gd` | `test_divine_rework` |
| Начальная армия, покупки, доход, бафы | `src/sim/army_state.gd`, `data/army/`, `data/buffs/`, `player_state.gd` | `test_economy`, `test_heroes`, боты |
| Базовые волны, очередь армии | `src/sim/wave_builder.gd`, `data/game_config.tres` | `test_match`, `test_divine_rework`, боты |
| Путь и доступные клетки | `src/sim/data/board_layout.gd`, `data/board/board_default.tres`, `field_state.gd` | `test_field_state`, `test_divine_rework` |
| Герои, выбор и навыки | `src/sim/heroes/`, `data/heroes/`, `commands/use_hero_skill_command.gd` | `test_heroes`, `test_lobby` |
| Поведение ботов | `src/sim/bot_brain.gd` | детерминизм, боты на тех же сидах |
| Раскладка всего матча, ввод и наблюдение | `src/view/match_screen.gd`, `src/ui/screen_fit.gd` | `tools/rework_smoke.gd`, ручной запуск |
| Лавка/армия, карты, идолы, резерв | `src/ui/shop_panel.gd`, `offer_card.gd`, `idol_slot.gd`, `inventory_bar.gd` | smoke, ручной запуск |
| Перетаскивание, подсветка и ПКМ на поле | `src/view/drag_payload.gd`, `field_view.gd` | smoke, ручной запуск |
| Бой, эффекты, звук, внешний вид | `src/view/battle_layer.gd`, `tower_painter.gd`, `sound_bank.gd`, `visuals/` | запуск; не менять sim ради картинки |
| Верхняя панель, справочник, обучение | `src/ui/match_hud.gd`, `heroes_gallery.gd`, `scenes/how_to_play.tscn` | запуск, smoke |
| Предпросмотр угрозы | `src/ui/army_preview.gd`, `MatchSim.build_incoming_armies()` | `test_match`, smoke |
| Логи и статистика | `src/analytics/match_logger.gd`, `bot_match_runner.gd`, `tools/analyze_logs.py` | `test_analytics`, сравнение логов |

В таблице короткие имена скриптов относятся к той же папке, что первый полный путь строки.
Тесты находятся в `tests/unit/test_<имя>.gd`.

## Как добавлять контент

- **Постройка:** `TowerData` → `data/towers/<id>.tres` → активный список `config.towers`.
  Графика: SVG в `assets/towers/`, ресурс `data/visuals/towers/`, запись в visual catalog.
  Уникальное правило — маленький компонент поведения; не добавлять проверки имени башни в UI.
- Проверка сочетания воды и Перуна: `tools/water_strategy_probe.gd` — равные
  вложения/площадь, плотные и редкие/быстрые пачки. Это отдельные бои, не матчи.
- **Моб:** `MobData` → `data/mobs/`; путь покупки через `ArmyUpgradeData` в `data/army/`
  и активном `config.army_upgrades`. Возможный бесплатный баф — `data/buffs/`.
  Добавить визуальный ресурс и описание контрмер. Базовые особые волны сейчас отключены.
- **Герой:** `HeroData` → `data/heroes/` → активный список `config.heroes`.
  Для новой особенности сначала проверить существующие `HeroEffect` и `HeroSkillData`.
  Проверить портрет/справочник и способность бота использовать навык.
- **Заговор:** `RiteData` → `data/rites/` → активный список `config.rites`.
  Идол усиливается через `IdolState`; чары и пробуждение — через `PlayerState`.
  Цель может быть в резерве. Учесть сохранение при слиянии и предел покупок.
- Наличие `.tres` в папке не означает активность: старый контент сохранён для истории и тестов.
  Решающие списки находятся в `data/game_config.tres`.
- `tests/fixtures/legacy_game_config.tres` — прежний каталог для старых тестов.
  Новые механики и баланс обязательно проверять и на настоящем конфиге игры.

## Команды из корня проекта

Полная проверка с контролем ошибок, даже при коде выхода Godot 0:
`python3 -I tools/check_project.py` (логи в `.godot/checks/`).

Перед отдельной командой Godot добавлять:
`XDG_CONFIG_HOME="$PWD/.godot/local-config" XDG_DATA_HOME="$PWD/.godot/local-data"`.

```bash
godot --path .
godot --headless --path . --editor --quit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_divine_rework -gexit
godot --headless --path . -s res://tools/rework_smoke.gd
godot --headless --path . -s res://tools/balance_sim.gd -- --matches=24 --players=5 --threads=4 --seed=1401
python3 -I tools/analyze_logs.py logs/bots/<папка>
```

Вторая команда — импорт/проверка редактором без окна, не доказательство качества картинки.
В ограниченной среде редактор может сообщать ошибку локального TCP-сокета;
отличать её от ошибок скриптов. Обычный запуск без окна проверяется `--quit-after 2`.
`balance_sim.gd -- --config=res://...` позволяет сравнить локальный вариант без правки
активного конфига; логи сохраняют путь конфига и версию бота.
Пути конкретных прогонов сохранять в журнале; сравнивать одинаковые сиды и одинаковые
версии ботов. Время тиков — игровое время; пауза, ускорение и готовность человека его меняют.

## Границы архитектуры и частые ошибки

- `MatchSim` координирует игроков; `PlayerState` владеет полем, магазином и армией.
- `FieldState` выполняет бой, отдаёт накопленные убийства/прорывы симуляции матча.
  Золото/HP героя начисляет `MatchSim`, не графика.
- Отображение отправляет команды. Новые поля, влияющие на исход, включать в хэш состояния.
  Броски боя — `FieldState.roll_chance()`, отдельный RNG с сидом, копируется призраку.
- Общая перемотка выполняет настоящие тики: ускорять только спрайты нельзя.
- Живые логи могут не иметь `match_end`; полный анализатор такие матчи пропускает.
- Часть документов и активов описывает предыдущие сборки; сначала проверить текущий каталог.
