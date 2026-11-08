"""Раскладка двора PvP: проезд на уровне земли, строительные клетки на кровлях подклетов."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GROUND = 0.0
ROOF = 1.12
DECK_LIFT = 0.15  # Прибавляется к высоте основания в ArenaLayout3D.


def main() -> None:
    src = json.loads((ROOT / "assets/arenas/forest/arena_layout.json").read_text())
    out = dict(src)
    out["note"] = "Noir courtyard: cellar roofs 1.12 m above cartway. " + src.get("note", "")
    out["terraces"] = {k: round(ROOF - DECK_LIFT, 2) for k in src["terraces"]}
    out["road"] = [[x, y, GROUND, length] for x, y, _z, length in src["road"]]
    dst = ROOT / "assets/noir/arena/arena_layout.json"
    dst.write_text(json.dumps(out, separators=(",", ":")))
    print(dst)


if __name__ == "__main__":
    main()
