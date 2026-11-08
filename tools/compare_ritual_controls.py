#!/usr/bin/env python3
"""Сравнение одинаковых контрольных политик до/после исправлений «Обряда»."""
import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("hp", "earned", "gold", "spent", "refunded", "alive", "tick", "result")


def identity(row: dict) -> tuple:
    return row["title"], row["mode"], row["scripted"], row["moves"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before = json.loads(args.before.read_text())
    after = json.loads(args.after.read_text())
    old = {identity(row): row for row in before}
    new = {identity(row): row for row in after}
    assert len(old) == len(before) and len(new) == len(after), "Повтор ключа политики"
    assert old.keys() == new.keys(), "Сравниваются разные политики"
    rows = []
    for key, row in new.items():
        assert all(field in row for field in (
            "events", "commands", "remaining", "idols", "rules_hash", "initial_hash", "simulation_version"
        )), f"Неполный отчёт {key}"
        assert all("remaining" in dawn and "idols" in dawn for dawn in row["dawns"])
        for event in row["events"]:
            if event["event"] == "damage":
                assert all(field in event for field in ("hp_damage", "ward_damage", "protected_by"))
        differences = {field: {"before": old[key][field], "after": row[field]}
                       for field in FIELDS if old[key][field] != row[field]}
        assert old[key]["rejected"] == row["rejected"], f"Изменились отказы приказов {key}"
        rows.append({"title": key[0], "mode": key[1], "scripted": key[2], "moves": key[3],
                     "hp_before": old[key]["hp"], "hp_after": row["hp"], "differences": differences})
    for title in ("Заполненная А", "Заполненная Б"):
        branches = [row for row in after if row["title"] == title]
        assert len(branches) == 3
        assert len({row["initial_hash"] for row in branches}) == 1, "Неодинаковые исходные состояния"
    baseline = args.before.parent
    for filename in ("protected_hashes.json", "ritual_resource_hashes.json"):
        hashes = json.loads((baseline / filename).read_text())
        for relative, expected in hashes.items():
            assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, relative
    old_script = (baseline / "probe_source.gd").read_text()
    new_script = (ROOT / "tools/ritual_trial_probe.gd").read_text()
    def policy(source: str) -> str:
        return source[source.index("\tvar rejected:"):source.index("\tvar report:")]
    assert policy(old_script) == policy(new_script), "Изменён код контрольной политики"
    report = {"same_policies": True, "protected_files_unchanged": True,
              "ritual_parameters_unchanged": True, "same_initial_states_per_branch": True,
              "simulation_version_after": after[0]["simulation_version"], "comparisons": rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    changed = sum(bool(row["differences"]) for row in rows)
    print(f"RITUAL COMPARE: {len(rows)} политик, изменённых исходов {changed}; "
          "старые режимы/параметры сохранены, исходные состояния веток одинаковы")
    for row in rows:
        print(f"  {row['title']} / {row['mode']}: HP {row['hp_before']} → {row['hp_after']}")


if __name__ == "__main__":
    main()
