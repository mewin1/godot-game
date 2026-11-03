---
name: godot-check
description: Проверить код Заставы — GUT, smoke, полная проверка. Использовать после правок sim/ui/view и перед коммитом.
---

# Проверка кода

Все команды Godot — из корня, с префиксом
`XDG_CONFIG_HOME="$PWD/.godot/local-config" XDG_DATA_HOME="$PWD/.godot/local-data"`.

Выбирай самую узкую проверку, которой достаточно:

| Что поменял | Команда |
|---|---|
| Один файл .gd | хук уже проверил при правке (`--check-only`); отдельно не гонять |
| Логика sim | `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=<test_файл> -gexit` |
| Несколько систем | GUT целиком: `... gut_cmdln.gd -gexit` |
| Перед коммитом / веха | `python3 -I tools/check_project.py` (импорт, GUT, smoke; логи `.godot/checks/`) |
| Новый `class_name` или SVG | сначала `godot --headless --path . --import` |

Экономия контекста:
- Вывод GUT резать: `2>&1 | grep -E "Tests|Passing|Failing|Asserts|FAILED|SCRIPT ERROR" | head -30`.
- `check_project.py` уже печатает сводку; полный лог открывать только у упавшего этапа (`tail -40`).
- Успешную проверку без новых правок не повторять.

Ловушки:
- `godot --headless --quit` грузит меню, ошибки экрана матча так не видны.
- Прогон дольше 2 минут — `run_in_background`.
- Баг в sim сначала воспроизвести тестом в `tests/unit/test_*.gd`.
