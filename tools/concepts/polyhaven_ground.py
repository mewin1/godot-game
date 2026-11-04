"""Фактуры лесной земли арены из Poly Haven (CC0, source_art/polyhaven) → assets/noir_h3d/arena/ground/.

python3 -I tools/concepts/polyhaven_ground.py
Смешивает их шейдер земли NoirArena3D (GROUND_SHADER). Модели Poly Haven (трава, корни, камни) пробовались
и не подошли по стилю — убраны.
"""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "source_art" / "polyhaven"
OUT = ROOT / "assets" / "noir_h3d" / "arena" / "ground"
GROUND = ["forrest_ground_01", "brown_mud_leaves_01", "forest_leaves_04"]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for g in GROUND:
        for f in (SRC / g).glob("*.jpg"):
            shutil.copy(f, OUT / f.name)
    print("[ph] фактуры земли ->", OUT)


main()
