---
name: balance-run
description: Прогнать матчи ботов и разобрать логи баланса (balance_sim + analyze_logs), сравнить варианты конфига.
---

# Баланс по логам

1. Прогон (с XDG-префиксом; 100 матчей — 70–150 с → `run_in_background`):
   `godot --headless --path . -s res://tools/balance_sim.gd -- --matches=24 --players=5 --threads=4 --seed=1401`
   Вариант без правки активного конфига: `--config=res://<копия>.tres`. Команды: `--teams=2|3`.
2. Логи: `logs/bots/<дата_время>/` (match_*.jsonl + summary.json). Сводка:
   `python3 -I tools/analyze_logs.py logs/bots/<папка>`. Живые матчи — `logs/live/<файл>.jsonl`.
3. Сравнение: одинаковые сиды, число матчей и версия бота; иначе разница — шум.

Экономия контекста: jsonl не читать целиком; смотреть сводку анализатора,
нужное — `python3 -I -c` по summary.json или `grep` по одному матчу.

Помнить: боты лишь ориентир, решает живая игра автора. Числа менять в `.tres`,
не в коде. Пути прогонов и выводы записать в журнал сессии (`memory/sessions/`).
Логи и `.godot/` в Git не добавлять.
