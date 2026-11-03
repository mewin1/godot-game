---
name: godot-look
description: Посмотреть игру глазами — скриншот матча, запуск через Godot MCP, осмотр узлов. Для проверки визуала и UI после правок view/ui.
---

# Посмотреть на игру

## Скриншот (дёшево, предпочтительно)
`godot --path . -s res://tools/capture_match.gd -- --out=res://output/<имя>.png [флаги]`
(с XDG-префиксом из AGENTS.md). Флаги: `--wave --motion=1.4` (середина волны),
`--first-round`, `--crowded`, `--hero-select`, `--idol-choice`, `--level=N`, `--size=WxH`.
Другая сцена: `tools/screenshot.gd -- --scene=res://scenes/<x>.tscn --out=...`.
Картинку смотреть через Read; при нужде — уменьшить или вырезать область.

## Godot MCP (когда нужно живое состояние)
`run_project` → `game_get_scene_tree` / `game_get_property` / `game_eval` / `game_screenshot` → `stop_project`.
- MCP-инструменты загружать через ToolSearch точечно (`select:mcp__godot__...`), не пачкой.
- `get_debug_output` и `stop_project` возвращают весь лог с десятками WARNING — звать редко.
- `game_screenshot` отдаёт PNG целиком: для серии кадров лучше capture_match.
- Перетаскивание проверять вызовами `_can_drop_data/_drop_data`, не мышью.
- `validate_script` у MCP не нужен: хук проверяет .gd при каждой правке.
- После `stop_project` убедиться: `git diff project.godot` без `[autoload]`/`McpInteractionServer`,
  в корне нет `mcp_interaction_server.gd`.

Визуал оценивает автор: в отчёте писать «проверено скриншотом», а не «выглядит хорошо».
