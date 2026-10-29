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
                row["hp_lost"].append(player["hp_lost"])
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
    header = ("раунд", "живых", "-HP", "теряли%", "HP", "золото_в_волну", "доход", "башен",
              "ур.башен", "клеток", "армия", "магазин", "прорывов", "урон_армии")
    print(" ".join(f"{h:>8}" for h in header))
    for round_number in sorted(by_round):
        row = by_round[round_number]
        alive = len(row["hp"]) / max(1, len(matches))
        values = (round_number, alive, mean(row["hp_lost"]), 100 * mean(row["lost_any"]),
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


if __name__ == "__main__":
    main()
