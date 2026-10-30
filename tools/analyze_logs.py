#!/usr/bin/env python3
"""Сводка по логам матчей (JSON Lines из logs/). Для анализа баланса.

Запуск:  python3 tools/analyze_logs.py logs/bots/<папка прогона>
         python3 tools/analyze_logs.py logs/live/<файл>.jsonl
Печатает: длину матчей, кривую по раундам (потери HP, несъеденное золото, доход, башни,
армия, уровень магазина), раунды выбывания и какое соотношение «армия / башни» побеждает.
"""
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def load_matches(path: Path) -> list[list[dict]]:
    files = [path] if path.is_file() else sorted(path.glob("*.jsonl"))
    matches = []
    for file in files:
        with file.open(encoding="utf-8") as stream:
            events = [json.loads(line) for line in stream if line.strip()]
        if any(event["event"] == "match_end" for event in events):
            matches.append(events)
    return matches


def mean(values: list[float]) -> float:
    return statistics.fmean(values) if values else 0.0


def print_match_lengths(matches: list[list[dict]]) -> None:
    rounds = sorted(next(e for e in m if e["event"] == "match_end")["round"] for m in matches)
    print(f"Матчей: {len(matches)}")
    print(f"Раунды: среднее {mean(rounds):.1f}, медиана {statistics.median(rounds)}, "
          f"мин {rounds[0]}, макс {rounds[-1]}")
    histogram = defaultdict(int)
    for value in rounds:
        histogram[value] += 1
    print("  распределение: " + ", ".join(f"{r}:{n}" for r, n in sorted(histogram.items())))


