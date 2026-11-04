"""Плоская раскладка арены «нуар» (двор за частоколом, как на new_concept/05_arena.jpg).

python3 -I tools/blender/noir/arena_layout.py → assets/noir/arena/arena_layout.json
Берёт линию дороги и клетки из лесной раскладки (assets/arenas/forest/arena_layout.json) и опускает всё
на один уровень: в нуарной арене нет террас, поле — мощёный двор. ArenaLayout3D берёт этот файл, если он есть.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GROUND = 0.0
DECK_LIFT = 0.15  # ArenaLayout3D поднимает площадки на столько — в нуаре плиты лежат прямо на дворе


def main() -> None:
    src = json.loads((ROOT / "assets/arenas/forest/arena_layout.json").read_text())
    out = dict(src)
    out["note"] = "Noir arena: flat courtyard. " + src.get("note", "")
    out["terraces"] = {k: GROUND - DECK_LIFT for k in src["terraces"]}
    out["road"] = [[x, y, GROUND, length] for x, y, _z, length in src["road"]]
    dst = ROOT / "assets/noir/arena/arena_layout.json"
    dst.write_text(json.dumps(out, separators=(",", ":")))
    print(dst)


if __name__ == "__main__":
    main()