def print_round_curve(matches: list[list[dict]]) -> None:
    by_round: dict[int, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    for events in matches:
        for event in events:
            if event["event"] == "wave_start":
                for player in event["players"]:
                    by_round[event["round"]]["unspent"].append(player["gold"])
            if event["event"] != "round_end":
                continue
            row = by_round[event["round"]]
            for player in event["players"]:
                # Старые логи включали урон после смерти в hp_lost.
                raw = player.get("raw_breach_damage", player["hp_lost"])
                actual = (player["hp_lost"] if "raw_breach_damage" in player else
                          min(player["hp_lost"], max(0, player["hp"] + player["hp_lost"])))
                row["hp_lost"].append(actual)
                row["raw_damage"].append(raw)
                row["lost_any"].append(1.0 if player["hp_lost"] > 0 else 0.0)
                row["hp"].append(player["hp"])
                row["income"].append(player["income"])
                row["towers"].append(len(player["towers"]))
                row["tower_levels"].append(sum(level for _, level in player["towers"]))
                row["cells"].append(player["cells_used"])
                row["army"].append(player["army_units"])
                row["shop"].append(player["shop_level"])
                row["leaks"].append(player["leaks"])
                row["army_dmg"].append(player.get("army_damage", 0))
    print("\nПо раундам (среднее на живого игрока):")
    header = ("раунд", "живых", "-HP", "сыр.урон", "теряли%", "HP", "золото_в_волну", "доход", "башен",
              "ур.башен", "клеток", "армия", "магазин", "прорывов", "урон_армии")
    print(" ".join(f"{h:>8}" for h in header))
    for round_number in sorted(by_round):
        row = by_round[round_number]
        alive = len(row["hp"]) / max(1, len(matches))
        values = (round_number, alive, mean(row["hp_lost"]), mean(row["raw_damage"]), 100 * mean(row["lost_any"]),
                  mean(row["hp"]), mean(row["unspent"]), mean(row["income"]),
                  mean(row["towers"]), mean(row["tower_levels"]), mean(row["cells"]),
                  mean(row["army"]), mean(row["shop"]), mean(row["leaks"]),
                  mean(row["army_dmg"]))
        print(" ".join(f"{v:>8.1f}" if isinstance(v, float) else f"{v:>8}" for v in values))


def print_eliminations(matches: list[list[dict]]) -> None:
    by_place: dict[int, list[int]] = defaultdict(list)
    for events in matches:
        for event in events:
            if event["event"] == "eliminated":
                by_place[event["place"]].append(event["round"])
    print("\nРаунд выбывания по местам: " + ", ".join(
        f"место {place}: {mean(rounds):.1f}" for place, rounds in sorted(by_place.items())))


def print_styles(matches: list[list[dict]]) -> None:
    """Связь доли золота на армию (стиль бота) с местом."""
    buckets: dict[str, list[int]] = defaultdict(list)
    for events in matches:
        start = next(e for e in events if e["event"] == "match_start")
        end = next(e for e in events if e["event"] == "match_end")
        for player in start["players"]:
            share = player.get("bot_army_share", -1)
            label = "человек" if share < 0 else f"армия {share // 20 * 20:>2}–{share // 20 * 20 + 19}%"
            buckets[label].append(end["places"][player["index"]])
    print("\nСтиль → среднее место (меньше — лучше) и доля побед:")
    for label in sorted(buckets):
        places = buckets[label]
        wins = 100 * sum(1 for p in places if p == 1) / len(places)
        print(f"  {label}: место {mean(places):.2f}, побед {wins:.0f}% (игроков {len(places)})")


def print_heroes(matches: list[list[dict]]) -> None:
    """Доля побед, среднее место и раунд выбывания по героям (из match_end)."""
    places: dict[str, list[int]] = defaultdict(list)
    skill_uses: dict[str, list[int]] = defaultdict(list)
    for events in matches:
        end = next(e for e in events if e["event"] == "match_end")
        for index, hero in enumerate(end.get("heroes", [])):
            if hero:
                places[hero].append(end["places"][index])
        last: dict[int, dict] = {}
        for event in events:
            if event["event"] == "round_end":
                for player in event["players"]:
                    last[player["player"]] = player
        for player in last.values():
            if player.get("hero"):
                skill_uses[player["hero"]].append(player.get("skill_uses", 0))
    if not places:
        return
    print("\nГерои → доля побед, среднее место, навык за матч (игроков):")
    rows = sorted(places.items(), key=lambda item: -sum(1 for p in item[1] if p == 1) / len(item[1]))
    for hero, values in rows:
        wins = 100 * sum(1 for p in values if p == 1) / len(values)
        print(f"  {hero:>10}: побед {wins:4.0f}%, место {mean(values):.2f}, "
              f"навык {mean(skill_uses[hero]):.1f} ({len(values)})")


def print_pressure(matches: list[list[dict]]) -> None:
    """Обрывы после спокойных серий, доступ к развитию и длительность без готовности."""
    deaths = abrupt = after_clean = 0
    shop_four, awakened = set(), set()
    player_keys = set()
    first_shop_four, durations, siege_losses = [], [], []
    for match_index, events in enumerate(matches):
        start = next(e for e in events if e["event"] == "match_start")
        config = start.get("config", {})
        tps = config.get("ticks_per_second", 20)
        waves, clean = {}, defaultdict(int)
        siege_leader = -1
        seconds = 0.0
        for event in events:
            number = event.get("round", 0)
            if event["event"] == "round_start":
                siege_leader = event.get("siege_leader", -1)
            elif event["event"] == "wave_start":
                waves = {p["player"]: p for p in event["players"]}
                seconds += event.get("prep_ticks", config.get("prep_ticks", 0)) / tps
                for player in event["players"]:
                    key = match_index, player["player"]
                    player_keys.add(key)
                    if player["shop_level"] == 4 and key not in shop_four:
                        shop_four.add(key)
                        first_shop_four.append(number)
                    if any(p.get("awakening", -1) >= 0 for p in player.get("placements", [])):
                        awakened.add(key)
            elif event["event"] == "round_end":
                seconds += event.get("wave_ticks", 0) / tps
                for player in event["players"]:
                    index = player["player"]
                    before = waves.get(index, {})
                    if index == siege_leader:
                        siege_losses.append(player["hp_lost"])
                    if player["hp"] <= 0:
                        deaths += 1
                        maximum = before.get("max_hp", config.get("hero_hp", 40))
                        abrupt += before.get("hp", 0) * 2 >= maximum
                        after_clean += clean[index] >= 3
                    clean[index] = clean[index] + 1 if player["hp_lost"] == 0 else 0
        durations.append(seconds / 60)
    count = max(1, len(player_keys))
    print("\nДавление и развитие (боты, не оценка удовольствия):")
    print(f"  смертей {deaths}, из >= половины HP {abrupt}, после >=3 чистых волн {after_clean}")
    print(f"  магазин 4: {100 * len(shop_four) / count:.1f}% игроков, "
          f"первый доступ в среднем р{mean(first_shop_four):.1f}; "
          f"пробуждение: {100 * len(awakened) / count:.1f}%")
    print(f"  потери лидера осады в среднем: {mean(siege_losses):.1f} HP")
    print(f"  полная подготовка + обычный просмотр боя: {mean(durations):.1f} мин "
          "(без ручной готовности, пауз, выбора героя и кнопки ×2)")


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    matches = load_matches(Path(sys.argv[1]))
    if not matches:
        print("Нет законченных матчей в логах.")
        sys.exit(1)
    print_match_lengths(matches)
    print_round_curve(matches)
    print_eliminations(matches)
    print_styles(matches)
    print_heroes(matches)
    print_pressure(matches)


if __name__ == "__main__":
    main()
